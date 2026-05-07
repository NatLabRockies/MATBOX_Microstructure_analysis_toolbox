function [res,newtype,foo] = fct_regiongrowing_otherregion_multipleseeds(M,p)

if length(unique(p.seed_label))==1
    newtype = 'Segmented (phase)';
else
    newtype = 'Segmented (instance)';
end
foo = [];

p.video = false;
videoname = 'full3D';

%% ALGORITHM
sz = size(M);
dimension = length(sz);
[n_seed,~] = size(p.seed_location);

if dimension == 2 && p.illustrate
    p.illustrate_color = true;
else
    p.illustrate_color = false;
end


if p.excludebackground
    if strcmp(p.selectbackground,'From label')
        p.background_volume = zeros(sz,'uint8');
        p.background_volume(M==p.background_label) = 1;
    end
end

if p.local
    res_ini = zeros(sz,'uint8');

    seed_x_min = min(p.seed_location(:,1));
    seed_y_min = min(p.seed_location(:,2));
    seed_x_max = max(p.seed_location(:,1));
    seed_y_max = max(p.seed_location(:,2));
    if dimension == 3
        seed_z_min = min(p.seed_location(:,3));
        seed_z_max = max(p.seed_location(:,3));
    end       

    local_x_min = max([1 seed_x_min-p.local_range]);
    local_y_min = max([1 seed_y_min-p.local_range]);
    local_x_max = min([sz(1) seed_x_max+p.local_range]);
    local_y_max = min([sz(2) seed_y_max+p.local_range]);
    if dimension == 3
        local_z_min = max([1 seed_z_min-p.local_range]);
        local_z_max = min([sz(3) seed_z_max+p.local_range]);
    end
 
    if dimension == 2
        M = M(local_x_min:local_x_max, local_y_min:local_y_max);
        if p.excludebackground
            p.background_volume = p.background_volume(local_x_min:local_x_max, local_y_min:local_y_max);
        end
    else
        M = M(local_x_min:local_x_max, local_y_min:local_y_max, local_z_min:local_z_max);
        if p.excludebackground
            p.background_volume = p.background_volume(local_x_min:local_x_max, local_y_min:local_y_max, local_z_min:local_z_max);
        end
    end

    Seedtmp = zeros(sz,'uint8');
    if dimension == 2
        seed_subidx = sub2ind(sz,p.seed_location(:,1),p.seed_location(:,2));
    else
        seed_subidx = sub2ind(sz,p.seed_location(:,1),p.seed_location(:,2),p.seed_location(:,3));
    end
    Seedtmp(seed_subidx) = 1;
   
    if dimension == 2
        Seedtmp = Seedtmp(local_x_min:local_x_max, local_y_min:local_y_max);
        seed_subidx = find(Seedtmp);
        [p.seed_location(:,1), p.seed_location(:,2)] = ind2sub(size(Seedtmp),seed_subidx);
    else
        Seedtmp = Seedtmp(local_x_min:local_x_max, local_y_min:local_y_max, local_z_min:local_z_max);
        seed_subidx = find(Seedtmp);        
        [p.seed_location(:,1), p.seed_location(:,2), p.seed_location(:,3)] = ind2sub(size(Seedtmp),seed_subidx);
    end  
end

sz = size(M);
sz_middle = round(sz/2);
%sz_middle(2)=210;




