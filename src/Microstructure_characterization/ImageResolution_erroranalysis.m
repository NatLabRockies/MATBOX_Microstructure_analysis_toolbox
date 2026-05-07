function [results_main, results_correlation, timedata_perphase, timedata_pervolume] = ImageResolution_erroranalysis(pMET,Msem,Nanoporosity,Wetting,Diffusivity,Conductivity,Mins,voxel_size, scaling, Current_folder, opt, infovol, results_main, results_correlation, timedata_perphase, timedata_pervolume)

% For new metric:
% Change ImageResolution_erroranalysis on 4 locations: calculation (1), extrapolation (2), fractal dimension (1)
% Do not change any other files

fprintf('> Image resolution analysis:\n\n');

size_choice = scaling;
size_choice = sort(size_choice);
number_resize = length(size_choice); % Number of different voxel size that will be analyzed

nMetric = length(pMET.metric);

if isempty(Mins)
    sz = size(Msem);
else
    sz = size(Mins);
end
dimension = length(sz);
if dimension == 2
    sz(3)=1;
end

Current_folder = fullfile(Current_folder,'ImRes');
if exist(Current_folder,'dir')==0 % Folder existence is checked, and created if necessary
    mkdir(Current_folder);
end

%% CALCULATION
% Initialization
for kMetric = 1:nMetric
    number_domain = length(pMET.metric(kMetric).result_initial);
    metric(kMetric).property_voxelsizedependence = zeros(number_resize+1,number_domain+1);
    metric(kMetric).property_voxelsizedependence(1,1)=voxel_size;
    metric(kMetric).property_voxelsizedependence(1,2:end)=pMET.metric(kMetric).result_initial;
end

