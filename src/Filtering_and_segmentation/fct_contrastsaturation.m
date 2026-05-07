function [M,newtype,foo] = fct_contrastsaturation(M,p)

foo=[];
newtype = 'same';

sz = size(M);
dimension = length(sz);

pp.volumethreshold_above = p.volumethreshold_above;
pp.volumethreshold_below = p.volumethreshold_below;

% Hard coded parameters
pp.max_iteration=100;
pp.target_error=0.1; % in percent

if p.excludebackground
    if strcmp(p.selectbackground,'From label')
        p.background_volume = zeros(sz,'uint8');
        p.background_volume(M==p.background_label) = 1;
    end
end

if p.local
    d = str2num(p.local_along(end));
    if d==3 && dimension==2
        warning('Local contrast correction along third axis is not possible: array is 2D.')
        return
    end
  
    Msav = M;
    for k = 1:sz(d)
        k0 = max([1 k-p.local_thickness]);
        k1 = min([sz(d) k+p.local_thickness]);

        if d==1 
            sl_new = squeeze(Msav(k,:,:));
            sl = squeeze(Msav(k0:k1,:,:));
            if p.excludebackground
                bk = squeeze(p.background_volume(k0:k1,:,:));
                sl(bk==1)=[];
            end       

        elseif d==2
            sl_new = squeeze(Msav(:,k,:));
            sl = squeeze(Msav(:,k0:k1,:));
            if p.excludebackground
                bk = squeeze(p.background_volume(:,k0:k1,:));
                sl(bk==1)=[];
            end              

        elseif d==3
            sl_new =  Msav(:,:,k);
            sl = Msav(:,:,k0:k1);
            if p.excludebackground
                bk = p.background_volume(:,:,k0:k1);
                sl(bk==1)=[];
            end
        end

        if ~isempty(sl)
            sl = reshape(sl,[numel(sl), 1]);
            [threshold_lowervalue, threshold_highervalue] = fct_contrastsaturation_algo(sl,pp);

            if p.volumethreshold_above~=0 && ~isempty(threshold_highervalue)
                sl_new(sl_new>=threshold_highervalue)=threshold_highervalue;
            end
            if p.volumethreshold_below~=0 && ~isempty(threshold_lowervalue)
                sl_new(sl_new<=threshold_lowervalue)=threshold_lowervalue;
            end

            if d==1
                M(k,:,:) = sl_new;
            elseif d==2
                M(:,k,:) = sl_new;
            elseif d==3
                M(:,:,k) = sl_new;
            end
        end


    end

else
    tmp = M;
    if p.excludebackground
        tmp(p.background_volume==1)=[];
    end
    tmp = reshape(tmp,[numel(tmp), 1]);
    [threshold_lowervalue, threshold_highervalue] = fct_contrastsaturation_algo(tmp,pp);
    if p.volumethreshold_above~=0
        M(M>=threshold_highervalue)=threshold_highervalue;
    end
    if p.volumethreshold_below~=0
        M(M<=threshold_lowervalue)=threshold_lowervalue;
    end
end

[M] = fct_intconvert(M);

end