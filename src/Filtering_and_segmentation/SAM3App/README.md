# SAM3Segmenter

A MATLAB R2026b app (v1.8) for interactive, click-based segmentation of `.tif` images and 3D volumes (multi-page TIFF) with Meta's SAM 3 / SAM 3.1 (`facebookresearch/sam3`). The Help tab inside the app holds the full user and setup guide; this file is the developer summary.

## Run

```matlab
cd C:\Users\franc\Documents\Claude\SAM3App
SAM3Segmenter                               % then Import → Open TIFF…
app = SAM3Segmenter; app.openFile("test_images\mri_27slices.tif");   % or open directly
```

## Tabs

| Tab | Contents |
|---|---|
| **Import** | Open TIFF…; **Load labels…** (reload a `.mat` export or label `.tif` onto the open image); file summary (size, slices, bit depth, 8-bit stretch used); preview of the middle slice |
| **Segmentation** | **Click mode** (*Refine one object* or *One object per click*); **Text prompt** + Find all + Min score (SAM 3 concept segmentation: every instance); **View** (XY/XZ/YZ), **Slice** slider/field with **−− − + ++** (±1 slice, ±1/10 of the axis), **⟲/⟳ 90°** view rotation; **Keep objects in one piece** (drops disconnected fragments of new masks); **mode** *Current slice (2D)* or *3D volume (propagate)* with From/To; objects list (multi-select, coloured entries, **Merge selected** / **Delete selected**; with nothing new defined, **Propagate** extends the existing objects on the slice into 3D under their own numbers), opacity, Export labels… |
| **Model and device** | Model (SAM 3 / SAM 3.1), device (auto/GPU/CPU), precision (auto/float32/float16/bfloat16), **Objects per pass** (Auto from free GPU memory, shown next to it; or Custom), Load/Unload, environment and checkpoint details |
| **About** | What the app is, how to cite SAM 3 (BibTeX), license notes (`docs/about.html`) |
| **Help** | Usage, SAM 3 / 3.1 setup on a new computer, troubleshooting (`docs/help.html`) |

Shortcuts on the Segmentation tab: Enter = Add object, Ctrl+Z = Undo, Esc = Clear, mouse wheel = zoom. Right-click removes a pending object (text results / one-per-click 3D) or, in one-per-click mode, a committed object.

Pending objects (text results, one-per-click objects in 3D) are shown in yellow until **Add object** (2D) or **Propagate** (3D). Propagation seeds SAM 3's tracker with the 2D masks (`add_new_mask`) and tracks all objects in one pass (2 objects: 38 s vs 32 s for one, on 20 slices). The view rotation is applied through the view-index map, so clicks, overlays, label writes and the slices sent for propagation are all rotated consistently; data and exports are never rotated.

## 3D volumes

- A multi-page TIFF with equal page sizes is loaded as a rows × cols × slices volume. Data that isn't 8-bit is stretched to 8 bits with one mapping for the whole file (0.5–99.5 percentile from up to 24 sampled pages).
- **Current slice** mode: objects are 2D masks written into the 3D label volume on the shown slice (any view axis).
- **3D volume** mode: click on one slice (a 2D preview appears), then **Propagate through volume**. The slices along the current view axis are sent to Python (about 3 s for 694 × 868 × 856). SAM 3's tracker (the SAM 2-style memory model inside SAM 3, the same weights as the 2D model) follows the object forward and backward through From..To. Progress is shown and can be cancelled; the slices done so far are kept. Check the result on a few slices, then **Add object**.
- Speed on the GTX 1080: about 1.5 s per slice in float16 (2.7 s in float32); the CPU takes about 25 s per slice. A 700-slice range takes about 18 minutes per object.
- Export: a multi-page uint16 TIFF (deflate) with the original size, or a `.mat` file (v7.3) with `labels`, `objects` (id, voxels, score, mode, axis, slice, range, clicks), `sourceFile`, `model`.

## Measured on the GTX 1080 (8 GB)

| | Embedding per slice | Per click | Peak GPU memory |
|---|---|---|---|
| SAM 3, float16 (auto) | 1.4 s | 0.02–0.3 s | ~4.5 GB (5.2 GB while propagating) |
| SAM 3, float32 | 2.6 s | 0.02–0.3 s | 4.7 GB |
| SAM 3, CPU | 23 s | ~1 s | — |
| SAM 3.1 (bfloat16 only) | 45–60 s | ~1.3 s | 9.5 GB (spills into system RAM) |

float16 and float32 masks agree to within a few pixels. SAM 3.1 weights are only exposed through the repo's multiplex *video* predictor. In single-image mode it tends to return the whole object and ignore exclude clicks, so it's experimental, 2D only. If it fails to load, the app falls back to SAM 3.

## Files

```
SAM3App/
├── SAM3Segmenter.m / .xml   App Designer plain-text app (v1.1)
├── python/sam3_backend.py   SamSession: load, set_image, predict, volume_*, propagate_*; environment_info()
├── docs/help.html, about.html
├── dev/appcode/             source of every method/callback body (see "Editing the app")
├── sam3/                    clone of facebookresearch/sam3 (unmodified, pip -e)
├── .venv/                   Python 3.12, torch 2.10.0+cu126, sam3 + deps
└── test_images/             truck_rgb8.tif, truck_gray16_2pages.tif, mri_27slices.tif
```

Checkpoints: `%USERPROFILE%\.cache\huggingface\hub` (sam3.pt 3.45 GB, sam3.1_multiplex.pt 3.5 GB). Hugging Face account `fussegli` is approved and logged in.

## Runtime patches in `sam3_backend.py` (the clone is not modified)

