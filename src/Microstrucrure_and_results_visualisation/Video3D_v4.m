function Video3D_v4(Img,box_sz,seq,times,vis,p)

% Size and quality
hFig = uifigure;
scrsz = get(0,'ScreenSize'); % Screen resolution
set(hFig,'position',[scrsz(1) scrsz(2) scrsz(3)*p.figure_size scrsz(4)*p.figure_size]);
viewer = viewer3d('Parent',hFig);
viewer.RenderingQuality = 'High';

% Box and scale bar
viewer.Box = p.box;
viewer.ScaleBar = false;
viewer.OrientationAxes = p.orientationaxes;

% Background, gradient and lighting
viewer.BackgroundColor = p.backgroundcolor;
viewer.GradientColor = p.gradientcolor;
viewer.BackgroundGradient = p.gradient;
viewer.Lighting="on";

%% VOLSHOW OBJECTS
kchildren = 0;
for k=1:length(Img)
    if Img(k).selected
        kchildren = kchildren+1;

        % Translation transformation
        tform = transltform3d([Img(k).ty,Img(k).tx,Img(k).tz]); % Switch axe X and Y

        tmp = Img(k).modified_forcolormap;
        tmp = whos('tmp');
        if strcmp(tmp.class,'uint8')
            visk = uint8(vis(kchildren));
        elseif strcmp(tmp.class,'uint16')
            visk = uint16(vis(kchildren));
        elseif strcmp(tmp.class,'uint32')
            visk = uint32(vis(kchildren));
        end  
        Img(k).visible = Img(k).modified_forcolormap * visk;

        min_(k) = double(min(min(min(Img(k).modified_forcolormap))));
        max_(k) = double(max(max(max(Img(k).modified_forcolormap))));

        % Note: volobj need to be initialize with the full volume (i.e., Img(k).modified_forcolormap)
        %       Otherwise it can cause opacity/colormap issue (especially if in the first frame the volume is fully clipped (not visible)
        %       Just after, we replace with the initial state (i.e., Img(k).visible)
        if strcmp(Img(k).datatype,'grey')
            volobj = volshow([],"Parent",viewer,"OverlayData",Img(k).modified_forcolormap,"OverlayColormap",Img(k).colmap,'OverlayAlphamap',Img(k).alphamap,'OverlayDisplayRangeMode',"data-range","Transformation",tform);
            volobj.RenderingStyle="GradientOpacity";
            volobj.OverlayRenderingStyle="LabelOverlay";
            viewer.Children(kchildren).OverlayData = Img(k).visible;
        elseif strcmp(Img(k).datatype,'semantic')
            if p.opacitfy_cummulative
                volobj = volshow(Img(k).modified_forcolormap,"Parent",viewer,"Interpolation","nearest","Colormap",Img(k).colmap,"Alphamap",Img(k).alphamap,"Transformation",tform);
                volobj.DisplayRangeMode = "manual";
                volobj.DisplayRange = [min_(k) max_(k)];
                viewer.Children(kchildren).Data = Img(k).visible;
            else
                volobj = volshow([],"Parent",viewer,"OverlayData",Img(k).modified_forcolormap,"Transformation",tform);
                [n_,~] = size(Img(k).colmap);
                volobj.OverlayColormap(1:n_,:) = Img(k).colmap;
                volobj.OverlayAlphamap(1:n_,:) = Img(k).alphamap; % Thanks Mathwork support to help me how to handle opacity correctly
                viewer.Children(kchildren).OverlayData = Img(k).visible;
            end
        elseif strcmp(Img(k).datatype,'instance')
            volobj = volshow([],"Parent",viewer,"OverlayData",Img(k).modified_forcolormap,"OverlayAlpha",1,"OverlayColormap",Img(k).colmap,'OverlayDisplayRangeMode',"data-range","Transformation",tform);
            viewer.Children(kchildren).OverlayData = Img(k).visible;
        end        

        Img(k).center = size(Img(k).modified_forcolormap)/2;
        % idx = find(Img(k).modified_forcolormap~=0);
        % [IX,IY,IZ] = ind2sub(size(Img(k).modified_forcolormap),idx);
        % Img(k).center = [mean(IX) mean(IY) mean(IZ)]/2;

        %drawnow
        %pause(0.1);
        %drawnow
    end
end
clear tmp;

%% SCALEBAR
% Switch axe X and Y
sav_box_sz = box_sz;
box_sz(1) = sav_box_sz(2);
box_sz(2) = sav_box_sz(1);
if p.scalebar
    if strcmp(p.scalebar_alignment,'Along axe x')
        if strcmp(p.scalebar_lengthexpressedin,'in ratio of the aligned axe length')
            linelength_voxel = round(box_sz(1)*p.scalebar_length);
        else
            linelength_voxel = p.scalebar_length/p.voxellength;
        end
        if strcmp(p.scalebar_xlocation,'beginning of axe x')
            x0 = 1;
        elseif strcmp(p.scalebar_xlocation,'middle of axe x')
            x0 = round(box_sz(1)/2);
        elseif strcmp(p.scalebar_xlocation,'end of axe x')
            x0 = box_sz(1);
        end
        x1 = x0+linelength_voxel-1;

        if strcmp(p.scalebar_ylocation,'beginning of axe y')
            y0 = - p.scalebar_dist_fromplane_xz*box_sz(2);
        elseif strcmp(p.scalebar_ylocation,'middle of axe y')
            y0 = round(box_sz(2)/2);
        elseif strcmp(p.scalebar_ylocation,'end of axe y')
            y0 = box_sz(2) + p.scalebar_dist_fromplane_xz*box_sz(2);
        end
        y1 = y0;

        if strcmp(p.scalebar_zlocation,'beginning of axe z')
            z0 = - p.scalebar_dist_fromplane_xy*box_sz(3);
        elseif strcmp(p.scalebar_zlocation,'middle of axe z')
            z0 = round(box_sz(3)/2);
        elseif strcmp(p.scalebar_zlocation,'end of axe z')
            z0 = box_sz(3) + p.scalebar_dist_fromplane_xy*box_sz(3);
        end
        z1 = z0;

    elseif strcmp(p.scalebar_alignment,'Along axe y')
        if strcmp(p.scalebar_lengthexpressedin,'in ratio of the aligned axe length')
            linelength_voxel = round(box_sz(2)*p.scalebar_length);
        else
            linelength_voxel = p.scalebar_length/p.voxellength;
        end

        if strcmp(p.scalebar_xlocation,'beginning of axe x')
            x0 = - p.scalebar_dist_fromplane_yz*box_sz(1);
        elseif strcmp(p.scalebar_xlocation,'middle of axe x')
            x0 = round(box_sz(1)/2);
        elseif strcmp(p.scalebar_xlocation,'end of axe x')
            x0 = box_sz(1) + p.scalebar_dist_fromplane_yz*box_sz(1);
        end
        x1 = x0;

        if strcmp(p.scalebar_ylocation,'beginning of axe y')
            y0 = 1;
        elseif strcmp(p.scalebar_ylocation,'middle of axe y')
            y0 = round(box_sz(2)/2);
        elseif strcmp(p.scalebar_ylocation,'end of axe y')
            y0 = box_sz(2);
        end
        y1 = y0+linelength_voxel-1;

        if strcmp(p.scalebar_zlocation,'beginning of axe z')
            z0 = - p.scalebar_dist_fromplane_xy*box_sz(3);
        elseif strcmp(p.scalebar_zlocation,'middle of axe z')
            z0 = round(box_sz(3)/2);
        elseif strcmp(p.scalebar_zlocation,'end of axe z')
            z0 = box_sz(3) + p.scalebar_dist_fromplane_xy*box_sz(3);
        end
        z1 = z0;

    elseif strcmp(p.scalebar_alignment,'Along axe z')
        if strcmp(p.scalebar_lengthexpressedin,'in ratio of the aligned axe length')
            linelength_voxel = round(box_sz(3)*p.scalebar_length);
        else
            linelength_voxel = p.scalebar_length/p.voxellength;
        end
        if strcmp(p.scalebar_xlocation,'beginning of axe x')
            x0 = - p.scalebar_dist_fromplane_yz*box_sz(1);
        elseif strcmp(p.scalebar_xlocation,'middle of axe x')
            x0 = round(box_sz(1)/2);
        elseif strcmp(p.scalebar_xlocation,'end of axe x')
            x0 = box_sz(1) + p.scalebar_dist_fromplane_yz*box_sz(1);
        end
        x1 = x0;

        if strcmp(p.scalebar_ylocation,'beginning of axe y')
            y0 = - p.scalebar_dist_fromplane_xz*box_sz(2);
        elseif strcmp(p.scalebar_ylocation,'middle of axe y')
            y0 = round(box_sz(2)/2);
        elseif strcmp(p.scalebar_ylocation,'end of axe y')
            y0 = box_sz(2) + p.scalebar_dist_fromplane_xz*box_sz(2);
        end
        y1 = y0;

        if strcmp(p.scalebar_zlocation,'beginning of axe z')
            z0 = 1;
        elseif strcmp(p.scalebar_zlocation,'middle of axe z')
            z0 = round(box_sz(3)/2);
        elseif strcmp(p.scalebar_zlocation,'end of axe z')
            z0 = box_sz(1);
        end
        z1 = z0+linelength_voxel-1;

    end

    linelength_physical = linelength_voxel*p.voxellength;
    linelength_label = [num2str(linelength_physical) ' ' p.voxelunit];

    line = images.ui.graphics.roi.Line(Position=[x0 y0 z0; x1 y1 z1],Color="black",Label=linelength_label);
    viewer.Annotations = line;
end

%% CAMERA POSITION
dref = sqrt(box_sz(1)^2 + box_sz(2)^2 + box_sz(3)^2);

viewer.CameraTarget = [box_sz(1)*p.CameraTarget(1) box_sz(2)*p.CameraTarget(2) box_sz(3)*p.CameraTarget(3)];

if strcmp(p.CameraPosition_coordinatesystem,'spherical')
    d = sqrt(box_sz(1)^2 + box_sz(2)^2 + box_sz(3)^2);
    [x,y,z] = sph2cart(deg2rad(p.CameraPosition_azimuth),deg2rad(p.CameraPosition_elevation),p.CameraPosition_distance*dref);
    x = x + viewer.CameraTarget(1);
    y = y + viewer.CameraTarget(2);
    z = z + viewer.CameraTarget(3);
    viewer.CameraPosition = [x y z];
elseif strcmp(p.CameraPosition_coordinatesystem,'cartesian ')
    viewer.CameraPosition = [box_sz(1)*p.CameraPosition_x box_sz(2)*p.CameraPosition_y box_sz(3)*p.CameraPosition_z];
end

viewer.CameraUpVector = p.CameraVector;

viewer.CameraZoom = p.zoom;

%% LIGHING
viewer.AmbientLight = p.ambient_light;
viewer.DiffuseLight = p.diffuse_light;
viewer.LightColor = p.light_color;
if strcmp(p.light_position_mode,'manual (cartesian)')
    viewer.LightPosition = [box_sz(1)*p.light_position_x box_sz(2)*p.light_position_y box_sz(3)*p.light_position_z];
elseif strcmp(p.light_position_mode,'manual (spherical)')
    d = sqrt(box_sz(1)^2 + box_sz(2)^2 + box_sz(3)^2);
    [x,y,z] = sph2cart(deg2rad(p.light_position_az),deg2rad(p.light_position_el),1*d);
    x = x + viewer.CameraTarget(1);
    y = y + viewer.CameraTarget(2);
    z = z + viewer.CameraTarget(3);
    viewer.LightPosition = [x y z];
end

%% FIRST FRAME
video_format = 'mpeg-4';
video_handle = VideoWriter([p.savefolder p.filename],video_format);
set(video_handle,'Quality',100); % Set video quality
set(video_handle,'FrameRate',p.fps);
open(video_handle);

current_frame = 0;

%% SEQUENCE
kchildren=0;
for k=1:length(Img)
    if Img(k).selected 
        kchildren = kchildren+1;
        vol(kchildren).tr_history = [0 0 0];
        vol(kchildren).rot_history = [0 0 0];
    end
end

for kseq = 1:1:length(seq)
    nframe = round(times(kseq) * p.fps);
    nframe = max([1 nframe]);
    pp.nframe = nframe;


    %% CLIP LABEL
    if isfield(seq(kseq),'cliplabel') && ~isempty(seq(kseq).cliplabel)
        pp.change_is = seq(kseq).cliplabel_change_is;
        pp.profile = seq(kseq).cliplabel_profile;
        pp.sens = seq(kseq).cliplabel_sens;

        kchildren = 0;
        for k=1:length(Img)
            if Img(k).selected
                kchildren = kchildren+1;
                if seq(kseq).vol(kchildren).cliplabel_todo
                    pp.start = seq(kseq).vol(kchildren).cliplabel_times(1);
                    pp.end = seq(kseq).vol(kchildren).cliplabel_times(2);
                    if cell2mat(seq(kseq).vol(kchildren).cliplabel_ordering_size)
                        psort.keepunchangedsomelabels = true;
                        psort.cst = '0';
                        psort.order = 'increasing';
                        [Imgsorted,~,~] = fct_sortpersize(Img(k).modified_forcolormap,psort);
                        seq(kseq).vol(kchildren).Imgsorted = Imgsorted;

                        a = double( ( max(max(max(Imgsorted))) - min(min(min(Imgsorted)))  )/(1-0) );
                        b = double( min(min(min(Imgsorted))) ); 
                        pp.startval = a * seq(kseq).vol(kchildren).cliplabel_fromto(1) + b;
                        pp.endval = a * seq(kseq).vol(kchildren).cliplabel_fromto(2) + b;
                        labels_clip(k).start = pp.startval;
                        labels_clip(k).frame = getnewvals(pp); 

                    else
                        a = (max_(k)-min_(k))/(1-0);
                        b = min_(k); 
                        pp.startval = a * seq(kseq).vol(kchildren).cliplabel_fromto(1) + b;
                        pp.endval = a * seq(kseq).vol(kchildren).cliplabel_fromto(2) + b;
                        labels_clip(k).start = pp.startval;
                        labels_clip(k).frame = getnewvals(pp);
                    end
                    if strcmp(Img(k).datatype,'instance') || strcmp(Img(k).datatype,'semantic')
                        labels_clip(k).start = round(labels_clip(k).start);
                        labels_clip(k).frame = round(labels_clip(k).frame);
                    end
                end
            end
        end
    end  

    if isfield(seq(kseq),'camera_zoom_todo') && ~isempty(seq(kseq).camera_zoom_todo)
        
        
        pp.start = 0;
        pp.end = 1;

        %% Camera Zoom
        if seq(kseq).camera_zoom_todo
            pp.change_is = seq(kseq).camera_zoom_change_is;
            pp.profile = seq(kseq).camera_zoom_profile;
            pp.sens = seq(kseq).camera_zoom_sens;
            pp.startval = viewer.CameraZoom;
            pp.endval = seq(kseq).camera_zoom_value;
            new_camera_zoom = getnewvals(pp);
        else
            new_camera_zoom = ones(nframe,1)*viewer.CameraZoom; % Unchanged
        end

        

        %% Camera Vector
        if seq(kseq).camera_vector_todo
            pp.change_is = seq(kseq).camera_vector_change_is;
            pp.profile = seq(kseq).camera_vector_profile;
            pp.sens = seq(kseq).camera_vector_sens;
            vec = seq(kseq).camera_vector_value;
            vec = vec/norm(vec);
            pp.startval = viewer.CameraUpVector(1); pp.endval = vec(1); new_camera_vector_1 = getnewvals(pp);
            pp.startval = viewer.CameraUpVector(2); pp.endval = vec(2); new_camera_vector_2 = getnewvals(pp);
            pp.startval = viewer.CameraUpVector(3); pp.endval = vec(3); new_camera_vector_3 = getnewvals(pp);
        else
            new_camera_vector_1 = ones(nframe,1)*viewer.CameraUpVector(1); % Unchanged
            new_camera_vector_2 = ones(nframe,1)*viewer.CameraUpVector(2);
            new_camera_vector_3 = ones(nframe,1)*viewer.CameraUpVector(3);
        end

        %% Camera Position
        if seq(kseq).camera_position_todo
            pp.change_is = seq(kseq).camera_coordinate_change_is;
            pp.profile = seq(kseq).camera_coordinate_profile;
            pp.sens = seq(kseq).camera_coordinate_sens;

            % X and Y
            if strcmp(seq(kseq).camera_coordinate,'cartesian')
                if strcmp(seq(kseq).camera_x_choice,'unchanged')
                    new_camera_pos_x = ones(nframe,1)*viewer.CameraPosition(1);
                else
                    if strcmp(seq(kseq).camera_x_choice,'absolute')
                        new_x = box_sz(1)*seq(kseq).camera_x;
                    elseif strcmp(seq(kseq).camera_x_choice,'delta')
                        new_x = viewer.CameraPosition(1) + box_sz(1)*seq(kseq).camera_x;
                    end
                    pp.startval = viewer.CameraPosition(1); pp.endval = new_x; new_camera_pos_x = getnewvals(pp);
                end
                if strcmp(seq(kseq).camera_y_choice,'unchanged')
                    new_camera_pos_y = ones(nframe,1)*viewer.CameraPosition(2);
                else
                    if strcmp(seq(kseq).camera_y_choice,'absolute')
                        new_y = box_sz(2)*seq(kseq).camera_y;
                    elseif strcmp(seq(kseq).camera_y_choice,'delta')
                        new_y = viewer.CameraPosition(2) + box_sz(2)*seq(kseq).camera_y;
                    end
                    pp.startval = viewer.CameraPosition(2); pp.endval = new_y; new_camera_pos_y = getnewvals(pp);
                end
            end

            % Z
            if strcmp(seq(kseq).camera_coordinate,'helical') || strcmp(seq(kseq).camera_coordinate,'cartesian')
                if strcmp(seq(kseq).camera_z_choice,'unchanged')
                    new_camera_pos_z = ones(nframe,1)*viewer.CameraPosition(3);
                else
                    if strcmp(seq(kseq).camera_z_choice,'absolute')
                        new_z = box_sz(3)*seq(kseq).camera_z;
                    elseif strcmp(seq(kseq).camera_z_choice,'delta')
                        new_z = viewer.CameraPosition(3) + box_sz(3)*seq(kseq).camera_z;
                    end
                    pp.startval = viewer.CameraPosition(3); pp.endval = new_z; new_camera_pos_z = getnewvals(pp);
                end
            end

            % Elevation, azimuth and distance
            if strcmp(seq(kseq).camera_coordinate,'spherical') || strcmp(seq(kseq).camera_coordinate,'helical')
                x = viewer.CameraPosition(1) - viewer.CameraTarget(1);
                y = viewer.CameraPosition(2) - viewer.CameraTarget(2);
                z = viewer.CameraPosition(3) - viewer.CameraTarget(3);
                [az,el,d] = cart2sph(x,y,z); % Current position
                az = rad2deg(az); el = rad2deg(el);  d = d/dref;

                if strcmp(seq(kseq).camera_azimuth_choice,'unchanged')
                    new_az = ones(nframe,1)*az;
                else
                    if strcmp(seq(kseq).camera_azimuth_choice,'absolute')
                        pp.startval = az; pp.endval = seq(kseq).camera_azimuth; new_az = getnewvals(pp);
                    elseif strcmp(seq(kseq).camera_azimuth_choice,'delta')
                        pp.startval = az; pp.endval = az+seq(kseq).camera_azimuth; new_az = getnewvals(pp);
                    end
                end
                if strcmp(seq(kseq).camera_elevation_choice,'unchanged') || strcmp(seq(kseq).camera_coordinate,'helical')
                    new_el = ones(nframe,1)*el;
                else
                    if strcmp(seq(kseq).camera_elevation_choice,'absolute')
                        pp.startval = el; pp.endval = seq(kseq).camera_elevation; new_el = getnewvals(pp);
                    elseif strcmp(seq(kseq).camera_elevation_choice,'delta')
                        pp.startval = el; pp.endval = el+seq(kseq).camera_elevation; new_el = getnewvals(pp);
                    end
                end
                if strcmp(seq(kseq).camera_dist_choice,'unchanged')
                    new_d = ones(nframe,1)*d;
                else
                    if strcmp(seq(kseq).camera_dist_choice,'absolute')
                        pp.startval = d; pp.endval = seq(kseq).camera_dist; new_d = getnewvals(pp);
                    elseif strcmp(seq(kseq).camera_dist_choice,'delta')
                        pp.startval = d; pp.endval = d+seq(kseq).camera_dist; new_d = getnewvals(pp);
                        new_d(new_d<=1e-9) = 1e-9;
                    end
                end

                new_az = reshape(new_az,[nframe,1]);
                new_el = reshape(new_el,[nframe,1]);
                new_d = reshape(new_d,[nframe,1]);

                [x,y,z] = sph2cart(deg2rad(new_az),deg2rad(new_el),new_d.*dref);
                new_camera_pos_x = x + viewer.CameraTarget(1);
                new_camera_pos_y = y + viewer.CameraTarget(2);
                if strcmp(seq(kseq).camera_coordinate,'spherical')
                    new_camera_pos_z = z + viewer.CameraTarget(3);
                end
            end

        else
            new_camera_pos_x = ones(nframe,1)*viewer.CameraPosition(1); % Unchanged
            new_camera_pos_y = ones(nframe,1)*viewer.CameraPosition(2);
            new_camera_pos_z = ones(nframe,1)*viewer.CameraPosition(3);
        end

        %% Camera Target
        if seq(kseq).camera_target_todo
            pp.change_is = seq(kseq).camera_target_change_is;
            pp.profile = seq(kseq).camera_target_profile;
            pp.sens = seq(kseq).camera_target_sens;
            if strcmp(seq(kseq).camera_target_x_is,'free')
                new_x = box_sz(1)*seq(kseq).camera_target_x;
                pp.startval = viewer.CameraTarget(1); pp.endval = new_x; new_camera_target_x = getnewvals(pp);
            elseif strcmp(seq(kseq).camera_target_x_is,'unchanged')
                new_camera_target_x = ones(nframe,1)*viewer.CameraTarget(1);
            elseif strcmp(seq(kseq).camera_target_x_is,'linked to camera position x')
                new_camera_target_x = new_camera_pos_x;
            elseif strcmp(seq(kseq).camera_target_x_is,'Constant angle: t=p-(old p-old t)')
                new_camera_target_x = new_camera_pos_x - (viewer.CameraPosition(1) - viewer.CameraTarget(1));
            end
            if strcmp(seq(kseq).camera_target_y_is,'free')
                new_y = box_sz(2)*seq(kseq).camera_target_y;
                pp.startval = viewer.CameraTarget(2); pp.endval = new_y; new_camera_target_y = getnewvals(pp);
            elseif strcmp(seq(kseq).camera_target_y_is,'unchanged')
                new_camera_target_y = ones(nframe,1)*viewer.CameraTarget(2);
            elseif strcmp(seq(kseq).camera_target_y_is,'linked to camera position y')
                new_camera_target_y = new_camera_pos_y;
            elseif strcmp(seq(kseq).camera_target_y_is,'Constant angle: t=p-(old p-old t)')
                new_camera_target_y = new_camera_pos_y - (viewer.CameraPosition(2) - viewer.CameraTarget(2));
            end
            if strcmp(seq(kseq).camera_target_z_is,'free')
                new_z = box_sz(3)*seq(kseq).camera_target_z;
                pp.startval = viewer.CameraTarget(3); pp.endval = new_z; new_camera_target_z = getnewvals(pp);
            elseif strcmp(seq(kseq).camera_target_z_is,'unchanged')
                new_camera_target_z = ones(nframe,1)*viewer.CameraTarget(3);
            elseif strcmp(seq(kseq).camera_target_z_is,'linked to camera position z')
                new_camera_target_z = new_camera_pos_z;
            elseif strcmp(seq(kseq).camera_target_z_is,'Constant angle: t=p-(old p-old t)')
                new_camera_target_z = new_camera_pos_z - (viewer.CameraPosition(3) - viewer.CameraTarget(3));
            end
        else
            new_camera_target_x = ones(nframe,1)*viewer.CameraTarget(1);
            new_camera_target_y = ones(nframe,1)*viewer.CameraTarget(2);
            new_camera_target_z = ones(nframe,1)*viewer.CameraTarget(3);
        end

    else
        new_camera_zoom = ones(nframe,1)*viewer.CameraZoom; % Unchanged

        new_camera_vector_1 = ones(nframe,1)*viewer.CameraUpVector(1); % Unchanged
        new_camera_vector_2 = ones(nframe,1)*viewer.CameraUpVector(2);
        new_camera_vector_3 = ones(nframe,1)*viewer.CameraUpVector(3);

        new_camera_pos_x = ones(nframe,1)*viewer.CameraPosition(1); % Unchanged
        new_camera_pos_y = ones(nframe,1)*viewer.CameraPosition(2);
        new_camera_pos_z = ones(nframe,1)*viewer.CameraPosition(3);

        new_camera_target_x = ones(nframe,1)*viewer.CameraTarget(1);
        new_camera_target_y = ones(nframe,1)*viewer.CameraTarget(2);
        new_camera_target_z = ones(nframe,1)*viewer.CameraTarget(3);
    end

    %% LIGHING
    if isfield(seq(kseq),'light_intensity_todo') && ~isempty(seq(kseq).light_intensity_todo)
        pp.start = 0;
        pp.end = 1;

        %% Light intensity
        if seq(kseq).light_intensity_todo
            pp.change_is = seq(kseq).light_intensity_change;
            pp.profile = seq(kseq).light_intensity_profile;
            pp.sens = seq(kseq).light_intensity_sens;
            pp.startval = viewer.AmbientLight;
            pp.endval = seq(kseq).light_newambientintensity_value;
            new_ambientlight_intensity = getnewvals(pp);
            pp.startval = viewer.DiffuseLight;
            pp.endval = seq(kseq).light_newsourceintensity_value;
            new_sourcelight_intensity = getnewvals(pp);            
        else
            new_ambientlight_intensity = ones(nframe,1)*viewer.AmbientLight; % Unchanged
            new_sourcelight_intensity = ones(nframe,1)*viewer.DiffuseLight;
        end

        %% Light Position
        if seq(kseq).light_movement_todo
            pp.change_is = seq(kseq).light_coordinate_change_is;
            pp.profile = seq(kseq).light_coordinate_profile;
            pp.sens = seq(kseq).light_coordinate_sens;

            if strcmp(seq(kseq).light_coordinate,'cartesian')
                if strcmp(seq(kseq).light_x_choice,'unchanged')
                    new_light_pos_x = ones(nframe,1)*viewer.LightPosition(1);
                else
                    if strcmp(seq(kseq).light_x_choice,'absolute')
                        new_x = box_sz(1)*seq(kseq).light_x;
                    elseif strcmp(seq(kseq).light_x_choice,'delta')
                        new_x = viewer.LightPosition(1) + box_sz(1)*seq(kseq).light_x;
                    end
                    pp.startval = viewer.LightPosition(1); pp.endval = new_x; new_light_pos_x = getnewvals(pp);
                end
                if strcmp(seq(kseq).light_y_choice,'unchanged')
                    new_light_pos_y = ones(nframe,1)*viewer.LightPosition(2);
                else
                    if strcmp(seq(kseq).light_y_choice,'absolute')
                        new_y = box_sz(2)*seq(kseq).light_y;
                    elseif strcmp(seq(kseq).light_y_choice,'delta')
                        new_y = viewer.LightPosition(2) + box_sz(2)*seq(kseq).light_y;
                    end
                    pp.startval = viewer.LightPosition(2); pp.endval = new_y; new_light_pos_y = getnewvals(pp);
                end
                if strcmp(seq(kseq).light_z_choice,'unchanged')
                    new_light_pos_z = ones(nframe,1)*viewer.LightPosition(3);
                else
                    if strcmp(seq(kseq).light_z_choice,'absolute')
                        new_z = box_sz(3)*seq(kseq).light_z;
                    elseif strcmp(seq(kseq).light_z_choice,'delta')
                        new_z = viewer.LightPosition(3) + box_sz(3)*seq(kseq).light_z;
                    end
                    pp.startval = viewer.LightPosition(3); pp.endval = new_z; new_light_pos_z = getnewvals(pp);
                end                
            end

            % Elevation, azimuth and distance
            if strcmp(seq(kseq).light_coordinate,'spherical')
                x = viewer.LightPosition(1) - viewer.CameraTarget(1);
                y = viewer.LightPosition(2) - viewer.CameraTarget(2);
                z = viewer.LightPosition(3) - viewer.CameraTarget(3);
                [az,el,~] = cart2sph(x,y,z); % Current position
                az = rad2deg(az); el = rad2deg(el);

                if strcmp(seq(kseq).light_azimuth_choice,'unchanged')
                    new_az = ones(nframe,1)*az;
                else
                    if strcmp(seq(kseq).light_azimuth_choice,'absolute')
                        pp.startval = az; pp.endval = seq(kseq).light_azimuth; new_az = getnewvals(pp);
                    elseif strcmp(seq(kseq).light_azimuth_choice,'delta')
                        pp.startval = az; pp.endval = az+seq(kseq).light_azimuth; new_az = getnewvals(pp);
                    end
                end
                if strcmp(seq(kseq).light_elevation_choice,'unchanged')
                    new_el = ones(nframe,1)*el;
                else
                    if strcmp(seq(kseq).light_elevation_choice,'absolute')
                        pp.startval = el; pp.endval = seq(kseq).light_elevation; new_el = getnewvals(pp);
                    elseif strcmp(seq(kseq).light_elevation_choice,'delta')
                        pp.startval = el; pp.endval = el+seq(kseq).light_elevation; new_el = getnewvals(pp);
                    end
                end
               
                new_az = reshape(new_az,[nframe,1]);
                new_el = reshape(new_el,[nframe,1]);
                new_d = ones(nframe,1);

                [x,y,z] = sph2cart(deg2rad(new_az),deg2rad(new_el),new_d.*dref);
                new_light_pos_x = x + viewer.CameraTarget(1);
                new_light_pos_y = y + viewer.CameraTarget(2);
                new_light_pos_z = z + viewer.CameraTarget(3);
            end

        else
            new_light_pos_x = ones(nframe,1)*viewer.LightPosition(1); % Unchanged
            new_light_pos_y = ones(nframe,1)*viewer.LightPosition(2);
            new_light_pos_z = ones(nframe,1)*viewer.LightPosition(3);
        end

    else
        new_ambientlight_intensity = ones(nframe,1)*viewer.AmbientLight; % Unchanged
        new_sourcelight_intensity = ones(nframe,1)*viewer.DiffuseLight;

        new_light_pos_x = ones(nframe,1)*viewer.LightPosition(1);
        new_light_pos_y = ones(nframe,1)*viewer.LightPosition(2);
        new_light_pos_z = ones(nframe,1)*viewer.LightPosition(3);
    end

    %% FRAME
    for kframe = 1:nframe
        current_frame = current_frame+1;

        % % Camera
        % viewer.CameraPosition = [new_camera_pos_x(kframe) new_camera_pos_y(kframe) new_camera_pos_z(kframe)];
        % viewer.CameraTarget = [new_camera_target_x(kframe) new_camera_target_y(kframe) new_camera_target_z(kframe)];
        % viewer.CameraZoom = new_camera_zoom(kframe);
        % viewer.CameraUpVector = [new_camera_vector_1(kframe) new_camera_vector_2(kframe) new_camera_vector_3(kframe)];

        %% CLIPPING
        if isfield(seq(kseq),'clipping') && ~isempty(seq(kseq).clipping)
            pp.change_is = seq(kseq).clipping_change_is;
            pp.profile = seq(kseq).clipping_profile;
            pp.sens = seq(kseq).clipping_sens;
  
            kchildren = 0;
            for k=1:length(Img)
                if Img(k).selected
                    kchildren = kchildren+1;
                    if seq(kseq).vol(kchildren).clipping_todo           
                        time = seq(kseq).vol(kchildren).clipping_time ;
                        pp.start = time(1);
                        pp.end = time(2);

                        x0_norms = cell2mat(seq(kseq).vol(kchildren).cliping_xyz(3));
                        x1_norms = cell2mat(seq(kseq).vol(kchildren).cliping_xyz(4));
                        y0_norms = cell2mat(seq(kseq).vol(kchildren).cliping_xyz(1));
                        y1_norms = cell2mat(seq(kseq).vol(kchildren).cliping_xyz(2));
                        z0_norms = cell2mat(seq(kseq).vol(kchildren).cliping_xyz(5));
                        z1_norms = cell2mat(seq(kseq).vol(kchildren).cliping_xyz(6));

                        x_variable = true;
                        if ~isempty(x0_norms)
                            if length(x0_norms) > 3 && strcmp(x0_norms(end-2:end),'cst')
                                x0_norms = str2num(x0_norms(1:end-3));
                                x_variable = false;
                            else
                                x0_norms = str2num(x0_norms);
                            end
                        else
                            x0_norms = [];
                        end
                        if ~isempty(x1_norms)
                            if length(x1_norms) > 3 && strcmp(x1_norms(end-2:end),'cst')
                                x1_norms = str2num(x1_norms(1:end-3));
                                x_variable = false;
                            else
                                x1_norms = str2num(x1_norms);
                            end
                        else
                            x1_norms = [];
                        end

                        y_variable = true;
                        if ~isempty(y0_norms)
                            if length(y0_norms) > 3 && strcmp(y0_norms(end-2:end),'cst')
                                y0_norms = str2num(y0_norms(1:end-3));
                                y_variable = false;
                            else
                                y0_norms = str2num(y0_norms);
                            end
                        else
                            y0_norms = [];
                        end
                        if ~isempty(y1_norms)
                            if length(y1_norms) > 3 && strcmp(y1_norms(end-2:end),'cst')
                                y1_norms = str2num(y1_norms(1:end-3));
                                y_variable = false;
                            else
                                y1_norms = str2num(y1_norms);
                            end
                        else
                            y1_norms = [];
                        end                        

                        z_variable = true;
                        if ~isempty(z0_norms)
                            if length(z0_norms) > 3 && strcmp(z0_norms(end-2:end),'cst')
                                z0_norms = str2num(z0_norms(1:end-3));
                                z_variable = false;
                            else
                                z0_norms = str2num(z0_norms);
                            end
                        else
                            z0_norms = [];
                        end
                        if ~isempty(z1_norms)
                            if length(z1_norms) > 3 && strcmp(z1_norms(end-2:end),'cst')
                                z1_norms = str2num(z1_norms(1:end-3));
                                z_variable = false;
                            else
                                z1_norms = str2num(z1_norms);
                            end
                        else
                            z1_norms = [];
                        end                        
                                                
                        nside = max([length(x0_norms) length(x1_norms) length(y0_norms) length(y1_norms) length(z0_norms) length(z1_norms)]);
                        for kside = 1:nside
                            x0_norm = []; x1_norm = [];
                            y0_norm = []; y1_norm = [];                            
                            z0_norm = []; z1_norm = [];
                            if length(x0_norms)>=kside
                                x0_norm = x0_norms(kside);
                            end
                            if length(x1_norms)>=kside
                                x1_norm = x1_norms(kside);
                            end
                            if length(y0_norms)>=kside
                                y0_norm = y0_norms(kside);
                            end
                            if length(y1_norms)>=kside
                                y1_norm = y1_norms(kside);
                            end
                            if length(z0_norms)>=kside
                                z0_norm = z0_norms(kside);
                            end
                            if length(z1_norms)>=kside
                                z1_norm = z1_norms(kside);
                            end                            

                            sz = size(Img(k).visible);
                            if ~isempty(x0_norm) && ~isempty(x1_norm)
                                if x_variable
                                    pp.startval = x0_norm; pp.endval = x1_norm; xs_norm = getnewvals(pp);
                                    a = (sz(1)-1)/(1-0);
                                    b = 1;
                                    x0  = round(a*x0_norm+b);
                                    x1s = round(a*xs_norm+b);
                                else
                                    a = (sz(1)-1)/(1-0);
                                    b = 1;  
                                    x0  = round(a*x0_norms+b);
                                    x1s  = ones(nframe,1) * round(a*x1_norms+b);
                                end
                            else
                                if seq(kseq).vol(kchildren).orthogonal
                                    x0 = 1;
                                    x1s = ones(nframe,1)*sz(1);
                                else
                                    x0 = sz(1)/2;
                                    x1s = ones(nframe,1)*x0;
                                end
                            end
                            if ~isempty(y0_norm) && ~isempty(y1_norm)
                                if y_variable
                                    pp.startval = y0_norm; pp.endval = y1_norm; ys_norm = getnewvals(pp);
                                    a = (sz(2)-1)/(1-0);
                                    b = 1;
                                    y0  = round(a*y0_norm+b);
                                    y1s = round(a*ys_norm+b);
                                else
                                    a = (sz(2)-1)/(1-0);
                                    b = 1;  
                                    y0  = round(a*y0_norms+b);
                                    y1s  = ones(nframe,1) * round(a*y1_norms+b);
                                end
                            else
                                if seq(kseq).vol(kchildren).orthogonal
                                    y0 = 1;
                                    y1s = ones(nframe,1)*sz(2);
                                else
                                    y0 = sz(2)/2;
                                    y1s = ones(nframe,1)*y0;
                                end
                            end
                            if ~isempty(z0_norm) && ~isempty(z1_norm)
                                if z_variable
                                    pp.startval = z0_norm; pp.endval = z1_norm; zs_norm = getnewvals(pp);
                                    a = (sz(3)-1)/(1-0);
                                    b = 1;
                                    z0  = round(a*z0_norm+b);
                                    z1s = round(a*zs_norm+b);
                                else
                                    a = (sz(3)-1)/(1-0);
                                    b = 1;  
                                    y0  = round(a*z0_norms+b);
                                    y1s  = ones(nframe,1) * round(a*z1_norms+b);
                                end
                            else
                                if seq(kseq).vol(kchildren).orthogonal
                                    z0 = 1;
                                    z1s = ones(nframe,1)*sz(3);
                                else
                                    z0 = sz(3)/2;
                                    z1s = ones(nframe,1)*z0;
                                end
                            end

                            % Ensure in-bounds
                            x1s(kframe) = max([1 x1s(kframe)]);
                            y1s(kframe) = max([1 y1s(kframe)]);
                            z1s(kframe) = max([1 z1s(kframe)]);

                            x1s(kframe) = min([sz(1) x1s(kframe)]);
                            y1s(kframe) = min([sz(2) y1s(kframe)]);
                            z1s(kframe) = min([sz(3) z1s(kframe)]);

                            sz2 = size(Img(k).modified_forcolormap);
                            x1s(kframe) = min([sz2(1) x1s(kframe)]);
                            y1s(kframe) = min([sz2(2) y1s(kframe)]);
                            z1s(kframe) = min([sz2(3) z1s(kframe)]);    

                            x0 = min([x0 sz(1)]); x0 = min([x0 sz2(1)]); 
                            y0 = min([y0 sz(2)]); y0 = min([y0 sz2(2)]);                             
                            z0 = min([z0 sz(3)]); z0 = min([z0 sz2(3)]); 

                            if seq(kseq).vol(kchildren).orthogonal
                                xst = min([x0, x1s(kframe)]); xend = max([x0, x1s(kframe)]);
                                yst = min([y0, y1s(kframe)]); yend = max([y0, y1s(kframe)]);
                                zst = min([z0, z1s(kframe)]); zend = max([z0, z1s(kframe)]);

                                if isempty(seq(kseq).vol(kchildren).clipping_label)
                                    if seq(kseq).vol(kchildren).clipping_additive
                                        Img(k).visible(xst:xend, yst:yend, zst:zend) = Img(k).modified_forcolormap(xst:xend, yst:yend, zst:zend);
                                    else
                                        Img(k).visible(xst:xend, yst:yend, zst:zend) = Img(k).modified_forcolormap(xst:xend, yst:yend, zst:zend)*0;
                                    end
                                else
                                    labels = str2num(seq(kseq).vol(kchildren).clipping_label);
                                    if seq(kseq).vol(kchildren).clipping_additive % Add
                                        tmp = Img(k).visible(xst:xend, yst:yend, zst:zend);
                                        tmp2 = Img(k).modified_forcolormap(xst:xend, yst:yend, zst:zend);
                                        for klabel = 1:length(labels)
                                            tmp(tmp2==labels(klabel)) = labels(klabel);
                                        end

                                    else % Remove
                                        tmp = Img(k).visible(xst:xend, yst:yend, zst:zend);
                                        for klabel = 1:length(labels)
                                            tmp(tmp==labels(klabel)) = 0;
                                        end
                                    end
                                    Img(k).visible(xst:xend, yst:yend, zst:zend) = tmp;
                                end


                            else
                                xst=x0-sz(1)/2; xend=x1s(kframe)-sz(1)/2;
                                yst=y0-sz(2)/2; yend=y1s(kframe)-sz(2)/2;
                                zst=z0-sz(3)/2; zend=z1s(kframe)-sz(3)/2;
                            
                                vec = [xend-xst yend-yst zend-zst];
                                vec = vec/norm(vec);
                                if nside == 1
                                    vec = -vec;
                                end
                                da = norm([xst yst zst]);
                                db = norm([xend yend zend]);
                                d1 = min([da db]);
                                d2 = max([da db]);

                                idx = find(ones(sz));
                                [IX,IY,IZ] = ind2sub(sz,idx);
                                IX = IX-sz(1)/2; IY =IY-sz(2)/2; IZ = IZ-sz(3)/2;
                                
                                tol=2;
                                cond1 = double(vec(1)*IX + vec(2)*IY + vec(3)*IZ - d1 >= tol);
                                cond2 = double(vec(1)*IX + vec(2)*IY + vec(3)*IZ - d2 <= tol);
                              
                                idbtw = find(cond1.*cond2);

                                if ~isempty(idbtw)
                                    if isempty(seq(kseq).vol(kchildren).clipping_label)
                                        if seq(kseq).vol(kchildren).clipping_additive
                                            Img(k).visible(idbtw) = Img(k).modified_forcolormap(idbtw);
                                        else
                                            Img(k).visible(idbtw) = Img(k).modified_forcolormap(idbtw)*0;
                                        end
                                    else
                                        labels = str2num(seq(kseq).vol(kchildren).clipping_label);
                                        if seq(kseq).vol(kchildren).clipping_additive % Add
                                            tmp = Img(k).visible(xst:xend, yst:yend, zst:zend);
                                            tmp2 = Img(k).modified_forcolormap(xst:xend, yst:yend, zst:zend);
                                            for klabel = 1:length(labels)
                                                tmp(tmp2==labels(klabel)) = labels(klabel);
                                            end

                                        else % Remove
                                            tmp = Img(k).visible(xst:xend, yst:yend, zst:zend);
                                            for klabel = 1:length(labels)
                                                tmp(tmp==labels(klabel)) = 0;
                                            end
                                        end
                                        Img(k).visible(xst:xend, yst:yend, zst:zend) = tmp;
                                    end
                                end

                            end
                            if strcmp(Img(k).datatype,'grey')
                                viewer.Children(kchildren).OverlayData = Img(k).visible;
                            elseif strcmp(Img(k).datatype,'semantic')
                                if p.opacitfy_cummulative
                                    viewer.Children(kchildren).Data = Img(k).visible;
                                else
                                    viewer.Children(kchildren).OverlayData = Img(k).visible;
                                end
                            elseif strcmp(Img(k).datatype,'instance')
                                viewer.Children(kchildren).OverlayData = Img(k).visible;
                            end

                        end

                    end
                end
            end
        end

        %% TRANSFORMATIONS (Translations and rotations)
        if isfield(seq(kseq),'transformation') && ~isempty(seq(kseq).transformation)
            kchildren = 0;
            for k=1:length(Img)
                if Img(k).selected
                    kchildren = kchildren+1;

                    tr = seq(kseq).vol(kchildren).tr;
                    rot = seq(kseq).vol(kchildren).rot; % + vol(kchildren).rot_history;
                    time = seq(kseq).vol(kchildren).time;

                    if sum(tr~=0) || sum(rot~=0)
                        pp.change_is = seq(kseq).transformation_change_is;
                        pp.profile = seq(kseq).transformation_profile;
                        pp.sens = seq(kseq).transformation_sens;
                        pp.start = time(1);
                        pp.end = time(2);

                        % % Rotations
                        pr.addition = false;
                        tmpvol = Img(k).visible;

                        pr.datatype = 'grey';
                        if strcmp(Img(k).datatype,'semantic') || strcmp(Img(k).datatype,'instance')
                            pr.datatype = 'label';
                        end

                        % Each rotation within a sequence starts is applied on the
                        % first frame of the last sequence and not the
                        % previous frame of the current sequence.
                        % This is to prevent error to accumulate
                        if rot(1)~=0 || rot(2)~=0 || rot(3)~=0
                            if rot(1)~=0
                                pr.axis = 'Axis 2';
                                pp.startval = 0; pp.endval = rot(1); rotations = getnewvals(pp);
                                pr.angle = rotations(kframe);
                                [tmpvol,~,~] = fct_rotation(tmpvol,pr);
                            end
                            if rot(2)~=0
                                pr.axis = 'Axis 1';
                                pp.startval = 0; pp.endval = rot(2); rotations = getnewvals(pp);
                                pr.angle = rotations(kframe);
                                [tmpvol,~,~] = fct_rotation(tmpvol,pr);
                            end
                            if rot(3)~=0
                                pr.axis = 'Axis 3';
                                pp.startval = 0; pp.endval = rot(3); rotations = getnewvals(pp);
                                pr.angle = rotations(kframe);
                                [tmpvol,~,~] = fct_rotation(tmpvol,pr);
                            end
                            if strcmp(Img(k).datatype,'grey')
                                viewer.Children(kchildren).OverlayData = tmpvol;
                            elseif strcmp(Img(k).datatype,'semantic')
                                if p.opacitfy_cummulative
                                    viewer.Children(kchildren).Data = tmpvol;
                                else
                                    viewer.Children(kchildren).OverlayData = tmpvol;
                                end
                            elseif strcmp(Img(k).datatype,'instance')
                                viewer.Children(kchildren).OverlayData = tmpvol;
                            end
                        end

                        % % Translations
                        % Change due to previous rotations
                        newcenter = size(tmpvol)/2;
                        delta = newcenter-Img(k).center;
                        % Change due to previous translations
                        pr_tr = vol(kchildren).tr_history;

                        pp.startval = 0; pp.endval = tr(1); tr1s = getnewvals(pp);
                        pp.startval = 0; pp.endval = tr(2); tr2s = getnewvals(pp);
                        pp.startval = 0; pp.endval = tr(3); tr3s = getnewvals(pp);

                        tform = transltform3d([Img(k).ty-delta(2)+pr_tr(1)+tr1s(kframe), Img(k).tx-delta(1)+pr_tr(2)+tr2s(kframe), Img(k).tz-delta(3)+pr_tr(3)+tr3s(kframe)]); % Switch axe X and Y
                        viewer.Children(kchildren).Transformation = tform;

                        % History for next sequence
                        if kframe == nframe
                            vol(kchildren).tr_history = vol(kchildren).tr_history + [tr1s(end) tr2s(end) tr3s(end)];
                            Img(k).visible = tmpvol;
                            %vol(kchildren).rot_history = vol(kchildren).rot_history + [rot(1) rot(2) rot(3)];
                        end

                    end

                end
            end
        end

        %% CLIPPING (LABELS)
        if isfield(seq(kseq),'cliplabel') && ~isempty(seq(kseq).cliplabel)
            kchildren = 0;
            for k=1:length(Img)
                if Img(k).selected
                    kchildren = kchildren+1;
                    if seq(kseq).vol(kchildren).cliplabel_todo
                        if cell2mat(seq(kseq).vol(kchildren).cliplabel_ordering_size)
                            fromlabel = labels_clip(k).start;
                            tolabel = labels_clip(k).frame(kframe);
                            min_label = min([fromlabel tolabel]);
                            max_label = max([fromlabel tolabel]);
                            
                            cond1 = seq(kseq).vol(kchildren).Imgsorted >= min_label;
                            cond2 = seq(kseq).vol(kchildren).Imgsorted <= max_label;
                            idx = find(cond1.*cond2);

                            if seq(kseq).vol(kchildren).cliplabel_additive
                                Img(k).visible(idx) = Img(k).modified_forcolormap(idx);
                            else
                                Img(k).visible(idx) = 0;
                            end   
                        else
                            fromlabel = labels_clip(k).start;
                            tolabel = labels_clip(k).frame(kframe);
                            min_label = min([fromlabel tolabel]);
                            max_label = max([fromlabel tolabel]);
                            
                            cond1 = Img(k).modified_forcolormap >= min_label;
                            cond2 = Img(k).modified_forcolormap <= max_label;
                            idx = find(cond1.*cond2);
                            if seq(kseq).vol(kchildren).cliplabel_additive
                                Img(k).visible(idx) = Img(k).modified_forcolormap(idx);
                            else
                                Img(k).visible(idx) = 0;
                            end
                        end
           
                    

                    end
                end
            end
            if strcmp(Img(k).datatype,'grey')
                viewer.Children(kchildren).OverlayData = Img(k).visible;
            elseif strcmp(Img(k).datatype,'semantic')
                if p.opacitfy_cummulative
                    viewer.Children(kchildren).Data = Img(k).visible;
                else
                    viewer.Children(kchildren).OverlayData = Img(k).visible;
                end
            elseif strcmp(Img(k).datatype,'instance')
                viewer.Children(kchildren).OverlayData = Img(k).visible;
            end
        end



        %% OPACITY
        if isfield(seq(kseq),'opacity') && ~isempty(seq(kseq).opacity)
            pp.start = 0;
            pp.end = 1;            
            kchildren = 0;
            for k=1:length(Img)
                if Img(k).selected && strcmp(Img(k).datatype,'semantic')
                    kchildren = kchildren+1;

                    op_from = str2num( seq(kseq).vol(kchildren).opacity_from );
                    op_to = str2num( seq(kseq).vol(kchildren).opacity_to );

                    n_opacity = length(Img(k).alphamap);
                    new_opacity = zeros(size(Img(k).alphamap));
                    
                    if n_opacity == length(op_from) % sum(op_to-op_from~=0)
                        pp.change_is = seq(kseq).opacity_change_is;
                        pp.profile = seq(kseq).opacity_profile;
                        pp.sens = seq(kseq).opacity_sens;
                        for k_op = 1:n_opacity
                            pp.startval = op_from(k_op); pp.endval = op_to(k_op); tmp = getnewvals(pp);
                            new_opacity(k_op) = tmp(kframe);
                        end
                        Img(k).alphamap = new_opacity;

                        if p.opacitfy_cummulative
                            viewer.Children(kchildren).Alphamap = Img(k).alphamap;
                        else
                            [n_,~] = size(Img(k).colmap);
                            viewer.Children(kchildren).OverlayColormap(1:n_,:) = Img(k).colmap;
                            viewer.Children(kchildren).OverlayAlphamap(1:n_,:) = Img(k).alphamap;
                        end     

                    end

                end
            end
        end



        

        %% DATA RANGE

        if isfield(seq(kseq),'cliplabel') && ~isempty(seq(kseq).cliplabel)
            kchildren = 0;
            for k=1:length(Img)
                if Img(k).selected
                    kchildren = kchildren + 1;
                    % 2024b for semantic
                    if strcmp(Img(k).datatype,'semantic')
                        %volobj = volshow(Img(k).visible,"Parent",viewer,"Interpolation","nearest","Colormap",Img(k).colmap,"Alphamap",Img(k).alphamap,"Transformation",tform);
                        viewer.Children(kchildren).DisplayRangeMode = "type-range";
                        viewer.Children(kchildren).DisplayRangeMode = "manual";
                        viewer.Children(kchildren).DisplayRange = [min_(k) max_(k)];
                    end
                    if strcmp(Img(k).datatype,'instance')  % 2025a for semantic
                        %volobj = volshow([],"Parent",viewer,"OverlayData",Img(k).visible,"OverlayAlpha",1,"OverlayColormap",Img(k).colmap,'OverlayDisplayRangeMode',"data-range","Transformation",tform);
                        %viewer.Children(kchildren).OverlayDisplayRangeMode = "type-range";
                        %viewer.Children(kchildren).OverlayDisplayRangeMode = "manual";
                        viewer.Children(kchildren).OverlayDisplayRange = [min_(k) max_(k)];
                    end
                end
            end
        end

        %% CAMERA
        viewer.CameraPosition = [new_camera_pos_x(kframe) new_camera_pos_y(kframe) new_camera_pos_z(kframe)];
        viewer.CameraTarget = [new_camera_target_x(kframe) new_camera_target_y(kframe) new_camera_target_z(kframe)];
        viewer.CameraZoom = new_camera_zoom(kframe);
        viewer.CameraUpVector = [new_camera_vector_1(kframe) new_camera_vector_2(kframe) new_camera_vector_3(kframe)];

        %% LIGHTING
        viewer.AmbientLight = new_ambientlight_intensity(kframe);
        viewer.DiffuseLight = new_sourcelight_intensity(kframe);

        viewer.LightPosition(1) = new_light_pos_x(kframe);
        viewer.LightPosition(2) = new_light_pos_y(kframe);
        viewer.LightPosition(3) = new_light_pos_z(kframe);        

        %% SAVE FRAME
        waitfor(viewer,"Busy",false)

        %if kseq>1 || kframe>1
            writeVideo(video_handle,getframe(hFig))
        %end

    end
end

close(video_handle);


%% FUNCTIONS
    function vals = getnewvals(p)
        if strcmp(p.change_is,'Progressive')
            if strcmp(p.profile,'Linear')
                dx = linspace(1/p.nframe, 1, p.nframe);
                vals = p.startval + (p.endval - p.startval).*dx;
                %vals = linspace(p.startval/p.nframe, p.endval, p.nframe);
            elseif strcmp(p.profile,'Quadratic')
                if strcmp(p.sens,'Start slow')
                    dx = linspace(1/p.nframe, 1, p.nframe);
                    dx = dx.^2;
                elseif strcmp(p.sens,'End slow')
                    dx = linspace(1/p.nframe, 1, p.nframe);
                    dx2 = dx.^2;
                    dx = dx + (dx-dx2);
                elseif strcmp(p.sens,'Symmetric')
                    da = linspace(0,1,1e5);
                    da = da.^2;
                    db = linspace(0,1,1e5);
                    db2 = db.^2;
                    db = db + (db-db2);
                    db=db+1;
                    xx = linspace(0,1,2e5-1);
                    dd = [da db(2:end)]*0.5;
                    dx = interp1(xx,dd,linspace(1/p.nframe, 1, p.nframe));
                end
                vals = p.startval + (p.endval - p.startval).*dx;
            elseif strcmp(p.profile,'Cubic')
                if strcmp(p.sens,'Start slow')
                    dx = linspace(1/p.nframe, 1, p.nframe);
                    dx = dx.^3;
                elseif strcmp(p.sens,'End slow')
                    dx = linspace(1/p.nframe, 1 ,p.nframe);
                    dx3 = dx.^3;
                    dx = dx + (dx-dx3);
                elseif strcmp(p.sens,'Symmetric')
                    da = linspace(0,1,1e5);
                    da = da.^3;
                    db = linspace(0,1,1e5);
                    db3 = db.^3;
                    db = db + (db-db3);
                    db=db+1;
                    xx = linspace(0,1,2e5-1);
                    dd = [da db(2:end)]*0.5;
                    dx = interp1(xx,dd,linspace(1/p.nframe, 1, p.nframe));
                end
                vals = p.startval + (p.endval - p.startval).*dx;
            end

            if (p.start>0 || p.end<1) && length(unique(vals))>1
                n = length(vals);
                sav_vals = vals;
                a = (1-0)/(p.end-p.start);
                b = 1-a*p.end;
                for kk=1:n
                    if kk/n < p.start
                        vals(kk)=0;
                    elseif kk/n > p.end
                        vals(kk)=sav_vals(end);
                    else
                        x = round((a*(kk/n)+b) * n);
                        x = max([1 x]);
                        x = min([x n]);
                        vals(kk) = sav_vals(x);
                    end
                end 
            end

        elseif strcmp(p.change_is,'Instantaneous')
            vals = ones(p.nframe,1)*p.endval;
        end

        % f=figure;
        % f.Color = 'w';
        % ax = axes(f);
        % hold on
        % plot(linspace(0,1,numel(vals)),vals,'LineStyle','-','LineWidth',2,'Color','r')
        % plot(linspace(0,1,numel(vals)),linspace(0,1,numel(vals)),'LineStyle','--','LineWidth',2,'Color','k')
        % axis equal; axis tight;
        % ax.FontName = 'Times new roman';
        % ax.FontSize = 14;
        % xlabel('Sequence normalized time');
        % ylabel('State normalized value');
        % grid on  

    end

end