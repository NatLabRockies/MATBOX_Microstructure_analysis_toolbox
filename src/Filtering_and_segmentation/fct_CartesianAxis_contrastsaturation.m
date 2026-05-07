function [M_new] = fct_CartesianAxis_contrastsaturation(M,p)

sz = size(M);

d = str2num(p.along(end));
x = 1:1:sz(d);

p.reference_region_from  = min([p.reference_region_from sz(d)]);
p.correction_region_from  = min([p.correction_region_from sz(d)]);
p.reference_region_to  = min([p.reference_region_to sz(d)]);
p.correction_region_to  = min([p.correction_region_to sz(d)]);

if p.excludebackground
    if strcmp(p.selectbackground,'From label')
        p.background_volume = zeros(sz,'uint8');
        p.background_volume(M==p.background_label) = 1;
    end
end

%% GET INITIAL VALUES

% Fig = figure;
% ax = axes('Parent',Fig);
% hold(ax,'on');
% axis tight;
% grid(ax,'on');

n = numel(x);
y_min = NaN(1,n); y_mean = NaN(1,n); y_max = NaN(1,n); y_std = NaN(1,n);
for k=1:1:n
    if d==1
        sl = M(x(k),:,:);
    elseif d==2
        sl = M(:,x(k),:);
    else
        sl = M(:,:,x(k));
    end
    sl = reshape(sl,[numel(sl),1]);

    if p.excludebackground
        if d==1
            sl_background = p.background_volume(x(k),:,:);
        elseif d==2
            sl_background = p.background_volume(:,x(k),:);
        else
            sl_background = p.background_volume(:,:,x(k));
        end
        sl_background = reshape(sl_background,[numel(sl_background),1]);
        sl(sl_background==1) = [];
    end

    if ~isempty(sl)
        y_min(k) = min(sl);
        y_mean(k) = mean(sl);
        y_max(k) = max(sl);
    end
end

% h_mean=plot(x,y_mean, 'Color', 'k','LineWidth',2,'DisplayName','Mean');
% h_min= plot(x,y_min, 'Color', 'b','LineStyle','--','LineWidth',1,'DisplayName','Min');
% h_max= plot(x,y_max, 'Color', 'r','LineStyle','--','LineWidth',1,'DisplayName','Max');

min_ref = mean( y_min(p.reference_region_from:p.reference_region_to), 'omitnan' );
mean_ref = mean( y_mean(p.reference_region_from:p.reference_region_to), 'omitnan' );
max_ref = mean( y_max(p.reference_region_from:p.reference_region_to), 'omitnan' );


%% CORRECT VALUE
M_new = M;
for k=p.correction_region_from:p.correction_region_to

    x0 = max([x(k)-p.windowsize 1]);
    x1 = min([x(k)+p.windowsize sz(d)]);

    if d==1
        slold = M(x(k),:,:);
        slwindow = M(x0:x1,:,:);
    elseif d==2
        slold = M(:,x(k),:);
        slwindow = M(:,x0:x1,:);
    else
        slold = M(:,:,x(k));
        slwindow = M(:,:,x0:x1);
    end
    slnew = slold;
    slwindow = reshape(slwindow,[numel(slwindow),1]);

    if p.excludebackground
        if d==1
            sl_background = p.background_volume(x0:x1,:,:);
        elseif d==2
            sl_background = p.background_volume(:,x0:x1,:);
        else
            sl_background = p.background_volume(:,:,x0:x1);
        end
        sl_background = reshape(sl_background,[numel(sl_background),1]);
        slwindow(sl_background==1) = [];
    end

    if ~isempty(slwindow)
        min_corr = min(slwindow);
        mean_corr = mean(slwindow);
        max_corr = max(slwindow);

        pol = polyfit(double([min_corr, mean_corr, max_corr]),double([min_ref, mean_ref, max_ref]),2);
        slnew = round(polyval(pol,double(slold)));
        % for kk=1:numel(slnew)
        %     slnew(kk) = round(polyval(pol,double(slold(kk))));
        % end
        %figure; imagesc(slold); axis equal tight; colormap gray;
        %figure; imagesc(slnew); axis equal tight; colormap gray;
        
        if d==1
            M_new(x(k),:,:) = slnew;
        elseif d==2
            M_new(:,x(k),:) = slnew;
        else
            M_new(:,:,x(k)) = slnew;
        end

        %Fig;
        %plot(double([min_corr, mean_corr, max_corr]),double([min_ref, mean_ref, max_ref]))

    end


end

if p.excludebackground
    idx = find(M==p.background_volume);
    M_new(idx) = M(idx);
end

[M_new] = fct_intconvert(M_new);

end