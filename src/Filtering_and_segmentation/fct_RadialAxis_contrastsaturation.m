function [M_new,newtype,foo] = fct_RadialAxis_contrastsaturation(M,p)

foo=[];
newtype = 'same';

sz = size(M);

if p.excludebackground
    if strcmp(p.selectbackground,'From label')
        p.background_volume = zeros(sz,'uint8');
        p.background_volume(M==p.background_label) = 1;
    end
end

%% SWAP IF NEEDED
if strcmp(p.along,'Axe 1')
    pp.action = 'Swap axis 1 with axis 3';
    [M,~,~] = fct_flipswap(M,pp);
    if p.excludebackground
        [p.background_volume,~,~] = fct_flipswap(p.background_volume,pp);
    end

elseif strcmp(p.along,'Axe 2')
    pp.action = 'Swap axis 2 with axis 3';
    [M,~,~] = fct_flipswap(M,pp);
    if p.excludebackground
        [p.background_volume,~,~] = fct_flipswap(p.background_volume,pp);        
    end        
end


%% ALGORITHM
[M_new] = fct_RadialAxis_contrastsaturation_algo(M,p);

%% SWAP BACK IF NEEDED
if strcmp(p.along,'Axe 1')
    [M_new,~,~] = fct_flipswap(M_new,pp);
    if p.excludebackground
        [p.background_volume,~,~] = fct_flipswap(p.background_volume,pp);
    end    
elseif strcmp(p.along,'Axe 2')
    [M_new,~,~] = fct_flipswap(M_new,pp);
    if p.excludebackground
        [p.background_volume,~,~] = fct_flipswap(p.background_volume,pp);
    end    
end

%% SAVE
if p.excludebackground
    idx = find(M==p.background_volume);
    M_new(idx) = M(idx);
end

[M_new] = fct_intconvert(M_new);

end