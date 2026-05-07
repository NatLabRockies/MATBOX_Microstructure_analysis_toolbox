function [M,newtype,foo] = fct_removethinlayerartifact(M,p)

sz = size(M);
foo=[];
newtype = 'same';

labels = unique(M);
numberphase = length(labels);
idx_artifact = [];
% Loop over intermediate phase
if numberphase>2
    for k=1:1:numberphase
        tmp = zeros(sz,'uint8');
        tmp(M==labels(k))=1;
        dmaps(k).array = bwdist(tmp);
    end
    for current=2:1:numberphase-1
        idcurrent = find(M==labels(current));

        darkers = current-1:-1:1;
        brighters = current+1:1:numberphase;
        for kd = 1:1:length(darkers)
            for kb = 1:1:length(brighters)

                dmapdarker_tmp = dmaps(darkers(kd)).array;
                dmapbrighter_tmp = dmaps(brighters(kb)).array;

                if p.illustrate
                    if current==2 % Only for illustration
                        dmapdarker = NaN(sz);
                        dmapdarker(idcurrent) = dmapdarker_tmp(idcurrent);
                        dmapbrighter = NaN(sz);
                        dmapbrighter(idcurrent) = dmapbrighter_tmp(idcurrent);
                        cmap = turbo; cmap(1,:) = [1 1 1];
                        figure;
                        imagesc(dmapdarker(:,:,1)); axis equal; colormap(cmap); title ('First intermediate phase. Distance map: to darker phase');
                        figure;
                        imagesc(dmapbrighter(:,:,1)); axis equal; colormap(cmap); title ('First intermediate phase. Distance map: to brigther phase');
                    end
                end

                dmapdarker = zeros(sz)+1e9; % Very high value
                dmapdarker(idcurrent) = dmapdarker_tmp(idcurrent);
                dmapbrighter = zeros(sz)+1e9; % Very high value
                dmapbrighter(idcurrent) = dmapbrighter_tmp(idcurrent);
                %cond1 = dmapdarker<=p.width_threshold;
                %cond2 = dmapbrighter<=p.width_threshold;
                %idtmp = find( (cond1.*cond2) == 1);
                idtmp = find( (dmapdarker+dmapbrighter) <= p.width_threshold);
                if ~isempty(idtmp)
                    idx_artifact = [idx_artifact; idtmp];
                end


            end
        end

    end
end
artifacts = zeros(sz);
artifacts(idx_artifact) = 1;
if p.illustrate
    figure;
    imagesc(artifacts(:,:,1)); axis equal; colormap gray; title ('Detected artifacts');
end

% Remove artifacts
if p.equidistribution
    [~, idx_nearest] = bwdist(~artifacts);
    M(idx_artifact) = M(idx_nearest(idx_artifact));
else
    M(idx_artifact) = p.assignto;
end

if p.illustrate
    figure;
    imagesc(M(:,:,1)); axis equal; colormap gray; title ('Artifacts removed');
end

% Convert to uint8 or uint16
[M] = fct_intconvert(M);

end


