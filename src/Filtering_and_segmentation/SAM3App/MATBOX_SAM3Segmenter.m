classdef MATBOX_SAM3Segmenter < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './SAM3Segmenter.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        MainGrid                        matlab.ui.container.GridLayout
        StatusLabel                     matlab.ui.control.Label
        TabGroup                        matlab.ui.container.TabGroup
        SegmentTab                      matlab.ui.container.Tab
        SegGrid                         matlab.ui.container.GridLayout
        SidePanel                       matlab.ui.container.Panel
        SideGrid                        matlab.ui.container.GridLayout
        HelpLabel                       matlab.ui.control.Label
        OpacitySlider                   matlab.ui.control.Slider
        OpacityLabel                    matlab.ui.control.Label
        ObjectButtonsGrid               matlab.ui.container.GridLayout
        DeleteAllPropagatedButton       matlab.ui.control.Button
        DeleteAllSelectedButton         matlab.ui.control.Button
        SplitObjectButton               matlab.ui.control.Button
        MergeObjectsButton              matlab.ui.control.Button
        DeleteObjectButton              matlab.ui.control.Button
        ObjectsListBox                  matlab.ui.control.ListBox
        ObjectsHeaderGrid               matlab.ui.container.GridLayout
        OnlySliceCheckBox               matlab.ui.control.CheckBox
        ObjectsHeading                  matlab.ui.control.Label
        PropagateInfoLabel              matlab.ui.control.Label
        PropagateButton                 matlab.ui.control.Button
        ContactGrid                     matlab.ui.container.GridLayout
        ContactDropDown                 matlab.ui.control.DropDown
        ContactLabel                    matlab.ui.control.Label
        RangeGrid                       matlab.ui.container.GridLayout
        ToField                         matlab.ui.control.NumericEditField
        ToLabel                         matlab.ui.control.Label
        FromField                       matlab.ui.control.NumericEditField
        FromLabel                       matlab.ui.control.Label
        ModeDropDown                    matlab.ui.control.DropDown
        ModeHeading                     matlab.ui.control.Label
        ConnectedCheckBox               matlab.ui.control.CheckBox
        ScoreGrid                       matlab.ui.container.GridLayout
        ScoreField                      matlab.ui.control.NumericEditField
        ScoreLabel                      matlab.ui.control.Label
        TextGrid                        matlab.ui.container.GridLayout
        FindButton                      matlab.ui.control.Button
        TextPromptField                 matlab.ui.control.EditField
        TextHeading                     matlab.ui.control.Label
        ClickModeDropDown               matlab.ui.control.DropDown
        ClickModeHeading                matlab.ui.control.Label
        SliceGrid                       matlab.ui.container.GridLayout
        RotateRightButton               matlab.ui.control.Button
        RotateLeftButton                matlab.ui.control.Button
        SliceCountLabel                 matlab.ui.control.Label
        SliceEditField                  matlab.ui.control.NumericEditField
        SliceSlider                     matlab.ui.control.Slider
        SliceLabel                      matlab.ui.control.Label
        AxisDropDown                    matlab.ui.control.DropDown
        ViewLabel                       matlab.ui.control.Label
        SliceUpBigButton                matlab.ui.control.Button
        SliceUpButton                   matlab.ui.control.Button
        SliceDownButton                 matlab.ui.control.Button
        SliceDownBigButton              matlab.ui.control.Button
        SegToolGrid                     matlab.ui.container.GridLayout
        CancelandreturntoMATBOXButton   matlab.ui.control.Button
        ExportButton                    matlab.ui.control.Button
        Separator1                      matlab.ui.control.Label
        ResetButton                     matlab.ui.control.Button
        ClearPointsButton               matlab.ui.control.Button
        UndoButton                      matlab.ui.control.Button
        AddObjectButton                 matlab.ui.control.Button
        ImageAxes                       matlab.ui.control.UIAxes
        ModelTab                        matlab.ui.container.Tab
        ModelGrid                       matlab.ui.container.GridLayout
        ModelInfoArea                   matlab.ui.control.TextArea
        ModelFormGrid                   matlab.ui.container.GridLayout
        ModelStatusGrid                 matlab.ui.container.GridLayout
        ModelStatusLabel                matlab.ui.control.Label
        ModelLamp                       matlab.ui.control.Lamp
        StatusFieldLabel                matlab.ui.control.Label
        ModelButtonsGrid                matlab.ui.container.GridLayout
        UnloadModelButton               matlab.ui.control.Button
        LoadModelButton                 matlab.ui.control.Button
        WeightsGrid                     matlab.ui.container.GridLayout
        WeightsInfoLabel                matlab.ui.control.Label
        StoreWeightsButton              matlab.ui.control.Button
        WeightsFieldLabel               matlab.ui.control.Label
        BatchGrid                       matlab.ui.container.GridLayout
        BatchInfoLabel                  matlab.ui.control.Label
        BatchSizeField                  matlab.ui.control.NumericEditField
        BatchModeDropDown               matlab.ui.control.DropDown
        BatchFieldLabel                 matlab.ui.control.Label
        PrecisionDropDown               matlab.ui.control.DropDown
        PrecisionFieldLabel             matlab.ui.control.Label
        DeviceDropDown                  matlab.ui.control.DropDown
        DeviceFieldLabel                matlab.ui.control.Label
        ModelDropDown                   matlab.ui.control.DropDown
        ModelFieldLabel                 matlab.ui.control.Label
        AboutTab                        matlab.ui.container.Tab
        AboutGrid                       matlab.ui.container.GridLayout
        AboutHTML                       matlab.ui.control.HTML
        HelpTab                         matlab.ui.container.Tab
        HelpGrid                        matlab.ui.container.GridLayout
        HelpHTML                        matlab.ui.control.HTML
    end

    properties (Access = private)
        Backend = []
        BaseImage = []
        ClickView = []
        Clicks = []
        CurrentMask = []
        CurrentScore = []
        DeviceKey = []
        Exported = []
        FilePath = []
        FileSummary = []
        IsBusy = []
        IsVolume = []
        LabelOverlay = []
        LabelVol = []
        LastBatch = []
        LoadedKey = []
        LoadedModel = []
        Mask3D = []
        Mask3DInfo = []
        MaskOverlay = []
        NeedsEmbedding = []
        NegMarkers = []
        NextId = []
        Objects = []
        Palette = []
        Pending = []
        PosMarkers = []
        ProjectRoot = []
        RGB = []
        SliceIndex = []
        SpeedPerSlice = []
        SpeedSource = []
        SplitMarkers = []
        SplitState = []
        ViewAxis = []
        ViewIdx = []
        ViewRot = []
        Vol = []
        VolumeSentAxis = []
    end
    
    properties (Access = public)
        SegOutput
    end

    methods (Access = private)

        function addObject(app, voxels, score, mode, axisName, slice, range, points, labels, prompt, bbox)
            % Commit an object: write its voxels (linear indices) into LabelVol and record it,
            % with its bounding box [rowMin rowMax colMin colMax zMin zMax] in the volume.
            if nargin < 11 || isempty(bbox)
                bbox = app.bboxFromVoxels(voxels);
            end
            id = app.NextId;
            app.LabelVol(voxels) = id;
            app.Objects(end + 1) = struct("id", id, "voxels", numel(voxels), "score", score, ...
                "mode", mode, "axis", axisName, "slice", slice, "range", range, ...
                "points", points, "labels", labels, "prompt", prompt, "bbox", bbox, "target", 0);
            app.NextId = id + 1;
            app.Exported = false;
        end
        

        function applySplit(app)
            % Run the split prepared in split mode, then leave split mode.
            st = app.SplitState;
            if isempty(st)
                return
            end
            if numel(st.seeds) < 2
                app.setStatus("Click at least two points inside the object (one per part) before applying the split.");
                return
            end
            app.IsBusy = true;
            busy = onCleanup(@() app.setIdle());
            dlg = uiprogressdlg(app.UIFigure, Title="Split", Message=sprintf("Splitting object %d…", st.id), ...
                Indeterminate="on");
            cleanup = onCleanup(@() delete(dlg));
            newIds = app.splitObject(st.id, st.seeds);
            app.cancelSplit();
            if isempty(newIds)
                app.setStatus("Could not split: the points fall in the same part of the object.");
                return
            end
            app.refreshObjectList([st.id newIds]);
            app.updateOverlays();
            app.setStatus(sprintf("Split object %d into %d parts (%s).", st.id, numel(newIds) + 1, ...
                strjoin("#" + string([st.id newIds]), ", ")));
        end
        

        function n = batchSize(app)
            % Objects per 3D-propagation pass (Model and device tab), and show it.
            % Auto asks the backend how many objects fit in the free GPU memory.
            if app.BatchModeDropDown.Value == "custom"
                n = app.BatchSizeField.Value;
                app.BatchInfoLabel.Text = sprintf("Custom: %d objects per pass", n);
                app.LastBatch = n;
                return
            end
            n = 8;
            if app.LoadedKey == "" || isempty(app.Backend)
                app.BatchInfoLabel.Text = "Auto: decided from the free GPU memory when the model is loaded";
                app.LastBatch = n;
                return
            end
            try
                out = cell(app.Backend.auto_batch_size());
                n = double(out{1});
                freeGB = double(out{2});
                if freeGB > 0
                    app.BatchInfoLabel.Text = sprintf("Auto: %d objects per pass (%.1f GB free GPU memory now)", n, freeGB);
                else
                    app.BatchInfoLabel.Text = sprintf("Auto: %d objects per pass (CPU)", n);
                end
            catch err
                app.BatchInfoLabel.Text = "Auto: 8 objects per pass (could not read GPU memory: " + err.message + ")";
            end
            app.LastBatch = n;
        end
        

        function bbox = bboxFromVoxels(app, voxels)
            % [rowMin rowMax colMin colMax zMin zMax] of linear voxel indices (NaN if none).
            if isempty(voxels)
                bbox = nan(1, 6);
                return
            end
            [r, c, z] = ind2sub(size(app.LabelVol), voxels);
            bbox = [min(r) max(r) min(c) max(c) min(z) max(z)];
        end
        

        function bb = bboxUnion(app, a, b)
            % Smallest box containing boxes a and b ([rMin rMax cMin cMax zMin zMax]; NaN = empty).
            if isempty(a) || any(~isfinite(a))
                bb = b;
                return
            end
            if isempty(b) || any(~isfinite(b))
                bb = a;
                return
            end
            bb = [min(a(1), b(1)) max(a(2), b(2)) min(a(3), b(3)) max(a(4), b(4)) min(a(5), b(5)) max(a(6), b(6))];
        end
        

        function cancelSplit(app)
            % Leave split mode without changing anything.
            app.SplitState = [];
            app.SplitObjectButton.Text = "Split";
            app.updateOverlays();
        end
        

        function clearPoints(app)
            % Forget the clicks, pending objects and mask(s) of the object(s) being segmented.
            app.Clicks = zeros(0, 3);
            app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
            app.CurrentMask = [];
            app.CurrentScore = 0;
            app.discardMask3D();
            app.updateOverlays();
            app.refreshObjectList();
        end
        

        function clickEach(app, xy, isRight, row, col)
            % "One object per click" mode.
            %   2D: a left-click segments a new object from that point alone and adds it
            %       immediately; a right-click deletes the object under the cursor.
            %   3D: a left-click adds a pending object (previewed on this slice); all
            %       pending objects are propagated together.
            is3D = app.IsVolume && app.ModeDropDown.Value == "3D";
            if isRight
                id = double(app.LabelVol(app.ViewIdx(row, col)));
                if id > 0
                    app.deleteObject(id);
                else
                    app.setStatus("Right-click on an object to remove it.");
                end
                return
            end
            if ~isempty(app.Mask3D)
                % Clicking again after a propagation starts a new set of objects.
                app.discardMask3D();
                app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
            end
            if app.LoadedModel == "sam3.1"
                app.Backend.next_object();  % SAM 3.1 keeps object state between prompts
            end
            app.IsBusy = true;
            busy = onCleanup(@() app.setIdle());
            try
                out = cell(app.Backend.predict(xy - 0.5, int32(1)));
            catch err
                uialert(app.UIFigure, err.message, "Segmentation failed");
                return
            end
            mask = app.connectedMask(logical(uint8(out{1})), xy);
            score = double(out{2});
            if ~any(mask(:))
                app.setStatus("No object found at this point.");
                return
            end
            if is3D
                app.Pending(end + 1) = struct("point", xy, "mask", mask, "score", score, "prompt", "", "target", 0, ...
                    "slice", app.SliceIndex, "axis", app.ViewAxis, "rot", app.ViewRot, "group", 0);
                app.ClickView = struct("axis", app.ViewAxis, "slice", app.SliceIndex, "rot", app.ViewRot);
                app.syncPending();
                app.setStatus(sprintf("%d clicked object(s) waiting (last: %d px, score %.2f). Click more objects " + ...
                    "(any slice), merge the ones that belong together, then Propagate through volume.", numel(app.Pending), nnz(mask), score));
                return
            end
            newPixels = app.ViewIdx(mask & app.LabelVol(app.ViewIdx) == 0);
            if isempty(newPixels)
                app.setStatus("This object is already labelled.");
                return
            end
            app.addObject(newPixels, score, "2D", app.ViewAxis, app.SliceIndex, ...
                [app.SliceIndex app.SliceIndex], xy, 1, "");
            id = app.NextId - 1;
            app.refreshObjectList(id);
            app.updateOverlays();
            app.setStatus(sprintf("Added object %d (%d px, score %.2f). Click the next object; right-click removes one.", ...
                id, numel(newPixels), score));
        end
        

        function bb = computeBBoxes(app, ids, dlg)
            % Bounding boxes of objects ids (rows of [rMin rMax cMin cMax zMin zMax]),
            % scanning the label volume once, slice by slice (about 2–30 s for a
            % 515 x 503 x 2517 volume). Used when labels are loaded without ranges.
            [R, C, Z] = size(app.LabelVol);
            N = max([ids(:); 1]);
            all = repmat([inf -inf inf -inf inf -inf], N, 1);
            for z = 1:Z
                S = app.LabelVol(:, :, z);
                idx = find(S);
                if ~isempty(idx)
                    lab = double(S(idx));
                    keep = lab <= N;
                    idx = idx(keep);
                    lab = lab(keep);
                    [r, c] = ind2sub([R C], idx);
                    u = unique(lab);
                    all(:, 1) = min(all(:, 1), accumarray(lab, r, [N 1], @min, inf));
                    all(:, 2) = max(all(:, 2), accumarray(lab, r, [N 1], @max, -inf));
                    all(:, 3) = min(all(:, 3), accumarray(lab, c, [N 1], @min, inf));
                    all(:, 4) = max(all(:, 4), accumarray(lab, c, [N 1], @max, -inf));
                    all(u, 5) = min(all(u, 5), z);
                    all(u, 6) = max(all(u, 6), z);
                end
                if nargin > 2 && mod(z, 50) == 0
                    dlg.Value = z / Z;
                end
            end
            bb = all(ids, :);
            bb(isinf(bb)) = NaN;
        end
        

        function tf = confirmDiscard(app)
            % Ask before throwing away objects that have not been exported.
            tf = true;
            if isempty(app.Objects) || app.Exported
                return
            end
            choice = uiconfirm(app.UIFigure, sprintf("Discard %d object(s) that have not been exported?", ...
                numel(app.Objects)), "Unsaved objects", Options=["Discard", "Cancel"], ...
                DefaultOption="Cancel", CancelOption="Cancel");
            tf = choice == "Discard";
        end
        

        function labels3D = connectedLabels3D(app, labels3D, count)
            % With "Keep objects in one piece" on, keep only the largest 26-connected
            % piece of each propagated object 1..count. Works inside each object's
            % bounding box, so it stays fast and light on large volumes.
            if ~app.ConnectedCheckBox.Value
                return
            end
            sz = size(labels3D);
            for k = 1:count
                idx = find(labels3D == k);
                if isempty(idx)
                    continue
                end
                [r, c, z] = ind2sub(sz, idx);
                rr = min(r):max(r);
                cc = min(c):max(c);
                zz = min(z):max(z);
                sub = labels3D(rr, cc, zz) == k;
                comps = bwconncomp(sub, 26);
                if comps.NumObjects <= 1
                    continue
                end
                [~, best] = max(cellfun(@numel, comps.PixelIdxList));
                drop = sub;
                drop(comps.PixelIdxList{best}) = false;
                block = labels3D(rr, cc, zz);
                block(drop) = 0;
                labels3D(rr, cc, zz) = block;
            end
        end
        

        function mask = connectedMask(app, mask, seedsXY)
            % With "Keep objects in one piece" on, reduce a 2D mask to a single
            % 8-connected piece: the largest piece containing one of the seed points
            % (x, y), or the largest piece overall if no seed lies on the mask.
            if ~app.ConnectedCheckBox.Value || isempty(mask) || ~any(mask(:))
                return
            end
            cc = bwconncomp(mask, 8);
            if cc.NumObjects <= 1
                return
            end
            sizes = cellfun(@numel, cc.PixelIdxList);
            candidates = 1:cc.NumObjects;
            if nargin > 2 && ~isempty(seedsXY)
                [h, w] = size(mask);
                r = min(max(round(seedsXY(:, 2)), 1), h);
                c = min(max(round(seedsXY(:, 1)), 1), w);
                seedIdx = sub2ind([h w], r, c);
                hit = find(cellfun(@(p) any(ismember(seedIdx, p)), cc.PixelIdxList));
                if ~isempty(hit)
                    candidates = hit;
                end
            end
            [~, best] = max(sizes(candidates));
            mask = false(size(mask));
            mask(cc.PixelIdxList{candidates(best)}) = true;
        end
        

        function idx = cropToVolume(app, k, cropSize, bb)
            % Linear indices k inside a crop (starting at bbox bb) -> indices into LabelVol.
            [a, b, c] = ind2sub(cropSize, k(:));
            idx = sub2ind(size(app.LabelVol), a + bb(1) - 1, b + bb(3) - 1, c + bb(5) - 1);
        end
        

        function deleteObject(app, ids)
            % Remove one or more committed objects from the label volume and the list.
            if ~isempty(app.SplitState) && ismember(app.SplitState.id, ids)
                app.cancelSplit();
            end
            app.LabelVol(ismember(app.LabelVol, ids)) = 0;
            app.Objects(ismember([app.Objects.id], ids)) = [];
            for o = 1:numel(app.Objects)
                if ismember(app.Objects(o).target, ids)
                    app.Objects(o).target = 0;
                end
            end
            for j = 1:numel(app.Pending)
                if ismember(app.Pending(j).target, ids)
                    app.Pending(j).target = 0;
                end
            end
            app.Exported = false;
            app.refreshObjectList();
            app.updateOverlays();
            if isscalar(ids)
                app.setStatus(sprintf("Deleted object %d.", ids));
            else
                app.setStatus(sprintf("Deleted %d objects.", numel(ids)));
            end
        end
        

        function discardMask3D(app)
            % Drop a propagated (not yet added) 3D mask.
            if ~isempty(app.Mask3D)
                app.Mask3D = [];
                app.Mask3DInfo = [];
                app.CurrentMask = [];
            end
        end
        

        function ok = ensureEmbedding(app)
            % Compute the embedding of the slice currently shown, with the loaded model.
            ok = false;
            if isempty(app.RGB) || ~app.ensureModel()
                return
            end
            if ~app.NeedsEmbedding
                ok = true;
                return
            end
            if app.LoadedModel == "sam3.1"
                msg = "Computing SAM 3.1 image features (about 45 s on a GTX 1080)…";
            else
                msg = "Computing the image embedding…";
            end
            app.IsBusy = true;
            busy = onCleanup(@() app.setIdle());
            dlg = uiprogressdlg(app.UIFigure, Title="Preparing image", Message=msg, Indeterminate="on");
            cleanup = onCleanup(@() delete(dlg));
            app.setStatus(msg);
            try
                seconds = double(app.Backend.set_image(app.RGB));
            catch err
                uialert(app.UIFigure, err.message, "Image embedding failed");
                app.setStatus("Image embedding failed.");
                return
            end
            app.NeedsEmbedding = false;
            if app.SpeedSource ~= "measured on this GPU"
                % propagation per slice ~ image encoder + ~10% tracking; keep the fastest
                % embedding seen (the first one includes warm-up)
                guess = 1.1 * seconds;
                if isempty(app.SpeedPerSlice) || app.SpeedSource == "" || guess < app.SpeedPerSlice
                    app.SpeedPerSlice = guess;
                end
                app.SpeedSource = "estimated from the image embedding";
                app.updateEstimate();
            end
            app.setStatus(sprintf("Slice ready (%.1f s). Left-click to include, right-click to exclude.", seconds));
            ok = true;
        end
        

        function ok = ensureModel(app)
            % Load the model with the settings of the Model tab, unless already loaded.
            ok = false;
            if ~app.ensurePython()
                return
            end
            model = string(app.ModelDropDown.Value);
            device = string(app.DeviceDropDown.Value);
            precision = string(app.PrecisionDropDown.Value);
            key = strjoin([model device precision], "|");
            if app.LoadedKey == key
                ok = true;
                return
            end
            msg = "Loading " + app.modelName(model) + " (about 20 s; the first run downloads 3.5 GB)…";
            dlg = uiprogressdlg(app.UIFigure, Title="Loading model", Message=msg, Indeterminate="on");
            cleanup = onCleanup(@() delete(dlg));
            app.setStatus(msg);
            app.ModelLamp.Color = [0.95 0.7 0.1];
            app.ModelStatusLabel.Text = "Loading…";
            try
                info = struct(app.Backend.load(model, device, precision, py.None, app.weightsDir()));
            catch err
                app.LoadedKey = "";
                app.LoadedModel = "";
                app.ModelLamp.Color = [0.85 0.2 0.2];
                app.ModelStatusLabel.Text = "Failed to load";
                app.updateButtons();
                uialert(app.UIFigure, err.message, "Model load failed");
                app.setStatus("Model load failed.");
                return
            end
            app.LoadedModel = string(info.version);
            app.LoadedKey = strjoin([app.LoadedModel device precision], "|");
            app.ModelDropDown.Value = char(app.LoadedModel);
            app.NeedsEmbedding = true;
            app.ModelLamp.Color = [0.2 0.7 0.3];
            app.ModelStatusLabel.Text = sprintf("%s loaded on %s (%s)", app.modelName(app.LoadedModel), ...
                string(info.device), string(info.dtype));
            reason = string(info.fallback_reason);
            if strlength(reason) > 0
                app.ModelLamp.Color = [0.95 0.7 0.1];
                app.ModelStatusLabel.Text = "SAM 3 loaded (SAM 3.1 unavailable)";
                uialert(app.UIFigure, "SAM 3.1 could not be loaded, so SAM 3 is used instead." + ...
                    newline + newline + reason, "Fell back to SAM 3", Icon="warning");
            end
            if app.LoadedModel == "sam3.1" && app.ModeDropDown.Value == "3D"
                app.ModeDropDown.Value = '2D';
                app.discardMask3D();
            end
            app.updateModelInfo(info);
            app.updateWeightsInfo();
            gpu = string(info.gpu);
            if strlength(gpu) == 0
                gpu = "CPU";
            end
            app.DeviceKey = string(matlab.lang.makeValidName(gpu + "_" + string(info.dtype)));
            app.SpeedPerSlice = [];
            app.SpeedSource = "";
            if ispref("SAM3Segmenter", app.DeviceKey)
                app.SpeedPerSlice = getpref("SAM3Segmenter", app.DeviceKey);
                app.SpeedSource = "measured on this GPU";
            end
            app.batchSize();   % show the automatic objects-per-pass value
            app.updateButtons();
            app.updateEstimate();
            app.setStatus(app.modelName(app.LoadedModel) + " ready.");
            ok = true;
        end
        

        function ok = ensurePython(app)
            % Start the project's Python environment (out-of-process) and create the backend.
            ok = true;
            if ~isempty(app.Backend)
                return
            end
            venvPython = fullfile(app.ProjectRoot, ".venv", "Scripts", "python.exe");
            if ~isfile(venvPython)
                uialert(app.UIFigure, "Python environment not found:" + newline + venvPython + ...
                    newline + newline + "See the Help tab for setup instructions.", "SAM 3 Segmenter");
                ok = false;
                return
            end
            pe = pyenv;
            if ~strcmpi(pe.Executable, venvPython) || pe.ExecutionMode ~= "OutOfProcess"
                if pe.Status == "Loaded"
                    if pe.ExecutionMode == "InProcess"
                        uialert(app.UIFigure, "MATLAB is already running another Python in-process. " + ...
                            "Restart MATLAB, then open the app again.", "SAM 3 Segmenter");
                        ok = false;
                        return
                    end
                    choice = uiconfirm(app.UIFigure, "MATLAB is using another Python environment. " + ...
                        "Restart Python with the SAM 3 environment?", "SAM 3 Segmenter", ...
                        Options=["Restart Python", "Cancel"]);
                    if choice ~= "Restart Python"
                        ok = false;
                        return
                    end
                    terminate(pyenv);
                end
                pyenv(Version=venvPython, ExecutionMode="OutOfProcess");
            end
            backendDir = fullfile(app.ProjectRoot, "python");
            if ~any(string(cell(py.sys.path)) == backendDir)
                py.sys.path().insert(int32(0), backendDir);
            end
            try
                backend = py.importlib.import_module("sam3_backend");
                app.Backend = backend.SamSession();
            catch err
                uialert(app.UIFigure, "Could not start the SAM backend:" + newline + err.message, "SAM 3 Segmenter");
                ok = false;
                return
            end
            app.updateModelInfo();
        end
        

        function s = formatDuration(app, seconds)
            % "42 s", "3 min 05 s" or "1 h 12 min".
            seconds = round(seconds);
            if seconds < 60
                s = sprintf("%d s", seconds);
            elseif seconds < 3600
                s = sprintf("%d min %02d s", floor(seconds / 60), mod(seconds, 60));
            else
                s = sprintf("%d h %02d min", floor(seconds / 3600), floor(mod(seconds, 3600) / 60));
            end
        end
        

        function imageClicked(app, event)
            % Route a click on the image according to the click mode.
            if app.IsBusy
                return
            end
            if ~isempty(app.SplitState)
                app.splitClick(event);
                return
            end
            if ~app.ensureEmbedding()
                return
            end
            isRight = event.Button == 3 || any(strcmp(app.UIFigure.SelectionType, ["alt" "extend"]));
            xy = event.IntersectionPoint(1:2);
            [h, w] = size(app.ViewIdx);
            row = min(max(round(xy(2)), 1), h);
            col = min(max(round(xy(1)), 1), w);
            % In every mode, a right-click on a pending object (text results, or
            % one-per-click objects in 3D) removes it.
            if isRight && ~isempty(app.Pending) && isempty(app.Mask3D)
                here = find(app.pendingHere());
                k = here(find(arrayfun(@(j) app.Pending(j).mask(row, col), here), 1, "last"));
                if ~isempty(k)
                    app.Pending(k) = [];
                    app.syncPending();
                    app.setStatus(sprintf("Removed a pending object; %d left.", numel(app.Pending)));
                else
                    app.setStatus("Right-click inside a highlighted object to remove it from the results.");
                end
                return
            end
            if app.ClickModeDropDown.Value == "each"
                app.clickEach(xy, isRight, row, col);
                return
            end
            if ~isempty(app.Mask3D) || ~isempty(app.Pending)
                % New refine clicks start a new object; drop previous results that no longer match.
                app.discardMask3D();
                app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
                app.Clicks = zeros(0, 3);
            end
            % One row per click (x, y, label) so points and labels cannot get out of step.
            app.Clicks(end + 1, :) = [xy, double(~isRight)];
            app.ClickView = struct("axis", app.ViewAxis, "slice", app.SliceIndex, "rot", app.ViewRot);
            app.runPrediction();
        end
        

        function v = listValue(app)
            % Raw selection of the object list as a numeric row vector.
            v = app.ObjectsListBox.Value;
            if iscell(v)
                v = cell2mat(v);
            end
            v = reshape(double(v), 1, []);
        end
        

        function target = mergeLabels(app, ids)
            % Merge objects ids into the lowest-numbered one right away (labels and records).
            ids = unique(ids);
            target = ids(1);
            if isscalar(ids)
                return
            end
            others = ids(2:end);
            app.LabelVol(ismember(app.LabelVol, others)) = target;
            group = app.Objects(ismember([app.Objects.id], ids));
            t = find([app.Objects.id] == target, 1);
            merged = app.Objects(t);
            merged.voxels = sum([group.voxels]);
            merged.score = max([group.score]);
            if numel(unique(string({group.mode}))) > 1
                merged.mode = "mixed";
            end
            merged.range = [min(arrayfun(@(o) o.range(1), group)), max(arrayfun(@(o) o.range(end), group))];
            merged.points = vertcat(group.points);
            merged.labels = vertcat(group.labels);
            prompts = unique(string({group.prompt}));
            merged.prompt = strjoin(prompts(strlength(prompts) > 0), ", ");
            bb = merged.bbox;
            for g = group
                bb = app.bboxUnion(bb, g.bbox);
            end
            merged.bbox = bb;
            app.Objects(t) = merged;
            app.Objects(ismember([app.Objects.id], others)) = [];
            % entries tied to a merged-away object now point at the target
            for o = 1:numel(app.Objects)
                if ismember(app.Objects(o).target, others)
                    app.Objects(o).target = target;
                end
            end
            for j = 1:numel(app.Pending)
                if ismember(app.Pending(j).target, others)
                    app.Pending(j).target = target;
                end
            end
        end
        

        function mergeObjects(app, ids, pendingIdx)
            % Merge the entries selected in the object list.
            %  - Propagated (3D) objects are merged into the lowest-numbered one.
            %  - Selected (not propagated) entries -- clicked objects and 2D objects --
            %    merged with a propagated object are tied to it: when propagated, their
            %    result is labelled as that object.
            %  - Without a propagated object, 2D objects are merged into the lowest-
            %    numbered one and clicked objects are tied to it; clicked objects alone
            %    are linked: tracked as one object, seeded on each of their slices.
            if nargin < 3
                pendingIdx = [];
            end
            ids = unique(ids);
            if numel(ids) + numel(pendingIdx) < 2
                return
            end
            modes = strings(1, numel(ids));
            for i = 1:numel(ids)
                modes(i) = string(app.Objects([app.Objects.id] == ids(i)).mode);
            end
            propagated = ids(modes == "3D");
            twoD = ids(modes ~= "3D");
            msg = "";
            if ~isempty(propagated)
                target = app.mergeLabels(propagated);
                tie = twoD;
            elseif ~isempty(twoD)
                target = app.mergeLabels(twoD);
                tie = [];
            else
                target = 0;
                tie = [];
            end
            for id = tie
                o = find([app.Objects.id] == id, 1);
                app.Objects(o).target = target;
            end
            if target > 0
                linked = pendingIdx;
                groups = unique([app.Pending(pendingIdx).group]);
                groups = groups(groups > 0);
                if ~isempty(groups)   % linked clicked objects follow together
                    linked = union(linked, find(ismember([app.Pending.group], groups)));
                end
                for j = linked
                    app.Pending(j).target = target;
                end
                pendingIdx = linked;
                parts = strings(0, 1);
                if numel(propagated) > 1 || (isempty(propagated) && numel(twoD) > 1)
                    parts(end + 1) = sprintf("merged objects into object %d", target);
                end
                nTied = numel(tie) + numel(pendingIdx);
                if nTied > 0
                    word = "entries";
                    if nTied == 1
                        word = "entry";
                    end
                    parts(end + 1) = sprintf("%d selected %s tied to object %d (propagate to extend it)", nTied, word, target);
                end
                msg = strjoin(parts, "; ");
                selection = target;
            else
                % clicked objects only (possibly on different slices): link them so they
                % are tracked as ONE object, seeded on all their slices
                targets = unique([app.Pending(pendingIdx).target]);
                targets = targets(targets > 0);
                groups = unique([app.Pending(pendingIdx).group]);
                groups = groups(groups > 0);
                members = pendingIdx;
                if ~isempty(groups)   % bring along the rest of any group already involved
                    members = union(members, find(ismember([app.Pending.group], groups)));
                end
                if ~isempty(targets)
                    for j = members
                        app.Pending(j).target = targets(1);
                    end
                    msg = sprintf("Linked %d clicked objects; they extend object %d", numel(members), targets(1));
                else
                    newGroup = max([0 app.Pending.group]) + 1;
                    for j = members
                        app.Pending(j).group = newGroup;
                    end
                    slices = unique([app.Pending(members).slice]);
                    msg = sprintf("Linked %d clicked objects into one object (starting slices %s)", ...
                        numel(members), strjoin(string(slices), ", "));
                end
                selection = -members;
            end
            app.Exported = false;
            app.syncPending();
            app.refreshObjectList(selection);
            app.updateOverlays();
            app.setStatus(upper(extractBefore(msg, 2)) + extractAfter(msg, 1) + ".");
        end
        

        function name = modelName(app, version)
            if version == "sam3.1"
                name = "SAM 3.1";
            else
                name = "SAM 3";
            end
        end
        

        function tf = onClickView(app)
            % True when the view shows the slice (axis, slice, rotation) where the
            % current clicks / clicked objects were made.
            v = app.ClickView;
            tf = ~isempty(v) && v.axis == app.ViewAxis && v.slice == app.SliceIndex && v.rot == app.ViewRot;
        end
        

        function s = orMissing(app, path)
            % Text for a checkpoint path: the path, or a hint that it is not downloaded yet.
            if strlength(path) > 0
                s = path;
            else
                s = "not downloaded yet (downloads on first load; needs Hugging Face access)";
            end
        end
        

        function here = pendingHere(app)
            % Logical row: which clicked objects belong to the shown slice (same axis,
            % slice and rotation).
            here = false(1, numel(app.Pending));
            for j = 1:numel(app.Pending)
                p = app.Pending(j);
                here(j) = p.slice == app.SliceIndex && p.axis == app.ViewAxis && p.rot == app.ViewRot;
            end
        end
        

        function [keys, futureIds] = pendingKeys(app)
            % For each clicked object j: the key of the object it will become, and the
            % number that object will have after Add object.
            %   tied to an object (target)  -> key = that object number
            %   linked with other clicked objects (group) -> shared negative key
            %   otherwise                   -> its own negative key
            % New objects are numbered NextId, NextId+1, ... in order of first appearance.
            n = numel(app.Pending);
            keys = zeros(1, n);
            futureIds = zeros(1, n);
            newKeys = zeros(1, 0);
            for j = 1:n
                p = app.Pending(j);
                if p.target > 0
                    keys(j) = p.target;
                    futureIds(j) = p.target;
                    continue
                end
                if p.group > 0
                    keys(j) = -(1e5 + p.group);
                else
                    keys(j) = -j;
                end
                r = find(newKeys == keys(j), 1);
                if isempty(r)
                    newKeys(end + 1) = keys(j); %#ok<AGROW>
                    r = numel(newKeys);
                end
                futureIds(j) = app.NextId + r - 1;
            end
        end
        

        function D = pendingLabels(app)
            % Objects that are not added yet, on the shown slice, as the object numbers
            % they will have after Add object (0 = none): a propagated 3D result, or
            % clicked objects of this slice (text results, one-per-click objects in 3D).
            % Existing objects that were propagated keep their own number.
            D = [];
            if ~isempty(app.Mask3D)
                P = app.Mask3D(app.ViewIdx);
                info = app.Mask3DInfo;
                src = zeros(1, info.count);
                if isfield(info, "sourceIds") && ~isempty(info.sourceIds)
                    src(1:min(end, numel(info.sourceIds))) = info.sourceIds(1:min(end, info.count));
                end
                map = src;
                newIds = app.NextId + (0:nnz(src == 0) - 1);
                map(src == 0) = newIds;
                D = zeros(size(P), "uint16");
                nz = P > 0;
                D(nz) = map(P(nz));
            elseif ~isempty(app.Pending)
                here = app.pendingHere();
                if ~any(here)
                    return
                end
                [~, futureIds] = app.pendingKeys();
                D = zeros(size(app.ViewIdx), "uint16");
                for j = find(here)
                    D(app.Pending(j).mask & D == 0) = futureIds(j);
                end
            end
        end
        

        function [points, labels, prompt, score] = promptOf(app, k)
            % The prompt that defined tracked object k of the last propagation
            % (a clicked object, or the clicks of the mask being refined).
            j = 0;
            if isfield(app.Mask3DInfo, "pendingOf") && k <= numel(app.Mask3DInfo.pendingOf)
                j = app.Mask3DInfo.pendingOf(k);
            end
            if j > 0 && j <= numel(app.Pending)
                p = app.Pending(j);
                points = p.point;
                labels = 1;
                prompt = p.prompt;
                score = p.score;
            else
                points = app.Clicks(:, 1:2);
                labels = app.Clicks(:, 3);
                prompt = "";
                score = app.CurrentScore;
            end
        end
        

        function propagate(app)
            % Track the selected (not yet propagated) objects through the From..To range:
            % clicked objects (one-per-click, text results, or the mask being refined),
            % each from its own slice, and objects added in 2D in this view. Entries
            % linked or tied together (Merge selected) are ONE tracked object, seeded on
            % all their slices. Objects with the same starting slice(s) share a run;
            % each run is split into passes of "Objects per pass". Where objects touch,
            % the "Where objects touch" rule decides. Propagated objects are not re-tracked.
            if app.IsBusy || ~app.ensureModel()
                return
            end
            if app.LoadedModel ~= "sam3"
                uialert(app.UIFigure, "3D propagation needs SAM 3. Select it in the Model and device tab.", ...
                    "SAM 3 required");
                return
            end
            hasPending = ~isempty(app.Pending);
            if hasPending && any(arrayfun(@(p) p.axis ~= app.ViewAxis || p.rot ~= app.ViewRot, app.Pending))
                uialert(app.UIFigure, "Some clicked objects were made in another view. Switch back to it, or clear them (Esc).", ...
                    "Propagate");
                return
            end
            refineMask = ~hasPending && isempty(app.Mask3D) && ~isempty(app.CurrentMask) && any(app.CurrentMask(:));
            objIds = app.seedObjectIds(true);
            if ~hasPending && ~refineMask && isempty(objIds)
                app.setStatus("Nothing to propagate: click objects, or add objects in 2D first.");
                return
            end
        
            % --- tracked objects: final key (>0 existing object number, <0 new object) and seeds
            finals = zeros(1, 0);
            pendingOf = zeros(1, 0);
            seedSlices = {};
            seedMasks = {};
            absorb = zeros(0, 2);   % [2D object id, object it is tied to]
            keys = app.pendingKeys();
            for j = 1:numel(app.Pending)
                t = find(finals == keys(j), 1);
                if isempty(t)
                    finals(end + 1) = keys(j); %#ok<AGROW>
                    pendingOf(end + 1) = j; %#ok<AGROW>
                    seedSlices{end + 1} = zeros(1, 0); %#ok<AGROW>
                    seedMasks{end + 1} = {}; %#ok<AGROW>
                    t = numel(finals);
                end
                seedSlices{t}(end + 1) = app.Pending(j).slice;
                seedMasks{t}{end + 1} = app.Pending(j).mask;
            end
            if refineMask
                finals(end + 1) = -2e6;
                pendingOf(end + 1) = 0;
                seedSlices{end + 1} = app.ClickView.slice;
                seedMasks{end + 1} = {app.CurrentMask};
            end
            for id = objIds
                o = app.Objects([app.Objects.id] == id);
                key = id;
                if o.target > 0
                    key = o.target;
                    absorb(end + 1, :) = [id o.target]; %#ok<AGROW>
                end
                t = find(finals == key, 1);
                if isempty(t)
                    finals(end + 1) = key; %#ok<AGROW>
                    pendingOf(end + 1) = 0; %#ok<AGROW>
                    seedSlices{end + 1} = zeros(1, 0); %#ok<AGROW>
                    seedMasks{end + 1} = {}; %#ok<AGROW>
                    t = numel(finals);
                end
                seedSlices{t}(end + 1) = o.slice;
                seedMasks{t}{end + 1} = app.LabelVol(app.viewIndex(o.slice)) == id;
            end
            numObjects = numel(finals);
            sourceIds = max(finals, 0);
            first = app.FromField.Value;
            last = app.ToField.Value;
            allSlices = unique([seedSlices{:}]);
            outside = allSlices(allSlices < first | allSlices > last);
            if first > last || ~isempty(outside)
                uialert(app.UIFigure, sprintf("Objects start on slice(s) %s, outside the range From %d to %d. " + ...
                    "Widen the range.", strjoin(string(outside), ", "), first, last), "Check the slice range");
                return
            end
            rule = string(app.ContactDropDown.Value);
        
            % --- runs: objects with the same starting slices; passes of batchSize objects
            signature = cellfun(@(s) strjoin(string(unique(s)), ","), seedSlices);
            [runKeys, ~, runOf] = unique(signature, "stable");
            batch = app.batchSize();
            jobs = struct("objects", {}, "slices", {});
            for r = 1:numel(runKeys)
                members = find(runOf == r);
                for s0 = 1:batch:numel(members)
                    jobs(end + 1) = struct("objects", members(s0:min(end, s0 + batch - 1)), ...
                        "slices", unique([seedSlices{members(1)}])); %#ok<AGROW>
                end
            end
            numJobs = numel(jobs);
            app.IsBusy = true;
            busy = onCleanup(@() app.setIdle());
            dlg = uiprogressdlg(app.UIFigure, Title="3D propagation", Message="Preparing…", Cancelable="on");
            cleanup = onCleanup(@() delete(dlg));
            try
                if ~app.sendVolume(dlg)
                    app.VolumeSentAxis = "";
                    app.setStatus("Propagation cancelled.");
                    return
                end
            catch err
                uialert(app.UIFigure, err.message, "Propagation failed");
                app.setStatus("Propagation failed.");
                return
            end
            labels3D = zeros(size(app.LabelVol), "uint16");
            trackBB = repmat([inf -inf inf -inf inf -inf], numObjects, 1);
            blocked = zeros(0, 1);   % "leave empty" rule: voxels no object may take
            cancelled = false;
            doneSlices = [];
            started = tic;
            weighted = 0;   % slices processed, weighted by the per-object cost (see updateEstimate)
            volSize = size(app.LabelVol);
            viewSize = size(app.ViewIdx);
            for q = 1:numJobs
                ids = jobs(q).objects;          % tracked indices in this pass
                sl = jobs(q).slices;
                maps = zeros([numel(sl) viewSize], "uint16");
                for b = 1:numel(ids)
                    t = ids(b);
                    for m = 1:numel(seedSlices{t})
                        row = find(sl == seedSlices{t}(m), 1);
                        layer = reshape(maps(row, :, :), viewSize);
                        layer(seedMasks{t}{m} & layer == 0) = b;
                        maps(row, :, :) = reshape(layer, [1 viewSize]);
                    end
                end
                dlg.Message = sprintf("Run %d of %d (starting slice %s): starting the tracker…", q, numJobs, strjoin(string(sl), ", "));
                try
                    total = double(app.Backend.propagate_start(int32(sl - 1), maps, int32(first - 1), int32(last - 1)));
                catch err
                    uialert(app.UIFigure, err.message, "Propagation failed");
                    break
                end
                while true
                    try
                        out = cell(app.Backend.propagate_step(int32(2)));
                    catch err
                        uialert(app.UIFigure, err.message, "Propagation failed");
                        cancelled = true;
                        break
                    end
                    idx = double(out{1}) + 1;
                    labs = uint16(out{2});
                    both = logical(uint8(out{6}));
                    for j = 1:numel(idx)
                        where = app.viewIndex(idx(j));
                        current = labels3D(where);
                        found = reshape(labs(j, :, :), size(labs, 2), size(labs, 3));
                        contested = reshape(both(j, :, :), size(both, 2), size(both, 3));
                        mine = zeros(size(found));
                        mine(found > 0) = ids(found(found > 0));        % pass-local -> tracked index
                        switch rule
                            case "overwrite"
                                take = found > 0;
                            case "empty"
                                clash = (found > 0 & current > 0 & current ~= mine) | (contested & found > 0);
                                if ~isempty(blocked)
                                    clash = clash | (found > 0 & ismember(where, blocked));
                                end
                                current(clash) = 0;
                                blocked = [blocked; where(clash)]; %#ok<AGROW>
                                take = found > 0 & current == 0 & ~clash;
                            otherwise   % keep: earlier objects keep their voxels
                                take = found > 0 & current == 0;
                        end
                        current(take) = mine(take);
                        labels3D(where) = current;
                        if any(take(:))
                            [rr, cc, zz] = ind2sub(volSize, where(take));
                            t = mine(take);
                            n = numObjects;
                            trackBB(:, 1) = min(trackBB(:, 1), accumarray(t, rr, [n 1], @min, inf));
                            trackBB(:, 2) = max(trackBB(:, 2), accumarray(t, rr, [n 1], @max, -inf));
                            trackBB(:, 3) = min(trackBB(:, 3), accumarray(t, cc, [n 1], @min, inf));
                            trackBB(:, 4) = max(trackBB(:, 4), accumarray(t, cc, [n 1], @max, -inf));
                            trackBB(:, 5) = min(trackBB(:, 5), accumarray(t, zz, [n 1], @min, inf));
                            trackBB(:, 6) = max(trackBB(:, 6), accumarray(t, zz, [n 1], @max, -inf));
                        end
                    end
                    doneSlices = union(doneSlices, idx);
                    weighted = weighted + numel(idx) * (1 + 0.08 * (numel(ids) - 1));
                    done = double(out{3});
                    progress = ((q - 1) * total + done) / (numJobs * total);
                    dlg.Value = min(1, progress);
                    remaining = toc(started) * (1 - progress) / max(progress, eps);
                    dlg.Message = sprintf("Run %d of %d (%d object(s), starting slice %s), slices %d–%d: %d of %d done (about %s left)", ...
                        q, numJobs, numel(ids), strjoin(string(sl), ", "), first, last, done, total, app.formatDuration(remaining));
                    if done >= total || isempty(idx)
                        break
                    end
                    if dlg.CancelRequested
                        app.Backend.propagate_cancel();
                        cancelled = true;
                        break
                    end
                end
                if cancelled
                    break
                end
            end
            seconds = toc(started);
            if weighted >= 4 && app.DeviceKey ~= ""
                app.SpeedPerSlice = seconds / weighted;
                app.SpeedSource = "measured on this GPU";
                setpref("SAM3Segmenter", app.DeviceKey, app.SpeedPerSlice);
            end
            labels3D = app.connectedLabels3D(labels3D, numObjects);   % optional one-piece cleanup
            trackBB(isinf(trackBB)) = NaN;
            app.Mask3D = labels3D;
            app.Mask3DInfo = struct("axis", app.ViewAxis, "slice", min(allSlices), "range", [first last], ...
                "slicesDone", numel(doneSlices), "cancelled", cancelled, "count", numObjects, ...
                "sourceIds", sourceIds, "pendingOf", pendingOf, "absorb", absorb, "bbox", trackBB, "rule", rule);
            app.CurrentMask = labels3D(app.ViewIdx) > 0;
            app.updateOverlays();
            app.refreshObjectList();
            verb = "Propagated";
            if cancelled
                verb = "Cancelled after";
            end
            present = unique(labels3D(labels3D > 0));
            missing = setdiff(1:numObjects, double(present));
            note = "";
            if ~isempty(missing)
                note = sprintf(" %d object(s) came out empty (covered by other objects).", numel(missing));
            end
            app.setStatus(sprintf("%s %d object(s) through %d slices in %s (%d run(s)) · %d voxels.%s Browse the slices to check, then Add object (Enter).", ...
                verb, numObjects, numel(doneSlices), app.formatDuration(seconds), numJobs, nnz(labels3D), note));
        end
        

        function runs = propagationPlan(app)
            % What Propagate would track right now, without asking anything: one row
            % per run with the number of tracked objects and the first/last starting
            % slice (runs group objects with the same starting slices). Used for the
            % time estimate; propagate() builds the same plan for real.
            runs = struct("objects", {}, "lo", {}, "hi", {});
            keys = zeros(1, 0);
            slices = {};
            if ~isempty(app.Pending)
                k = app.pendingKeys();
                for j = 1:numel(app.Pending)
                    t = find(keys == k(j), 1);
                    if isempty(t)
                        keys(end + 1) = k(j); %#ok<AGROW>
                        slices{end + 1} = zeros(1, 0); %#ok<AGROW>
                        t = numel(keys);
                    end
                    slices{t}(end + 1) = app.Pending(j).slice;
                end
            elseif isempty(app.Mask3D) && ~isempty(app.CurrentMask) && any(app.CurrentMask(:)) && ~isempty(app.ClickView)
                keys(end + 1) = -2e6;
                slices{end + 1} = app.ClickView.slice;
            end
            for id = app.seedObjectIds(false)
                o = app.Objects([app.Objects.id] == id);
                key = id;
                if o.target > 0
                    key = o.target;
                end
                t = find(keys == key, 1);
                if isempty(t)
                    keys(end + 1) = key; %#ok<AGROW>
                    slices{end + 1} = zeros(1, 0); %#ok<AGROW>
                    t = numel(keys);
                end
                slices{t}(end + 1) = o.slice;
            end
            if isempty(keys)
                return
            end
            signature = cellfun(@(s) strjoin(string(unique(s)), ","), slices);
            [~, ~, runOf] = unique(signature, "stable");
            for r = 1:max(runOf)
                s = unique([slices{find(runOf == r, 1)}]);
                runs(end + 1) = struct("objects", nnz(runOf == r), "lo", min(s), "hi", max(s)); %#ok<AGROW>
            end
        end
        

        function [vol, summary] = readVolume(app, path, info, dlg)
            % Read all pages into an 8-bit rows x cols x slices [x 3] volume.
            % Non-uint8 data is stretched between the 0.5 and 99.5 percentiles of the
            % whole file (estimated from up to 24 evenly spaced pages), so every slice
            % uses the same grey-level mapping.
            n = numel(info);
            readPage = @(k) imread(path, Index=k, Info=info);
            first = readPage(1);
            isIndexed = ~isempty(info(1).Colormap) && ismatrix(first);
            if isIndexed
                toColor = @(I) im2uint8(ind2rgb(I, info(1).Colormap));
                first = toColor(first);
            else
                toColor = @(I) I;
            end
            channels = 1 + 2 * (size(first, 3) >= 3);
            lo = [];
            hi = [];
            if ~isa(first, "uint8")
                sample = [];
                for k = unique(round(linspace(1, n, min(n, 24))))
                    I = double(toColor(readPage(k)));
                    I = I(:, :, 1:min(size(I, 3), channels));
                    I = I(isfinite(I));
                    sample = [sample; I(1:max(1, floor(numel(I) / 2e5)):end)]; %#ok<AGROW>
                end
                v = sort(sample);
                lo = v(max(1, round(0.005 * numel(v))));
                hi = v(max(1, round(0.995 * numel(v))));
                if hi <= lo
                    lo = v(1);
                    hi = v(end);
                end
                if hi <= lo
                    hi = lo + 1;
                end
            end
            vol = zeros(size(first, 1), size(first, 2), n, channels, "uint8");
            for k = 1:n
                if k == 1
                    I = first;
                else
                    I = toColor(readPage(k));
                end
                vol(:, :, k, :) = reshape(app.toUint8(I, lo, hi, channels), size(vol, 1), size(vol, 2), 1, channels);
                if mod(k, 10) == 0 || k == n
                    dlg.Value = k / n;
                    dlg.Message = sprintf("Reading page %d of %d…", k, n);
                    if dlg.CancelRequested
                        vol = [];
                        summary = struct();
                        return
                    end
                end
            end
            [~, name, ext] = fileparts(path);
            if n > 1
                text = sprintf("%s%s: 3D volume, %d × %d × %d", name, ext, size(vol, 2), size(vol, 1), n);
            else
                text = sprintf("%s%s: 2D image, %d × %d", name, ext, size(vol, 2), size(vol, 1));
            end
            summary = struct("name", name + ext, "pages", n, "rows", size(vol, 1), "cols", size(vol, 2), ...
                "channels", channels, "class", class(first), "bitDepth", info(1).BitDepth, "lo", lo, "hi", hi, ...
                "text", string(text));
        end
        

        function refreshObjectList(app, selectIds)
            % Object list in two groups:
            %   "Selected (not propagated)": clicked objects not added yet (ItemsData -1, -2, ...)
            %       and objects added in 2D; Propagate tracks these.
            %   "Propagated (3D)": objects already propagated.
            % Entries are written in the object's overlay colour, or grey when the
            % object is not on the shown slice; "Only this slice" hides those.
            % selectIds (optional): list values to select; default keeps the selection.
            lb = app.ObjectsListBox;
            if nargin < 2
                selectIds = app.listValue();
            end
            removeStyle(lb);
            onSlice = [];
            if ~isempty(app.LabelVol) && ~isempty(app.ViewIdx)
                u = unique(app.LabelVol(app.ViewIdx));
                onSlice = reshape(double(u(u > 0)), 1, []);
            end
            onlySlice = app.OnlySliceCheckBox.Value;
            n = size(app.Palette, 1);
            colorOf = @(id) app.Palette(mod(id - 1, n) + 1, :);
            grey = [0.6 0.6 0.6];
            items = strings(0, 1);
            data = zeros(1, 0);
            styles = cell(0, 2);   % {row, uistyle}
            HEADER_SEL = 1e6 + 1;
            HEADER_PROP = 1e6 + 2;
        
            % --- selected (not propagated): clicked objects, then 2D objects
            here = app.pendingHere();
            [~, futureIds] = app.pendingKeys();
            selItems = strings(0, 1);
            selData = zeros(1, 0);
            selStyles = cell(0, 2);
            switch app.ViewAxis
                case "XY"
                    letter = "z";
                case "XZ"
                    letter = "y";
                otherwise
                    letter = "x";
            end
            for j = 1:numel(app.Pending)
                if onlySlice && ~here(j)
                    continue
                end
                p = app.Pending(j);
                text = sprintf("Clicked %d  (%s %d, not propagated, %d px, score %.2f)", j, letter, p.slice, nnz(p.mask), p.score);
                if p.target > 0
                    text = text + sprintf("  → Object %d", p.target);
                elseif p.group > 0
                    mates = setdiff(find([app.Pending.group] == p.group), j);
                    if ~isempty(mates)
                        text = text + "  ⇄ " + strjoin("Clicked " + string(mates), ", ");
                    end
                end
                selItems(end + 1) = text; %#ok<AGROW>
                selData(end + 1) = -j; %#ok<AGROW>
                color = colorOf(futureIds(j));
                if ~here(j)
                    color = grey;
                end
                selStyles(end + 1, :) = {numel(selItems), uistyle(FontColor=color, FontAngle="italic")}; %#ok<AGROW>
            end
            propItems = strings(0, 1);
            propData = zeros(1, 0);
            propStyles = cell(0, 2);
            for o = app.Objects
                visible = ismember(o.id, onSlice);
                if onlySlice && ~visible
                    continue
                end
                rangeText = "";
                if isfield(o, "bbox") && numel(o.bbox) == 6 && all(isfinite(o.bbox))
                    [r, letter] = app.sliceRange(o.bbox);
                    if r(1) == r(2)
                        rangeText = sprintf(", %s %d", letter, r(1));
                    else
                        rangeText = sprintf(", %s %d–%d", letter, r(1), r(2));
                    end
                end
                text = sprintf("Object %d  (%s%s, %d vox, score %.2f)", o.id, o.mode, rangeText, o.voxels, o.score);
                if isfield(o, "target") && o.target > 0
                    text = text + sprintf("  → Object %d", o.target);
                end
                if visible
                    st = uistyle(FontColor=colorOf(o.id), FontWeight="bold");
                else
                    st = uistyle(FontColor=grey);
                end
                if o.mode == "3D"
                    propItems(end + 1) = text; %#ok<AGROW>
                    propData(end + 1) = o.id; %#ok<AGROW>
                    propStyles(end + 1, :) = {numel(propItems), st}; %#ok<AGROW>
                else
                    selItems(end + 1) = text; %#ok<AGROW>
                    selData(end + 1) = o.id; %#ok<AGROW>
                    selStyles(end + 1, :) = {numel(selItems), st}; %#ok<AGROW>
                end
            end
            headerStyle = uistyle(FontColor=[0.45 0.45 0.45], FontAngle="italic");
            if ~isempty(selItems)
                items(end + 1) = "— Selected (not propagated) —";
                data(end + 1) = HEADER_SEL;
                styles(end + 1, :) = {numel(items), headerStyle};
                offset = numel(items);
                items = [items; selItems(:)];
                data = [data selData];
                for s = 1:size(selStyles, 1)
                    styles(end + 1, :) = {selStyles{s, 1} + offset, selStyles{s, 2}}; %#ok<AGROW>
                end
            end
            if ~isempty(propItems)
                items(end + 1) = "— Propagated (3D) —";
                data(end + 1) = HEADER_PROP;
                styles(end + 1, :) = {numel(items), headerStyle};
                offset = numel(items);
                items = [items; propItems(:)];
                data = [data propData];
                for s = 1:size(propStyles, 1)
                    styles(end + 1, :) = {propStyles{s, 1} + offset, propStyles{s, 2}}; %#ok<AGROW>
                end
            end
            if isempty(items)
                lb.Items = {};
                lb.ItemsData = [];
            else
                lb.Items = cellstr(items);
                lb.ItemsData = data;
                keep = selectIds(ismember(selectIds, data) & abs(selectIds) < 1e6);
                lb.Value = keep;
                for s = 1:size(styles, 1)
                    addStyle(lb, styles{s, 2}, "item", styles{s, 1});
                end
            end
            app.updateButtons();
            app.updateEstimate();
        end
        

        function runPrediction(app)
            % Segment the current object on the current slice from all its clicks.
            if isempty(app.Clicks)
                app.CurrentMask = [];
                app.CurrentScore = 0;
                app.updateOverlays();
                app.updateButtons();
                return
            end
            clicks = app.Clicks;  % snapshot: the request always uses matching points and labels
            app.IsBusy = true;
            busy = onCleanup(@() app.setIdle());
            app.setStatus("Segmenting…");
            try
                % MATLAB pixel centres are at integers; SAM uses 0-based continuous coordinates.
                out = cell(app.Backend.predict(clicks(:, 1:2) - 0.5, int32(clicks(:, 3))));
            catch err
                uialert(app.UIFigure, err.message, "Segmentation failed");
                app.setStatus("Segmentation failed.");
                return
            end
            app.CurrentMask = app.connectedMask(logical(uint8(out{1})), clicks(clicks(:, 3) == 1, 1:2));
            app.CurrentScore = double(out{2});
            app.updateOverlays();
            app.updateButtons();
            if app.ModeDropDown.Value == "3D"
                next = "press Propagate through volume.";
            else
                next = "press Add object (Enter) to keep it.";
            end
            app.setStatus(sprintf("%d point(s) · mask %d px · score %.2f · %.2f s — %s", ...
                size(clicks, 1), nnz(app.CurrentMask), app.CurrentScore, double(out{3}), next));
        end
        

        function ids = seedObjectIds(app, ask)
            % Objects added in 2D in the current view axis and not propagated yet:
            % Propagate tracks these (each from its own slice), together with any
            % clicked objects. Propagated (3D) objects are never re-propagated.
            % With ask = true and a list selection covering only some of them, the
            % user chooses all or selected.
            if nargin < 2
                ask = false;
            end
            ids = [];
            if isempty(app.Objects)
                return
            end
            ok = arrayfun(@(o) o.mode ~= "3D" && string(o.axis) == app.ViewAxis && isfinite(o.slice), app.Objects);
            ids = reshape([app.Objects(ok).id], 1, []);
            selected = intersect(app.selectedObjectIds(), ids);
            if ~ask || isempty(ids) || isempty(selected) || numel(selected) == numel(ids)
                return
            end
            allText = sprintf("All %d", numel(ids));
            selText = sprintf("Selected only (%d)", numel(selected));
            choice = uiconfirm(app.UIFigure, sprintf("%d objects added in 2D (%s view) are not propagated yet. " + ...
                "Which should be tracked through slices %d–%d?", numel(ids), app.ViewAxis, ...
                app.FromField.Value, app.ToField.Value), "Propagate objects", ...
                Options=[allText, selText, "Cancel"], DefaultOption=allText, CancelOption="Cancel");
            if choice == "Cancel"
                ids = [];
            elseif choice == selText
                ids = selected;
            end
        end
        

        function ids = selectedObjectIds(app)
            % Object ids selected in the object list (clicked-object entries and
            % group headers excluded), as a row vector.
            ids = app.listValue();
            ids = ids(ids > 0 & ids < 1e6);
        end
        

        function idx = selectedPendingIdx(app)
            % Indices into app.Pending of the clicked objects selected in the list
            % (they are listed with ItemsData -1, -2, ...).
            v = app.listValue();
            idx = -v(v < 0 & v > -1e6);
            idx = idx(idx <= numel(app.Pending));
        end
        

        function ok = sendVolume(app, dlg)
            % Copy the 8-bit volume to Python as the slices displayed (current view
            % axis and rotation); the tracker treats them as video frames. ~32 MB chunks.
            ok = true;
            key = app.ViewAxis + "/" + app.ViewRot;
            if app.VolumeSentAxis == key
                return
            end
            d = app.viewDims();
            channels = size(app.Vol, 4);
            app.Backend.volume_begin(int32(d(3)), int32(d(1)), int32(d(2)), int32(channels));
            step = max(1, floor(32e6 / (d(1) * d(2) * channels)));
            for s = 1:step:d(3)
                ks = s:min(d(3), s + step - 1);
                switch app.ViewAxis
                    case "XY"
                        chunk = permute(app.Vol(:, :, ks, :), [3 1 2 4]);   % m x rows x cols
                    case "XZ"
                        chunk = permute(app.Vol(ks, :, :, :), [1 3 2 4]);   % m x z x cols
                    otherwise
                        chunk = permute(app.Vol(:, ks, :, :), [2 3 1 4]);   % m x z x rows
                end
                if app.ViewRot ~= 0
                    % rotate every slice like the display (rot90 acts on dims 1-2)
                    chunk = permute(rot90(permute(chunk, [2 3 1 4]), app.ViewRot), [3 1 2 4]);
                end
                app.Backend.volume_put(int32(s - 1), chunk);
                dlg.Value = ks(end) / d(3);
                dlg.Message = sprintf("Sending slices to SAM: %d of %d…", ks(end), d(3));
                if dlg.CancelRequested
                    ok = false;
                    return
                end
            end
            app.VolumeSentAxis = key;
        end
        

        function setIdle(app)
            % Called (via onCleanup) when a model call finishes, even after an error.
            if isvalid(app)
                app.IsBusy = false;
            end
        end
        

        function setSlice(app, k)
            % Go to view slice k. Clicks belong to the slice they were made on, so
            % unpropagated clicks are dropped; a propagated 3D mask is kept and shown.
            d = app.viewDims();
            k = min(max(1, round(k)), d(3));
            app.SliceSlider.Value = k;
            app.SliceEditField.Value = k;
            if k == app.SliceIndex
                return
            end
            app.SliceIndex = k;
            app.NeedsEmbedding = true;
            if isempty(app.Mask3D) && isempty(app.Pending) && ~isempty(app.Clicks)
                app.Clicks = zeros(0, 3);
                app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
                app.CurrentMask = [];
                app.setStatus("Clicks cleared: they belong to the slice they were made on.");
            end
            app.showView(false);
        end
        

        function setStatus(app, msg)
            app.StatusLabel.Text = msg;
            drawnow limitrate
        end
        

        function setupView(app)
            % Configure the slice controls for the current view axis.
            d = app.viewDims();
            n = d(3);
            app.SliceIndex = min(max(1, app.SliceIndex), n);
            app.SliceSlider.Limits = [1 max(2, n)];
            app.SliceSlider.Value = app.SliceIndex;
            app.SliceEditField.Limits = [1 max(1, n)];
            app.SliceEditField.Value = app.SliceIndex;
            app.SliceCountLabel.Text = "/ " + n;
            app.FromField.Limits = [1 max(1, n)];
            app.ToField.Limits = [1 max(1, n)];
            app.FromField.Value = 1;
            app.ToField.Value = n;
            app.AxisDropDown.Enable = app.IsVolume;
            app.SliceSlider.Enable = n > 1;
            app.SliceEditField.Enable = n > 1;
            for b = [app.SliceDownBigButton app.SliceDownButton app.SliceUpButton app.SliceUpBigButton]
                b.Enable = n > 1;
            end
            app.ModeDropDown.Enable = app.IsVolume;
        end
        

        function showView(app, recreate)
            % Show the current slice. recreate = true rebuilds the axes content
            % (needed when the view size changes: new file or new axis).
            ax = app.ImageAxes;
            app.ViewIdx = app.viewIndex(app.SliceIndex);
            app.RGB = app.viewImage();
            if ~isempty(app.Mask3D)
                app.CurrentMask = app.Mask3D(app.ViewIdx) > 0;
            end
            if recreate || isempty(app.BaseImage) || ~isvalid(app.BaseImage)
                cla(ax);
                [h, w, ~] = size(app.RGB);
                app.BaseImage = image(ax, app.RGB);
                hold(ax, "on");
                blank = zeros(h, w, 3, "uint8");
                app.LabelOverlay = image(ax, blank, AlphaData=0, PickableParts="none", HitTest="off");
                app.MaskOverlay = image(ax, blank, AlphaData=0, PickableParts="none", HitTest="off");
                app.PosMarkers = plot(ax, NaN, NaN, "+", Color=[0.1 0.9 0.2], MarkerSize=16, ...
                    LineWidth=3, PickableParts="none", HitTest="off");
                app.NegMarkers = plot(ax, NaN, NaN, "x", Color=[1 0.15 0.15], MarkerSize=16, ...
                    LineWidth=3, PickableParts="none", HitTest="off");
                app.SplitMarkers = plot(ax, NaN, NaN, "o", Color=[1 0.55 0], MarkerFaceColor=[1 0.55 0], ...
                    MarkerSize=10, LineWidth=2, PickableParts="none", HitTest="off");
                hold(ax, "off");
                axis(ax, "image");
                ax.XTick = [];
                ax.YTick = [];
                % Scroll to zoom; plain clicks go to the image (no drag-to-pan).
                ax.Interactions = zoomInteraction;
                app.BaseImage.ButtonDownFcn = @(~, event) app.imageClicked(event);
            else
                app.BaseImage.CData = app.RGB;
            end
            if app.IsVolume
                names = dictionary(["XY" "XZ" "YZ"], ["Z" "Y" "X"]);
                d = app.viewDims();
                title(ax, sprintf("%s view, %s slice %d / %d", app.ViewAxis, ...
                    names(app.ViewAxis), app.SliceIndex, d(3)), Interpreter="none");
            else
                title(ax, '2D slice', Interpreter="none");
            end
            app.updateOverlays();
            app.refreshObjectList();
        end
        

        function [range, letter] = sliceRange(app, bbox)
            % Range of an object's bounding box along the current slicing axis, and
            % that axis' letter: XY view -> z, XZ view -> y (rows), YZ view -> x (cols).
            switch app.ViewAxis
                case "XY"
                    range = bbox(5:6);
                    letter = "z";
                case "XZ"
                    range = bbox(1:2);
                    letter = "y";
                otherwise
                    range = bbox(3:4);
                    letter = "x";
            end
        end
        

        function splitClick(app, event)
            % Split mode: left-click adds a split point inside the object (one per
            % part, any slice); right-click removes the last point.
            st = app.SplitState;
            isRight = event.Button == 3 || any(strcmp(app.UIFigure.SelectionType, ["alt" "extend"]));
            if isRight
                if ~isempty(st.seeds)
                    st.seeds(end) = [];
                    app.SplitState = st;
                    app.updateOverlays();
                end
                app.setStatus(sprintf("Split object %d: %d point(s).", st.id, numel(st.seeds)));
                return
            end
            xy = event.IntersectionPoint(1:2);
            [h, w] = size(app.ViewIdx);
            row = min(max(round(xy(2)), 1), h);
            col = min(max(round(xy(1)), 1), w);
            voxel = app.ViewIdx(row, col);
            if app.LabelVol(voxel) ~= st.id
                app.setStatus(sprintf("Click inside object %d (its entry is selected in the list).", st.id));
                return
            end
            st.seeds(end + 1, 1) = voxel;
            app.SplitState = st;
            app.updateOverlays();
            app.updateButtons();
            app.setStatus(sprintf("Split object %d: %d point(s). Add one per part, then Apply split (Enter); Esc cancels.", ...
                st.id, numel(st.seeds)));
        end
        

        function newIds = splitObject(app, id, seeds)
            % Split object id into one part per seed voxel (linear indices into LabelVol),
            % by a marker-controlled watershed on (distance to the nearest point minus
            % distance to the object's edge): touching blobs separate at their narrowest
            % neck; without a neck the cut falls about halfway between the points.
            % Works in 2D and 3D, inside the object's bounding box. Part 1 keeps id;
            % the others get new numbers.
            newIds = [];
            o = find([app.Objects.id] == id, 1);
            bb = app.Objects(o).bbox;
            if numel(bb) ~= 6 || any(~isfinite(bb))
                bb = app.bboxFromVoxels(find(app.LabelVol == id));
            end
            rr = bb(1):bb(2);
            cc = bb(3):bb(4);
            zz = bb(5):bb(6);
            block = app.LabelVol(rr, cc, zz);
            mask = block == id;
            [sr, sc, sz] = ind2sub(size(app.LabelVol), seeds(:));
            local = sub2ind(size(mask), sr - bb(1) + 1, sc - bb(3) + 1, sz - bb(5) + 1);
            local = local(mask(local));                       % seeds must lie inside the object
            if numel(local) < 2
                return
            end
            markers = false(size(mask));
            markers(local) = true;
            % Relief: low near the points and deep inside the object, high at narrow
            % necks and far from any point. Parts meet at a neck when there is one,
            % otherwise roughly halfway between the points.
            depth = bwdist(~mask);
            relief = bwdist(markers) - depth;
            basins = watershed(imimposemin(relief, markers));
            basins(~mask) = 0;
            seedBasin = basins(local);
            [~, firstOf] = unique(seedBasin(seedBasin > 0), "stable");   % seeds sharing a basin = one part
            kept = seedBasin(seedBasin > 0);
            kept = kept(firstOf);
            parts = zeros(size(mask), "uint16");
            for s = 1:numel(kept)
                parts(basins == kept(s)) = s;
            end
            if numel(kept) < 2
                return
            end
            % watershed ridge voxels go to the nearest part
            rest = mask & parts == 0;
            if any(rest(:))
                [~, nearest] = bwdist(parts > 0);
                parts(rest) = parts(nearest(rest));
            end
            cropSize = [size(mask, 1) size(mask, 2) size(mask, 3)];
            toVolume = @(k) app.cropToVolume(k, cropSize, bb);
            base = app.Objects(o);
            for s = 2:numel(kept)
                newId = app.NextId;
                block(parts == s) = newId;
                voxels = toVolume(find(parts == s));
                part = base;
                part.id = newId;
                part.voxels = numel(voxels);
                part.bbox = app.bboxFromVoxels(voxels);
                part.points = zeros(0, 2);
                part.labels = zeros(0, 1);
                part.target = 0;
                app.Objects(end + 1) = part;
                app.NextId = newId + 1;
                newIds(end + 1) = newId; %#ok<AGROW>
            end
            app.LabelVol(rr, cc, zz) = block;
            first = toVolume(find(parts == 1));
            app.Objects(o).voxels = numel(first);
            app.Objects(o).bbox = app.bboxFromVoxels(first);
            app.Exported = false;
        end
        

        function syncPending(app)
            % Redraw after the clicked objects changed. They are drawn through
            % pendingLabels (on their own slice), not through the refine mask/clicks.
            if ~isempty(app.Pending)
                app.Clicks = zeros(0, 3);
            end
            app.CurrentMask = [];
            app.updateOverlays();
            app.refreshObjectList();
        end
        

        function out = toUint8(app, I, lo, hi, channels)
            % Convert one page to uint8 with 1 or 3 channels, using the file-wide stretch.
            if islogical(I)
                I = uint8(I) * 255;
            end
            if channels == 1
                I = I(:, :, 1);
            else
                I = I(:, :, 1:3);
            end
            if isempty(lo)
                out = uint8(I);
            else
                d = double(I);
                d(~isfinite(d)) = lo;
                out = uint8(255 * min(max((d - lo) / (hi - lo), 0), 1));
            end
        end
        

        function updateButtons(app)
            % Enable only the actions that make sense in the current state.
            hasImage = ~isempty(app.Vol);
            hasPoints = ~isempty(app.Clicks);
            hasPending = ~isempty(app.Pending);
            has3D = ~isempty(app.Mask3D);
            hasMask = ~isempty(app.CurrentMask) && any(app.CurrentMask(:));
            hasObjects = ~isempty(app.Objects);
            is3DMode = app.IsVolume && app.ModeDropDown.Value == "3D";
            eachMode = app.ClickModeDropDown.Value == "each";
            if is3DMode
                app.AddObjectButton.Enable = has3D;
            else
                app.AddObjectButton.Enable = hasPending || (~eachMode && hasMask);
            end
            app.UndoButton.Enable = ~has3D && (hasPending || (eachMode && ~is3DMode && hasObjects) || ...
                (~eachMode && hasPoints));
            app.ClearPointsButton.Enable = hasPoints || hasPending || has3D;
            app.ResetButton.Enable = hasImage && (hasPoints || hasPending || hasObjects || has3D);
            app.ExportButton.Enable = hasObjects;
            numSelected = numel(app.selectedObjectIds()) + numel(app.selectedPendingIdx());
            app.DeleteObjectButton.Enable = numSelected >= 1;
            app.MergeObjectsButton.Enable = numSelected >= 2 && isempty(app.SplitState);
            has3DObjects = hasObjects && any([app.Objects.mode] == "3D");
            has2DObjects = hasObjects && any([app.Objects.mode] ~= "3D");
            app.DeleteAllSelectedButton.Enable = hasPending || has2DObjects;
            app.DeleteAllPropagatedButton.Enable = has3DObjects;
            app.SplitObjectButton.Enable = ~isempty(app.SplitState) || (numel(app.selectedObjectIds()) == 1 && numSelected == 1);
            app.FromField.Enable = is3DMode;
            app.ToField.Enable = is3DMode;
            canSeed = hasPending || (hasMask && isempty(app.Pending)) || (is3DMode && ~isempty(app.seedObjectIds()));
            app.PropagateButton.Enable = is3DMode && ~has3D && canSeed && app.LoadedModel ~= "sam3.1";
            app.FindButton.Enable = hasImage && app.LoadedModel ~= "sam3.1";
            app.RotateLeftButton.Enable = hasImage;
            app.RotateRightButton.Enable = hasImage;
            app.UnloadModelButton.Enable = app.LoadedKey ~= "";
        end
        

        function updateEstimate(app)
            % Propagation time estimate for what Propagate would track now, based on
            % the speed of THIS GPU: measured in earlier propagations (saved per GPU and
            % precision), else estimated from the image-embedding time, else a rough guess.
            % Model: seconds per slice = base * (1 + 0.08 * (objects in the pass - 1));
            % a run processes the range plus the slices between its first and last
            % starting slice (forward and backward passes overlap there).
            if ~app.IsVolume
                app.PropagateInfoLabel.Text = "3D mode is available for multi-page TIFF volumes.";
                return
            end
            if app.LoadedModel == "sam3.1"
                app.PropagateInfoLabel.Text = "3D propagation needs SAM 3 (Model and device tab).";
                return
            end
            base = app.SpeedPerSlice;
            source = app.SpeedSource;
            if isempty(base)
                base = 1.5;
                source = "rough guess until the first click";
            end
            first = app.FromField.Value;
            last = app.ToField.Value;
            n = max(0, last - first + 1);
            batch = app.LastBatch;
            if isempty(batch)
                batch = 8;
            end
            runs = app.propagationPlan();
            if isempty(runs)
                app.PropagateInfoLabel.Text = sprintf("Define objects (clicks, text, or 2D objects), then propagate. " + ...
                    "This GPU: about %.1f s per slice (%s).", base, source);
                return
            end
            seconds = 0;
            objects = 0;
            for r = runs
                frames = n + 1 + (r.hi - r.lo);
                left = r.objects;
                while left > 0
                    k = min(batch, left);
                    seconds = seconds + frames * base * (1 + 0.08 * (k - 1));
                    left = left - k;
                end
                objects = objects + r.objects;
            end
            app.PropagateInfoLabel.Text = sprintf("%d object(s) in %d run(s), slices %d–%d: about %s (%s).", ...
                objects, numel(runs), first, last, app.formatDuration(seconds), source);
        end
        

        function updateImportTab(app)
            % Show the file summary and a preview of the middle slice.
            s = app.FileSummary;
            if s.channels == 3
                channelText = "RGB";
            else
                channelText = "grayscale";
            end
            lines = ["File:  " + s.name, "Folder:  " + string(fileparts(app.FilePath)), "", ...
                sprintf("Size:  %d × %d pixels (width × height)", s.cols, s.rows), ...
                sprintf("Pages / slices:  %d", s.pages), ...
                sprintf("Data:  %s, %d bits per sample, %s", s.class, s.bitDepth, channelText)];
            if isempty(s.lo)
                lines(end + 1) = "Display / SAM input:  8-bit data used as is";
            else
                lines(end + 1) = sprintf("Display / SAM input:  stretched to 8 bits between %g and %g (0.5–99.5 percentile)", s.lo, s.hi);
            end
            lines(end + 1) = sprintf("Memory:  %.1f MB (8-bit copy) + %.1f MB (labels)", ...
                numel(app.Vol) / 1e6, 2 * numel(app.LabelVol) / 1e6);
            if s.pages > 1
                lines = [lines, "", "Opened as a 3D volume: use View and Slice in the Segmentation tab."];
            end
            app.FileInfoLabel.Text = lines;
            mid = ceil(size(app.Vol, 3) / 2);
            img = reshape(app.Vol(:, :, mid, :), size(app.Vol, 1), size(app.Vol, 2), []);
            if size(img, 3) == 1
                img = repmat(img, 1, 1, 3);
            end
            image(app.PreviewAxes, img);
            axis(app.PreviewAxes, "image");
            app.PreviewAxes.XTick = [];
            app.PreviewAxes.YTick = [];
            title(app.PreviewAxes, sprintf("Preview (slice %d of %d)", mid, size(app.Vol, 3)));
        end
        

        function updateModelInfo(app, info)
            % Fill the Model tab's details box from the Python environment (and loaded model).
            lines = strings(0, 1);
            try
                env = struct(py.sam3_backend.environment_info());
                yesNo = ["no" "yes"];
                lines(end + 1) = "Python:            " + string(env.python);
                lines(end + 1) = "PyTorch:           " + string(env.torch);
                lines(end + 1) = "CUDA available:    " + yesNo(1 + logical(env.cuda_available));
                if strlength(string(env.gpu)) > 0
                    lines(end + 1) = "GPU:               " + string(env.gpu);
                end
                lines(end + 1) = "sam3 package:      " + string(env.sam3_package);
                lines(end + 1) = "SAM 3 weights:     " + app.orMissing(string(env.sam3_checkpoint));
                lines(end + 1) = "SAM 3.1 weights:   " + app.orMissing(string(env.sam31_checkpoint));
            catch err
                lines(end + 1) = "Could not query the Python environment: " + err.message;
            end
            if nargin > 1
                lines(end + 1) = "";
                lines(end + 1) = "Loaded model:      " + app.modelName(string(info.version));
                lines(end + 1) = "Device:            " + string(info.device);
                lines(end + 1) = "Precision:         " + string(info.dtype);
                if double(info.vram_gb) > 0
                    lines(end + 1) = sprintf("GPU memory:        %.1f GB", double(info.vram_gb));
                end
            end
            app.ModelInfoArea.Value = cellstr(lines);
        end
        

        function updateOverlays(app)
            % Redraw committed objects, the current mask, and the click markers for the shown slice.
            if isempty(app.BaseImage) || ~isvalid(app.BaseImage)
                return
            end
            alpha = app.OpacitySlider.Value;
            L = app.LabelVol(app.ViewIdx);
            % Objects not added yet (propagated 3D result, text results, one-per-click
            % objects in 3D) are drawn in the colours they will have, with a yellow
            % outline; the single object being refined is drawn in yellow.
            D = app.pendingLabels();
            C = L;
            if ~isempty(D)
                C(C == 0 & D > 0) = D(C == 0 & D > 0);
            end
            if any(C(:))
                n = double(max(C(:)));
                cmap = app.Palette(mod(0:n - 1, size(app.Palette, 1)) + 1, :);
                app.LabelOverlay.CData = label2rgb(C, cmap, [0 0 0]);
                % objects selected in the list are drawn more opaque, with their outline
                selected = ismember(L, app.selectedObjectIds());
                app.LabelOverlay.AlphaData = min(1, alpha * double(C > 0) + 0.35 * double(selected) + double(bwperim(selected)));
            else
                app.LabelOverlay.AlphaData = 0;
            end
            yellow = zeros([size(L) 3], "uint8");
            yellow(:, :, 1) = 255;
            yellow(:, :, 2) = 215;
            m = app.CurrentMask;
            if ~isempty(D) && any(D(:))
                app.MaskOverlay.CData = yellow;
                app.MaskOverlay.AlphaData = double(boundarymask(D) & D > 0);   % "not added yet" outline per object
            elseif ~isempty(m) && isequal(size(m), size(L)) && any(m(:)) && (isempty(app.Pending) || app.onClickView())
                app.MaskOverlay.CData = yellow;
                app.MaskOverlay.AlphaData = min(1, alpha * double(m) + double(bwperim(m)));
            else
                app.MaskOverlay.AlphaData = 0;
            end
            onClickSlice = ~isempty(app.ClickView) && app.ClickView.axis == app.ViewAxis && ...
                app.ClickView.slice == app.SliceIndex && app.ClickView.rot == app.ViewRot;
            pos = [NaN NaN];
            neg = [NaN NaN];
            if ~isempty(app.Pending) && isempty(app.Mask3D)
                here = app.pendingHere();
                if any(here)
                    pos = vertcat(app.Pending(here).point);   % clicked objects of this slice
                end
            elseif onClickSlice && ~isempty(app.Clicks)
                if any(app.Clicks(:, 3) == 1)
                    pos = app.Clicks(app.Clicks(:, 3) == 1, 1:2);
                end
                if any(app.Clicks(:, 3) == 0)
                    neg = app.Clicks(app.Clicks(:, 3) == 0, 1:2);
                end
            end
            split = [NaN NaN];
            if ~isempty(app.SplitState) && ~isempty(app.SplitState.seeds)
                [onView, where] = ismember(app.SplitState.seeds, app.ViewIdx);
                if any(onView)
                    [r, c] = ind2sub(size(app.ViewIdx), where(onView));
                    split = [c r];
                end
            end
            if ~isempty(app.SplitMarkers) && isvalid(app.SplitMarkers)
                set(app.SplitMarkers, XData=split(:, 1), YData=split(:, 2));
            end
            set(app.PosMarkers, XData=pos(:, 1), YData=pos(:, 2));
            set(app.NegMarkers, XData=neg(:, 1), YData=neg(:, 2));
        end
        

        function updateWeightsInfo(app)
            % One line per model in the Model tab: where its weights will be loaded from.
            parts = strings(0, 1);
            for w = app.weightsStatus()
                label = app.modelName(w.version);
                if w.local
                    parts(end + 1) = label + ": app folder"; %#ok<AGROW>
                elseif strlength(w.cached) > 0
                    parts(end + 1) = label + ": Hugging Face cache"; %#ok<AGROW>
                else
                    parts(end + 1) = label + ": not downloaded yet"; %#ok<AGROW>
                end
            end
            app.WeightsInfoLabel.Text = strjoin(parts, "  ·  ");
        end
        

        function d = viewDims(app, axisName)
            % [height width numSlices] of the displayed 2D views along an axis,
            % after the display rotation (odd quarter turns swap height and width).
            % XY: rows x cols, slices along Z. XZ: Z x cols, slices along Y (rows).
            % YZ: Z x rows, slices along X (cols).
            if nargin < 2
                axisName = app.ViewAxis;
            end
            [r, c, z, ~] = size(app.Vol);
            switch axisName
                case "XY"
                    d = [r c z];
                case "XZ"
                    d = [z c r];
                otherwise
                    d = [z r c];
            end
            if mod(app.ViewRot, 2) == 1
                d([1 2]) = d([2 1]);
            end
        end
        

        function rgb = viewImage(app, k)
            % 8-bit RGB image of view slice k (grayscale volumes are replicated to 3 channels).
            idx = app.ViewIdx;
            if nargin > 1
                idx = app.viewIndex(k);
            end
            plane = numel(app.Vol) / size(app.Vol, 4);
            channels = size(app.Vol, 4);
            rgb = zeros([size(idx) 3], "uint8");
            for ch = 1:3
                rgb(:, :, ch) = app.Vol(idx + (min(ch, channels) - 1) * plane);
            end
        end
        

        function idx = viewIndex(app, k, axisName)
            % Linear indices (into a rows x cols x slices array) of view slice k,
            % arranged as the displayed H x W image (including the display rotation).
            % LabelVol(idx) is the label slice, and writing through idx puts a 2D
            % result back into the volume, so rotation needs no other special cases.
            if nargin < 3
                axisName = app.ViewAxis;
            end
            [r, c, z, ~] = size(app.Vol);
            switch axisName
                case "XY"
                    idx = reshape((1:r * c) + (k - 1) * r * c, r, c);
                case "XZ"
                    [cc, zz] = meshgrid(1:c, 1:z);           % view is z x c
                    idx = k + (cc - 1) * r + (zz - 1) * r * c;
                otherwise
                    [rr, zz] = meshgrid(1:r, 1:z);           % view is z x r
                    idx = rr + (k - 1) * r + (zz - 1) * r * c;
            end
            idx = rot90(idx, app.ViewRot);
        end
        

        function d = weightsDir(app)
            % The app's own weights folder (copied together with the app).
            d = fullfile(app.ProjectRoot, "weights");
        end
        

        function st = weightsStatus(app)
            % Where each model's weights are: the app's "weights" folder (used first,
            % no download or login needed), the Hugging Face cache, or nowhere yet.
            % Returns a struct array with fields version, name, file, local, cached.
            models = ["sam3" "sam3.pt" "facebook--sam3"; "sam3.1" "sam3.1_multiplex.pt" "facebook--sam3.1"];
            hub = fullfile(getenv("USERPROFILE"), ".cache", "huggingface", "hub");
            if strlength(string(getenv("HF_HOME"))) > 0
                hub = fullfile(getenv("HF_HOME"), "hub");
            end
            st = struct("version", {}, "name", {}, "file", {}, "local", {}, "cached", {});
            for m = 1:size(models, 1)
                localFile = fullfile(app.weightsDir(), models(m, 2));
                hit = dir(fullfile(hub, "models--" + models(m, 3), "snapshots", "*", models(m, 2)));
                cached = "";
                if ~isempty(hit)
                    cached = string(fullfile(hit(1).folder, hit(1).name));
                end
                st(end + 1) = struct("version", models(m, 1), "name", models(m, 2), "file", string(localFile), ...
                    "local", isfile(localFile), "cached", cached); %#ok<AGROW>
            end
        end
        

        
        function [] = Initialize_afterimport(app,vol)
            app.Vol = vol;
            app.IsVolume = size(vol, 3) > 1;
            app.LabelVol = zeros(size(vol, 1), size(vol, 2), size(vol, 3), "uint16");
            app.Objects = struct("id", {}, "voxels", {}, "score", {}, "mode", {}, "axis", {}, ...
                "slice", {}, "range", {}, "points", {}, "labels", {}, "prompt", {}, "bbox", {}, "target", {});
            app.NextId = 1;
            app.Exported = true;
            app.Mask3D = [];
            app.VolumeSentAxis = "";
            app.ViewAxis = "XY";
            app.ViewRot = 0;
            app.AxisDropDown.Value = 'XY';
            app.ModeDropDown.Value = '2D';
            app.Clicks = zeros(0, 3);
            app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
            app.CurrentMask = [];
            app.SliceIndex = ceil(size(vol, 3) / 2);
            pause(0.1);
            app.setupView();
            app.showView(true);
            app.refreshObjectList();
            %app.updateImportTab();
            app.updateEstimate();
            app.TabGroup.SelectedTab = app.SegmentTab;
            app.setStatus("Click on the image to segment.");
        end
    end

    methods (Access = public)

        function n = deleteGroup(app, which)
            % Delete a whole group of the object list:
            %   "selected"   -> clicked objects not added yet and objects added in 2D (not propagated)
            %   "propagated" -> all propagated (3D) objects
            % Returns the number of entries removed.
            n = 0;
            if which == "selected"
                n = numel(app.Pending);
                app.Pending = app.Pending([]);
                app.syncPending();
                ids = [];
                if ~isempty(app.Objects)
                    ids = [app.Objects([app.Objects.mode] ~= "3D").id];
                end
            else
                ids = [];
                if ~isempty(app.Objects)
                    ids = [app.Objects([app.Objects.mode] == "3D").id];
                end
            end
            if ~isempty(ids)
                app.deleteObject(ids);
            end
            n = n + numel(ids);
            app.refreshObjectList();
            app.updateOverlays();
        end
        

        function loadLabels(app, path)
            % Load labels exported earlier (.mat from Export labels, or a label TIFF)
            % onto the open image, replacing the current objects.
            % Also usable from the command line: app.loadLabels("img_labels.mat")
            path = string(path);
            if isempty(app.Vol)
                uialert(app.UIFigure, "Open the image first, then load its labels.", "Load labels");
                return
            end
            [~, ~, ext] = fileparts(path);
            objects = [];
            try
                if strcmpi(ext, ".mat")
                    vars = whos("-file", path);
                    if ~any(strcmp({vars.name}, "labels"))
                        error("The file has no variable ""labels"".");
                    end
                    S = load(path, "labels");
                    L = S.labels;
                    if any(strcmp({vars.name}, "objects"))
                        S = load(path, "objects");
                        objects = S.objects;
                    end
                else
                    info = imfinfo(path);
                    L = zeros(info(1).Height, info(1).Width, numel(info), "uint16");
                    for k = 1:numel(info)
                        L(:, :, k) = imread(path, Index=k, Info=info);
                    end
                end
            catch err
                uialert(app.UIFigure, err.message, "Could not read labels");
                return
            end
            if ~isequal(size(L, 1:3), size(app.LabelVol, 1:3))
                uialert(app.UIFigure, sprintf("The labels are %s but the image is %s.", ...
                    mat2str(size(L, 1:3)), mat2str(size(app.LabelVol, 1:3))), "Size mismatch");
                return
            end
            app.LabelVol = uint16(L);
            ids = reshape(double(unique(app.LabelVol(app.LabelVol > 0))), 1, []);
            template = struct("id", 0, "voxels", 0, "score", NaN, "mode", "imported", "axis", "XY", ...
                "slice", NaN, "range", [NaN NaN], "points", zeros(0, 2), "labels", zeros(0, 1), "prompt", "", ...
                "bbox", nan(1, 6), "target", 0);
            fields = string(fieldnames(template))';
            app.Objects = repmat(template, 1, 0);
            counts = accumarray(double(app.LabelVol(app.LabelVol > 0)), 1);
            for id = ids
                o = template;
                o.id = id;
                if isstruct(objects) && isfield(objects, "id")
                    k = find([objects.id] == id, 1);
                    if ~isempty(k)
                        for f = fields(isfield(objects, fields))
                            o.(f) = objects(k).(f);
                        end
                    end
                end
                o.voxels = counts(id);
                app.Objects(end + 1) = o;
            end
            missing = arrayfun(@(o) numel(o.bbox) ~= 6 || any(~isfinite(o.bbox)), app.Objects);
            if any(missing)
                dlg = uiprogressdlg(app.UIFigure, Title="Load labels", Message="Computing object ranges…");
                bb = app.computeBBoxes([app.Objects(missing).id], dlg);
                delete(dlg);
                k = find(missing);
                for m = 1:numel(k)
                    app.Objects(k(m)).bbox = bb(m, :);
                end
            end
            app.NextId = max([ids 0]) + 1;
            app.Exported = true;
            app.clearPoints();
            app.refreshObjectList();
            app.updateOverlays();
            [~, name, ext] = fileparts(path);
            app.setStatus(sprintf("Loaded %d object(s) from %s%s.", numel(ids), name, ext));
        end
        

        function openFile(app, path)
            % Read a TIFF (single page = 2D image, multi-page = 3D volume) and show it.
            % Also usable from the command line: app = SAM3Segmenter; app.openFile("img.tif")
            path = string(path);
            try
                info = imfinfo(path);
            catch err
                uialert(app.UIFigure, err.message, "Could not open image");
                return
            end
            n = numel(info);
            if n > 1 && (numel(unique([info.Width])) > 1 || numel(unique([info.Height])) > 1)
                uialert(app.UIFigure, "The pages have different sizes, so this file is not a volume. " + ...
                    "Only the first page is loaded.", "Not a volume", Icon="warning");
                n = 1;
                info = info(1);
            end
            dlg = uiprogressdlg(app.UIFigure, Title="Reading TIFF", Message="Reading " + n + " page(s)…", ...
                Cancelable="on");
            cleanup = onCleanup(@() delete(dlg));
            try
                [vol, summary] = app.readVolume(path, info, dlg);
            catch err
                uialert(app.UIFigure, err.message, "Could not read image");
                return
            end
            if isempty(vol)
                app.setStatus("Loading cancelled.");
                return
            end

            app.Vol = vol;
            app.FilePath = path;
            app.FileSummary = summary;
            app.IsVolume = size(vol, 3) > 1;
            app.LabelVol = zeros(size(vol, 1), size(vol, 2), size(vol, 3), "uint16");
            app.Objects = struct("id", {}, "voxels", {}, "score", {}, "mode", {}, "axis", {}, ...
                "slice", {}, "range", {}, "points", {}, "labels", {}, "prompt", {}, "bbox", {}, "target", {});
            app.NextId = 1;
            app.Exported = true;
            app.Mask3D = [];
            app.VolumeSentAxis = "";
            app.ViewAxis = "XY";
            app.ViewRot = 0;
            app.AxisDropDown.Value = 'XY';
            app.ModeDropDown.Value = '2D';
            app.Clicks = zeros(0, 3);
            app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
            app.CurrentMask = [];
            app.SliceIndex = ceil(size(vol, 3) / 2);
            app.setupView();
            app.showView(true);
            app.refreshObjectList();
            app.updateImportTab();
            app.updateEstimate();
            app.TabGroup.SelectedTab = app.SegmentTab;
            app.setStatus(summary.text + " — click on the image to segment.");
        end
        

    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app, vol)
            app.ProjectRoot = string(fileparts(mfilename("fullpath")));
            app.Backend = [];
            app.LoadedModel = "";
            app.LoadedKey = "";
            app.FilePath = "";
            app.FileSummary = struct("name", "", "text", "");
            app.Vol = [];
            app.IsVolume = false;
            app.ViewAxis = "XY";
            app.ViewRot = 0;  % display rotation in quarter turns (counter-clockwise)
            app.SliceIndex = 1;
            app.ViewIdx = [];
            app.RGB = [];
            app.LabelVol = [];
            app.Objects = struct("id", {}, "voxels", {}, "score", {}, "mode", {}, "axis", {}, ...
                "slice", {}, "range", {}, "points", {}, "labels", {}, "prompt", {}, "bbox", {}, "target", {});
            app.NextId = 1;
            app.Clicks = zeros(0, 3);  % one row per click: x, y, label (1 include, 0 exclude)
            app.ClickView = [];
            app.SplitState = [];     % split mode: struct(id, seeds) while choosing split points
            app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});  % one-object-per-click, 3D
            app.CurrentMask = [];
            app.CurrentScore = 0;
            app.Mask3D = [];
            app.Mask3DInfo = [];
            app.NeedsEmbedding = true;
            app.Exported = true;
            app.IsBusy = false;
            app.SpeedPerSlice = [];   % seconds per slice for 1 object on this GPU (see updateEstimate)
            app.SpeedSource = "";
            app.DeviceKey = "";
            app.LastBatch = [];
            app.VolumeSentAxis = "";
            % Distinct object colours; yellow is reserved for the mask being edited.
            app.Palette = [0.90 0.10 0.10; 0.12 0.47 0.90; 0.20 0.75 0.30; 0.85 0.25 0.85; ...
                0.10 0.80 0.85; 1.00 0.50 0.05; 0.55 0.35 0.85; 0.00 0.55 0.50; ...
                0.95 0.45 0.60; 0.60 0.40 0.20];
            app.AboutHTML.HTMLSource = fullfile(app.ProjectRoot, "docs", "SAM3_about.html");
            app.HelpHTML.HTMLSource = fullfile(app.ProjectRoot, "docs", "SAM3_help.html");
            app.ModelInfoArea.Value = {'Python and the model start when you load a model or first click on an image.'};
            app.updateWeightsInfo();
            app.updateButtons();

            app.Initialize_afterimport(vol);
        
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            if app.IsBusy || ~app.confirmDiscard()
                return
            end
            if ~isempty(app.Backend)
                try
                    app.Backend.unload();  % free GPU memory; the Python process stays for reuse
                catch
                end
            end
            delete(app);
        
        end

        % Window key press function: UIFigure
        function UIFigureWindowKeyPress(app, event)
            % Shortcuts work on the Segmentation tab only, and avoid Backspace/Delete,
            % which are editing keys in the number fields.
            if app.IsBusy || app.TabGroup.SelectedTab ~= app.SegmentTab
                return
            end
            ctrl = any(strcmp(event.Modifier, "control"));
            if ~isempty(app.SplitState)
                if strcmp(event.Key, "return")
                    app.applySplit();
                elseif strcmp(event.Key, "escape")
                    app.cancelSplit();
                    app.setStatus("Split cancelled.");
                end
                return
            end
            if strcmp(event.Key, "return") && isempty(event.Modifier)
                app.AddObjectButtonPushed(event);
            elseif strcmp(event.Key, "z") && ctrl
                app.UndoButtonPushed(event);
            elseif strcmp(event.Key, "escape")
                app.ClearPointsButtonPushed(event);
            end
        
        end

        % Callback function: not associated with a component
        function OpenButtonPushed(app, event)
            if app.IsBusy || ~app.confirmDiscard()
                return
            end
            [file, folder] = uigetfile({'*.tif;*.tiff', 'TIFF images (*.tif, *.tiff)'; '*.*', 'All files'}, ...
                "Open TIFF image or volume");
            figure(app.UIFigure);
            if isequal(file, 0)
                return
            end
            app.openFile(fullfile(folder, file));
        
        end

        % Callback function: not associated with a component
        function LoadLabelsButtonPushed(app, event)
            if app.IsBusy || isempty(app.Vol)
                if isempty(app.Vol)
                    app.setStatus("Open the image first, then load its labels.");
                end
                return
            end
            if ~app.confirmDiscard()
                return
            end
            folder = fileparts(app.FilePath);
            [file, folder] = uigetfile({'*.mat;*.tif;*.tiff', 'Labels (*.mat, *.tif)'; '*.*', 'All files'}, ...
                "Load labels", folder);
            figure(app.UIFigure);
            if isequal(file, 0)
                return
            end
            app.loadLabels(fullfile(folder, file));
            app.TabGroup.SelectedTab = app.SegmentTab;
        
        end

        % Button pushed function: AddObjectButton
        function AddObjectButtonPushed(app, event)
            if app.IsBusy
                return
            end
            changed = [];
            if ~isempty(app.Mask3D)
                % Propagated result: every tracked object extends its existing object or
                % becomes a new one. The contact rule decides voxels already used by other objects.
                info = app.Mask3DInfo;
                finals = info.sourceIds;
                newK = find(finals == 0);
                finals(newK) = app.NextId + (0:numel(newK) - 1);
                nz = find(app.Mask3D);
                tracked = double(app.Mask3D(nz));
                target = finals(tracked);
                target = target(:);
                old = double(app.LabelVol(nz));
                lostTo0 = zeros(0, 1);
                switch info.rule
                    case "overwrite"
                        sel = old ~= target;
                    case "empty"
                        clash = old > 0 & old ~= target;
                        app.LabelVol(nz(clash)) = 0;
                        lostTo0 = old(clash);
                        sel = old == 0;
                    otherwise
                        sel = old == 0;
                end
                app.LabelVol(nz(sel)) = target(sel);
                maxId = max([finals(:); old(:); app.NextId]);
                gained = accumarray(target(sel), 1, [maxId 1]);
                lost = accumarray([old(sel & old > 0); lostTo0], 1, [maxId 1]);
                % new objects (numbers already chosen; skip those that ended up empty)
                for t = reshape(newK, 1, [])
                    id = finals(t);
                    if gained(id) == 0
                        continue
                    end
                    [points, labels, prompt, score] = app.promptOf(t);
                    app.Objects(end + 1) = struct("id", id, "voxels", gained(id), "score", score, ...
                        "mode", "3D", "axis", info.axis, "slice", info.slice, "range", info.range, ...
                        "points", points, "labels", labels, "prompt", prompt, "bbox", info.bbox(t, :), "target", 0);
                    changed(end + 1) = id; %#ok<AGROW>
                end
                app.NextId = max([app.NextId, finals + 1]);
                % existing objects that were tracked: extend them
                for t = find(info.sourceIds > 0)
                    id = finals(t);
                    o = find([app.Objects.id] == id, 1);
                    if isempty(o)
                        continue
                    end
                    app.Objects(o).mode = "3D";
                    app.Objects(o).axis = info.axis;
                    app.Objects(o).range = info.range;
                    app.Objects(o).bbox = app.bboxUnion(app.Objects(o).bbox, info.bbox(t, :));
                    [points, labels] = app.promptOf(t);
                    app.Objects(o).points = [app.Objects(o).points; points];
                    app.Objects(o).labels = [app.Objects(o).labels; labels(:)];
                    changed(end + 1) = id; %#ok<AGROW>
                end
                % 2D objects tied to another object: their voxels become that object
                for a = 1:size(info.absorb, 1)
                    [src, dst] = deal(info.absorb(a, 1), info.absorb(a, 2));
                    s = find([app.Objects.id] == src, 1);
                    d = find([app.Objects.id] == dst, 1);
                    if isempty(s) || isempty(d)
                        continue
                    end
                    w = app.viewIndex(app.Objects(s).slice, app.Objects(s).axis);
                    w = w(app.LabelVol(w) == src);
                    app.LabelVol(w) = dst;
                    gained(dst) = gained(dst) + numel(w);
                    lost(src) = lost(src) + numel(w);
                    app.Objects(d).bbox = app.bboxUnion(app.Objects(d).bbox, app.Objects(s).bbox);
                    app.Objects(d).points = [app.Objects(d).points; app.Objects(s).points];
                    app.Objects(d).labels = [app.Objects(d).labels; app.Objects(s).labels(:)];
                end
                % voxel counts (and ranges of objects that lost voxels)
                shrunk = [];
                for o = 1:numel(app.Objects)
                    id = app.Objects(o).id;
                    if id <= maxId && ~ismember(id, finals(newK))
                        app.Objects(o).voxels = app.Objects(o).voxels + gained(id) - lost(id);
                        if lost(id) > 0
                            shrunk(end + 1) = o; %#ok<AGROW>
                        end
                    end
                end
                for o = shrunk
                    if app.Objects(o).voxels > 0
                        app.Objects(o).bbox = app.bboxFromVoxels(find(app.LabelVol == app.Objects(o).id));
                    end
                end
                absorbed = info.absorb(:, 1);
                app.Objects(ismember([app.Objects.id], absorbed) | [app.Objects.voxels] <= 0) = [];
                msg = sprintf("Added/extended %d 3D object(s)", numel(changed));
                if ~isempty(absorbed)
                    msg = msg + sprintf("; %d tied object(s) merged into their target", numel(absorbed));
                end
                lostIds = find(lost > 0);
                lostIds = setdiff(lostIds(:)', [changed absorbed(:)']);
                if ~isempty(lostIds)
                    msg = msg + sprintf("; %d other object(s) lost voxels (%s rule)", numel(lostIds), info.rule);
                end
                app.Exported = false;
            elseif ~isempty(app.Pending)
                % Clicked objects (text results) in 2D: each becomes an object, linked
                % ones become one object, tied ones extend their object; only free voxels.
                [keys, futureIds] = app.pendingKeys();
                madeKeys = zeros(1, 0);
                madeIds = zeros(1, 0);
                for j = 1:numel(app.Pending)
                    p = app.Pending(j);
                    w = app.viewIndex(p.slice);
                    newVoxels = w(p.mask & app.LabelVol(w) == 0);
                    if isempty(newVoxels)
                        continue
                    end
                    id = futureIds(j);
                    made = find(madeKeys == keys(j), 1);
                    if ~isempty(made)
                        id = madeIds(made);
                    end
                    d = find([app.Objects.id] == id, 1);
                    if (p.target > 0 || ~isempty(made)) && ~isempty(d)
                        app.LabelVol(newVoxels) = id;
                        app.Objects(d).voxels = app.Objects(d).voxels + numel(newVoxels);
                        app.Objects(d).bbox = app.bboxUnion(app.Objects(d).bbox, app.bboxFromVoxels(newVoxels));
                    else
                        app.addObject(newVoxels, p.score, "2D", app.ViewAxis, p.slice, [p.slice p.slice], p.point, 1, p.prompt);
                        id = app.NextId - 1;
                        madeKeys(end + 1) = keys(j); %#ok<AGROW>
                        madeIds(end + 1) = id; %#ok<AGROW>
                    end
                    changed(end + 1) = id; %#ok<AGROW>
                end
                app.Exported = false;
                msg = sprintf("Added %d object(s)", numel(unique(changed)));
            else
                m = app.CurrentMask;
                if isempty(m) || ~any(m(:))
                    return
                end
                newVoxels = app.ViewIdx(m & app.LabelVol(app.ViewIdx) == 0);
                if ~isempty(newVoxels)
                    app.addObject(newVoxels, app.CurrentScore, "2D", app.ViewAxis, app.SliceIndex, ...
                        [app.SliceIndex app.SliceIndex], app.Clicks(:, 1:2), app.Clicks(:, 3), "");
                    changed = app.NextId - 1;
                end
                msg = sprintf("Added object %d", changed);
            end
            if isempty(changed)
                app.setStatus("Already covered by existing objects.");
                return
            end
            try
                app.Backend.next_object();
            catch
            end
            app.clearPoints();
            app.refreshObjectList(changed);
            app.updateOverlays();
            app.setStatus(msg + ".");
        
        end

        % Button pushed function: UndoButton
        function UndoButtonPushed(app, event)
            if app.IsBusy || ~isempty(app.Mask3D)
                return
            end
            if ~isempty(app.Pending)
                % drop the last pending object (text result or one-per-click object in 3D)
                app.Pending(end) = [];
                app.syncPending();
                app.setStatus(sprintf("Removed the last pending object; %d left.", numel(app.Pending)));
                return
            end
            if app.ClickModeDropDown.Value == "each"
                if ~isempty(app.Objects)
                    % objects are added on click in 2D, so undo removes the newest one
                    app.deleteObject(app.Objects(end).id);
                end
                return
            end
            if isempty(app.Clicks)
                return
            end
            app.Clicks(end, :) = [];
            app.runPrediction();
            if isempty(app.Clicks)
                app.setStatus("All points removed.");
            end
        
        end

        % Button pushed function: ClearPointsButton
        function ClearPointsButtonPushed(app, event)
            if app.IsBusy
                return
            end
            app.clearPoints();
            app.setStatus("Points cleared.");
        
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            if app.IsBusy || ~app.confirmDiscard()
                return
            end
            app.LabelVol(:) = 0;
            app.Objects = struct("id", {}, "voxels", {}, "score", {}, "mode", {}, "axis", {}, ...
                "slice", {}, "range", {}, "points", {}, "labels", {}, "prompt", {}, "bbox", {}, "target", {});
            app.NextId = 1;
            app.Exported = true;
            if ~isempty(app.Backend)
                try
                    app.Backend.next_object();
                catch
                end
            end
            app.clearPoints();
            app.refreshObjectList();
            app.setStatus("All objects and points removed.");
        
        end

        % Button pushed function: ExportButton
        function ExportButtonPushed(app, event)
            if app.IsBusy
                return
            end
            % [folder, name] = fileparts(app.FilePath);
            % [file, outFolder] = uiputfile({'*.tif', 'Label image or volume, uint16 (*.tif)'; ...
            %     '*.mat', 'Labels and click prompts (*.mat)'}, "Export labels", fullfile(folder, name + "_labels.tif"));
            % figure(app.UIFigure);
            % if isequal(file, 0)
            %     return
            % end
            % target = fullfile(outFolder, file);
            % [~, ~, ext] = fileparts(target);
            % dlg = uiprogressdlg(app.UIFigure, Title="Export", Message="Writing " + file + "…", Indeterminate="on");
            % cleanup = onCleanup(@() delete(dlg));
            % try
            %     if strcmpi(ext, ".mat")
            %         labels = app.LabelVol;
            %         objects = app.Objects;  % points are in view-slice pixel coordinates (x, y)
            %         sourceFile = app.FilePath;
            %         model = app.LoadedModel;
            %         save(target, "labels", "objects", "sourceFile", "model", "-v7.3");
            %     else
            %         n = size(app.LabelVol, 3);
            %         for k = 1:n
            %             if k == 1
            %                 imwrite(app.LabelVol(:, :, k), target, Compression="deflate");
            %             else
            %                 imwrite(app.LabelVol(:, :, k), target, WriteMode="append", Compression="deflate");
            %             end
            %         end
            %     end
            % catch err
            %     uialert(app.UIFigure, err.message, "Export failed");
            %     return
            % end
            % app.Exported = true;
            % app.setStatus(sprintf("Exported %d object(s) to %s", numel(app.Objects), target));
        
            app.SegOutput = app.LabelVol;
            uiresume(app.UIFigure);

        end

        % Button pushed function: SliceDownBigButton, SliceDownButton, 
        % ...and 2 other components
        function SliceStepButtonPushed(app, event)
            % −− / − / + / ++ : move by one slice, or by a tenth of the slices on this axis.
            if app.IsBusy || isempty(app.Vol)
                return
            end
            d = app.viewDims();
            big = max(1, round(d(3) / 10));
            switch event.Source
                case app.SliceDownBigButton
                    step = -big;
                case app.SliceDownButton
                    step = -1;
                case app.SliceUpButton
                    step = 1;
                otherwise
                    step = big;
            end
            app.setSlice(app.SliceIndex + step);
        
        end

        % Value changed function: AxisDropDown
        function AxisDropDownValueChanged(app, event)
            if app.IsBusy || isempty(app.Vol)
                app.AxisDropDown.Value = event.PreviousValue;
                return
            end
            app.ViewAxis = string(event.Value);
            if isempty(app.Mask3D)
                app.Clicks = zeros(0, 3);
                app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
                app.CurrentMask = [];
            end
            d = app.viewDims();
            app.SliceIndex = ceil(d(3) / 2);
            app.NeedsEmbedding = true;
            app.setupView();
            app.showView(true);
            app.updateEstimate();
            app.setStatus(sprintf("%s view: %d slices of %d × %d.", app.ViewAxis, d(3), d(2), d(1)));
        
        end

        % Value changed function: SliceSlider
        function SliceSliderValueChanged(app, event)
            if ~app.IsBusy
                app.setSlice(event.Value);
            end
        
        end

        % Value changing function: SliceSlider
        function SliceSliderValueChanging(app, event)
            if ~app.IsBusy
                app.setSlice(event.Value);
            end
        
        end

        % Value changed function: SliceEditField
        function SliceEditFieldValueChanged(app, event)
            if app.IsBusy
                app.SliceEditField.Value = event.PreviousValue;
                return
            end
            app.setSlice(event.Value);
        
        end

        % Button pushed function: RotateLeftButton, RotateRightButton
        function RotateButtonPushed(app, event)
            if app.IsBusy || isempty(app.Vol)
                return
            end
            if event.Source == app.RotateLeftButton
                app.ViewRot = mod(app.ViewRot + 1, 4);   % counter-clockwise (rot90 convention)
            else
                app.ViewRot = mod(app.ViewRot - 1, 4);
            end
            if isempty(app.Mask3D)
                % clicks and pending masks are in view coordinates; a propagated 3D mask is kept
                app.Clicks = zeros(0, 3);
                app.Pending = struct("point", {}, "mask", {}, "score", {}, "prompt", {}, "target", {}, "slice", {}, "axis", {}, "rot", {}, "group", {});
                app.CurrentMask = [];
            end
            app.NeedsEmbedding = true;
            app.showView(true);
            app.setStatus(sprintf("View rotated by %d°.", 90 * app.ViewRot));
        
        end

        % Value changed function: ClickModeDropDown
        function ClickModeDropDownValueChanged(app, event)
            if app.IsBusy
                app.ClickModeDropDown.Value = event.PreviousValue;
                return
            end
            app.clearPoints();
            if event.Value == "each"
                app.setStatus("One object per click: left-click each object (added at once in 2D, pending in 3D); " + ...
                    "right-click removes one; Ctrl+Z undoes the last.");
            else
                app.setStatus("Refine mode: clicks combine into one object (right-click excludes); press Add object to keep it.");
            end
        
        end

        % Value changed function: TextPromptField
        function TextPromptFieldValueChanged(app, event)
            if strlength(strtrim(string(event.Value))) > 0
                app.setStatus("Press Find all to segment every """ + strtrim(string(event.Value)) + """ on this slice.");
            end
        
        end

        % Button pushed function: FindButton
        function FindButtonPushed(app, event)
            prompt = strtrim(string(app.TextPromptField.Value));
            if app.IsBusy || isempty(app.Vol)
                return
            end
            if strlength(prompt) == 0
                app.setStatus("Type a short noun phrase (e.g. ""grain"") in the text prompt field first.");
                return
            end
            if ~app.ensureEmbedding()
                return
            end
            if app.LoadedModel ~= "sam3"
                uialert(app.UIFigure, "Text prompts need SAM 3. Select it in the Model and device tab.", "SAM 3 required");
                return
            end
            app.IsBusy = true;
            busy = onCleanup(@() app.setIdle());
            app.setStatus("Searching for """ + prompt + """…");
            try
                out = cell(app.Backend.find_text(prompt, app.ScoreField.Value));
            catch err
                uialert(app.UIFigure, err.message, "Text prompt failed");
                app.setStatus("Text prompt failed.");
                return
            end
            masks = logical(uint8(out{1}));
            scores = double(out{2});
            boxes = double(out{3});
            app.discardMask3D();
            app.Clicks = zeros(0, 3);
            if ~isempty(app.Pending)
                here = [app.Pending.slice] == app.SliceIndex & strlength([app.Pending.prompt]) > 0;
                app.Pending(here) = [];   % a new search on this slice replaces the previous results here
            end
            [h, w] = size(app.ViewIdx);
            for k = 1:numel(scores)
                center = [mean(boxes(k, [1 3])), mean(boxes(k, [2 4]))] + 0.5;  % to MATLAB pixel coordinates
                app.Pending(end + 1) = struct("point", center, "mask", app.connectedMask(reshape(masks(k, :, :), h, w)), ...
                    "score", scores(k), "prompt", prompt, "target", 0, ...
                    "slice", app.SliceIndex, "axis", app.ViewAxis, "rot", app.ViewRot, "group", 0);
            end
            app.ClickView = struct("axis", app.ViewAxis, "slice", app.SliceIndex, "rot", app.ViewRot);
            app.syncPending();
            if isempty(scores)
                app.setStatus(sprintf("No ""%s"" found with score ≥ %.2f. Try another phrase or a lower Text min score.", ...
                    prompt, app.ScoreField.Value));
                return
            end
            if app.IsVolume && app.ModeDropDown.Value == "3D"
                next = "Propagate through volume";
            else
                next = "Add object (Enter) to keep them";
            end
            app.setStatus(sprintf("Found %d ""%s"" (scores %.2f–%.2f). Right-click removes wrong ones; %s.", ...
                numel(scores), prompt, min(scores), max(scores), next));
        
        end

        % Value changed function: ModeDropDown
        function ModeDropDownValueChanged(app, event)
            if app.IsBusy
                app.ModeDropDown.Value = event.PreviousValue;
                return
            end
            if event.Value == "3D" && app.LoadedModel == "sam3.1"
                app.ModeDropDown.Value = event.PreviousValue;
                uialert(app.UIFigure, "3D propagation needs SAM 3. Select it in the Model and device tab.", ...
                    "SAM 3 required");
                return
            end
            app.clearPoints();  % clicks and pending objects mean different things in 2D and 3D
            if event.Value == "2D"
                app.setStatus("Current-slice mode: objects are 2D masks on the slice where you click.");
            else
                app.setStatus("3D mode: click on one slice to define the object, then press Propagate through volume.");
            end
            app.updateOverlays();
            app.updateButtons();
            app.updateEstimate();
        
        end

        % Value changed function: FromField, ToField
        function RangeFieldsChanged(app, event)
            app.updateEstimate();
        
        end

        % Button pushed function: PropagateButton
        function PropagateButtonPushed(app, event)
            app.propagate();
        
        end

        % Value changed function: OnlySliceCheckBox
        function OnlySliceCheckBoxValueChanged(app, event)
            app.refreshObjectList();
        
        end

        % Value changed function: ObjectsListBox
        function ObjectsListBoxValueChanged(app, event)
            % Selecting an object that is not on the shown slice moves to the middle of
            % its range along the current axis (or to the slice of clicked objects).
            now = event.Value;
            if iscell(now)
                now = cell2mat(now);
            end
            before = event.PreviousValue;
            if iscell(before)
                before = cell2mat(before);
            end
            added = setdiff(double(now), double(before));
            added = added(abs(added) < 1e6);            % ignore the group headers
            if ~app.IsBusy && isscalar(added)
                if added > 0
                    o = app.Objects([app.Objects.id] == added);
                    onSlice = any(app.LabelVol(app.ViewIdx) == added, "all");
                    if ~isempty(o) && ~onSlice && isfield(o, "bbox") && all(isfinite(o.bbox))
                        r = app.sliceRange(o.bbox);
                        app.setSlice(round(mean(r)));
                    end
                elseif -added <= numel(app.Pending)
                    p = app.Pending(-added);
                    if p.axis == app.ViewAxis && p.rot == app.ViewRot && p.slice ~= app.SliceIndex
                        app.setSlice(p.slice);
                    end
                end
            end
            app.updateOverlays();   % highlight the selected objects
            app.updateButtons();
            n = numel(app.selectedObjectIds()) + numel(app.selectedPendingIdx());
            if n > 1
                app.setStatus(sprintf("%d entries selected: Merge selected joins them (clicked/2D objects merged " + ...
                    "with a propagated object are propagated as that object).", n));
            end
        
        end

        % Button pushed function: DeleteObjectButton
        function DeleteObjectButtonPushed(app, event)
            ids = app.selectedObjectIds();
            pendingIdx = app.selectedPendingIdx();
            if app.IsBusy || (isempty(ids) && isempty(pendingIdx))
                return
            end
            if ~isempty(pendingIdx)
                app.Pending(pendingIdx) = [];
                app.syncPending();
            end
            if ~isempty(ids)
                app.deleteObject(ids);
            else
                app.setStatus(sprintf("Removed %d clicked object(s).", numel(pendingIdx)));
            end
        
        end

        % Button pushed function: MergeObjectsButton
        function MergeObjectsButtonPushed(app, event)
            ids = app.selectedObjectIds();
            pendingIdx = app.selectedPendingIdx();
            if app.IsBusy || numel(ids) + numel(pendingIdx) < 2
                app.setStatus("Select two or more entries in the list (Ctrl+click or Shift+click), then Merge.");
                return
            end
            app.mergeObjects(ids, pendingIdx);
        
        end

        % Button pushed function: SplitObjectButton
        function SplitObjectButtonPushed(app, event)
            % First press: start split mode for the selected object. Second press: apply.
            if app.IsBusy
                return
            end
            if ~isempty(app.SplitState)
                app.applySplit();
                return
            end
            ids = app.selectedObjectIds();
            if ~isscalar(ids)
                app.setStatus("Select exactly one object in the list to split it.");
                return
            end
            app.SplitState = struct("id", ids, "seeds", zeros(0, 1));
            app.SplitObjectButton.Text = "Apply split";
            app.updateOverlays();
            app.setStatus(sprintf("Split object %d: click one point inside each part (2 or more; any slice), " + ...
                "then Apply split or Enter. Right-click removes the last point, Esc cancels.", ids));
        
        end

        % Button pushed function: DeleteAllPropagatedButton, 
        % ...and 1 other component
        function DeleteAllButtonPushed(app, event)
            % Shared by "Delete all not propagated" and "Delete all propagated" (asks first).
            if app.IsBusy
                return
            end
            if event.Source == app.DeleteAllSelectedButton
                which = "selected";
                what = "all clicked objects and all objects added in 2D (not propagated)";
            else
                which = "propagated";
                what = "all propagated (3D) objects";
            end
            choice = uiconfirm(app.UIFigure, "Delete " + what + "? This cannot be undone.", "Delete all", ...
                Options=["Delete", "Cancel"], DefaultOption="Cancel", CancelOption="Cancel", Icon="warning");
            if choice ~= "Delete"
                return
            end
            if ~isempty(app.SplitState)
                app.cancelSplit();
            end
            n = app.deleteGroup(which);
            word = "entries";
            if n == 1
                word = "entry";
            end
            app.setStatus(sprintf("Deleted %d %s (%s).", n, word, what));
        
        end

        % Value changed function: OpacitySlider
        function OpacitySliderValueChanged(app, event)
            app.updateOverlays();
        
        end

        % Value changed function: DeviceDropDown, ModelDropDown, 
        % ...and 1 other component
        function ModelSettingsChanged(app, event)
            if app.LoadedKey == ""
                return
            end
            app.ModelLamp.Color = [0.65 0.65 0.65];
            app.ModelStatusLabel.Text = "Settings changed: press Load model (or click on the image) to apply.";
            app.clearPoints();
        
        end

        % Value changed function: BatchModeDropDown, BatchSizeField
        function BatchSettingsChanged(app, event)
            app.BatchSizeField.Enable = app.BatchModeDropDown.Value == "custom";
            app.batchSize();   % refresh the displayed value
            app.updateEstimate();
        
        end

        % Button pushed function: StoreWeightsButton
        function StoreWeightsButtonPushed(app, event)
            % Put the weights in the app's "weights" folder, so a copy of the app folder
            % works on another computer without downloading or logging in to Hugging Face.
            % SAM 3 is copied from the Hugging Face cache (downloaded if needed); SAM 3.1
            % is copied only if it is already in the cache.
            if app.IsBusy
                return
            end
            folder = app.weightsDir();
            status = app.weightsStatus();
            app.IsBusy = true;
            busy = onCleanup(@() app.setIdle());
            dlg = uiprogressdlg(app.UIFigure, Title="Store weights", Message="Preparing…", Indeterminate="on");
            cleanup = onCleanup(@() delete(dlg));
            done = strings(0, 1);
            try
                if ~isfolder(folder)
                    mkdir(folder);
                end
                for w = status
                    if w.local
                        done(end + 1) = app.modelName(w.version) + " (already there)"; %#ok<AGROW>
                        continue
                    end
                    if strlength(w.cached) > 0
                        dlg.Message = sprintf("Copying %s (%.1f GB) into %s…", w.name, dir(w.cached).bytes / 1e9, folder);
                        drawnow
                        copyfile(w.cached, w.file);
                        done(end + 1) = app.modelName(w.version) + " (copied)"; %#ok<AGROW>
                    elseif w.version == "sam3"
                        if ~app.ensurePython()
                            return
                        end
                        dlg.Message = "Downloading sam3.pt (3.5 GB) from Hugging Face into " + folder + "…";
                        drawnow
                        py.sam3_backend.download_weights("sam3", folder);
                        done(end + 1) = "SAM 3 (downloaded)"; %#ok<AGROW>
                    end
                end
                licenseFile = fullfile(app.ProjectRoot, "sam3", "LICENSE");
                if isfile(licenseFile)
                    copyfile(licenseFile, fullfile(folder, "SAM_LICENSE.txt"));   % the SAM License travels with the weights
                end
            catch err
                uialert(app.UIFigure, err.message, "Store weights failed");
                app.updateWeightsInfo();
                return
            end
            app.updateWeightsInfo();
            app.setStatus("Weights in " + folder + ": " + strjoin(done, ", ") + ". The app loads them from there from now on.");
        
        end

        % Button pushed function: LoadModelButton
        function LoadModelButtonPushed(app, event)
            if app.IsBusy
                return
            end
            if ~isempty(app.Vol)
                app.ensureEmbedding();
            else
                app.ensureModel();
            end
        
        end

        % Button pushed function: UnloadModelButton
        function UnloadModelButtonPushed(app, event)
            if app.IsBusy || isempty(app.Backend)
                return
            end
            app.Backend.unload();
            app.LoadedKey = "";
            app.LoadedModel = "";
            app.NeedsEmbedding = true;
            app.VolumeSentAxis = "";
            app.clearPoints();
            app.ModelLamp.Color = [0.65 0.65 0.65];
            app.ModelStatusLabel.Text = "Not loaded (GPU memory released)";
            app.updateModelInfo();
            app.batchSize();
            app.updateButtons();
            app.setStatus("Model unloaded.");
        
        end

        % Button pushed function: CancelandreturntoMATBOXButton
        function CancelandreturntoMATBOXButtonPushed(app, event)
            app.SegOutput = [];
            uiresume(app.UIFigure);
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = MATBOX_SAM3Segmenter(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end