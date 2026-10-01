"""Point-prompt segmentation backend for the SAM3Segmenter MATLAB app.

Wraps two models from facebookresearch/sam3 behind one small interface:

* "sam3"   - SAM 3 image model with instance interactivity (``predict_inst``),
  the repo's own "SAM 1 task" path for point prompts on still images. Its
  tracker (the SAM 2-style memory model inside SAM 3) is also used to
  propagate an object through a 3D volume, treating slices as video frames.
* "sam3.1" - SAM 3.1 Object Multiplex checkpoint, used through the video
  model with the image as a single-frame video (the repo only exposes 3.1
  weights through the video predictor). 2D only, experimental.

MATLAB cannot enter Python context managers, so every call here sets its own
autocast / inference-mode context. The module also applies runtime
compatibility patches so SAM 3 runs well on pre-Ampere GPUs (e.g. Pascal),
without modifying the cloned repository:

1. ``vitdet.addmm_act`` hard-casts the ViT MLP to bfloat16. It is replaced by
   an equivalent linear + activation that keeps the input dtype.
2. The tracker constructors enter a process-wide bfloat16 autocast that is
   never exited. It is exited after building the model; each call then sets
   the precision it needs explicitly.
3. On GPUs below sm_70, Triton post-processing kernels (connected components,
   NMS, distance transform) are routed to the repo's CPU implementations.

Without 1 and 2, bfloat16 attention on GPUs without native bfloat16 falls
back to the math kernel and needs more than 8 GB of GPU memory.
"""

import contextlib
import gc
import io
import itertools
import os
import sys
import time
import warnings
import weakref

# Keep MATLAB's command window readable: sam3 logs every click at INFO level,
# and a few dependencies emit known, harmless warnings.
os.environ.setdefault("LOG_LEVEL", "WARNING")
os.environ.setdefault("TQDM_DISABLE", "1")  # the app shows its own progress dialog
warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", message=".*Flash Attention is disabled.*")
warnings.filterwarnings("ignore", message=".*TypedStorage is deprecated.*")
warnings.filterwarnings("ignore", message=".*NumPy array is not writable.*")

# MATLAB puts its current folder ("") on sys.path. If that folder contains the
# cloned repo directory "sam3", Python would import it as a namespace package
# instead of the installed sam3 package, so drop it before importing sam3.
sys.path[:] = [p for p in sys.path if p not in ("", ".")]

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image

import sam3

if getattr(sam3, "__file__", None) is None:
    raise ImportError(
        f"'sam3' resolved to the folder {list(sam3.__path__)} instead of the installed "
        "package. Restart Python (terminate(pyenv)) and open the app again."
    )

import sam3.model.vitdet as _vitdet
import sam3.model_builder as _builder


def _addmm_act_keep_dtype(activation, linear, mat1):
    bias = None if linear.bias is None else linear.bias.to(mat1.dtype)
    y = F.linear(mat1, linear.weight.to(mat1.dtype), bias)
    if activation in (F.gelu, torch.nn.GELU):
        return F.gelu(y)
    if activation in (F.relu, torch.nn.ReLU):
        return F.relu(y)
    raise ValueError(f"Unexpected activation {activation}")


_vitdet.addmm_act = _addmm_act_keep_dtype


def _use_cpu_postprocessing_on_old_gpus():
    """Route Triton-only kernels to the repo's CPU versions on GPUs below sm_70.

    Triton cannot compile these kernels for Pascal (sm_6x); without this the
    repo retries the compile on every call and prints the failed PTX.
    """
    if not torch.cuda.is_available() or torch.cuda.get_device_capability(0) >= (7, 0):
        return
    import sam3.model.sam3_tracker_utils as tracker_utils
    import sam3.perflib.connected_components as cc
    import sam3.perflib.nms as nms

    def connected_components(input_tensor):
        labels, counts = cc.connected_components_cpu(input_tensor.cpu())
        return labels.to(input_tensor.device), counts.to(input_tensor.device)

    def generic_nms(ious, scores, iou_threshold=0.5):
        return nms.generic_nms_cpu(ious, scores, iou_threshold).to(ious.device)

    def edt(data):
        from scipy.ndimage import distance_transform_edt

        out = np.stack([distance_transform_edt(d) for d in data.cpu().numpy()])
        return torch.from_numpy(out).to(device=data.device, dtype=torch.float32)

    cc.connected_components = connected_components
    nms.generic_nms = generic_nms
    tracker_utils.edt_triton = edt