% Loop on each voxel size
for current_iteration=1:number_resize

    % % Microstructure scaling
    % New voxel size
    for kMetric = 1:nMetric
        metric(kMetric).property_voxelsizedependence(current_iteration+1,1)=size_choice(current_iteration)*voxel_size;
    end
    % Set parameters
    parameters_scaling.scaling_factor = size_choice(current_iteration);

    % Scale
    if ~isempty(Msem)
        parameters_scaling.label_or_greylevel = 'Label';
        parameters_scaling.background = min(infovol.phaselabel_semantic);
        Mlabel_resized = function_scaling(Msem,parameters_scaling);
        sz = size(Mlabel_resized);

        if strcmp(infovol.nanoporosity_representation,'Mixed (heterogeneous)')
            parameters_scaling.label_or_greylevel = 'Grey level';
            if parameters_scaling.scaling_factor<=1
                Nanoporosity_resized = function_scaling(Nanoporosity,parameters_scaling);
            else
                [~,Nanoporosity_resized] = function_downscaling_perlabel(Msem,Nanoporosity,parameters_scaling);
            end
        else
            Nanoporosity_resized = zeros(sz,'single')-1;
            if infovol.isbackground
                k0 = 2;
            else
                k0 = 1;
            end
            for k=k0:length(infovol.phaselabel_semantic)
                Nanoporosity_resized(Mlabel_resized==infovol.phaselabel_semantic(k)) = cell2mat(infovol.nanoporosity(k));
            end
        end

        if strcmp(infovol.wetting_representation,'Mixed (heterogeneous)')
            parameters_scaling.label_or_greylevel = 'Grey level';
            if parameters_scaling.scaling_factor<=1
                wetting_resized = function_scaling(Wetting,parameters_scaling);
            else
                [~,wetting_resized] = function_downscaling_perlabel(Msem,Wetting,parameters_scaling);
            end
        else
            wetting_resized = zeros(sz,'single')-1;
            if infovol.isbackground
                k0 = 2;
            else
                k0 = 1;
            end
            for k=k0:length(infovol.phaselabel_semantic)
                if ~ischar(cell2mat(infovol.air_saturation(k)))
                    if strcmp(infovol.wetting_input_is,'Air saturation') % Convert to wetting
                        wetting_resized(M_semantic==infovol.phaselabel_semantic(k)) = 1-cell2mat(infovol.air_saturation(k));
                    else
                        wetting_resized(M_semantic==infovol.phaselabel_semantic(k)) = cell2mat(infovol.wetting(k));
                    end
                end
            end
        end
        wetting_resized(Nanoporosity_resized==0)=0;

        if ~isempty(Diffusivity)
            if strcmp(infovol.poretransport_representation,'Diffusivity D (heterogeneous)')
                parameters_scaling.label_or_greylevel = 'Grey level';
                if parameters_scaling.scaling_factor<=1
                    Diffusivity_resized = function_scaling(Diffusivity,parameters_scaling);
                else
                    [~,Diffusivity_resized] = function_downscaling_perlabel(Msem,Diffusivity,parameters_scaling);
                end
            else
                Diffusivity_resized = zeros(sz,'single')-1;
                if infovol.isbackground
                    k0 = 2;
                else
                    k0 = 1;
                end
                for k=k0:length(infovol.phaselabel_semantic)
                    if ~ischar(cell2mat(infovol.poretransport(k)))
                        Diffusivity_resized(Mlabel_resized==infovol.phaselabel_semantic(k)) = cell2mat(infovol.poretransport(k));
                    end
                end
                if strcmp(infovol.poretransport_representation,'Bruggeman exponent p (uniform)') % Need to convert into diffusivity
                    Diffusivity_resized = (Nanoporosity_resized.*wetting_resized).^Diffusivity_resized;
                end                
            end
            Diffusivity_resized(isinf(Diffusivity_resized))=0;
            Diffusivity_resized(isnan(Diffusivity_resized))=0;
            Diffusivity_resized(Diffusivity_resized<0)=0;
            Diffusivity_resized(Diffusivity_resized>1)=1;
        end

        if ~isempty(Conductivity)
            if strcmp(infovol.solidtransport_representation,'Conductivity K (heterogeneous)')
                parameters_scaling.label_or_greylevel = 'Grey level';
                if parameters_scaling.scaling_factor<=1
                    Conductivity_resized = function_scaling(M_bulkconductivity,parameters_scaling);
                else
                    [~,Conductivity_resized] = function_downscaling_perlabel(Msem,Conductivity,parameters_scaling);
                end
            else
                Conductivity_resized = zeros(sz,'single')-1;
                if infovol.isbackground
                    k0 = 2;
                else
                    k0 = 1;
                end
                for k=k0:length(infovol.phaselabel_semantic)
                    if ~ischar(cell2mat(infovol.solidtransport(k)))
                        Conductivity_resized(Mlabel_resized==infovol.phaselabel_semantic(k)) = cell2mat(infovol.solidtransport(k));
                    end
                end
                if strcmp(infovol.solidtransport_representation,'Bruggeman exponent p (uniform)') % Need to convert into diffusivity
                    Conductivity_resized = (1-Nanoporosity_resized).^Conductivity_resized;
                end                
            end
            Conductivity_resized(isinf(Conductivity_resized))=0;
            Conductivity_resized(isnan(Conductivity_resized))=0;
            Conductivity_resized(Conductivity_resized<0)=0;
            Conductivity_resized(Conductivity_resized>1)=1;            
        end  

    end
    if ~isempty(Mins)
        parameters_scaling.label_or_greylevel = 'Label';
        parameters_scaling.background = min(infovol.phaselabel_instance);
        Mlabel_resized = function_scaling(Mins,parameters_scaling);
        sz = size(Mlabel_resized);

        Nanoporosity_resized = [];
        wetting_resized = [];
    end

    % CPU and stopwatch time - start
    time_cpu_start_volume = cputime; % CPU start
    time_clock_start_volume = tic; % Stopwatch start
    voxel_number = prod(sz); % Number of voxel

    % % Algorithm: SPECIFIC FOR EACH FILE
    if strcmp(pMET.fct_name,'Volume fraction')
        % Background
        n_voxel_background = 0;
        if infovol.isbackground
            background_label = infovol.phaselabel(1);
            n_voxel_background = sum(sum(sum(Mlabel_resized==background_label)));
        end
        n_voxel = voxel_number - n_voxel_background;

        if nMetric==2 % p.combined_todo==1: [vf_solid, vf_pore, vf_liquid, vf_gas, vf_AM]
            nvoxel.AM = 0;
            nvoxel.solid = 0;
            nvoxel.pore = 0;
            nvoxel.liquid = 0;
            nvoxel.gas = 0;
        end

        % Volume fraction label-wise
        number_domain = length(pMET.metric(1).result_initial);
        for current_domain=1:number_domain % Loop over all phases
            time_cpu_start_phase = cputime; % CPU start
            time_clock_start_phase = tic; % Stopwatch start
            [~,vf,~,n] = Charact_Volumefractions_algorithm(Mlabel_resized, pMET.metric(1).domain_label(current_domain), n_voxel, Nanoporosity_resized, wetting_resized, infovol.activematerial_identification);
            metric(1).property_voxelsizedependence(current_iteration+1,current_domain+1) = vf.label;
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
            vf_AM = nvoxel.AM/n_voxel;
            vf_solid = nvoxel.solid/n_voxel;
            vf_pore = nvoxel.pore/n_voxel;
            vf_liquid = nvoxel.liquid/n_voxel;
            vf_gas = nvoxel.gas/n_voxel;
            metric(2).property_voxelsizedependence(current_iteration+1,2:end) = [vf_solid vf_pore vf_liquid vf_gas vf_AM];
        end

        % CPU and stopwatch time - end
        timedata_pervolume = [timedata_pervolume; [voxel_number (cputime-time_cpu_start_volume) toc(time_clock_start_volume)]];

    elseif strcmp(pMET.fct_name,'Transport')

        number_direction_todo = length(pMET.direction_todo);
        kmetric = 0;
        current_phase_todo = 0;
        if sum(pMET.phases_todo)>0
            number_phase_todo = sum(pMET.phases_todo);
            for current_phase_todo=1:number_phase_todo % Loop over all phases
                label = pMET.phaselabel_todo(current_phase_todo);
                nvoxel = sum(sum(sum( Mlabel_resized==label )));
                for current_direction_todo = 1:number_direction_todo % Loop over all directions
                    time_cpu_start_phase = cputime; % CPU start
                    time_clock_start_phase = tic; % Stopwatch start
                    
                    direction = pMET.direction_todo(current_direction_todo);
                    
                    % % Algorithm
                    [Deff,Mc,Tau,Bruggeman,eps] = Call_TauFactor2_binary(Mlabel_resized,direction,label);

                    kmetric = kmetric +1;
                    metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = Tau;
                    kmetric = kmetric +1;
                    metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = Bruggeman;
                    kmetric = kmetric +1;
                    metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = Deff;                    
                    
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

                [pore_Deff,pore_Mc,pore_Tau,pore_Bruggeman,pore_eps,n_voxel] = Call_TauFactor2_pore(Nanoporosity_resized,wetting_resized,Diffusivity_resized,direction);

                kmetric = kmetric +1;
                metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = pore_Tau;
                kmetric = kmetric +1;
                metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = pore_Bruggeman;
                kmetric = kmetric +1;
                metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = pore_Deff;
                
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

                [solid_Deff,solid_Mc,solid_Tau,solid_Bruggeman,solid_eps,n_voxel] = Call_TauFactor2_solid(Nanoporosity_resized,Conductivity_resized,direction);


                kmetric = kmetric +1;
                metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = solid_Tau;
                kmetric = kmetric +1;
                metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = solid_Bruggeman;
                kmetric = kmetric +1;
                metric(kmetric).property_voxelsizedependence(current_iteration+1,current_phase_todo+1) = solid_Deff;

                % Time
                timedata_pervolume = [timedata_pervolume; [n_voxel (cputime-time_cpu_start_phase) toc(time_clock_start_phase)]];
            end
        end
    end


