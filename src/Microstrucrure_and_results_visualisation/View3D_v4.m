function View3D_v4(Img,box_sz,vis,p)

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

        if strcmp(Img(k).datatype,'grey')
            obj_grey = volshow([],"Parent",viewer,"OverlayData",Img(k).modified_forcolormap*visk,"OverlayColormap",Img(k).colmap,'OverlayAlphamap',Img(k).alphamap,'OverlayDisplayRangeMode',"data-range","Transformation",tform);
            obj_grey.RenderingStyle="GradientOpacity";
            obj_grey.OverlayRenderingStyle="LabelOverlay";
        elseif strcmp(Img(k).datatype,'semantic')
            if p.opacitfy_cummulative
                obj_sem = volshow(Img(k).modified_forcolormap*visk,"Parent",viewer,"Interpolation","nearest","Colormap",Img(k).colmap,"Alphamap",Img(k).alphamap,"Transformation",tform);
            else
                obj_sem = volshow([],"Parent",viewer,"OverlayData",Img(k).modified_forcolormap*visk,"Transformation",tform);
                [n,~] = size(Img(k).colmap);
                obj_sem.OverlayColormap(1:n,:) = Img(k).colmap;
                obj_sem.OverlayAlphamap(1:n,:) = Img(k).alphamap; % Thanks Mathwork support to help me how to handle opacity correctly
            end
        elseif strcmp(Img(k).datatype,'instance')
            obj_inst = volshow([],"Parent",viewer,"OverlayData",Img(k).modified_forcolormap*visk,"OverlayAlpha",1,"OverlayColormap",Img(k).colmap,'OverlayDisplayRangeMode',"data-range","Transformation",tform);
        end

        drawnow
        pause(0.1);
        drawnow % Force rendering before moving to next volume
        %waitfor(viewer,"Busy",false) % Less efficient than drawnow, pause, drawnow        
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
viewer.CameraTarget = [box_sz(1)*p.CameraTarget(1) box_sz(2)*p.CameraTarget(2) box_sz(3)*p.CameraTarget(3)];

if strcmp(p.CameraPosition_coordinatesystem,'spherical')
    d = sqrt(box_sz(1)^2 + box_sz(2)^2 + box_sz(3)^2);
    [x,y,z] = sph2cart(deg2rad(p.CameraPosition_azimuth),deg2rad(p.CameraPosition_elevation),p.CameraPosition_distance*d);
    x = x + viewer.CameraTarget(1);
    y = y + viewer.CameraTarget(2);
    z = z + viewer.CameraTarget(3);
    viewer.CameraPosition = [x y z];
elseif strcmp(p.CameraPosition_coordinatesystem,'cartesian ')
    viewer.CameraPosition = [box_sz(1)*p.CameraPosition_x box_sz(2)*p.CameraPosition_y box_sz(3)*p.CameraPosition_z];
end

viewer.CameraUpVector = p.CameraVector;

viewer.CameraZoom = p.zoom;

%% LIGHTING
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

%% SAVE FIGURE
if isfield(p,'fullpath')
    exportapp(hFig,[p.fullpath '.png']);
end

end