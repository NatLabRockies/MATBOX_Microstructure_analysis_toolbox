function [M_new] = fct_RadialAxis_contrastsaturation_algo(M,p)

sz = size(M);
dimension = length(sz);
d = 3;
if dimension == 2
    sz = [sz 1];
end

p.reference_region_from  = min([p.reference_region_from sz(d)]);
p.correction_region_from  = min([p.correction_region_from sz(d)]);


%% DISTANCE MAP
tmp = zeros(sz(1),sz(2));
if strcmp(p.center_is,'Auto')
    p.center_values = [round(sz(1)/2) round(sz(2)/2)];
end
tmp(p.center_values(1), p.center_values(2))=1;
dmap = bwdist(tmp);
for z=1:1:sz(3)
    BW(:,:,z) = dmap;
end
if p.excludebackground
    BW(p.background_volume==1) = NaN;
end

BW = round(BW);
BW(BW==0)=1;
x = unique(BW);
x(isnan(x))=[];
x(x==0)=[];
n = numel(x);

p.reference_region_to  = min([p.reference_region_to n]);
p.correction_region_to  = min([p.correction_region_to n]);


%% GET INITIAL VALUES

% Fig = figure;
% ax = axes('Parent',Fig);
% hold(ax,'on');
% axis tight;
% grid(ax,'on');

y_min = NaN(1,n); y_mean = NaN(1,n); y_max = NaN(1,n);
for k=p.reference_region_from:p.reference_region_to
    vals = M(abs(BW-k)<=1.1);  
    if ~isempty(vals)
        y_min(k) = min(vals);
        y_mean(k) = mean(vals);
        y_max(k) = max(vals);
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
    x1 = min([x(k)+p.windowsize n]);

    id_old = find(abs(BW-k)<=1.1);
    val_old = M(id_old);

    cond1 = single(BW>=x0-0.1);
    cond2 = single(BW<=x1+0.1);
    cond = cond1+cond2==2;

    slwindow = M(cond==1);

    if ~isempty(slwindow)
        min_corr = min(slwindow);
        mean_corr = mean(slwindow);
        max_corr = max(slwindow);

        pol = polyfit(double([min_corr, mean_corr, max_corr]),double([min_ref, mean_ref, max_ref]),2);
        val_new = round(polyval(pol,double(val_old)));
        M_new(id_old) = val_new;
        tmp = isnan(M_new);        
    end
end

end