end

% Sort per voxel size
for kMetric = 1:nMetric
    metric(kMetric).property_voxelsizedependence = sortrows(metric(kMetric).property_voxelsizedependence,1);
end

%% EXTRAPOLATION TO 0 nm
if ~strcmp(pMET.metric(1).scaling_extrapolation,'None')
    interpolation_voxelsize_order = zeros(nMetric,1);
    n=0;
    for kMetric = 1:nMetric
        scaling_extrapolation = pMET.metric(kMetric).scaling_extrapolation;
        number_domain = length(pMET.metric(kMetric).result_initial);

        tmp = zeros(number_resize+2,number_domain+1); % + 0 nm and + initial voxel size
        x = metric(kMetric).property_voxelsizedependence(:,1);
        max_order = length(scaling)-1;

        if strcmp(scaling_extrapolation,'Best')

        else
            if strcmp(scaling_extrapolation,'Linear')
                interpolation_voxelsize_order(kMetric)=1;
            elseif strcmp(scaling_extrapolation,'Quadratic')
                interpolation_voxelsize_order(kMetric)=2;
            elseif strcmp(scaling_extrapolation,'Cubic')
                interpolation_voxelsize_order(kMetric)=3;
            end
            interpolation_voxelsize_order(kMetric) = min(interpolation_voxelsize_order(kMetric),max_order);
            % fprintf('  %s: extrapolation to zero voxel size: polynomial of order %i\n\n',pMET.metric(kMetric).name,interpolation_voxelsize_order);
            for current_domain=1:1:number_domain
                n=n+1;
                y = metric(kMetric).property_voxelsizedependence(:,current_domain+1);
                pi = polyfit(x,y,interpolation_voxelsize_order(kMetric));
                vq = polyval(pi,0);
                tmp(1,current_domain+1)=vq;

                if strcmp(pMET.fct_name,'Volume fraction')
                    if kMetric==1
                        idx = current_domain;
                    else
                        idx = n;
                    end
                elseif strcmp(pMET.fct_name,'Transport')
                    idx = current_domain;
                end

                results_correlation(idx).([pMET.metric(kMetric).shortname_correlation '_extrapolated']) = vq;
                interpolation_voxelsize(kMetric).domain(current_domain).pi=pi;
            end
        end
        tmp(2:end,:) = metric(kMetric).property_voxelsizedependence;
        metric(kMetric).property_voxelsizedependence = tmp; clear tmp;
    end
