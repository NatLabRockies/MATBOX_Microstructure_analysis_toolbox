function [] = fct_plotgreylevel_perslice(M,p)

Fig = figure;

%% Default options
if nargin==1
    p = [];
end
% Set default option
if ~isfield(p,'fontname')
    p.fontname = 'Times new roman';
end
if ~isfield(p,'excludebackground')
    p.excludebackground = false;
end
if ~isfield(p,'filename')
    Fig.Name= 'Grey level per slice';
    p.filename = 'Grey level per slice';
else
    Fig.Name= ['Grey level per slice, ' p.filename];
end
if ~isfield(p,'sub')
    p.sub = [];
end

if ~isfield(p,'voxelsize')
    p.voxelsize = 1;
end
if ~isfield(p,'voxelunit')
    p.voxelunit = 'Voxel';
end

if ~isfield(p,'xlabel')
    p.xlabel = 'Grey level';
end

%% Plot
sz = size(M);
dimension = length(sz);

if p.excludebackground
    str_sub = [p.sub ' (background excluded)'];
else
    str_sub = p.sub;
end

p.filename = strrep(p.filename,'_',' ');
str_sub = strrep(str_sub,'_',' ');

if strcmp(p.voxelunit,'um')
    p.voxelunit = '\mum';
end

scrsz = get(0,'ScreenSize'); % Screen resolution

Fig.Color='white'; % Background colour

set(Fig,'position',round([scrsz(1) scrsz(2) scrsz(3)*4/5 scrsz(4)*3/5])); % Full screen figure

t = tiledlayout(1,dimension);
t.TileSpacing = 'compact';
t.Padding = 'compact';
title(t,p.filename,'FontName',p.fontname,'FontSize',14,'FontWeight','bold');
if ~isempty(str_sub)
    subtitle(t,str_sub,'FontName',p.fontname,'FontSize',12);
end

for dim=1:1:dimension
    ax = nexttile(dim);
    hold(ax,'on');

    x = 1:1:sz(dim);
    n = numel(x);
    x_um = x*p.voxelsize;
    y_min = NaN(1,n); y_mean = NaN(1,n); y_max = NaN(1,n); y_std = NaN(1,n);
    for k=1:1:n
        if dim==1
            sl = M(x(k),:,:);
        elseif dim==2
            sl = M(:,x(k),:);
        else
            sl = M(:,:,x(k));
        end
        sl = reshape(sl,[numel(sl),1]);

        if p.excludebackground
            if strcmp(p.selectbackground,'From label')
                sl(sl==p.background_label) = [];
            else
                if dim==1
                    sl_background = p.background_volume(x(k),:,:);
                elseif dim==2
                    sl_background = p.background_volume(:,x(k),:);
                else
                    sl_background = p.background_volume(:,:,x(k));
                end
                sl_background = reshape(sl_background,[numel(sl_background),1]);
                sl(sl_background==1) = [];
            end
        end

        if ~isempty(sl)
            y_min(k) = min(sl);
            y_mean(k) = mean(sl);
            y_max(k) = max(sl);
            if length(unique(sl))>1
                y_std(k) = std(double(sl));
            end
        end
    end

    h_mean=plot(x_um,y_mean, 'Color', 'k','LineWidth',2,'DisplayName','Mean');
    h_min= plot(x_um,y_min, 'Color', 'b','LineStyle','--','LineWidth',1,'DisplayName','Min');
    h_max= plot(x_um,y_max, 'Color', 'r','LineStyle','--','LineWidth',1,'DisplayName','Max');

    tmp1 = find(isnan(y_mean));
    tmp1 = reshape(tmp1,[numel(tmp1),1]);
    tmp2 = find(isnan(y_std));
    tmp2 = reshape(tmp2,[numel(tmp2),1]);    
    id_NaN = unique([tmp1; tmp2]);

    %id_NaN = unique([find(isnan(y_mean)); find(isnan(y_std))]);
    x_tmp = x_um; y_mean_tmp= y_mean;  y_std_tmp= y_std;
    x_tmp(id_NaN)=[]; y_mean_tmp(id_NaN)=[]; y_std_tmp(id_NaN)=[];

    std_min = (y_mean_tmp - y_std_tmp);
    std_max = (y_mean_tmp + y_std_tmp);
    x2 = [x_tmp, fliplr(x_tmp)];
    inBetween = [std_min, fliplr(std_max)];
    h_=fill(x2, inBetween, [0.5 0.5 0.5],'DisplayName','+/- std');
    set(h_,'LineStyle','none','FaceAlpha',0.25);

    legend(ax)

    xlabel(['Position along axe ' num2str(dim,'%i') ' (' p.voxelunit  ')' ]);
    ylabel(p.xlabel);
    axis tight;
    xlim([0 max(x_um)]);

    grid(ax,'on');
    set(ax,'FontName',p.fontname,'FontSize',12);
    hold(ax,'off');
end

if isfield(p,'fullpath')
    [filepath,~,~] = fileparts(p.fullpath);
    if ~exist(filepath,'dir')
        mkdir(filepath);
    end
    savefig(Fig,p.fullpath)
    saveas(Fig,p.fullpath,'png');
end

end

