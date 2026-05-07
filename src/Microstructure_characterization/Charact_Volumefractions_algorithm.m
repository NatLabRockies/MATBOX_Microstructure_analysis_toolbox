function [stats,vf,ratio,nvoxel] = Charact_Volumefractions_algorithm(array,label,n_voxel,nanoporosity,wetting,activematerial_identification)

stats = [];
vf = [];
ratio = [];
nvoxel = [];

%% Number of voxel and background
% No need as we provide n_voxel instead
% n_voxel_background = 0;
% if ~isempty(backgroundlabel)
%     n_voxel_background = sum(sum(sum( array==backgroundlabel )));
% end
% n_voxel = numel(array) - n_voxel_background;

%% Binary image
BWlog = array==label;
BW = single(BWlog);

if isempty(nanoporosity)
    stats.nanoporosity = [NaN NaN NaN NaN NaN NaN];
    stats.wetting = [NaN NaN NaN NaN NaN NaN];
    nvoxel.FOV = n_voxel; % non-zero
    nvoxel.label = sum(sum(sum( BW )));  % non-zero
    nvoxel.label_and_solid = 0;
    nvoxel.label_and_pore = 0;
    nvoxel.label_and_liquid = 0;
    nvoxel.label_and_gas = 0;
    nvoxel.onlypore = 0;
    nvoxel.onlysolid = 0;
    nvoxel.mixed = 0;
    nvoxel.label_and_AM = 0;
    vf.label = nvoxel.label / nvoxel.FOV; % non-zero
    vf.label_and_solid = nvoxel.label_and_solid / nvoxel.FOV;
    vf.label_and_pore = nvoxel.label_and_pore / nvoxel.FOV;
    vf.label_and_liquid = nvoxel.label_and_liquid / nvoxel.FOV;
    vf.label_and_gas = nvoxel.label_and_gas / nvoxel.FOV;
    vf.label_and_AM = nvoxel.label_and_AM / nvoxel.FOV;
    ratio.label_solidpart = nvoxel.label_and_solid / nvoxel.label;
    ratio.label_porepart = nvoxel.label_and_pore / nvoxel.label;
    ratio.label_liquidpart = nvoxel.label_and_liquid / nvoxel.label;
    ratio.label_gaspart = nvoxel.label_and_gas / nvoxel.label;
else

    %% Statistics
    vals = nanoporosity(BWlog);
    vals = round(double(vals),4);
    vals = reshape(vals,[1 numel(vals)]);
    if numunique(vals)==1 % Std can provide non-zero (numerical error) if vals is a long array with the same repeating value
        stats.nanoporosity = [vals(1) vals(1) vals(1) 0 vals(1) vals(1)];
    elseif numunique(vals)==0
        stats.nanoporosity = [NaN NaN NaN NaN NaN NaN];
    else
        stats.nanoporosity = [mean(vals) median(vals) mode(vals) std(vals) min(vals) max(vals)];
    end

    vals = wetting(BWlog);
    vals = round(double(vals),4);
    vals = reshape(vals,[1 numel(vals)]);
    if numunique(vals)==1 % Std can provide non-zero (numerical error) if vals is a long array with the same repeating value
        stats.wetting = [vals(1) vals(1) vals(1) 0 vals(1) vals(1)];
    elseif numunique(vals)==0
        stats.wetting = [NaN NaN NaN NaN NaN NaN];
    else
        stats.wetting = [mean(vals) median(vals) mode(vals) std(vals) min(vals) max(vals)];
    end

    %% Number of voxels for normalization
    nvoxel.FOV = n_voxel; % n_voxel does not count voxels that belong to the background, if any
    nvoxel.label = sum(sum(sum( BW )));

    %% Number of voxels for each state
    nvoxel.label_and_solid = sum(sum(sum( BW.*(1-nanoporosity) )));
    nvoxel.label_and_pore = sum(sum(sum( BW.*nanoporosity )));
    nvoxel.label_and_liquid = sum(sum(sum( BW.*nanoporosity.*wetting )));
    nvoxel.label_and_gas = sum(sum(sum( BW.*nanoporosity.*(1-wetting) )));

    %% Number of voxels for each category
    nvoxel.onlypore = sum(sum(sum( BWlog.*(nanoporosity==1) )));
    nvoxel.onlysolid = sum(sum(sum( BWlog.*(nanoporosity==0) )));

    cond1 = nanoporosity>0;
    cond2 = nanoporosity<1;
    nvoxel.mixed = sum(sum(sum( BWlog.*cond1.*cond2 )));

    %% Number of voxel of active material
    labels = cell2mat(activematerial_identification(:,1));
    idx = find(labels == label);
    AM_voidliquidsolid = cell2mat(activematerial_identification(idx,2:end));
    nvoxel.label_and_AM = 0;
    if AM_voidliquidsolid(1)==1 % Active material is gas in this phase
        nvoxel.label_and_AM = nvoxel.label_and_AM + nvoxel.label_and_gas;
    end
    if AM_voidliquidsolid(2)==1 % Active material is liquid in this phase
        nvoxel.label_and_AM = nvoxel.label_and_AM + nvoxel.label_and_liquid;
    end
    if AM_voidliquidsolid(3)==1 % Active material is solid in this phase
        nvoxel.label_and_AM = nvoxel.label_and_AM + nvoxel.label_and_solid;
    end

    %% Volume fractions
    vf.label = nvoxel.label / nvoxel.FOV;
    vf.label_and_solid = nvoxel.label_and_solid / nvoxel.FOV;
    vf.label_and_pore = nvoxel.label_and_pore / nvoxel.FOV;
    vf.label_and_liquid = nvoxel.label_and_liquid / nvoxel.FOV;
    vf.label_and_gas = nvoxel.label_and_gas / nvoxel.FOV;
    vf.label_and_AM = nvoxel.label_and_AM / nvoxel.FOV;

    %% Ratio
    ratio.label_solidpart = nvoxel.label_and_solid / nvoxel.label;
    ratio.label_porepart = nvoxel.label_and_pore / nvoxel.label;
    ratio.label_liquidpart = nvoxel.label_and_liquid / nvoxel.label;
    ratio.label_gaspart = nvoxel.label_and_gas / nvoxel.label;
end

end
