function [M,newtype,foo] = fct_linearrescaling(M,p)

sz = size(M);
dimension = length(sz);

foo=[];
newtype = 'same';

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
            max_=max(max(max(sl)));
            min_=min(min(min(sl)));
            initial_delta=max_-min_;
            final_delta=p.nvalues-1;       

            if p.excludebackground
                sl_new = round( ((double((sl_new-min_)) ./ double(initial_delta)) .* final_delta)+1 );
            else
                sl_new =  round( ((double((sl_new-min_)) ./ double(initial_delta)) .* final_delta) );
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
    if p.excludebackground
        M(p.background_volume==1) = 0;
    end

else
    if p.excludebackground
        vals = M;
        vals(p.background_volume==1)=[];
        max_=max(vals);
        min_=min(vals);
    else
        max_=max(max(max(M)));
        min_=min(min(min(M)));
    end
    initial_delta=max_-min_;
    final_delta=p.nvalues-1;
    if p.excludebackground
        M = round( ((double((M-min_)) ./ double(initial_delta)) .* final_delta)+1 );
        M(p.background_volume==1) = 0;
    else
        M =  round( ((double((M-min_)) ./ double(initial_delta)) .* final_delta) );
    end
end

[M] = fct_intconvert(M);

end