_use_cpu_postprocessing_on_old_gpus()


def _exit_global_autocast(*roots):
    """Exit the process-wide bf16 autocast contexts the sam3 constructors enter."""
    seen = set()
    for root in roots:
        mods = root.modules() if isinstance(root, torch.nn.Module) else [root]
        for m in mods:
            ctx = getattr(m, "bf16_context", None)
            if ctx is not None and id(ctx) not in seen:
                seen.add(id(ctx))
                ctx.__exit__(None, None, None)
                m.bf16_context = None
    if torch.is_autocast_enabled("cuda"):
        torch.set_autocast_enabled("cuda", False)


class _VolumeFrames:
    """Slices of a uint8 volume, converted to model input only when the tracker asks.

    Same conversion as the repo's JPEG loader (sam2_utils._load_img_as_tensor):
    RGB, resize to image_size x image_size, scale to [0, 1], normalise with
    mean 0.5 / std 0.5. Converting lazily avoids holding a float copy of the
    whole volume (about 6 MB per slice at 1008 x 1008).
    """

    def __init__(self, volume, first, last, size):
        self.volume, self.first, self.size = volume, first, size
        self.count = last - first + 1

    def __len__(self):
        return self.count

    def __getitem__(self, i):
        img = Image.fromarray(self.volume[self.first + i]).convert("RGB")
        arr = np.asarray(img.resize((self.size, self.size)), dtype=np.float32) / 255.0
        return (torch.from_numpy(arr).permute(2, 0, 1) - 0.5) / 0.5


_SESSIONS = weakref.WeakSet()


