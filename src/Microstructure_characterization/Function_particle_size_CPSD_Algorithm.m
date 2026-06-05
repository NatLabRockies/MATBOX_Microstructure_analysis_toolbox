function [Particle_size, dmap, IDX] = Function_particle_size_CPSD_Algorithm(BW,varargin)
% Return largest diameter in voxel length of the largest sphere that contain each voxel noted 1
 
if isempty(varargin)
    roundvalues = false;
elseif length(varargin)==1
    roundvalues = cell2mat(varargin(1));
    round_digit = [];
elseif length(varargin)==2
    roundvalues = cell2mat(varargin(1));
    round_digit = cell2mat(varargin(2));
end
approximate = false; % legacy

%% STEP 1: CALCULATE LARGEST SPHERE CENTERED IN EACH VOXEL
% We use the matlab built-in function bwdist to calculate the distance transform (euclidean)
% bwdist(BW) : For each pixel in BW, the distance transform assigns a number that is the distance between that pixel and the nearest nonzero pixel of BW
% then, bwdist(~BW,'euclidean') :
v = version('-release');
if strcmp(v,'2025b') || strcmp(v,'2026a')
    dmap = bwdist(~BW,'euclidean');
    IDX = [];
    % Error using bwdist (line 166)
    % Binary images with more than 2^24 pixels do not support index array output.
else
    [dmap, IDX] = bwdist(~BW,'euclidean');
end

if roundvalues
    if ~isempty(round_digit)
        dmap=round(dmap,round_digit);
    else
        dmap=round(dmap);
    end
end

%% STEP 2: ASSIGN VOXELS TO THE LARGEST SPHERE THAT CONTAINS THEM
% Definition of the continum spherical PSD
% In order to reduce CPU time, we will (i) check the condition "voxel belong to
% sphere" from largest sphere to smallest sphere and (ii) remove from
% further condition check all voxels which have been already assigned

tolerance=1e-6;

sz=size(BW);
Particle_size = zeros(sz);
% Current maximum distance
current_distance = max(max(max(dmap)));

cond0 = BW==1;

if ~isinf(current_distance)

    % The iteration continues while the distance transform contains values superior to 0
    % = -1 voxels have been already assigned to largest possible sphere
    dmapmod = dmap;
    while current_distance>0 % Much less iterations if roundvalues is true
        %current_distance
        %pause(0.1)
        current_distance_map = zeros(sz);
        current_distance_map( abs(dmap-current_distance)<tolerance ) = 1;      % Voxels which are the center of the largest sphere are set equal to 1
        current_distance_map = bwdist(current_distance_map,'euclidean');
        cond1 = current_distance_map<(current_distance+tolerance);             % Assign all voxels that does not belong to a largest sphere
        Particle_size ( cond0 & cond1 & Particle_size<(current_distance+tolerance) ) = current_distance;
        %Particle_size (cond1 & Particle_size<(current_distance+tolerance) ) = current_distance;

        % Update distance transform
        if approximate % Faster but that will create some artifact near interfaces.
            dmapmod( cond1 & Particle_size<(current_distance+tolerance) )=-1;
        else
            dmapmod( abs(dmapmod-current_distance)<tolerance ) =-1;
        end

        % Update current maximum distance
        current_distance =  max(max(max(dmapmod)));
    end

    Particle_size = 2*Particle_size; % Diameter

end

end