1. `perflib.fused.addmm_act` hard-casts the ViT MLP to bfloat16 → replaced by an equivalent that keeps the input dtype.
2. The tracker constructors switch on a process-wide bfloat16 autocast and never switch it off → switched off after building; each call sets its own precision.
3. On GPUs below sm_70, the Triton kernels (connected components, NMS, distance transform) → the repo's CPU versions.
4. SAM 3.1 `start_session` passes `offload_state_to_cpu`, which `init_state` rejects → `init_state` is called directly.
5. The tracker `init_state` only accepts MP4 files or JPEG folders → volumes are passed as an in-memory, lazily converted frame list (same normalisation as the repo's JPEG loader).
6. MATLAB's current folder shadows the installed `sam3` package (the clone folder has the same name) → `""` is removed from `sys.path` before importing.
7. Logging, tqdm progress bars and the checkpoint-key dumps are silenced so the MATLAB command window stays readable.

Without 1 and 2, SAM 3 needs about 11 s and more than 8 GB per image on Pascal, because attention falls back to the math kernel.

Extra packages the repo doesn't declare: `einops`, `pycocotools`, `psutil`, `triton-windows` (3.6), `scikit-image`; `numpy` < 2.

## Editing the app

App Designer's own save reformats `SAM3Segmenter.m`. If the toolkit's `AppDesignerAgentInterface.open()` is used on that reformatted file, it strips the first character of each callback line. After `open()`, always re-apply **all** bodies from `dev/appcode/` (methods via `addMethod`, callbacks via `setCallbackCode`), then `save()` and run `checkcode`. Edits made in App Designer itself are fine; copy them back into `dev/appcode/` if you keep using the scripted route.

## Python environment in MATLAB

The app sets `pyenv(Version=".venv\Scripts\python.exe", ExecutionMode="OutOfProcess")`, which MATLAB remembers. To go back to your system Python:

```matlab
terminate(pyenv); pyenv(Version="C:\Users\franc\AppData\Local\Programs\Python\Python312\python.exe", ExecutionMode="InProcess")
```

## 3D propagation memory (GTX 1080, float16, SAM 3)

Peak GPU memory for a pass: about 3.75 GB for the model, plus about 1.5 GB, plus about 0.16 GB per tracked object (1 object: 5.2 GB, 8: 6.2 GB, 16: 7.5 GB; 1.6 / 2.5 / 3.7 s per slice). With Windows and other programs, about 7.4 GB is usable, so 16 objects in one pass spill into shared memory and effectively hang. Objects are therefore propagated in passes. *Auto* = floor((free GPU memory − 1.9 GB) / 0.16 GB), from `SamSession.auto_batch_size()` at propagation time. Earlier passes keep voxels where objects overlap.

## Object list, ties and contact rule (v1.8)

- The list shows two groups: **Selected (not propagated)** (clicked objects `Clicked j`, ItemsData −j, plus objects with mode 2D) and **Propagated (3D)**. Entries show the range on the current slicing axis (from `Objects.bbox` = [rMin rMax cMin cMax zMin zMax], kept up to date on add, extend, merge and contact losses; computed by `computeBBoxes` when loading older labels). They are grey when the object is not on the shown slice, and **Only this slice** filters those out. Selecting an object that is not on the slice jumps to the middle of its range.
- **Propagate** tracks only the selected entries of one slice. Clicked objects stay attached to their slice (`ClickView`) while you browse. A selected entry merged with a propagated object gets `target` = that object: it is tracked and added as that object, and a tied 2D object's own voxels are folded into it.
- **Where objects touch** (keep / overwrite / empty) applies within a pass (the backend's `contested` map), between passes, and against `LabelVol` in **Add object**. Voxel counts are updated from gained/lost tallies, and objects that lose voxels get their bbox recomputed.
- The backend keeps a single live `SamSession`: creating one unloads any earlier session, so a second app window (or one closed abnormally) cannot leave a second model copy on the GPU.

- v1.6: clicked objects carry their own slice/axis/rotation and may be on different slices; linked clicked objects (`group`) are one tracked object seeded on several slices (`propagate_start` takes several slices; forward from the first, backward from the last). Runs are grouped by identical seed-slice sets, because objects starting after a run's first slice would have no memory yet.
- v1.7: **Split** (object buttons): select one object, click one point per part (any slice; `SplitState.seeds` are voxel indices), then Apply split / Enter. `splitObject` runs a marker-controlled watershed on `bwdist(points) − bwdist(~object)` inside the object's bbox, so it cuts at necks and otherwise roughly halfway between the points. Part 1 keeps the id.
- v1.8: "Min score" renamed **Text min score** (text prompt only). **Delete all not propagated** / **Delete all 3D** buttons (confirm first); also scriptable: `app.deleteGroup("selected")` / `app.deleteGroup("propagated")`.
- Time estimate: `updateEstimate` = sum over runs/passes of (range + seed spread + 1) slices × base × (1 + 0.08·(objects−1)). `base` is measured by `propagate` and saved with `setpref("SAM3Segmenter", <GPU>_<precision>)`, otherwise taken as 1.1 × the image-embedding time (first estimate on a new GPU). On the GTX 1080 (float16) the measured value is 1.56 s per slice; the prediction for a 2-run test was 28 s against 28 s actual.
- v1.9: `SAM3App\weights` (sam3.pt, sam3.1_multiplex.pt, SAM_LICENSE.txt) is used before the Hugging Face cache (`load(..., weights_dir)`). **Store weights in app folder** (Model tab) copies them from the cache, or downloads SAM 3 there. To install on another PC, copy `SAM3Segmenter.m/.xml`, `python\`, `docs\`, optionally `weights\` (no download/login needed then) and `sam3\`; recreate `.venv`.
