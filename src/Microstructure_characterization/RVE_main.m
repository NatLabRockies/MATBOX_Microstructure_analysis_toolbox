function [results_main, results_correlation, timedata_perphase, timedata_pervolume] = RVE_main(pRVEs,pMET,Msem,Nanoporosity,Wetting,Diffusivity,Conductivity,Mins,voxel_size,Current_folder,opt,infovol,results_main, results_correlation, timedata_perphase, timedata_pervolume)

% For new metric:
% Change RVE_main on 2 locations: calculation and correlation
% Do not change any other files

% To do:
% Add: RVE_figures           : add violon plot
% Fix: RVE_convergence_Table : (not critical) Correct FOV_length and RVE_length (currently tables are not saved)
% Fix: Result_RVEconv        : (not critial) remove x axis length as already put inFOV_length instead

if isempty(Mins)
    sz = size(Msem);
else
    sz = size(Mins);
end
dimension = length(sz);
if dimension == 2
    sz(3)=1;
end

nMetric = length(pMET.metric);

for k_RVE = 1:length(pRVEs) % Loop over all RVE analysis
    pRVE = pRVEs(k_RVE); % Select RVE parameters
    RVE(k_RVE).RVEparameters = pRVE; % For result structure
    RVE(k_RVE).attempted = false;

    %% CHECK IF ANALYSIS POSSIBLE
    if dimension == 2
        if strcmp(pRVE.type,'C') && strcmp(pRVE.Constantdirection,'Direction 3')
            warning('Impossible RVE analysis: domain is 2D but constant direction is set along axe 3!');
            continue
        elseif strcmp(pRVE.type,'D')
            warning('Impossible RVE analysis: domain is 2D but with two constant directions!');
            continue
        elseif strcmp(pRVE.type,'G') && (strcmp(pRVE.Growthdirection,'Direction 3, from z min to z max') || strcmp(pRVE.Growthdirection,'Direction 3, from z max to z min'))
            warning('Impossible convergence analysis: domain is 2D but growing direction is set along axe 3!');
            continue
        end
        if strcmp(pRVE.analysis,'Independent subvolumes') && pRVE.RVEconvergence_with_FOV
            if strcmp(pRVE.RVEconvergence_Crop,'1 direction') && (strcmp(pRVE.RVEconvergence_thatis,'Shrink along direction 3, from z min to z max') || strcmp(pRVE.RVEconvergence_thatis,'Shrink along direction 3, from z max to z min') || strcmp(pRVE.RVEconvergence_thatis,'Shrink along direction 3, from both ends'))
                warning('Impossible RVE=f(FOV) analysis: domain is 2D but shrinking direction is set along axe 3!');
                continue
            elseif strcmp(pRVE.RVEconvergence_Crop,'2 direction') && (strcmp(pRVE.RVEconvergence_thatis,'And keep direction 1 uncropped') || strcmp(pRVE.RVEconvergence_thatis,'And keep direction 2 uncropped'))
                warning('Impossible RVE=f(FOV) analysis: domain is 2D but shrinking direction is set along axe 3!');
                continue
            elseif strcmp(pRVE.RVEconvergence_Crop,'3 direction')
                warning('Impossible RVE=f(FOV) analysis: domain is 2D but shrinking direction is set along axe 3!');
                continue
            end
        end
    end
    RVE(k_RVE).attempted = true;

    %% CREATE FOLDER
    if opt.save.xls || opt.save.savefig
        Sub_folder_RVE = fullfile(Current_folder, pRVE.savename);
        v=0;
        while exist(Sub_folder_RVE,'dir')
            v=v+1;
            Sub_folder_RVE = fullfile(Current_folder, [pRVE.savename '_bis' num2str(v)]);
        end
        mkdir(Sub_folder_RVE);
    end

    %% SELECT THRESHOLDS
    if ~ischar(pRVE.threshold_subs_val) % not 'n/a'
        thresholds = pRVE.threshold_subs_val; % Subvolumes
    else
        thresholds = pRVE.threshold_onesub_val; % One volume
    end
    n_threshold = length(thresholds);

    %% RVE CONVERGENCE ANALYSIS
    if strcmp(pRVE.analysis,'Independent subvolumes') && pRVE.RVEconvergence_with_FOV
        FOVbounds = RVE_convergence_FOVbounds(pRVE,sz);
        if ~isempty(FOVbounds)
            [nFOV,~] = size(FOVbounds); % Number of FOV
            length_FOV = zeros(nFOV+1,2);
            for kMetric = 1:nMetric
                number_domain = length(pMET.metric(kMetric).result_initial);
                metric(kMetric).number_domain = number_domain;
                metric(kMetric).Result_RVEconv = zeros(nFOV+1,n_threshold+1,number_domain,3,2);
            end
            % FOV size / number of threshold / phase / subdomain RVE or convergence size <, = , > /  size (both FOV and subdomain) in cubic or square root (=1), square root or length (=2)
        end
    else
        for kMetric = 1:nMetric
            number_domain = length(pMET.metric(kMetric).result_initial);
            metric(kMetric).number_domain = number_domain;
        end
    end
    if exist('FOVbounds','var') && ~isempty(FOVbounds)
        pRVE.RVEconvergence_with_FOV = true; % Overwritte
    else
        pRVE.RVEconvergence_with_FOV = false;
        nFOV = 0;
    end

    %% LOOP OVER FOVs
    for k_FOV = 0:1:nFOV

        %% SELECT FOV
        if k_FOV>0
            x0 = FOVbounds(k_FOV,1); x1 = FOVbounds(k_FOV,2);
            y0 = FOVbounds(k_FOV,3); y1 = FOVbounds(k_FOV,4);
            z0 = FOVbounds(k_FOV,5); z1 = FOVbounds(k_FOV,6);
            if ~isempty(Msem)
                Msem_FOV = Msem(x0:x1,y0:y1,z0:z1);
                sz_FOV = size(Msem_FOV);
                Nano_FOV = Nanoporosity(x0:x1,y0:y1,z0:z1);
                Wett_FOV = Wetting(x0:x1,y0:y1,z0:z1);
                if ~isempty(Diffusivity)
                    Diff_FOV = Diffusivity(x0:x1,y0:y1,z0:z1);
                else
                    Diff_FOV = [];
                end
                if ~isempty(Conductivity)
                    Cond_FOV = Conductivity(x0:x1,y0:y1,z0:z1);
                else
                    Cond_FOV = [];
                end
            end
            if ~isempty(Mins)
                Mins_FOV = Mins(x0:x1,y0:y1,z0:z1);
                sz_FOV = size(Mins_FOV);
            end
        else
            sz_FOV = sz;
        end
        FOVsize = (prod(sz_FOV))^(1/dimension) * voxel_size;
        if dimension == 3
            FOVlength_str = 'cubic root';
            if strcmp(pRVE.analysis,'Independent subvolumes')
                RVE(k_RVE).Representativity_analysis = 'Representative volume element (RVE)';
            else
                RVE(k_RVE).Representativity_analysis = 'Volume convergence';
            end
        else
            FOVlength_str = 'square root';
            if strcmp(pRVE.analysis,'Independent subvolumes')
                RVE(k_RVE).Representativity_analysis = 'Representative Section Area (RSA)';
            else
                RVE(k_RVE).Representativity_analysis = 'Section area convergence';
            end
        end
        RVE(k_RVE).FOVlength_str = FOVlength_str;

        %% SELECT SUBDOMAINS FOR THIS FOV
        [All_subdomain,GROUP_SUBDOMAIN, REP2ndsize, Representativity_2ndlength_str, Representativity_analysis_size2] = RVE_Subdomains(pRVE, sz_FOV, voxel_size); % Location of all subdomains
        if isempty(All_subdomain)
            warning('FOV is too small to satisfy the minimum subomain condition.')
            continue
        end

        RVE(k_RVE).Representativity_2ndlength_str = Representativity_2ndlength_str;
        RVE(k_RVE).Representativity_analysis_size2 = Representativity_analysis_size2;

        if pRVE.RVEconvergence_with_FOV
            [FOV2ndsize, FOV2ndsize_lengthstr] = RVE_2ndsize(pRVE,sz_FOV,voxel_size); % Get FOV second size

            length_FOV(k_FOV+1,1) = FOVsize;
            %Result_RVEconv(k_FOV+1,1,:,:,1,:) = FOVsize; % FOV size
            if k_FOV ==1
                fprintf('       Representativity convergence analysis\n');
                fprintf('       The same representativity analysis performed on the full FOV is redone on smaller, cropped, FOVs\n');
                fprintf('       RVE, RSA sizes are then plotted as function of the FOV size. If not reaching a plateau, RVE, RSA sizes are still underestimated!\n');
            end
            if k_FOV > 0
                if isempty(FOV2ndsize)
                    fprintf('          Cropping iteration #%i/%i: FOV %s =%1.2f %s\n',k_FOV,nFOV,FOVlength_str,FOVsize,infovol.unit);
                else
                    fprintf('          Cropping iteration #%i/%i: FOV %s =%1.2f %s, FOV 2nd size %s =%1.2f %s\n',k_FOV,nFOV,FOVlength_str,FOVsize,infovol.unit,FOV2ndsize_lengthstr,FOV2ndsize,infovol.unit);
                end
            end
            if ~isempty(FOV2ndsize)
                length_FOV(k_FOV+1,2) = FOV2ndsize;
                %Result_RVEconv(k_FOV+1,1,:,:,2,:) = FOV2ndsize; % FOV second size
                nsize = 2;
            else
                nsize = 1;
            end
        end

        % Information about subdomains
        RVE(k_RVE).info = table(All_subdomain(:,1),All_subdomain(:,2),All_subdomain(:,3),All_subdomain(:,4),All_subdomain(:,5),All_subdomain(:,6),All_subdomain(:,7),All_subdomain(:,8),All_subdomain(:,9),All_subdomain(:,10),All_subdomain(:,11),All_subdomain(:,12),...
            'VariableNames',{'Subdomain Id' 'Group Id' 'Number subdomain' 'Cubic root' 'Square root' 'Length' 'x0' 'x1' 'y0' 'y1' 'z0' 'z1'});
        [number_subdomain,~] = size(All_subdomain); % The number of subdomain
        number_group_size = length(GROUP_SUBDOMAIN.id); % the number of group of subdomains sharing the same size

        %% APPLY ALGORITHM ON SUBDOMAINS
        % Colunm 1 is the subdomain id
        % Colunm 2-4 are the sizes of the subdomain.
        for kMetric = 1:nMetric
            metric(kMetric).Property_eachsubdomain = zeros(number_subdomain, metric(kMetric).number_domain + 4);
            for subdomain_id = 1:number_subdomain
                metric(kMetric).Property_eachsubdomain(subdomain_id,1)=subdomain_id;
                % Equivalent size of the subdomain
                metric(kMetric).Property_eachsubdomain(subdomain_id,2)=All_subdomain(subdomain_id,4)*voxel_size; % Cubic root length
                metric(kMetric).Property_eachsubdomain(subdomain_id,3)=All_subdomain(subdomain_id,5)*voxel_size; % Square root length
                metric(kMetric).Property_eachsubdomain(subdomain_id,4)=All_subdomain(subdomain_id,6)*voxel_size; % Length
            end
        end

        % Property calculated for each subdomain
        for subdomain_id = 1:number_subdomain
            % Boundary of the subdomain
            x0 = All_subdomain(subdomain_id,7); x1 = All_subdomain(subdomain_id,8);
            y0 = All_subdomain(subdomain_id,9); y1 = All_subdomain(subdomain_id,10);
            z0 = All_subdomain(subdomain_id,11); z1 = All_subdomain(subdomain_id,12);
            % Crop FOV
            if k_FOV == 0
                if ~isempty(Msem)
                    current_subdomain_labels = Msem(x0:x1,y0:y1,z0:z1);
                    current_subdomain_np = Nanoporosity(x0:x1,y0:y1,z0:z1);
                    current_subdomain_wet = Wetting(x0:x1,y0:y1,z0:z1);
                    if ~isempty(Diffusivity)
                        current_subdomain_diff = Diffusivity(x0:x1,y0:y1,z0:z1);
                    else
                        current_subdomain_diff = [];
                    end
                    if ~isempty(Conductivity)
                        current_subdomain_cond = Conductivity(x0:x1,y0:y1,z0:z1);
                    else
                        current_subdomain_cond = [];
                    end
                    voxel_number_tmp=numel(current_subdomain_labels);
                end
                if ~isempty(Mins)
                    current_subdomain_labels = Mins(x0:x1,y0:y1,z0:z1);
                    current_subdomain_np = [];
                    current_subdomain_wet = [];
                    voxel_number_tmp=numel(current_subdomain_labels);
                end
            else
                if ~isempty(Msem)
                    current_subdomain_labels = Msem_FOV(x0:x1,y0:y1,z0:z1);
                    current_subdomain_np = Nano_FOV(x0:x1,y0:y1,z0:z1);
                    current_subdomain_wet = Wett_FOV(x0:x1,y0:y1,z0:z1);
                    if ~isempty(Diffusivity)
                        current_subdomain_diff = Diff_FOV(x0:x1,y0:y1,z0:z1);
                    else
                        current_subdomain_diff = [];
                    end
                    if ~isempty(Conductivity)
                        current_subdomain_cond = Cond_FOV(x0:x1,y0:y1,z0:z1);
                    else
                        current_subdomain_cond = [];
                    end
                    voxel_number_tmp=numel(current_subdomain_labels);
                end
                if ~isempty(Mins)
                    current_subdomain_labels = Mins_FOV(x0:x1,y0:y1,z0:z1);
                    current_subdomain_np = [];
                    current_subdomain_wet = [];
                    voxel_number_tmp=numel(current_subdomain_labels);
                end
            end

            % CPU and stopwatch time - start
            time_cpu_start_volume = cputime; % CPU start
            time_clock_start_volume = tic; % Stopwatch start

            % % Algorithm: SPECIFIC FOR EACH FILE
            if strcmp(pMET.fct_name,'Volume fraction')
                % Background
                n_voxel_background = 0;
                if infovol.isbackground
                    background_label = infovol.phaselabel(1);
                    n_voxel_background = sum(sum(sum(current_subdomain_labels==background_label)));
                end
                n_voxel = voxel_number_tmp - n_voxel_background;

                if nMetric==2 % p.combined_todo==1: [vf_solid, vf_pore, vf_liquid, vf_gas, vf_AM]
                    nvoxel.AM = 0;
                    nvoxel.solid = 0;
                    nvoxel.pore = 0;
                    nvoxel.liquid = 0;
                    nvoxel.gas = 0;
                end

                % Volume fraction label-wise
                number_domain = metric(1).number_domain;
                for current_domain=1:number_domain % Loop over all phases
                    time_cpu_start_phase = cputime; % CPU start
                    time_clock_start_phase = tic; % Stopwatch start
                    [~,vf,~,n] = Charact_Volumefractions_algorithm(current_subdomain_labels, pMET.metric(1).domain_label(current_domain), n_voxel, current_subdomain_np, current_subdomain_wet, infovol.activematerial_identification);
                    if n_voxel_background==0
                        metric(1).Property_eachsubdomain(subdomain_id,current_domain+4) = vf.label;
                    else
                        metric(1).Property_eachsubdomain(subdomain_id,current_domain+4) = NaN;
                    end
                    % Time
                    timedata_perphase = [timedata_perphase; [n.label (cputime-time_cpu_start_phase) toc(time_clock_start_phase)]];
                    if nMetric==2
                        nvoxel.AM = nvoxel.AM + n.label_and_AM;
                        nvoxel.solid = nvoxel.solid + n.label_and_solid;
                        nvoxel.pore = nvoxel.pore + n.label_and_pore;
                        nvoxel.liquid = nvoxel.liquid + n.label_and_liquid;
                        nvoxel.gas = nvoxel.gas + n.label_and_gas;
                    end
                end
                if nMetric==2 % p.combined_todo==1: [vf_solid, vf_pore, vf_liquid, vf_gas, vf_AM]
                    if n_voxel_background==0
                        vf_AM = nvoxel.AM/n_voxel;
                        vf_solid = nvoxel.solid/n_voxel;
                        vf_pore = nvoxel.pore/n_voxel;
                        vf_liquid = nvoxel.liquid/n_voxel;
                        vf_gas = nvoxel.gas/n_voxel;
                    else
                        vf_AM = NaN;
                        vf_solid = NaN;
                        vf_pore = NaN;
                        vf_liquid = NaN;
                        vf_gas = NaN;                        
                    end
                    metric(2).Property_eachsubdomain(subdomain_id,5:end) = [vf_solid vf_pore vf_liquid vf_gas vf_AM];                    
                end

                % CPU and stopwatch time - end
                timedata_pervolume = [timedata_pervolume; [voxel_number_tmp (cputime-time_cpu_start_volume) toc(time_clock_start_volume)]];


            elseif strcmp(pMET.fct_name,'Transport')
                number_direction_todo = length(pMET.direction_todo);
                kmetric = 0;
                current_phase_todo = 0;
                if sum(pMET.phases_todo)>0
                    number_phase_todo = sum(pMET.phases_todo);
                    for current_phase_todo=1:number_phase_todo % Loop over all phases
                        label = pMET.phaselabel_todo(current_phase_todo);
                        nvoxel = sum(sum(sum( current_subdomain_labels==label )));
                        for current_direction_todo = 1:number_direction_todo % Loop over all directions
                            time_cpu_start_phase = cputime; % CPU start
                            time_clock_start_phase = tic; % Stopwatch start
                            direction = pMET.direction_todo(current_direction_todo);
                            % % Algorithm
                            [Deff,Mc,Tau,Bruggeman,eps] = Call_TauFactor2_binary(current_subdomain_labels,direction,label);
                            kmetric = kmetric +1;
                            metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = Tau;
                            kmetric = kmetric +1;
                            metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = Bruggeman;
                            kmetric = kmetric +1;
                            metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = Deff;

                            % Time
                            timedata_perphase = [timedata_perphase; [nvoxel (cputime-time_cpu_start_phase) toc(time_clock_start_phase)]];
                        end
                    end

                end

                kmetric = 0;
                if pMET.pore_combined_todo
                    current_phase_todo = current_phase_todo + 1;
                    for current_direction_todo = 1:number_direction_todo % Loop over all directions
                        direction = pMET.direction_todo(current_direction_todo);

                        time_cpu_start_phase = cputime; % CPU start
                        time_clock_start_phase = tic; % Stopwatch start

                        [pore_Deff,pore_Mc,pore_Tau,pore_Bruggeman,pore_eps,n_voxel] = Call_TauFactor2_pore(current_subdomain_np,current_subdomain_wet,current_subdomain_diff,direction);

                        kmetric = kmetric +1;
                        metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = pore_Tau;
                        kmetric = kmetric +1;
                        metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = pore_Bruggeman;
                        kmetric = kmetric +1;
                        metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = pore_Deff;

                        % Time
                        timedata_pervolume = [timedata_pervolume; [n_voxel (cputime-time_cpu_start_phase) toc(time_clock_start_phase)]];
                    end
                end

                kmetric = 0;
                if pMET.solid_combined_todo
                    current_phase_todo = current_phase_todo + 1;
                    for current_direction_todo = 1:number_direction_todo % Loop over all directions
                        direction = pMET.direction_todo(current_direction_todo);
                        time_cpu_start_phase = cputime; % CPU start
                        time_clock_start_phase = tic; % Stopwatch start

                        [solid_Deff,solid_Mc,solid_Tau,solid_Bruggeman,solid_eps,n_voxel] = Call_TauFactor2_solid(current_subdomain_np,current_subdomain_cond,direction);

                        kmetric = kmetric +1;
                        metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = solid_Tau;
                        kmetric = kmetric +1;
                        metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = solid_Bruggeman;
                        kmetric = kmetric +1;
                        metric(kmetric).Property_eachsubdomain(subdomain_id,current_phase_todo+4) = solid_Deff;

                        % Time
                        timedata_pervolume = [timedata_pervolume; [n_voxel (cputime-time_cpu_start_phase) toc(time_clock_start_phase)]];
                    end
                end
            end

        end

        %% STATISTICAL ANALYSIS and RVE SIZE
        for kMetric=1:1:nMetric
            number_domain = metric(kMetric).number_domain;
            RVE(k_RVE).Metric(kMetric).name = pMET.metric(kMetric).name;
            [Property_subdomains_statistics, Size_RVE, Difference_convergence, Size_convergence] = RVE_statisticalanalysis(number_group_size,number_domain,GROUP_SUBDOMAIN,metric(kMetric).Property_eachsubdomain,voxel_size,pRVE,dimension);

            %% SAVE FOR CORRELATION
            if k_FOV == 0
                for k_threshold=1:1:n_threshold
                    n=0;
                    for current_domain=1:number_domain
                        n=n+1;
                        if strcmp(pMET.fct_name,'Volume fraction')
                            if kMetric==1
                                idx = current_domain;
                            else
                                idx = n;
                            end
                        elseif strcmp(pMET.fct_name,'Transport')
                            idx = current_domain;
                        end

                        if strcmp(pRVE.analysis,'Independent subvolumes')
                            if strcmp(pRVE.threshold_subs_choice,'Relative standard deviation')
                                s2 = '_relstd';
                            elseif strcmp(pRVE.threshold_subs_choice,'Standard deviation')
                                s2 = '_std';
                            elseif strcmp(pRVE.threshold_subs_choice,'Maximum - minimum')
                                s2 = '_maxmin';
                            end
                            if Size_RVE(k_threshold,current_domain,2,1)~=0
                                s1 = strrep(FOVlength_str, ' ', '');
                                str = [pMET.metric(kMetric).shortname_correlation '_RVE_' pRVE.savename '_' s1 s2 num2str(thresholds(k_threshold),'%1.2f')  ];
                                str = strrep(str, '.', 'p');
                                results_correlation(idx).(str) = Size_RVE(k_threshold,current_domain,2,1);
                            end
                            if ischar(Representativity_2ndlength_str) && Size_RVE(k_threshold,current_domain,2,2)~=0
                                s1 = strrep(Representativity_2ndlength_str, ' ', '');
                                str = [pMET.metric(kMetric).shortname_correlation '_RVE_' pRVE.savename '_' s1 s2 num2str(thresholds(k_threshold),'%1.2f')  ];
                                str = strrep(str, '.', 'p');
                                results_correlation(idx).(str) = Size_RVE(k_threshold,current_domain,2,2);
                            end

                        else
                            if strcmp(pRVE.threshold_onesub_choice,'Relative difference')
                                s2 = '_reldiff';
                            elseif strcmp(pRVE.threshold_onesub_choice,'Difference')
                                s2 = '_diff';
                            end
                            if Size_convergence(k_threshold,current_domain,2,1)~=0
                                s1 = strrep(FOVlength_str, ' ', '');
                                str = [pMET.metric(kMetric).shortname_correlation '_conv_' pRVE.savename '_' s1 s2 num2str(thresholds(k_threshold),'%1.2f')  ];
                                str = strrep(str, '.', 'p');
                                results_correlation(idx).(str) = Size_convergence(k_threshold,current_domain,2,1);
                            end
                            if ischar(Representativity_2ndlength_str) && Size_convergence(k_threshold,current_domain,2,2)~=0
                                s1 = strrep(Representativity_2ndlength_str, ' ', '');
                                str = [pMET.metric(kMetric).shortname_correlation '_conv_' pRVE.savename '_' s1 s2 num2str(thresholds(k_threshold),'%1.2f')  ];
                                str = strrep(str, '.', 'p');
                                results_correlation(idx).(str) = Size_convergence(k_threshold,current_domain,2,2);
                            end
                        end

                    end

                end
            end

            %% MANAGING RESULTS
            [Res] = RVE_tableresult(metric(kMetric).Property_eachsubdomain, Property_subdomains_statistics, Size_RVE, Difference_convergence, Size_convergence, pRVE, FOVlength_str,Representativity_2ndlength_str,infovol,pMET.metric(kMetric));
            RVE(k_RVE).Metric(kMetric).res = Res;
            if pRVE.RVEconvergence_with_FOV
                for k_threshold=1:1:n_threshold
                    for current_domain=1:number_domain
                        for ksize = 1:nsize
                            if strcmp(pRVE.analysis,'Independent subvolumes')
                                metric(kMetric).Result_RVEconv(k_FOV+1,k_threshold+1,current_domain,1,ksize) = Size_RVE(k_threshold,current_domain,1,ksize);
                                metric(kMetric).Result_RVEconv(k_FOV+1,k_threshold+1,current_domain,2,ksize) = Size_RVE(k_threshold,current_domain,2,ksize);
                                metric(kMetric).Result_RVEconv(k_FOV+1,k_threshold+1,current_domain,3,ksize) = Size_RVE(k_threshold,current_domain,3,ksize);
                            else
                                metric(kMetric).Result_RVEconv(k_FOV+1,k_threshold+1,current_domain,1,ksize) = Size_convergence(k_threshold,current_domain,1,ksize);
                                metric(kMetric).Result_RVEconv(k_FOV+1,k_threshold+1,current_domain,2,ksize) = Size_convergence(k_threshold,current_domain,2,ksize);
                                metric(kMetric).Result_RVEconv(k_FOV+1,k_threshold+1,current_domain,3,ksize) = Size_convergence(k_threshold,current_domain,3,ksize);
                            end
                        end
                    end
                end
            end

            %% TEXT DISPLAY AND SAVE RESULTS
            if k_FOV == 0
                pRVE.disp_parRVE = true;
                RVE_displayandsave(Res,RVE(k_RVE),k_RVE,pRVE,pMET.metric(kMetric),Sub_folder_RVE,opt,infovol);
            end

            %% FIGURES
            if k_FOV == 0
                parameters_figure.propertyname = pMET.metric(kMetric).name;
                parameters_figure.propertynameunit = pMET.metric(kMetric).unit;
                parameters_figure.domain_name = pMET.metric(kMetric).domain_name;
                parameters_figure.domain_color = pMET.metric(kMetric).domain_color;
                parameters_figure.RVE = pRVE;
                parameters_figure.Criterion=[pRVE.threshold_subs_val 0];
                parameters_figure.savefolder = Sub_folder_RVE;
                parameters_figure.Property_subdomains_statistics = Property_subdomains_statistics;
                parameters_figure.Property_eachsubdomain = metric(kMetric).Property_eachsubdomain;
                parameters_figure.Difference_convergence = Difference_convergence;
                parameters_figure.Size_RVE = Size_RVE;
                parameters_figure.convergence_criterion = pRVE.threshold_onesub_val;
                parameters_figure.Size_convergence = Size_convergence;
                parameters_figure.Analysis_name = {RVE(k_RVE).Representativity_analysis, Representativity_analysis_size2};
                parameters_figure.Length_name = {FOVlength_str, Representativity_2ndlength_str};
                parameters_figure.Wholevolume_size = [FOVsize REP2ndsize];
                parameters_figure.Wholevolume_results = pMET.metric(kMetric).result_initial;
                parameters_figure.infovol = infovol;
                parameters_figure.opt = opt;
                RVE_figures(parameters_figure) % Figures
            end
        end
    end

    %% CONVERGENCE ANALYSIS RESULT
    if pRVE.RVEconvergence_with_FOV
        for kMetric=1:1:nMetric
            % Table
            parameters_figure.nsize = nsize;
            parameters_figure.RVE_length_name = {FOVlength_str, Representativity_2ndlength_str};
            parameters_figure.FOV_length_name = {FOVlength_str, FOV2ndsize_lengthstr};
            parameters_figure.infovol = infovol;
            parameters_figure.thresholds = thresholds;
            parameters_figure.propertyname = pMET.metric(kMetric).name;
            parameters_figure.domain_name = pMET.metric(kMetric).domain_name;
            parameters_figure.domain_color = pMET.metric(kMetric).domain_color;
            parameters_figure.Result_RVEconv = metric(kMetric).Result_RVEconv;
            parameters_figure.length_FOV = length_FOV;
            parameters_figure.opt = opt;
            parameters_figure.Sub_folder_RVE = Sub_folder_RVE;
            %[RVE(k_RVE).Metric(kMetric).res] = RVE_convergence_Table(parameters_figure ,RVE(k_RVE).Metric(kMetric).res);

            % Figure
            parameters_figure.Result_RVEconv = metric(kMetric).Result_RVEconv;
            RVE_convergence_figures(parameters_figure) % Figures
            % Save
            RVE(k_RVE).Metric(kMetric).res.RVEconvergence = metric(kMetric).Result_RVEconv;
            RVE(k_RVE).Metric(kMetric).res.length_FOV = length_FOV;

        end
    end

end

results_main.RVE = RVE; % Save in main table result

end