class SamSession:
    """One loaded model, the embedding of the current image, and 3D propagation state."""

    def __init__(self):
        # Only one session holds a model: a new app window (or an app that was
        # not closed normally) must not leave a second copy of the model on the GPU.
        for other in list(_SESSIONS):
            other.unload()
        _SESSIONS.add(self)
        self.version = ""
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.dtype = "float32"
        self.fallback_reason = ""
        self._model = None
        self._processor = None
        self._predictor = None
        self._state = None
        self._image = None
        self._obj_id = 1
        self._volume = None
        self._prop = None

    # ------------------------------------------------------------------ load
    def load(self, prefer="sam3", device="auto", precision="auto", checkpoint_path=None, weights_dir=None):
        """Load ``prefer`` ("sam3" or "sam3.1") on ``device`` ("auto", "cuda", "cpu").

        ``precision`` is "auto", "float32", "float16" or "bfloat16" (SAM 3 only;
        SAM 3.1 always runs in bfloat16). "auto" picks bfloat16 on Ampere or newer
        GPUs, float16 on older GPUs and float32 on the CPU. If SAM 3.1 cannot be
        loaded, SAM 3 is loaded instead and the reason is kept in ``fallback_reason``.
        ``weights_dir``: a folder holding sam3.pt / sam3.1_multiplex.pt (e.g. the
        app's "weights" folder); a file found there is used instead of the
        Hugging Face cache, so no download or login is needed.
        """
        prefer, device, precision = str(prefer), str(device), str(precision)
        if device == "auto":
            device = "cuda" if torch.cuda.is_available() else "cpu"
        if device == "cuda" and not torch.cuda.is_available():
            raise RuntimeError("No CUDA GPU is available to PyTorch; choose the CPU device")
        self.device = device
        self.dtype = self._resolve_precision(precision)
        order = ["sam3.1", "sam3"] if prefer == "sam3.1" else ["sam3"]
        self.fallback_reason = ""
        errors = []
        for version in order:
            try:
                self._unload()
                # The repo prints full lists of checkpoint keys while building
                # (hundreds of lines); keep them out of MATLAB's command window.
                with contextlib.redirect_stdout(io.StringIO()):
                    path = checkpoint_path if version == prefer else None
                    if path is None:
                        path = local_checkpoint(version, weights_dir)
                    if version == "sam3.1":
                        self._load_sam31(path)
                    else:
                        self._load_sam3(path)
                self.version = version
                if errors:
                    self.fallback_reason = "; ".join(errors)
                return self.info()
            except Exception as exc:  # noqa: BLE001 - reported back to MATLAB
                errors.append(f"{version}: {type(exc).__name__}: {exc}")
        self._unload()
        raise RuntimeError("Could not load any SAM model. " + " | ".join(errors))

    def _resolve_precision(self, precision):
        if self.device == "cpu":
            return "float32"
        if precision == "auto":
            major = torch.cuda.get_device_capability(0)[0]
            return "bfloat16" if major >= 8 else "float16"
        if precision not in ("float32", "float16", "bfloat16"):
            raise ValueError(f"Unknown precision {precision!r}")
        return precision

    def _load_sam31(self, checkpoint_path):
        if self.device != "cuda":
            raise RuntimeError("SAM 3.1 requires a CUDA GPU")
        if checkpoint_path is None:
            checkpoint_path = _builder.download_ckpt_from_hf(version="sam3.1")
        predictor = _builder.build_sam3_multiplex_video_predictor(
            checkpoint_path=None if checkpoint_path is None else str(checkpoint_path),
            use_fa3=False,  # FlashAttention 3 needs Hopper GPUs
            async_loading_frames=False,
        )
        _exit_global_autocast(predictor, predictor.model)
        self._predictor = predictor
        self._model = predictor.model

    def _load_sam3(self, checkpoint_path):
        model = _builder.build_sam3_image_model(
            device=self.device,
            checkpoint_path=None if checkpoint_path is None else str(checkpoint_path),
            load_from_HF=checkpoint_path is None,
            enable_inst_interactivity=True,
        )
        _exit_global_autocast(model)
        from sam3.model.sam3_image_processor import Sam3Processor

        # The tracker inside the interactive predictor is the same SAM 2-style
        # model that the repo's video model uses; give it the image encoder so
        # it can also propagate through volumes (no second copy of the weights).
        model.inst_interactive_predictor.model.backbone = model.backbone
        self._model = model
        self._processor = Sam3Processor(model, device=self.device)

    def unload(self):
        """Release the model, the volume and free GPU memory."""
        self._unload()
        self._image = None
        self._volume = None

    def _unload(self):
        self._model = self._processor = self._predictor = None
        self._state = None
        self._prop = None
        self.version = ""
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

    # ------------------------------------------------------------- inference
    def _precision(self):
        if self.version == "sam3.1":
            return torch.autocast("cuda", dtype=torch.bfloat16)
        if self.dtype == "float32":
            return torch.autocast(self.device, enabled=False)
        return torch.autocast(self.device, dtype=getattr(torch, self.dtype))

    def set_image(self, image):
        """Set an HxWx3 uint8 RGB image and compute its embedding. Returns seconds."""
        if self._model is None:
            raise RuntimeError("No model loaded; call load() first")
        img = np.ascontiguousarray(np.asarray(image, dtype=np.uint8))
        if img.ndim != 3 or img.shape[2] != 3:
            raise ValueError(f"Expected an HxWx3 uint8 image, got shape {img.shape}")
        t0 = time.time()
        self._image = img
        self._obj_id = 1
        with torch.inference_mode(), self._precision():
            if self.version == "sam3.1":
                # Call init_state directly: the shared start_session passes
                # offload_state_to_cpu, which the multiplex model rejects.
                self._state = self._model.init_state(
                    resource_path=[Image.fromarray(img)],
                    offload_video_to_cpu=False,
                    async_loading_frames=False,
                )
                # Compute (and cache) the frame features now rather than on
                # the first click, so the wait happens while opening the image.
                self._model._prepare_backbone_feats(self._state, 0, reverse=False)
            else:
                chw = torch.from_numpy(img).permute(2, 0, 1).contiguous()
                self._state = self._processor.set_image(chw)
        if self.device == "cuda":
            torch.cuda.synchronize()
        return time.time() - t0

    def predict(self, points_xy, labels):
        """Segment one object from clicks on the current image.

        points_xy : N x 2 pixel coordinates (x, y), zero-based.
        labels    : N values, 1 = include, 0 = exclude.
        Returns (mask uint8 HxW, score float, seconds).
        """
        if self._state is None:
            raise RuntimeError("No image set; call set_image() first")
        pts = np.array(points_xy, dtype=np.float32).reshape(-1, 2)  # copies:
        lbl = np.array(labels, dtype=np.int32).reshape(-1)  # MATLAB arrays are read-only
        if len(pts) != len(lbl):
            raise ValueError(f"Got {len(pts)} points but {len(lbl)} labels")
        h, w = self._image.shape[:2]
        if len(pts) == 0:
            return np.zeros((h, w), np.uint8), 0.0, 0.0
        t0 = time.time()
        with torch.inference_mode(), self._precision():
            if self.version == "sam3.1":
                mask, score = self._predict_sam31(pts, lbl, h, w)
            else:
                mask, score = self._predict_sam3(pts, lbl)
        return mask, score, time.time() - t0

    def _predict_sam3(self, pts, lbl):
        multi = len(pts) == 1  # one click is ambiguous: pick the best of 3
        masks, scores, _ = self._model.predict_inst(
            self._state,
            point_coords=pts,
            point_labels=lbl,
            multimask_output=multi,
        )
        best = int(np.argmax(scores))
        return masks[best].astype(np.uint8), float(scores[best])

    def _predict_sam31(self, pts, lbl, h, w):
        rel = pts / np.array([w, h], dtype=np.float32)
        # The first prompt on a new object only registers it and returns no
        # mask in single-frame mode, so prompt once more if nothing came back.
        for _ in range(2):
            _, out = self._model.add_prompt(
                inference_state=self._state,
                frame_idx=0,
                points=torch.from_numpy(rel),
                point_labels=torch.from_numpy(lbl),
                clear_old_points=True,
                obj_id=self._obj_id,
                rel_coordinates=True,
                output_prob_thresh=0.0,
            )
            if out is None:
                raise RuntimeError("SAM 3.1 object limit reached; reload the image")
            ids = np.asarray(out["out_obj_ids"]).reshape(-1)
            if np.any(ids == self._obj_id):
                break
        hit = np.flatnonzero(ids == self._obj_id)
        if hit.size == 0:
            return np.zeros((h, w), np.uint8), 0.0
        k = int(hit[0])
        mask = np.asarray(out["out_binary_masks"][k]).astype(np.uint8)
        score = float(np.asarray(out["out_probs"]).reshape(-1)[k])
        return mask, score

    def next_object(self):
        """Forget the current object's clicks so the next clicks start a new one."""
        if self.version == "sam3.1" and self._state is not None:
            with torch.inference_mode(), self._precision():
                try:
                    self._model.remove_object(self._state, self._obj_id, frame_idx=0)
                except Exception:  # noqa: BLE001 - fall back to a fresh id
                    pass
            self._obj_id += 1

    # ------------------------------------------------------------- 3D volume
    def volume_begin(self, num_slices, height, width, channels=1):
        """Allocate the volume (slices along the propagation axis) before volume_put."""
        shape = (int(num_slices), int(height), int(width))
        if int(channels) == 3:
            shape += (3,)
        self._prop = None
        self._volume = np.zeros(shape, dtype=np.uint8)

    def volume_put(self, start, chunk):
        """Copy a chunk of uint8 slices (m x H x W [x 3]) starting at zero-based ``start``."""
        data = np.asarray(chunk, dtype=np.uint8)
        if data.ndim == self._volume.ndim - 1:
            data = data[None]
        start = int(start)
        self._volume[start:start + data.shape[0]] = data

    def find_text(self, prompt, threshold=0.5):
        """Find every instance of a short text concept (e.g. "grain") on the current image.

        Returns (masks uint8[K, H, W], scores float[K], boxes float[K, 4] as x0, y0, x1, y1).
        """
        if self.version != "sam3":
            raise RuntimeError("Text prompts need the SAM 3 model")
        if self._state is None:
            raise RuntimeError("No image set; call set_image() first")
        h, w = self._image.shape[:2]
        with torch.inference_mode(), self._precision():
            self._processor.confidence_threshold = float(threshold)
            out = self._processor.set_text_prompt(prompt=str(prompt), state=self._state)
            masks = out["masks"].reshape(-1, h, w).cpu().numpy().astype(np.uint8)
            scores = out["scores"].float().cpu().numpy().reshape(-1)
            boxes = out["boxes"].float().cpu().numpy().reshape(-1, 4)
        order = np.argsort(-scores)
        return masks[order], scores[order], boxes[order]

    def propagate_start(self, slice_idx, label_map, first, last):
        """Prepare tracking of objects through slices ``first..last`` (zero-based).

        ``slice_idx`` is one slice index or an array of them, and ``label_map``
        the matching H x W label map(s) (m x H x W): each object's starting mask
        as its number 1, 2, ... (0 = background). An object may have masks on
        several slices (the same number on each): the tracker then uses all of
        them. The tracker runs forward from the first seeded slice to ``last``
        and backward from the last seeded slice to ``first``. All objects are
        tracked in the same pass. Returns the number of slices.
        """
        if self.version != "sam3":
            raise RuntimeError("3D propagation needs the SAM 3 model")
        if self._volume is None:
            raise RuntimeError("No volume; call volume_begin/volume_put first")
        n, h, w = self._volume.shape[:3]
        slices = [int(v) for v in np.array(slice_idx, dtype=np.int64).reshape(-1)]
        maps = np.array(label_map, dtype=np.int64).reshape(len(slices), h, w)
        first, last = max(0, int(first)), min(n - 1, int(last))
        if any(not first <= sl <= last for sl in slices):
            raise ValueError("Every seeded slice must lie inside the propagation range")
        if not maps.any():
            raise ValueError("label_map contains no object")
        self._prop = None
        tracker = self._model.inst_interactive_predictor.model
        tracker.use_memory_selection = True  # as in the repo's video model
        with torch.inference_mode(), self._precision():
            state = tracker.init_state(
                video_height=h, video_width=w, num_frames=last - first + 1,
                offload_video_to_cpu=True, offload_state_to_cpu=True,
            )
            state["images"] = _VolumeFrames(self._volume, first, last, tracker.image_size)
            for sl, lab in zip(slices, maps):
                for k in np.unique(lab):
                    if k > 0:
                        tracker.add_new_mask(inference_state=state, frame_idx=sl - first, obj_id=int(k),
                                             mask=torch.from_numpy(lab == k))
        lo, hi = min(slices), max(slices)
        forward = tracker.propagate_in_video(
            state, start_frame_idx=lo - first, max_frame_num_to_track=last - lo,
            reverse=False, propagate_preflight=True, tqdm_disable=True)
        backward = tracker.propagate_in_video(
            state, start_frame_idx=hi - first, max_frame_num_to_track=hi - first,
            reverse=True, propagate_preflight=True, tqdm_disable=True)
        self._prop = {
            "tracker": tracker, "state": state, "first": first,
            "frames": itertools.chain(forward, backward),
            "done": set(), "total": last - first + 1, "t0": time.time(),
        }
        return self._prop["total"]

    def propagate_step(self, max_slices=8):
        """Run up to ``max_slices`` more slices of the current propagation.

        Returns (indices int64[m] zero-based, labels uint16[m, H, W], done, total,
        seconds, contested uint8[m, H, W]). ``labels`` holds the object number of
        each pixel (0 = background); where objects overlap, the one with the
        highest mask logit wins, and ``contested`` marks those pixels (claimed by
        two or more objects) so the caller can apply its own contact rule.
        When done == total the propagation is finished and its state released.
        """
        p = self._prop
        if p is None:
            raise RuntimeError("No propagation in progress")
        idx, slices, contested = [], [], []
        with torch.inference_mode(), self._precision():
            for _ in range(int(max_slices)):
                try:
                    frame_idx, obj_ids, _, video_res_masks, _ = next(p["frames"])
                except StopIteration:
                    break
                ids = [int(i) for i in obj_ids]
                if not ids:
                    lab = np.zeros(self._volume.shape[1:3], np.uint16)
                    both = np.zeros(self._volume.shape[1:3], np.uint8)
                else:
                    logits = video_res_masks[:, 0].float()
                    best, arg = logits.max(dim=0)
                    lab_t = torch.tensor(ids, device=arg.device)[arg]
                    lab = torch.where(best > 0, lab_t, 0).cpu().numpy().astype(np.uint16)
                    both = ((logits > 0).sum(dim=0) > 1).cpu().numpy().astype(np.uint8)
                idx.append(p["first"] + int(frame_idx))
                slices.append(lab)
                contested.append(both)
                p["done"].add(int(frame_idx))
        done, total, seconds = len(p["done"]), p["total"], time.time() - p["t0"]
        if done >= total or not idx:
            self.propagate_cancel()
        shape = (0,) + tuple(self._volume.shape[1:3])
        return (np.array(idx, dtype=np.int64),
                np.stack(slices) if slices else np.zeros(shape, np.uint16),
                done, total, seconds,
                np.stack(contested) if contested else np.zeros(shape, np.uint8))

    def propagate_cancel(self):
        """Stop the current propagation and free its memory."""
        if self._prop is not None:
            self._prop["tracker"].use_memory_selection = False
        self._prop = None
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

    def auto_batch_size(self):
        """Objects per propagation pass that fit in the free GPU memory.

        Measured on a GTX 1080 (float16, SAM 3): a pass needs about 1.5 GB on
        top of the loaded model, plus about 0.16 GB per tracked object; a
        0.4 GB margin is kept for other programs. Returns (count, free_gb).
        """
        if self.device != "cuda" or not torch.cuda.is_available():
            return 8, 0.0
        gc.collect()
        torch.cuda.empty_cache()
        free, _ = torch.cuda.mem_get_info()
        free_gb = free / 1e9
        per_object = 0.16 if self.dtype != "float32" else 0.3
        count = int((free_gb - 1.9) // per_object)
        return max(1, min(64, count)), round(free_gb, 2)

    # ----------------------------------------------------------------- info
    def info(self):
        gpu, vram = "", 0.0
        if torch.cuda.is_available():
            props = torch.cuda.get_device_properties(0)
            gpu, vram = props.name, props.total_memory / 1e9
        return {
            "version": self.version,
            "device": self.device,
            "dtype": self.dtype if self.version != "sam3.1" else "bfloat16",
            "gpu": gpu,
            "vram_gb": round(vram, 1),
            "cuda_available": torch.cuda.is_available(),
            "torch": str(torch.__version__),
            "python": sys.executable,
            "fallback_reason": self.fallback_reason,
        }


CHECKPOINTS = {"sam3": ("facebook/sam3", "sam3.pt"), "sam3.1": ("facebook/sam3.1", "sam3.1_multiplex.pt")}


def local_checkpoint(version, weights_dir):
    """Path of a model's checkpoint in weights_dir, or None if it is not there."""
    if not weights_dir:
        return None
    path = os.path.join(str(weights_dir), CHECKPOINTS[str(version)][1])
    return path if os.path.isfile(path) else None


def download_weights(version, weights_dir):
    """Download a model's checkpoint straight into weights_dir (needs Hugging Face
    access and login). Returns the file path."""
    from huggingface_hub import hf_hub_download

    repo, name = CHECKPOINTS[str(version)]
    os.makedirs(str(weights_dir), exist_ok=True)
    return hf_hub_download(repo_id=repo, filename=name, local_dir=str(weights_dir))


def environment_info():
    """Describe the Python side without loading a model (for the app's Model tab)."""
    from huggingface_hub import try_to_load_from_cache

    def cached(repo, name):
        path = try_to_load_from_cache(repo_id=repo, filename=name)
        return path if isinstance(path, str) else ""

    gpu = torch.cuda.get_device_name(0) if torch.cuda.is_available() else ""
    return {
        "python": sys.executable,
        "torch": str(torch.__version__),
        "cuda_available": torch.cuda.is_available(),
        "gpu": gpu,
        "sam3_package": os.path.dirname(sam3.__file__),
        "sam3_checkpoint": cached("facebook/sam3", "sam3.pt"),
        "sam31_checkpoint": cached("facebook/sam3.1", "sam3.1_multiplex.pt"),
    }