end

%% FRACTAL DIMENSION
if pMET.fractal_bertei
    resolution = metric(1).property_voxelsizedependence(:,1);
    n=0;
    for kMetric = 1:nMetric
        number_domain = length(pMET.metric(kMetric).result_initial);
        metric(kMetric).fractal_dimension = zeros(number_domain,1);
        metric(kMetric).fractal_propensity = zeros(number_domain,1);
        if strcmp(pMET.fct_name,'Volume fraction')
            metric(kMetric).topology_dimension = ones(number_domain,1)*dimension;
        elseif strcmp(pMET.fct_name,'Transport')
            metric(kMetric).topology_dimension = ones(number_domain,1)*dimension;
        end
        for current_domain=1:number_domain
            n=n+1;
            values = metric(kMetric).property_voxelsizedependence(:,current_domain+1);
            [metric(kMetric).fractal_dimension(current_domain), metric(kMetric).fractal_propensity(current_domain), metric(kMetric).logs(current_domain).vals] = RichardsonMandelbrot_fractaldimension(metric(kMetric).topology_dimension(1),resolution,values);

            if strcmp(pMET.fct_name,'Volume fraction')
                if kMetric==1
                    idx = current_domain;
                else
                    idx = n;
                end
            end

            results_correlation(idx).([pMET.metric(kMetric).shortname_correlation '_fractaldimension']) = metric(kMetric).fractal_dimension(current_domain);
            results_correlation(idx).([pMET.metric(kMetric).shortname_correlation '_fractalpropensity']) = metric(kMetric).fractal_propensity(current_domain);
        end
    end
end

