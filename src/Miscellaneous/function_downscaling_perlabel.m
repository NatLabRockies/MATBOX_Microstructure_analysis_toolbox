function [Label_downsized, Array_downsized] = function_downscaling_perlabel(Label,Array,p)

% Example with a dowscaling factor of 2
% Label = [0 0 1 1    and Array = [0.8 0.8 0 0
%          0 1 1 1                 0.8 0   0 0
%          1 1 1 1                 0   0   0 0
%          1 1 1 1]                0   0   0 0];
%
% Label_downsized = [0 1   and Array_downsized = [0.8 0   and not: [0.6 0
%                    1 1]                         0   0]            0   0];

sz = size(Label);
dimension = length(sz);
if dimension == 2
    Label_downsized = imresize(Label,1/p.scaling_factor,'nearest');
else
    Label_downsized = imresize3(Label,1/p.scaling_factor,'nearest');
end
sz_downsized = size(Label_downsized);

sz_resized = size(Label_downsized);
Array_downsized = zeros(sz_downsized,'like',Array);

ids = unique(Label_downsized);
for k=1:length(ids)
    idx = find(Label_downsized==ids(k));
    if dimension == 2
        [IX,IY] = ind2sub(sz_resized,idx);
    else
        [IX,IY,IZ] = ind2sub(sz_resized,idx);
    end
    IX_original = round(IX*p.scaling_factor);
    IY_original = round(IY*p.scaling_factor);
    if dimension == 3
        IZ_original = round(IZ*p.scaling_factor);
    end

    for kk=1:length(idx)
        xmin = max([0, IX_original(kk) - p.scaling_factor + 1]);
        ymin = max([0, IY_original(kk) - p.scaling_factor + 1]);
        xmax = min([sz(1), IX_original(kk)]);
        ymax = min([sz(2), IY_original(kk)]);
        zmin = 1;
        zmax = 1;
        if dimension == 3
            zmin = max([0, IZ_original(kk) - p.scaling_factor + 1]);
            zmax = min([sz(3), IZ_original(kk)]);
        end

        sub_label = Label(xmin:xmax,ymin:ymax,zmin:zmax);
        sub_array = Array(xmin:xmax,ymin:ymax,zmin:zmax);
        sub_idx = sub_label==ids(k);

        Array_downsized(idx(kk)) = mean(mean(mean( sub_array(sub_idx)  )));
    end
end

idnan = find(isnan(Array_downsized)==1);
if ~isempty(idnan) % It can happen for very high downscaling
    if dimension == 2
        tmp = imresize(Array,1/p.scaling_factor,'nearest');
    else
        tmp = imresize3(Array,1/p.scaling_factor,'nearest');
    end
    Array_downsized(idnan) =  tmp(idnan);
end

end