if p.illustrate
    minM = min(min(min(M)));
    maxM = max(max(max(M)));

    fig = figure;
    fig.Color = 'w';
    if dimension == 2
        ax = axes('Parent',fig);
        RGB = cat(3, M, M, M); % For preview
        imagesc(ax, RGB);
        axis(ax, 'tight');
        axis(ax, 'equal');
    else
        tl = tiledlayout(1,3, 'Padding', 'loose', 'TileSpacing', 'compact');
        title(tl,{['Growing iteration: ' num2str(0) ', delta: ' num2str(0)],''})

        ax1 = nexttile;
        G = squeeze(M(sz_middle(1),:,:));
        RGB = cat(3, G, G, G); % For preview
        imagesc(ax1, RGB);
        axis(ax1, 'tight');
        axis(ax1, 'equal');
        title(ax1,'View normal to axe 1');

        ax2 = nexttile;
        G = squeeze(M(:,sz_middle(2),:));
        RGB = cat(3, G, G, G); % For preview
        imagesc(ax2, RGB);
        axis(ax2, 'tight');
        axis(ax2, 'equal');
        title(ax2','View normal to axe 2');

        ax3 = nexttile;
        G = M(:,:,sz_middle(3));
        RGB = cat(3, G, G, G); % For preview
        imagesc(ax3, RGB);
        axis(ax3, 'tight');
        axis(ax3, 'equal');
        title(ax3,'View normal to axe 3');
    end
    drawnow

    if p.video
        video_format = 'mpeg-4';
        video_handle = VideoWriter(fullfile(pwd, videoname),video_format);
        set(video_handle,'Quality',100); % Set video quality
        set(video_handle,'FrameRate',2);
        open(video_handle);
        writeVideo(video_handle,getframe(fig))
    end

end

%% ALL BOUNDS
% Scale 1 is finer, Scale n is coarser
fprintf(['Pretask 1/2: grid initialization...\n']);

function scale = multiscale_bounds(dim, ws)

nscale = length(ws);
for kscale = 1:nscale
    scale(kscale).n_cell = round(dim/ws(kscale));
    scale(kscale).bounds = round(linspace(1,dim,scale(kscale).n_cell+1));
    if kscale>1
        nn = scale(kscale).n_cell+1;
        for kk = 1:nn
            current_val = scale(kscale).bounds(kk);
            lowerscale = scale(kscale-1).bounds;
            d = abs(lowerscale-current_val);
            if min(d)~=0
                idx = find(d==min(d));
                scale(kscale).bounds(kk:nn) = round(linspace(lowerscale(idx(end)), dim, nn-kk+1));
            end
        end
    end

end

end

ws = zeros(p.n_scale,1);
ws(1) = 2*p.minw+1;
for k=2:p.n_scale
    ws(k) = 2*ws(k-1);
end
for k=1:dimension
    dim(k).scale = multiscale_bounds(sz(k), ws);
    for k_scale = 1:p.n_scale
        for k_cell = 1:dim(k).scale(k_scale).n_cell
            dim(k).scale(k_scale).x0 = dim(k).scale(k_scale).bounds(1:end-1);
            dim(k).scale(k_scale).x1 = dim(k).scale(k_scale).bounds(2:end)-1;
            dim(k).scale(k_scale).x1(end) = dim(k).scale(k_scale).x1(end)+1;
        end
    end
end

%% Initial seeds
% Scale 1 is finer, Scale n is coarser
id_seed_notatcoarsedscale = zeros(n_seed,1);
res = zeros(sz,'uint8');

if p.illustrate && p.illustrate_color
    cols = [colororder; rand(100,3)];
    cols(1,:) = [1 0 0];
    cols(2,:) = [0 1 0];
    cols(3,:) = [0 0 1];
    cols(5,:) = [0 1 1];
    for k_scale=1:p.n_scale
        illustration(k_scale).img = zeros(sz,'uint8');
        illustration(k_scale).col = cols(k_scale,:);
    end
    illustration(k_scale+1).col = cols(k_scale+1,:);
end


for k_scale = 1:p.n_scale

    nx = dim(1).scale(k_scale).n_cell;
    ny = dim(2).scale(k_scale).n_cell;
    if dimension == 3
        nz = dim(3).scale(k_scale).n_cell;
    else
        nz = 1;
    end

    scale(k_scale).idmap = zeros(nx,ny,nz);
    scale(k_scale).is_edge = zeros(nx*ny*nz,1);
    scale(k_scale).assign_map = zeros(nx,ny,nz);

    if k_scale>1
        Finerscale_idmap = Currentscale_idmap;
    end

    if p.n_scale>1 && k_scale < p.n_scale
        Currentscale_idmap = zeros(sz,'uint16');
    end

    id = 0;
    for kz = 1:nz
        if dimension == 2
            z0 = 1; z1 = 1;
        else
            z0 = dim(3).scale(k_scale).x0(kz);
            z1 = dim(3).scale(k_scale).x1(kz);
        end
        for ky = 1:ny
            y0 = dim(2).scale(k_scale).x0(ky);
            y1 = dim(2).scale(k_scale).x1(ky);
            for kx = 1:nx
                x0 = dim(1).scale(k_scale).x0(kx);
                x1 = dim(1).scale(k_scale).x1(kx);                

                sub = M(x0:x1,y0:y1,z0:z1);

                if p.excludebackground
                    back = p.background_volume(x0:x1,y0:y1,z0:z1);
                    sub(back==1)=[];
                end
                vals = reshape(sub,[numel(sub), 1]);
                if ~isempty(vals) % not only background
                    id = id + 1;

                    if p.n_scale>1 && k_scale < p.n_scale
                        Currentscale_idmap(x0:x1,y0:y1,z0:z1) = id;
                    end

                    scale(k_scale).idmap(kx,ky,kz) = id;
                    scale(k_scale).listgrid(id).mean = mean(vals);
                    scale(k_scale).listgrid(id).min = min(vals);
                    scale(k_scale).listgrid(id).max = max(vals);
                    scale(k_scale).listgrid(id).adjacency = [];
                    scale(k_scale).listgrid(id).assignto = [];
                    scale(k_scale).listgrid(id).xyz = [x0 x1 y0 y1 z0 z1];
                    scale(k_scale).listgrid(id).kxyz = [kx ky kz];

                    if k_scale == p.n_scale % Assign seed for the coarser grid
                        for k_seed = 1:n_seed
                            xs = p.seed_location(k_seed,1);
                            ys = p.seed_location(k_seed,2);
                            if dimension == 3
                                zs = p.seed_location(k_seed,3);
                            else
                                zs = 1;
                            end
                            if xs>=x0 && xs<=x1 && ys>=y0 && ys<=y1 && zs>=z0 && zs<=z1

                                % If window size is too big, the coarse grid may be too heterogeneous for some seeds
                                if strcmp(p.dt_choice,'Mean')
                                    bool = true;
                                elseif strcmp(p.dt_choice,'Extremum')
                                    mmax = scale(k_scale).listgrid(id).max;
                                    mmin = scale(k_scale).listgrid(id).min;
                                    bool = mmax -  mmin <= p.dt;
                                end

                                if bool % Homogeneous enough: use this seed at the coarser resolution
                                    scale(k_scale).listgrid(id).assignto = p.seed_label(k_seed);
                                    res(x0:x1,y0:y1,z0:z1) = p.seed_label(k_seed);
                                    scale(k_scale).is_edge(id) = 1;
                                    scale(k_scale).assign_map(kx,ky,kz)=1;

                                    if p.n_scale > 1
                                        idfiner = scale(k_scale).listgrid(id).finerscale_ids;
                                        for kkk=1:length(idfiner)
                                            scale(k_scale-1).is_edge(idfiner(kkk))=1;
                                            scale(k_scale-1).listgrid(idfiner(kkk)).assignto = scale(k_scale).listgrid(id).assignto;
                                            %scale(k_scale).listgrid(id_adjacents(ka)).xyz
                                            %scale(k_scale-1).listgrid(idfiner(kkk)).xyz
                                        end
                                    end
                                else % This seed is not used at the coarser resolution, but it will be re-tested for the other scales
                                    id_seed_notatcoarsedscale(k_seed) = 1;
                                end


                            end
                        end
                    end

                    if k_scale ~=1 % Who is contained in the grid immediately finer?
                        unis = unique(Finerscale_idmap(x0:x1,y0:y1,z0:z1));
                        unis(unis==0)=[];
                        scale(k_scale).listgrid(id).finerscale_ids = unis;
                    end

                end
            end
        end
    end

end


%% Step2: grid adjacency
fprintf('Pretask 2/2:: grid adjacency...\n');
for k_scale = 1:p.n_scale
    nx = dim(1).scale(k_scale).n_cell;
    ny = dim(2).scale(k_scale).n_cell;
    if dimension == 3
        nz = dim(3).scale(k_scale).n_cell;
    else
        nz = 1;
    end

    for kz = 1:nz
        for ky = 1:ny
            for kx = 1:nx
                id = scale(k_scale).idmap(kx,ky,kz);
                if id~=0
                    if kx>1
                        top_id = scale(k_scale).idmap(kx-1,ky,kz);
                        if top_id~=0
                            scale(k_scale).listgrid(id).adjacency = [scale(k_scale).listgrid(id).adjacency top_id];
                        end
                    end
                    if kx<nx
                        bottom_id = scale(k_scale).idmap(kx+1,ky,kz);
                        if bottom_id~=0
                            scale(k_scale).listgrid(id).adjacency = [scale(k_scale).listgrid(id).adjacency bottom_id];
                        end
                    end

                    if ky>1
                        left_id = scale(k_scale).idmap(kx,ky-1,kz);
                        if left_id~=0
                            scale(k_scale).listgrid(id).adjacency = [scale(k_scale).listgrid(id).adjacency left_id];
                        end
                    end
                    if ky<ny
                        right_id = scale(k_scale).idmap(kx,ky+1,kz);
                        if right_id~=0
                            scale(k_scale).listgrid(id).adjacency = [scale(k_scale).listgrid(id).adjacency right_id];
                        end
                    end

                    if dimension == 3
                        if kz>1
                            rear_id = scale(k_scale).idmap(kx,ky,kz-1);
                            if rear_id~=0
                                scale(k_scale).listgrid(id).adjacency = [scale(k_scale).listgrid(id).adjacency rear_id];
                            end
                        end
                        if kz<nz
                            front_id = scale(k_scale).idmap(kx,ky,kz+1);
                            if front_id~=0
                                scale(k_scale).listgrid(id).adjacency = [scale(k_scale).listgrid(id).adjacency front_id];
                            end
                        end
                    end
                end
            end
        end
    end
end


%% Step 3: growing
% Scale 1 is finer, Scale n is coarser
iter_scale = 0;
for k_scale = p.n_scale:-1:1
    iter_scale = iter_scale+1;

    iter = 0;
    ntot_old = 0;
    %ntot_new = sum(sum(sum( scale(k_scale).assign_map )));
    ntot_new = 1;

    fprintf(['Scale ' num2str(k_scale) ', growing...\n']);


    if k_scale < p.n_scale % Check for seeds not used at coarser grids
        ids_missing = find(id_seed_notatcoarsedscale);
        id_seed_notatthisscale = zeros(n_seed,1);
        if ~isempty(ids_missing)
            is_missing = false;
            for k_missing = 1:length(ids_missing)
                xs = p.seed_location(ids_missing(k_missing),1);
                ys = p.seed_location(ids_missing(k_missing),2);
                if dimension == 3
                    zs = p.seed_location(ids_missing(k_missing),3);
                else
                    zs = 1;
                end
                if res(xs,ys,zs)==0
                    id_seed_notatthisscale(ids_missing(k_missing)) = 1;
                end
            end

            if sum(id_seed_notatthisscale)
                ids_missing = find(id_seed_notatthisscale);

                nx = dim(1).scale(k_scale).n_cell;
                ny = dim(2).scale(k_scale).n_cell;
                if dimension == 3
                    nz = dim(3).scale(k_scale).n_cell;
                else
                    nz = 1;
                end
                id = 0;
                for kz = 1:nz
                    if dimension == 2
                        z0 = 1; z1 = 1;
                    else
                        z0 = dim(3).scale(k_scale).x0(kz);
                        z1 = dim(3).scale(k_scale).x1(kz);
                    end
                    for ky = 1:ny
                        y0 = dim(2).scale(k_scale).x0(ky);
                        y1 = dim(2).scale(k_scale).x1(ky);
                        for kx = 1:nx
                            x0 = dim(1).scale(k_scale).x0(kx);
                            x1 = dim(1).scale(k_scale).x1(kx);

                            sub = M(x0:x1,y0:y1,z0:z1);

                            if p.excludebackground
                                back = p.background_volume(x0:x1,y0:y1,z0:z1);
                                sub(back==1)=[];
                            end
                            vals = reshape(sub,[numel(sub), 1]);
                            if ~isempty(vals) % not only background
                                id = id + 1;

                                for k_missing = 1:length(ids_missing)
                                    xs = p.seed_location(ids_missing(k_missing),1);
                                    ys = p.seed_location(ids_missing(k_missing),2);
                                    if dimension == 3
                                        zs = p.seed_location(ids_missing(k_missing),3);
                                    else
                                        zs = 1;
                                    end
                                    if xs>=x0 && xs<=x1 && ys>=y0 && ys<=y1 && zs>=z0 && zs<=z1

                                        if strcmp(p.dt_choice,'Mean')
                                            bool = true;
                                        elseif strcmp(p.dt_choice,'Extremum')
                                            mmax = scale(k_scale).listgrid(id).max;
                                            mmin = scale(k_scale).listgrid(id).min;
                                            bool = mmax -  mmin <= p.dt;
                                        end

                                        if bool
                                            scale(k_scale).listgrid(id).assignto = p.seed_label(k_seed);
                                            res(x0:x1,y0:y1,z0:z1) = p.seed_label(k_seed);
                                            scale(k_scale).is_edge(id) = 1;
                                            scale(k_scale).assign_map(kx,ky,kz)=1;
                                        %     if p.n_scale > 1
                                        %         idfiner = scale(k_scale).listgrid(id).finerscale_ids;
                                        %         for kkk=1:length(idfiner)
                                        %             scale(k_scale-1).is_edge(idfiner(kkk))=1;
                                        %             scale(k_scale-1).listgrid(idfiner(kkk)).assignto = scale(k_scale).listgrid(id).assignto;
                                        %         end
                                        %     end
                                        end

                                    end
                                end


                            end
                        end
                    end
                end


            end
        end
    end



    while ntot_new>ntot_old && iter<p.max_iter
        ntot_old = ntot_new;
        iter = iter +1;
        fprintf('   Growing scale %i, iteration: %i',k_scale,iter)

        id_edges = find(scale(k_scale).is_edge);
        for ke=1:length(id_edges)

            % xe0 = scale(k_scale).listgrid(id_edges(ke)).xyz(1);
            % xe1 = scale(k_scale).listgrid(id_edges(ke)).xyz(2);
            % ye0 = scale(k_scale).listgrid(id_edges(ke)).xyz(3);
            % ye1 = scale(k_scale).listgrid(id_edges(ke)).xyz(4);
            % ze0 = scale(k_scale).listgrid(id_edges(ke)).xyz(5);
            % ze1 = scale(k_scale).listgrid(id_edges(ke)).xyz(6);

            if k_scale>1
                idfiner = scale(k_scale).listgrid(id_edges(ke)).finerscale_ids;
                for kkk=1:length(idfiner)
                    scale(k_scale-1).is_edge(idfiner(kkk))=1;
                    scale(k_scale-1).listgrid(idfiner(kkk)).assignto = scale(k_scale).listgrid(id_edges(ke)).assignto;
                    %scale(k_scale).listgrid(id_adjacents(ka)).xyz
                    %scale(k_scale-1).listgrid(idfiner(kkk)).xyz
                end
            end

           
            id_adjacents =  scale(k_scale).listgrid(id_edges(ke)).adjacency;
            for ka = 1:length(id_adjacents)

                x0 =  scale(k_scale).listgrid(id_adjacents(ka)).xyz(1);
                x1 =  scale(k_scale).listgrid(id_adjacents(ka)).xyz(2);
                y0 =  scale(k_scale).listgrid(id_adjacents(ka)).xyz(3);
                y1 =  scale(k_scale).listgrid(id_adjacents(ka)).xyz(4);
                z0 =  scale(k_scale).listgrid(id_adjacents(ka)).xyz(5);
                z1 =  scale(k_scale).listgrid(id_adjacents(ka)).xyz(6);

                if strcmp(p.dt_choice,'Mean')
                    bool = abs( scale(k_scale).listgrid(id_adjacents(ka)).mean -  scale(k_scale).listgrid(id_edges(ke)).mean) <= p.dt;
                elseif strcmp(p.dt_choice,'Extremum')
                    mmax = max([scale(k_scale).listgrid(id_adjacents(ka)).max scale(k_scale).listgrid(id_edges(ke)).max]);
                    mmin = min([scale(k_scale).listgrid(id_adjacents(ka)).min scale(k_scale).listgrid(id_edges(ke)).min]);
                    bool = mmax -  mmin <= p.dt;
                end

                if bool % Coarse growing     
                    scale(k_scale).is_edge(id_adjacents(ka))=1;
                    scale(k_scale).listgrid(id_adjacents(ka)).assignto = scale(k_scale).listgrid(id_edges(ke)).assignto;
                    res(x0:x1,y0:y1,z0:z1) = scale(k_scale).listgrid(id_edges(ke)).assignto;
                    scale(k_scale).assign_map(scale(k_scale).listgrid(id_adjacents(ka)).kxyz(1), scale(k_scale).listgrid(id_adjacents(ka)).kxyz(2), scale(k_scale).listgrid(id_adjacents(ka)).kxyz(3))=1;

                    if k_scale>1
                        idfiner = scale(k_scale).listgrid(id_adjacents(ka)).finerscale_ids;
                        for kkk=1:length(idfiner)
                            scale(k_scale-1).is_edge(idfiner(kkk))=1;
                            scale(k_scale-1).listgrid(idfiner(kkk)).assignto = scale(k_scale).listgrid(id_edges(ke)).assignto;
                            %scale(k_scale).listgrid(id_adjacents(ka)).xyz
                            %scale(k_scale-1).listgrid(idfiner(kkk)).xyz
                        end
                    end

                else % Fine growing
                    if k_scale==1 % Only for the finer scale

                        subM = M(x0:x1,y0:y1,z0:z1);
                        subR = res(x0:x1,y0:y1,z0:z1);

                        if strcmp(p.dt_choice,'Mean')
                            cond1 = abs( double(subM) -  scale(k_scale).listgrid(id_edges(ke)).mean) <= p.dt;
                        elseif strcmp(p.dt_choice,'Extremum')
                            mmax = max( double(subM), ones(size(subM))*double(scale(k_scale).listgrid(id_edges(ke)).max));
                            mmin = min( double(subM), ones(size(subM))*double(scale(k_scale).listgrid(id_edges(ke)).min));
                            cond1 = mmax -  mmin <= p.dt;
                        end

                        cond2 = subR==0;
                        subR(cond1.*cond2==1) =  scale(k_scale).listgrid(id_edges(ke)).assignto;
                        res(x0:x1,y0:y1,z0:z1) =  subR;

                        if sum(sum(sum(subR~=0)))==numel(subR)
                            scale(k_scale).is_edge(id_adjacents(ka))=1;
                            scale(k_scale).listgrid(id_adjacents(ka)).assignto = scale(k_scale).listgrid(id_edges(ke)).assignto;
                            scale(k_scale).assign_map(scale(k_scale).listgrid(id_adjacents(ka)).kxyz(1), scale(k_scale).listgrid(id_adjacents(ka)).kxyz(2), scale(k_scale).listgrid(id_adjacents(ka)).kxyz(3))=1;
                        end
                    end

                end
            end

            scale(k_scale).is_edge(id_edges(ke))=0;

        end
        ntot_new = sum(sum(sum( scale(k_scale).assign_map )));
        fprintf(' ... delta: %i\n',ntot_new-ntot_old)

        if p.illustrate
            if dimension == 2
                if p.illustrate_color
                    if iter_scale == 1
                        RGB = cat(3, M + (maxM+minM)/2*illustration(iter_scale).col(1)*res, M + (maxM+minM)/2*illustration(iter_scale).col(2)*res, M + (maxM+minM)/2*illustration(iter_scale).col(3)*res); % For preview
                    else
                        new = res./res;
                        R = M; G = M; B = M;
                        for kkk=1:p.n_scale
                            new = new - illustration(kkk).img;
                            R = R + (maxM+minM)/2*illustration(kkk).col(1)*illustration(kkk).img;
                            G = G + (maxM+minM)/2*illustration(kkk).col(2)*illustration(kkk).img;
                            B = B + (maxM+minM)/2*illustration(kkk).col(3)*illustration(kkk).img;
                        end
                        R = R + (maxM+minM)/2*illustration(iter_scale).col(1)*new;
                        G = G + (maxM+minM)/2*illustration(iter_scale).col(2)*new;
                        B = B + (maxM+minM)/2*illustration(iter_scale).col(3)*new;
                        RGB = cat(3, R, G, B);
                    end
                else
                    RGB = cat(3, M + (maxM+minM)/2*res, M, M);
                end
                cla(ax);
                imagesc(ax, RGB);
                axis(ax, 'tight');
                axis(ax, 'equal');
                title(['Growing scale: ' num2str(k_scale) ', iteration: ' num2str(iter) ', delta: ' num2str(ntot_new-ntot_old)]);
            else
                cla(ax1);
                resS = squeeze(res(sz_middle(1),:,:));
                G = squeeze(M(sz_middle(1),:,:));
                RGB = cat(3, G+100*resS, G, G); % For preview
                imagesc(ax1, RGB);
                axis(ax1, 'tight');
                axis(ax1, 'equal');
                title(ax1,'View normal to axe 1');

                cla(ax2);
                resS = squeeze(res(:,sz_middle(2),:));
                G = squeeze(M(:,sz_middle(2),:));
                RGB = cat(3, G+100*resS, G, G); % For preview
                imagesc(ax2, RGB);
                axis(ax2, 'tight');
                axis(ax2, 'equal');
                title(ax2,'View normal to axe 2');

                cla(ax3);
                resS = res(:,:,sz_middle(3));
                G = M(:,:,sz_middle(3));
                RGB = cat(3, G+100*resS, G, G); % For preview
                imagesc(ax3, RGB);
                axis(ax3, 'tight');
                axis(ax3, 'equal');
                title(ax3,'View normal to axe 3');

                title(tl,{['Growing scale: ' num2str(k_scale) ', iteration: ' num2str(iter) ', delta: ' num2str(ntot_new-ntot_old)],''})
            end
            drawnow;
        end
        if p.video
            writeVideo(video_handle,getframe(fig))
        end
    end

    if p.illustrate && p.illustrate_color
        illustration(iter_scale).img = res./res;
        if iter_scale>1
            for kkk=1:iter_scale-1
                idxtmp = find(illustration(kkk).img);
                illustration(iter_scale).img(idxtmp) = 0; 
            end
        end
    end

end

if p.excludebackground
    res(p.background_volume==1) = 0;
end


%% Step 4: continuity
% Fine growing can induce disconnected pixels
fprintf('Post task (continuity 1/2)...\n');

% %res2 = res;
% res2 = zeros(sz,'like',M);
% for ks=1:n_seed
%     xs = p.seed_location(ks,1);
%     ys = p.seed_location(ks,2);
%     if dimension == 3
%         zs = p.seed_location(ks,3);
%     else
%         zs = 1;
%     end
%     if res(xs,ys,zs)~=0
%         tmp = zeros(sz);
%         tmp(res==p.seed_label(ks))=1;
%         if dimension == 2
%             C = bwlabel(tmp,4);
%             largestcluster_label = C(p.seed_location(ks,1),p.seed_location(ks,2));
%         else
%             C = bwlabeln(tmp,6);
%             largestcluster_label = C(p.seed_location(ks,1),p.seed_location(ks,2),p.seed_location(ks,3));
%         end
%         res2(C==largestcluster_label)=p.seed_label(ks);
%     end
% end

% Dumber but Faster
if dimension == 2
    C = bwlabel(res,4);
    idxseed = sub2ind(sz,p.seed_location(:,1),p.seed_location(:,2));
else
    C = bwlabeln(res,6);
    idxseed = sub2ind(sz,p.seed_location(:,1),p.seed_location(:,2),p.seed_location(:,3));
end
check = find(res(idxseed)~=0);

% Cluster id that contains at least one seed
uniC = unique(C(idxseed(check)));

idxres = find(res~=0);
res2 = zeros(sz,'like',res);
for k=1:length(idxres)
    if ismember(C(idxres(k)),uniC) 
        res2(idxres(k)) = res(idxres(k));
    end
end
res = res2;
clear res2


%% Step 5: nearby growing
fprintf('Post task (interface growing)...\n');
[dmap,IDX] = bwdist(res);

cond1 = dmap<=ws(1);
cond2 = res ==0;
nearby = find(cond1.*cond2);

%figure; imagesc(res); axis equal tight; colormap turbo;
%figure; imagesc(dmap); axis equal tight; colormap turbo;

for k=1:length(nearby)
    if abs( M(IDX(nearby(k))) - M(nearby(k)) ) <= p.dt/4
        res(nearby(k))=1;
    end
end

%figure; imagesc(res); axis equal tight; colormap turbo;


%% Step 6:
% Fine growing can induce disconnected pixels
fprintf('Post task (continuity 2/2)...\n');

% %res2 = res;
% res2 = zeros(sz,'like',M);
% for ks=1:n_seed
%     xs = p.seed_location(ks,1);
%     ys = p.seed_location(ks,2);
%     if dimension == 3
%         zs = p.seed_location(ks,3);
%     else
%         zs = 1;
%     end
%     if res(xs,ys,zs)~=0
%         tmp = zeros(sz);
%         tmp(res==p.seed_label(ks))=1;
%         if dimension == 2
%             C = bwlabel(tmp,4);
%             largestcluster_label = C(p.seed_location(ks,1),p.seed_location(ks,2));
%         else
%             C = bwlabeln(tmp,6);
%             largestcluster_label = C(p.seed_location(ks,1),p.seed_location(ks,2),p.seed_location(ks,3));
%         end
%         res2(C==largestcluster_label)=p.seed_label(ks);
%     end
% end

% Dumber but Faster
if dimension == 2
    C = bwlabel(res,4);
    idxseed = sub2ind(sz,p.seed_location(:,1),p.seed_location(:,2));
else
    C = bwlabeln(res,6);
    idxseed = sub2ind(sz,p.seed_location(:,1),p.seed_location(:,2),p.seed_location(:,3));
end
check = find(res(idxseed)~=0);

% Cluster id that contains at least one seed
uniC = unique(C(idxseed(check)));

idxres = find(res~=0);
res2 = zeros(sz,'like',res);
for k=1:length(idxres)
    if ismember(C(idxres(k)),uniC) 
        res2(idxres(k)) = res(idxres(k));
    end
end
res = res2;
clear res2

%%


fprintf('Done!\n');

if p.illustrate
    if dimension == 2
        if p.illustrate_color

            new = res./res;
            for kkk=1:p.n_scale
                illustration(kkk).img(res==0)=0;
                new = new - illustration(kkk).img;
            end
            R = M; G = M; B = M;
            for kkk=1:p.n_scale
                R = R + (maxM+minM)/2*illustration(kkk).col(1)*illustration(kkk).img;
                G = G + (maxM+minM)/2*illustration(kkk).col(2)*illustration(kkk).img;
                B = B + (maxM+minM)/2*illustration(kkk).col(3)*illustration(kkk).img;
            end
            R = R + (maxM+minM)/2*illustration(kkk+1).col(1)*new;
            G = G + (maxM+minM)/2*illustration(kkk+1).col(2)*new;
            B = B + (maxM+minM)/2*illustration(kkk+1).col(3)*new;
            RGB = cat(3, R, G, B);
        else
            RGB = cat(3, M+100*res, M, M); % For preview
        end
        cla(ax);
        imagesc(ax, RGB);
        axis(ax, 'tight');
        axis(ax, 'equal');
        drawnow;
        title('Continuity check and interface growing');
        
    else
        cla(ax1);
        resS = squeeze(res(sz_middle(1),:,:));
        G = squeeze(M(sz_middle(1),:,:));
        RGB = cat(3, G+100*resS, G, G); % For preview
        imagesc(ax1, RGB);
        axis(ax1, 'tight');
        axis(ax1, 'equal');
        title('View normal to axe 1');

        cla(ax2);
        resS = squeeze(res(:,sz_middle(2),:));
        G = squeeze(M(:,sz_middle(2),:));
        RGB = cat(3, G+100*resS, G, G); % For preview
        imagesc(ax2, RGB);
        axis(ax2, 'tight');
        axis(ax2, 'equal');
        title('View normal to axe 2');

        cla(ax3);
        resS = res(:,:,sz_middle(3));
        G = M(:,:,sz_middle(3));
        RGB = cat(3, G+100*resS, G, G); % For preview
        imagesc(ax3, RGB);
        axis(ax3, 'tight');
        axis(ax3, 'equal');
        title('View normal to axe 3');      

        title(tl,{'Continuity check and interface growing',''})
    end
    if p.video
        writeVideo(video_handle,getframe(fig))
        writeVideo(video_handle,getframe(fig))
        writeVideo(video_handle,getframe(fig))
    end
end

if p.local
    if dimension == 2
        res_ini(local_x_min:local_x_max, local_y_min:local_y_max) = res;
    else
        res_ini(local_x_min:local_x_max, local_y_min:local_y_max, local_z_min:local_z_max) = res;
    end
    res = res_ini;
end

end