%% MANAGING RESULTS
for kMetric = 1:nMetric
    number_domain = length(pMET.metric(kMetric).result_initial);
    Variable_name_table={['Voxel size ' infovol.unit]}; % Columns name
    for current_domain=1:number_domain
        Variable_name_table(1+current_domain) = pMET.metric(kMetric).domain_name(current_domain);
    end
    voxelsizedependence(kMetric).table = array2table(metric(kMetric).property_voxelsizedependence,'VariableNames',Variable_name_table);

    if pMET.fractal_bertei
        % Variable_name_table={'Voxel size log'}; % Columns name
        % tmp = [];
        % for current_domain=1:number_domain
        %     Variable_name_table(1+current_domain) = {[char(pMET.metric(kMetric).domain_name(current_domain)) ' log']};
        %     tmp = [tmp metric(kMetric).logs(current_domain).vals(:,2)];
        % end
        %voxelsizedependence(kMetric).table_log = array2table([metric(kMetric).logs(current_domain).vals(:,1) tmp],'VariableNames',Variable_name_table);
        fractaldimension(kMetric).Table = table(pMET.metric(kMetric).domain_name,metric(kMetric).fractal_dimension,metric(kMetric).topology_dimension,metric(kMetric).fractal_propensity,...
            'VariableNames',{'Phase','Fractal dimension','Topology dimension','Fractal propensity'});
    end
end

%% DISPLAY TEXT RESULTS
for kMetric = 1:nMetric
    scaling_extrapolation = pMET.metric(kMetric).scaling_extrapolation;
    if strcmp(scaling_extrapolation,'None')
        fprintf('  %s\n\n',pMET.metric(kMetric).name);
    else
        fprintf('  %s: extrapolation to zero voxel size: polynomial of order %i\n\n',pMET.metric(kMetric).name,interpolation_voxelsize_order(kMetric));
    end
    voxelsizedependence(kMetric).name = pMET.metric(kMetric).name;
    disp(voxelsizedependence(kMetric).table)
    if pMET.fractal_bertei
        %disp(voxelsizedependence(kMetric).table_log)
        str = ['    Richardson/Mandelbrot formula: Log(property) = m + (' num2str(metric(kMetric).topology_dimension(1)) '-fractal dimension)*log(voxel size))'];
        disp(str);
        fractaldimension(kMetric).name = pMET.metric(kMetric).name;
        disp(fractaldimension(kMetric).Table)
    end
end

%% SAVE RESULTS
results_main.voxelsizedependence = voxelsizedependence; % Save in main table result
if pMET.fractal_bertei
    results_main.fractaldimension = fractaldimension;
end

if opt.save.xls
    for kMetric = 1:nMetric
        filename = [pMET.metric(kMetric).filename '_voxelsize_dependence']; % Filename without extension
        % Prepare the data
        clear DATA_writetable
        DATA_writetable.sheet(1).name=pMET.metric(kMetric).name;
        DATA_writetable.sheet(1).table=voxelsizedependence(kMetric).table;
        if pMET.fractal_bertei
            %DATA_writetable.sheet(2).name='Log log';
            %DATA_writetable.sheet(2).table=voxelsizedependence(kMetric).table_log;
            DATA_writetable.sheet(2).name='Fractal dimension Mandelbrot';
            DATA_writetable.sheet(2).table=fractaldimension(kMetric).Table;
        end
        % Save function
        Function_Writetable(Current_folder,filename,DATA_writetable)
    end
end

%% FIGURES
for kMetric = 1:nMetric
    parameters_figure.inputfilename = pMET.inputfilename;
    parameters_figure.propertyname = pMET.metric(kMetric).name;
    parameters_figure.propertynameunit = pMET.metric(kMetric).unit;
    parameters_figure.method = [];
    parameters_figure.property_voxelsizedependence = metric(kMetric).property_voxelsizedependence;
    parameters_figure.domain_name = pMET.metric(kMetric).domain_name;
    parameters_figure.domain_color = pMET.metric(kMetric).domain_color;
    parameters_figure.ylabel = pMET.metric(kMetric).name;
    
    scaling_extrapolation = pMET.metric(kMetric).scaling_extrapolation;
    if ~strcmp(scaling_extrapolation,'None')
        parameters_figure.interpolation_voxelsize = interpolation_voxelsize(kMetric);
    else
        parameters_figure.interpolation_voxelsize = [];
    end
    parameters_figure.Current_folder = Current_folder;
    parameters_figure.filename = [pMET.metric(kMetric).filename '_voxelsize_dependence'];
    parameters_figure.infovol = infovol;
    parameters_figure.opt = opt;
    ImageResolution_erroranalysis_figures(parameters_figure) % Figures
end

end