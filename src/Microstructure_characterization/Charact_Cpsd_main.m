function [] = Charact_Cpsd_main(M,infovol,opt,p,Mins)
% Calculate Particle size with a spherical assumption (C-PSD)
%   Method is detailed in L.D. Gelb and K. E. Gubbins, Langmuir, 15, 2, 1998, at https://doi.org/10.1021/la9808418
% Charact_Cpsd_main(M,infovol,opt,p,Mins) - when use with the toolbox
% or
% Charact_Cpsd_main(M, labels, voxelsize, unit) - when use as a standalone function
% with: M, a 3D or 2D array: the segmented volume or image
%       labels: either 'All' (all phased are characterized) or a 1D array listing the labels to characterize
%       voxelsize, a scalar: the voxel length
%       unit, a string: the unit name of the voxel length
%       e.g.: Charact_Cpsd_main(<your_3d_array>, [1], 0.4, 'um');
%       e.g.: Charact_Cpsd_main(<your_3d_array>, [0, 1, 2], 0.4, 'um');
%       e.g.: Charact_Cpsd_main(<your_3d_array>, 'All' , 0.4, 'um');

%% DEFAULT VALUES
expected_number_argument = 5;
nargin; % Number of input variable when the function is call

if nargin ~= expected_number_argument % Unexpected number of argument
    
    if nargin == 4 % Case for function called as: Function_particle_size_CPSD(Phase_microstructure, labels, voxelsize, unit)
        labels = infovol; clear infovol;
        voxelsize = opt; clear opt;
        unit = p; clear p;
               
        % Set default folder
        t = datetime('now','TimeZone','local','Format','d_MMM_y_HH_mm_ss'); % Set unique folder based on time, with second precision
        infovol.volumesubfolder = ['DiameterCpsd_' char(t)];
        if ispc
            infovol.mainfolder=winqueryreg('HKEY_CURRENT_USER', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', 'Desktop'); % Find desktop folder of windows user
            separator = '\';
        else
            infovol.mainfolder = pwd;
            separator = '/';
        end
        infovol.volpath = [infovol.mainfolder separator infovol.volumesubfolder separator];    

        % Set default phase information
        allcolor=[get(0, 'DefaultAxesColorOrder'); rand(100,3);];
        infovol.phaselabel = unique(Phase_microstructure);
        for k=1:1:length(infovol.phaselabel) % Loop over all unique values
            infovol.phasename(k,1) = {['Phase ' num2str(infovol.phaselabel(k))]}; % Assign phase name based on code value
            infovol.phasecolor(k,:) = allcolor(k,:);
            if isnumeric(labels)
                if ismember(infovol.phaselabel(k),labels)
                    p.todo(k)=1;
                else
                    p.todo(k)=0;
                end
            elseif strcmp(labels,'All')
                p.todo(k)=1;
            else
                disp 'Error calling Function_particle_size_CPSD. Incorrect labels argument.'
                help Function_particle_size_CPSD
                return
            end
        end
        if ~sum(p.todo)
            disp 'Error calling Function_particle_size_CPSD. Labels argument correspond to no existing label.'
            help Function_particle_size_CPSD
            return
        end

        infovol.voxelsize = voxelsize;
        infovol.unit = unit;
        
        % Set default direction information
        infovol.directionname = {'in-plane direction 1';'in-plane direction 2';'through-plane direction'};
        
        % Set default options
        opt.save.mat = true;
        opt.save.xls = true;
        opt.save.savefig = true;
        opt.save.fig_infig = true;
        opt.save.fig_format = {'png'};
        
        % Set display options
        opt.format.fontname = 'Times New Roman';
        opt.format.axefontsize =  12;
        opt.format.legendfontsize =  10;
        opt.format.titlefontsize =  14;
        opt.format.sgtitlefontsize =  16;
        opt.format.linewidth = 2;
        opt.format.grid = 'on'; opt.format.minorgrid = 'on';
        opt.format.autoclosefig = false;

        % Set default colormap
        p.colormap = 'turbo';
        p.colormap_background = 'white';
        
        % No Voxel size dependence analysis
        p.scaling = 1;
        % No Representative Volume Element analysis
        p.RVE.number_RVE = 0;
        
    else % Incorrect number of argument
        disp 'Error calling Function_particle_size_CPSD. Wrong number of argument.'
        help Function_particle_size_CPSD
        return
    end
    
end


%% DATE
date_start = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss Z');

%% FOLDER
Current_folder = fullfile(infovol.volpath,'Diameter_Cpsd',infovol.sub);
if ~exist(Current_folder,'dir') % Folder existence is checked, and created if necessary
    mkdir(Current_folder);
end

%% VOLUME INFORMATION
Domain_size = size(Phase_microstructure);
if length(Domain_size)==2 % Add third column with unit value
    Domain_size = [Domain_size 1];
    number_dimension = 2;
else
    number_dimension =3; % 3D case
end
number_phase = length(infovol.phaselabel); % Number of phase
voxel_number = prod(Domain_size); % Number of voxel
voxel_size = infovol.voxelsize;
voxel_unit = infovol.unit;

%% INITIALIZE RESULTS (USE FOR CORRELATION and VISUALIZATION)
current_phase_todo = 0;

L = length(p.todo);
if L < number_phase
    p.todo = [p.todo; ones(number_phase-L)];
elseif L > number_phase
    p.todo = p.todo(1:number_phase);
end

if infovol.isbackground
    p.todo(1) = 0;
end

for current_phase=1:1:number_phase
    if p.todo(current_phase)
        current_phase_todo=current_phase_todo+1;
        results_correlation(current_phase_todo).name = infovol.phasename(current_phase,1);
        results_visualization(current_phase_todo).name = infovol.phasename(current_phase,1);
    end
end

%% REMOVE TRUNCATED INSTANCES 

if isfield(p,'removetruncatedparticles') && p.removetruncatedparticles && ~isempty(Mins)
    if infovol.isbackground
        BW = zeros(Domain_size);
        BW(Mins==0)=1;
        tmp = ones(Domain_size+2);
        if number_dimension == 2
            tmp(2:end-1,2:end-1) = BW;
        else
            tmp(2:end-1,2:end-1,2:end-1) = BW;
        end
        dmap = bwdist(tmp,'chessboard');
        if number_dimension == 2
            attheborders = unique(Mins(dmap(2:end-1,2:end-1)==1));
        else
            attheborders = unique(Mins( dmap(2:end-1,2:end-1,2:end-1)==1 ));
        end
    else
        x0 = unique(Mins(1,:,:));
        x1 = unique(Mins(end,:,:));
        y0 = unique(Mins(:,1,:));
        y1 = unique(Mins(:,end,:));
        z0 = unique(Mins(:,:,1));
        z1 = unique(Mins(:,:,end));
        attheborders = unique([x0;x1;y0;y1;z0;z1]);
    end

    if ~isempty(attheborders)
        for k=1:1:length(attheborders)
            if infovol.isbackground
                Phase_microstructure(Mins==attheborders(k))=1;
            else
                Phase_microstructure(Mins==attheborders(k))=0;
            end
        end
    end
end


%% PARAMETERS
% Note: those are not algorithm paramter (c-PSD is parameter free), but post-processing smoothing parameter to get a better looking distribution function

% Cumulative and distribution functions parameters
density_fct_parameters.round_value = 3;
density_fct_parameters.smooth_cumulative_fct = true;

%%
%% ALGORITHM ON WHOLE VOLUME
%%

%% CALCULATION

roundingCPDS = true; % Faster, minimal loss of precision

time_cpu_start_volume = cputime; % CPU start
time_clock_start_volume = tic; % Stopwatch start
if infovol.isbackground && p.symmetry
    psym.Background = zeros(Domain_size);
    idx_background = find(Phase_microstructure == 0);
    psym.Background(idx_background)=1;
    psym.perslice = false;
    Phase_microstructure_initial = Phase_microstructure;
    [Phase_microstructure] = fct_symmetry(Phase_microstructure,psym);
end

% Initialization (generic)
number_phase_todo = sum(p.todo); % How many phase are we going to analyse ?
Numbervoxel_phase=zeros(number_phase_todo,1); 
timedata = zeros(number_phase_todo+1,3); timedata(1,1) = voxel_number;
timedata_domain = cell(number_phase_todo+1,1);
phasename_todo = cell(number_phase_todo,1);
phaselabel = zeros(number_phase_todo,1);
% Initialization (algorithm-specific)
PSD_results = zeros(number_phase_todo,5); % min, mean, max, std, std%
Particle_lvl_description = zeros(number_phase_todo,1);

current_phase_todo = 0;
for current_phase=1:1:number_phase % Loop over all phases
    if p.todo(current_phase)
        time_cpu_start_phase = cputime; % CPU start
        time_clock_start_phase = tic; % Stopwatch start

        current_phase_todo=current_phase_todo+1;
        phasename_todo(current_phase_todo,1) = infovol.phasename(current_phase,1);
        Numbervoxel_phase(current_phase_todo,1)= sum(sum(sum(Phase_microstructure==phaselabel(current_phase_todo,1) )));

        % % Algorithm
        phaselabel(current_phase_todo,1) = infovol.phaselabel(current_phase);
        % Create a binary microstructure : 1 = current analysed phase, 0 = complementay phase
        binary_phase=zeros(Domain_size); % Initialization
        binary_phase(Phase_microstructure == phaselabel(current_phase_todo,1)) = 1; % Binary phase
        [Particle_size, ~, ~] = Function_particle_size_CPSD_Algorithm(binary_phase,roundingCPDS); % Call algorithm
        if infovol.isbackground && p.symmetry
            binary_phase(idx_background) = 0;
            Particle_size(idx_background) = 0;
        end

        % Particle level description 1- (number of voxels that belong to particles
        % of size <= sqrt(3) normalized with the number of voxel of the phase).
        % The higher the better.
        Particle_lvl_description(current_phase_todo,1) = 1 - (sum(sum(sum( logical(double(binary_phase==1) .* double(Particle_size<=sqrt(3))) )))) / (sum(sum(sum(binary_phase==1))));
        % Statistics
        Particle_size = Particle_size*voxel_size;
        all_diameters = Particle_size(binary_phase==1);
        PSD_results(current_phase_todo,1) = min(all_diameters); % Minimum
        PSD_results(current_phase_todo,2) = mean(all_diameters);% Mean
        PSD_results(current_phase_todo,3) = max(all_diameters); % Maximum
        PSD_results(current_phase_todo,4) = std(all_diameters); % Standard deviation
        PSD_results(current_phase_todo,5) = 100*PSD_results(current_phase_todo,4)/PSD_results(current_phase_todo,2); % Relative standard deviation
        % Cumulative and probability density distribution functions
        [PSD(current_phase_todo).psd, ~] = Function_probability_density(all_diameters,[],density_fct_parameters);
        PSD_results(current_phase_todo,6) = PSD(current_phase_todo).psd.x50; % d50
        PSD_results(current_phase_todo,7) = PSD(current_phase_todo).psd.smoothed_x50; % smoothed d50
        PSD_results(current_phase_todo,8) = PSD(current_phase_todo).psd.integral_probability_density_fct;
        PSD_results(current_phase_todo,9) = PSD(current_phase_todo).psd.integral_smoothed_probability_density_fct;

        % % correlation
        results_correlation(current_phase_todo).Particle_diameter_mean_CPSD = PSD_results(current_phase_todo,2);
        results_correlation(current_phase_todo).Particle_diameter_std_CPSD = PSD_results(current_phase_todo,4);
        results_correlation(current_phase_todo).Particle_diameter_relstd_CPSD = PSD_results(current_phase_todo,5);
        %results_correlation(current_phase_todo).Particle_radius_mean_CPSD = PSD_results(current_phase_todo,2)/2; % Example on how to add new correlation
        results_correlation(current_phase_todo).Particle_level_details = Particle_lvl_description(current_phase_todo,1);

        % % Visualization
        results_visualization(current_phase_todo).Particle_diameter_CPSD = Particle_size;
        %results_visualization(current_phase_todo).Particle_radius_CPSD = Particle_size/2; % Example on how to add new visualization

        % % Time
        timedata_domain(current_phase_todo+1,1) = infovol.phasename(current_phase,1);
        timedata(current_phase_todo+1,1) = Numbervoxel_phase(current_phase_todo,1);
        timedata(current_phase_todo+1,2) = cputime-time_cpu_start_phase; % CPU elapsed time
        timedata(current_phase_todo+1,3) = toc(time_clock_start_phase); % CPU elapsed time        
    end
end
% CPU and stopwatch time - end
timedata_domain(1,1) = {'Full volume'};
timedata(1,2) = cputime-time_cpu_start_volume; % CPU elapsed time
timedata(1,3) = toc(time_clock_start_volume); % Stopwatch elapsed time
timedata_pervolume = timedata(1,:);
timedata_perphase = timedata(2:end,:);

%% TABLES
% Time
Table_time = table(timedata_domain(:,1), timedata(:,1),timedata(:,2),timedata(:,3),...
    'VariableNames',{'Domain', 'Number of voxel','CPU time s' 'Stopwatch s'});
Results_cpsd.Table_time = Table_time; % Save in main table result

% Result calculated on whole volume
Table_cpsd = table(phasename_todo,phaselabel,PSD_results(:,1),PSD_results(:,2),PSD_results(:,3),PSD_results(:,4),PSD_results(:,5),...
    'VariableNames',{'Phase' 'Label' ['Min ' voxel_unit] ['Mean ' voxel_unit] ['Max ' voxel_unit] ['Std ' voxel_unit] 'Std %'});
Results_cpsd.Table_cpsd = Table_cpsd; % Save in main table result

Table_cpsd_d50 = table(phasename_todo, phaselabel,PSD_results(:,6),PSD_results(:,7),PSD_results(:,8),PSD_results(:,9),...
    'VariableNames',{'Phase' 'Label' ['d50 (from distribution fct) ' voxel_unit] ['Smoothed d50 ' voxel_unit] 'Distribution integral' 'Smoothed distribution integral'});
Table_cpsd_lvldetail = table(phasename_todo, phaselabel,Particle_lvl_description(:,1),...
    'VariableNames',{'Phase' 'Label' 'Particle_level_detail ([0 1])'});
%Table_radius = table(phasename_todo, phaselabel,PSD_results(:,1)/2,PSD_results(:,2)/2,PSD_results(:,3)/2,PSD_results(:,4)/2,PSD_results(:,5),...
%   'VariableNames',{'Phase' 'Label' ['Min ' voxel_unit] ['Mean ' voxel_unit] ['Max ' voxel_unit] ['Std ' voxel_unit] 'Std %'}); % Example

for current_phase_todo=1:1:number_phase_todo
    array_tmp(:,1) = PSD(current_phase_todo).psd.cumulative_fct(:,1);
    array_tmp(:,2) = PSD(current_phase_todo).psd.cumulative_fct(:,2);
    array_tmp(:,3) = PSD(current_phase_todo).psd.probability_density_fct(:,2);
    if ~isempty(PSD(current_phase_todo).psd.smoothed_cumulative_fct)
        array_tmp(:,4) = PSD(current_phase_todo).psd.smoothed_cumulative_fct(:,1);
        array_tmp(:,5) = PSD(current_phase_todo).psd.smoothed_cumulative_fct(:,2);
        array_tmp(:,6) = PSD(current_phase_todo).psd.smoothed_probability_density_fct(:,2);
        Variable_name_table={['Diameter ' voxel_unit] 'Cumulative function' 'Probability density distribution function' ['Diameter (smoothed) ' voxel_unit] 'Cumulative function smoothed' 'Probability density function smoothed'};
    else
        Variable_name_table={['Diameter ' voxel_unit] 'Cumulative function' 'Probability density distribution function'};
    end
    Table_cumulative_sizedistribution.phase(current_phase_todo).table = array2table(array_tmp,...
        'VariableNames',Variable_name_table);
    clear array_tmp
end

Results_cpsd.Table_cpsd = Table_cpsd; % Save in main table result
%Results_cpsd.Table_radius = Table_radius; % Save in main table result (example)
Results_cpsd.Table_cpsd_d50 = Table_cpsd_d50;
Results_cpsd.Table_cpsd_lvldetail = Table_cpsd_lvldetail;
Results_cpsd.Table_cumulative_sizedistribution = Table_cumulative_sizedistribution; 

%% SAVE TABLES
if opt.save.xls
    filename = 'Continuum_PSD'; % Filename without extension
    % Prepare the data
    clear DATA_writetable
    DATA_writetable.sheet(1).name='Results';
    DATA_writetable.sheet(1).table=Table_cpsd;
    DATA_writetable.sheet(2).name='Level details';
    DATA_writetable.sheet(2).table=Table_cpsd_lvldetail;        
    DATA_writetable.sheet(3).name='D50 from cumulativefct';
    DATA_writetable.sheet(3).table=Table_cpsd_d50;       
    % Cumulative and size distribution
    sheet_=3;
    for current_phase_todo = 1:1:number_phase_todo
        sheet_=sheet_+1;
        DATA_writetable.sheet(sheet_).name=[char(phasename_todo(current_phase_todo,1)) '_PSD'];
        DATA_writetable.sheet(sheet_).table=Table_cumulative_sizedistribution.phase(current_phase_todo).table;
    end
    % Save function
    Function_Writetable(Current_folder,filename,DATA_writetable)
end

%% DISPLAY
fprintf('> Calculated on the whole domain:\n\n');
disp 'Particle diameter';
disp(Table_cpsd)
disp 'Particle diameter (from cumulative function)';
disp(Table_cpsd_d50)
disp 'Particle level of details: 1 - number voxel phase with particle size <sqrt(3)*voxel length / number voxel phase';
disp '   [0,1]: 0=worst, 1=ideal';
disp(Table_cpsd_lvldetail)
fprintf('Computation time, in seconds:\n\n');
disp(Table_time)


%%
%% ADDITIONAL RESULTS ON THE WHOLE VOLUME 
%%
scrsz = get(0,'ScreenSize'); % Screen resolution

strunit = voxel_unit;
if strcmp(strunit,'um') || strcmp(strunit,'micrometer') || strcmp(strunit,'Micrometer') || strcmp(strunit,'micrometers') || strcmp(strunit,'Micrometers')
    axisunit = '(\mum)';
    Dunit = '\mum';
else
    axisunit = ['(' strunit ')'];
    Dunit = voxel_unit;
end

%% CUMULATIVE AND DISTRIBUTION FUNCTIONS PLOT
parameters_distributionfigure.figureposition = [100 100 1500 800];
parameters_distributionfigure.fontname = opt.format.fontname;
parameters_distributionfigure.grid = opt.format.grid;
parameters_distributionfigure.minorgrid = opt.format.minorgrid;
parameters_distributionfigure.fullpath = Current_folder;
parameters_distributionfigure.save = opt.save.savefig;
parameters_distributionfigure.subaxe1_title = 'Cumulative function';
parameters_distributionfigure.subaxe2_title = 'Distribution function';
parameters_distributionfigure.xlabel = ['Particle diameter ' axisunit];
parameters_distributionfigure.axefontsize = opt.format.axefontsize;
parameters_distributionfigure.legendfontsize = opt.format.legendfontsize;
parameters_distributionfigure.titlefontsize = opt.format.titlefontsize;
parameters_distributionfigure.sgtitlefontsize = opt.format.sgtitlefontsize;
parameters_distributionfigure.unit = Dunit;
parameters_distributionfigure.closefig = opt.format.autoclosefig;
for current_phase_todo=1:1:number_phase_todo % Loop over all phases
    parameters_distributionfigure.figurename =  ['Particle diameter, ' char(phasename_todo(current_phase_todo,1))];
    parameters_distributionfigure.filename = ['Diameter_CPSD_' char(phasename_todo(current_phase_todo,1))];
    parameters_distributionfigure.title = ['Particle diameter (C-PSD), ' char(phasename_todo(current_phase_todo,1))];
    function_probability_distribution_figure(PSD(current_phase_todo).psd,parameters_distributionfigure);
end
    
%% ALONG DIRECTIONS
% Calculate the function Diameter(x) defined as 1/L*int(Diameter(x)*dx,0,L)=d_50
% For each direction and each phase
alongdirection_parameters.number_phase = number_phase;
alongdirection_parameters.data = results_visualization;
alongdirection_parameters.field = 'Particle_diameter_CPSD';
alongdirection_parameters.number_dimension = number_dimension;
alongdirection_parameters.Domain_size = Domain_size;
alongdirection_parameters.voxel_size = voxel_size;
alongdirection_parameters.ignore_value = 0;
alongdirection_parameters.ignore_min = true;
alongdirection_parameters.Variable_name_table = {['Position ' voxel_unit] ['mean diameter ' voxel_unit] ['max diameter ' voxel_unit] ['std ' voxel_unit]};
alongdirection_parameters.infovol = infovol;
alongdirection_parameters.opt = opt;
alongdirection_parameters.phasename_todo = phasename_todo;
alongdirection_parameters.todo = p.todo;
alongdirection_parameters.Table_filename = 'Diameter_CPSD';
alongdirection_parameters.figure_name = 'Diameter CPSD';
alongdirection_parameters.axe_title = 'Particle diameter (C-PSD)';
alongdirection_parameters.figure_title = 'Particle diameter along directions (C-PSD)';
alongdirection_parameters.figure_filename = 'Diameter_CPSD_along_directions';
alongdirection_parameters.ylabel = ['Diameter ' axisunit];
alongdirection_parameters.ylabel_unit = Dunit;
alongdirection_parameters.axisunit = axisunit;
alongdirection_parameters.legendname = 'diameter';
alongdirection_parameters.mean_val = PSD_results(:,2);
alongdirection_parameters.Current_folder = Current_folder;
[Table_evolution] = Function_along_direction(alongdirection_parameters); % Call function
Results_cpsd.Table_evolution = Table_evolution; % Save in main table result

%% PARTICLE DIAMETER MAP

% Color map
%myColorMap = turbo(256);
str = ['myColorMap = ' p.colormap '(256);'];
eval(str);
if strcmp(p.colormap_background,'white')
    myColorMap(1,:) = 1; 
elseif strcmp(p.colormap_background,'black')
    myColorMap(1,:) = 0; 
elseif strcmp(p.colormap_background,'grey')
    myColorMap(1,:) = [0.75 0.75 0.75];     
end

for current_phase_todo=1:1:number_phase_todo % Loop over phases
    data_Particle_size = results_visualization(current_phase_todo).Particle_diameter_CPSD;
    Fig = figure; % Create figure
    Fig.Name= ['Particle diameter, phase ' char(phasename_todo(current_phase_todo))]; % Figure name
    Fig.Color='white'; % Background colour
    set(Fig,'position',[scrsz(1) scrsz(2) scrsz(3)*number_dimension/3 scrsz(4)*1/2]); % Full screen figure
    for current_direction=1:1:number_dimension % Iterate over axe
        sub_axes=subplot(1,number_dimension,current_direction,'Parent',Fig);
        hold(sub_axes,'on'); % Active subplot
        h_title=title ({'Slice in the middle',['View normal to ' char(infovol.directionname(current_direction))]}); % Set title font
        % - Plot graphs
        if current_direction==1
            tmp=squeeze(data_Particle_size(round(Domain_size(1)/2),:,:));
            h=image(tmp,'CDataMapping','scaled');
            t_1x = sprintf('Position along %s ',char(infovol.directionname(3)));
            t_1y = sprintf('Position along %s ',char(infovol.directionname(2)));
            set(h, 'XData', [0, Domain_size(3)*voxel_size]);
            set(h, 'YData', [0, Domain_size(2)*voxel_size]);
        elseif current_direction==2
            tmp=squeeze(data_Particle_size(:,round(Domain_size(2)/2),:));
            h=image(tmp,'CDataMapping','scaled');
            t_1x = sprintf('Position along %s ',char(infovol.directionname(3)));
            t_1y = sprintf('Position along %s ',char(infovol.directionname(1)));
            set(h, 'XData', [0, Domain_size(3)*voxel_size]);
            set(h, 'YData', [0, Domain_size(1)*voxel_size]);
        elseif current_direction==3
            h=image(data_Particle_size(:,:,round(Domain_size(3)/2)),'CDataMapping','scaled');
            t_1x = sprintf('Position along %s ',char(infovol.directionname(1)));
            t_1y = sprintf('Position along %s ',char(infovol.directionname(2)));
            set(h, 'XData', [0, Domain_size(1)*voxel_size]);
            set(h, 'YData', [0, Domain_size(2)*voxel_size]);
        end
        axis equal; axis tight;
%         x_value = get(sub_axes,'XTick');
%         set(sub_axes,'XtickLabel',x_value*voxel_size/1000);
%         y_value = get(sub_axes,'YTick');
%         set(sub_axes,'YtickLabel',y_value*voxel_size/1000);
        % - Axis label
        t_ = xlabel(' ');
        t_2 = axisunit;
        t_.String= [t_1x t_2]; % Sprintf does not accept greek characters
        t_ = ylabel(' ');
        t_2 = axisunit;
        t_.String= [t_1y t_2]; % Sprintf does not accept greek characters
        set(sub_axes,'FontName',opt.format.fontname,'FontSize',opt.format.axefontsize); % Fontname and fontsize
        colormap(myColorMap);
        % Create colorbar
        %colorbar('peer',sub_axes);
        h=colorbar(sub_axes);
        ylabel(h, ['Diameter ' axisunit]);
        set(h,'FontName',opt.format.fontname,'FontSize',opt.format.axefontsize);        
        h_title.FontSize = opt.format.titlefontsize; % Set title fontsize
        hold(sub_axes,'off'); % Relase figure
    end
    sgtitle(Fig,['Particle diameter (C-PSD), ' char(phasename_todo(current_phase_todo))],'FontWeight','bold','FontSize',opt.format.sgtitlefontsize,'FontName',opt.format.fontname);
    if opt.save.savefig % Save figure
        filename= sprintf('View_CPSD_%s', char(phasename_todo(current_phase_todo)));
        function_savefig(Fig, Current_folder, filename, opt.save); % Call function
    end
    if opt.format.autoclosefig
        close(Fig); % Do not keep open figures
    end
end


%%
%% IMAGE RESOLUTION SENSITIVITY ANALYSIS
%%

p.scaling(p.scaling==1)=[];
if ~isempty(p.scaling) % Check if voxel size analysis is asked
    size_choice = p.scaling;
    size_choice = sort(size_choice);
    number_resize=length(size_choice); % Number of different voxel size that will be analyzed
    
    %% CALCULATION
    % Initialization
    property_voxelsizedependence = zeros(number_resize+1,number_phase_todo+1,2);
    property_voxelsizedependence(1,1,:)=voxel_size;
    property_voxelsizedependence(1,2:end,1)=PSD_results(:,2)';
    property_voxelsizedependence(1,2:end,2)=Particle_lvl_description(:,1)';    

    current_phase_todo = 0;
    for current_phase=1:1:number_phase % Loop over all phases
        if p.todo(current_phase)
            current_phase_todo=current_phase_todo+1;
            PSDresized(current_phase_todo).iteration(1).voxelsize = voxel_size;
            PSDresized(current_phase_todo).iteration(1).psd = PSD(current_phase_todo).psd;
        end
    end

    % Loop on each voxel size
    for current_iteration=1:1:number_resize

        % % Microstructure scaling
        % New voxel size
        current_voxel_size = size_choice(current_iteration)*voxel_size;
        property_voxelsizedependence(current_iteration+1,1,:)=current_voxel_size;
        % Set parameters
        parameters_scaling.scaling_factor = size_choice(current_iteration);
        parameters_scaling.label_or_greylevel = 'Label';
        parameters_scaling.background = min(infovol.phaselabel);
        % Scale
        if infovol.isbackground && p.symmetry
            Phase_microstructure = Phase_microstructure_initial;
        end
        Phase_microstructure_resized = function_scaling(Phase_microstructure,parameters_scaling);
        if infovol.isbackground && p.symmetry
            psym.Background = zeros(size(Phase_microstructure_resized));
            idx_background = find(Phase_microstructure_resized == 0);
            psym.Background(idx_background)=1;
            [Phase_microstructure_resized] = fct_symmetry(Phase_microstructure_resized,psym);       
        end
        % CPU and stopwatch time - start
        time_cpu_start_volume = cputime; % CPU start
        time_clock_start_volume = tic; % Stopwatch start
        % Number of voxel of the current resized microstructure
        voxel_number_tmp=numel(Phase_microstructure_resized);
        Current_domain_size = size(Phase_microstructure_resized);

        current_phase_todo = 0;
        for current_phase=1:1:number_phase % Loop over all phases
            if p.todo(current_phase)
                time_cpu_start_phase = cputime; % CPU start
                time_clock_start_phase = tic; % Stopwatch start

                current_phase_todo=current_phase_todo+1;

                % % Algorithm: SPECIFIC FOR EACH FILE
                % Create a binary microstructure : 1 = current analysed phase, 0 = complementay phase
                binary_phase=zeros(Current_domain_size); % Initialization
                code_tmp = infovol.phaselabel(current_phase);
                Numbervoxel_phase_tmp= sum(sum(sum(Phase_microstructure_resized==code_tmp )));
                binary_phase(Phase_microstructure_resized == code_tmp) = 1; % Binary phase
                [Particle_size,~,~] = Function_particle_size_CPSD_Algorithm(binary_phase,roundingCPDS); % Call algorithm
                if infovol.isbackground && p.symmetry
                    binary_phase(idx_background) = 0;
                    Particle_size(idx_background) = 0;
                end

                property_voxelsizedependence(current_iteration+1,current_phase_todo+1,2) = 1 - (sum(sum(sum( logical(double(binary_phase==1) .* double(Particle_size<=sqrt(3))) )))) / (sum(sum(sum(binary_phase==1))));
                Particle_size = Particle_size*current_voxel_size;
                all_diameters = Particle_size(binary_phase==1);
                property_voxelsizedependence(current_iteration+1,current_phase_todo+1,1) = mean(all_diameters);
                PSDresized(current_phase_todo).iteration(current_iteration+1).voxelsize = current_voxel_size;
                [PSDresized(current_phase_todo).iteration(current_iteration+1).psd, ~] = Function_probability_density(all_diameters,[],density_fct_parameters);

                % % Time
                timedata_perphase = [timedata_perphase; [Numbervoxel_phase_tmp (cputime-time_cpu_start_phase) toc(time_clock_start_phase)]];

            end
        end
        % CPU and stopwatch time - end
        timedata_pervolume = [timedata_pervolume; [voxel_number_tmp (cputime-time_cpu_start_volume) toc(time_clock_start_volume)]];

    end
    clear Phase_microstructure_resized;

    % Sort per voxel size
    property_voxelsizedependence(:,:,1) = sortrows(property_voxelsizedependence(:,:,1),1);  
    property_voxelsizedependence(:,:,2) = sortrows(property_voxelsizedependence(:,:,2),1);       
    
    %% EXTRAPOLATION TO 0 nm
    tmp = zeros(number_resize+2,number_phase_todo+1,2); % + 0 nm and + initial voxel size
    x=property_voxelsizedependence(:,1,1);
    str_correlation(1).name = 'Particle_diameter_mean_CPSD';
    str_correlation(2).name = 'Particle_level_details';    
    fprintf('> Mean diameter dependence with the voxel size\n');
    for kparameter=1:1:2
        if kparameter==1
            if strcmp(p.scaling_extrapolation,'Linear')
                interpolation_voxelsize_order=1;
            elseif strcmp(p.scaling_extrapolation,'Quadratic')
                interpolation_voxelsize_order=2;
            elseif strcmp(p.scaling_extrapolation,'Cubic')
                interpolation_voxelsize_order=3;
            end
            max_order = length(p.scaling)-1;
            interpolation_voxelsize_order = min(interpolation_voxelsize_order,max_order);
            fprintf('  Extrapolation to zero voxel size: polynomial of order %i\n\n',interpolation_voxelsize_order);
        else
            if strcmp(p.lvldetail_scaling_extrapolation,'Linear')
                interpolation_voxelsize_order=1;
            elseif strcmp(p.lvldetail_scaling_extrapolation,'Quadratic')
                interpolation_voxelsize_order=2;
            elseif strcmp(p.lvldetail_scaling_extrapolation,'Cubic')
                interpolation_voxelsize_order=3;
            end
            max_order = length(p.scaling)-1;
            interpolation_voxelsize_order = min(interpolation_voxelsize_order,max_order);
        end
        for current_phase_todo=1:1:number_phase_todo
            y=property_voxelsizedependence(:,current_phase_todo+1,kparameter);
            pi = polyfit(x,y,interpolation_voxelsize_order);
            vq = polyval(pi,0);
            tmp(1,current_phase_todo+1,kparameter)=vq;
            interpolation_voxelsize(current_phase_todo,kparameter).pi=pi;
            % For correlation
            results_correlation(current_phase_todo).([str_correlation(kparameter).name '_extrapolated']) = vq;            
        end
        tmp(2:end,:,kparameter) = property_voxelsizedependence(:,:,kparameter);
    end
    property_voxelsizedependence = tmp; clear tmp;      

    %% MANAGING RESULTS
    % Results are saved in a table
    Variable_name_table={['Voxel size ' voxel_unit]}; % Columns name
    for current_phase_todo=1:1:number_phase_todo
        Variable_name_table(1+current_phase_todo)=phasename_todo(current_phase_todo);
    end
    % Table
    Table_Meandiameter_voxelsizedependence = array2table(property_voxelsizedependence(:,:,1),...
        'VariableNames',Variable_name_table);
    Table_ParticleLvlDescription_voxelsizedependence = array2table(property_voxelsizedependence(:,:,2),...
        'VariableNames',Variable_name_table);    
    
    %% DISPLAY TEXT RESULTS
    disp(Table_Meandiameter_voxelsizedependence)
    fprintf('> Particle level of details dependence with the voxel size\n');
    fprintf('  Extrapolation to zero voxel size: polynomial of order %i\n\n',interpolation_voxelsize_order);
    disp(Table_ParticleLvlDescription_voxelsizedependence)

    
    %% SAVE RESULTS
    Results_cpsd.voxelsizedependence_d50 = Table_Meandiameter_voxelsizedependence; % Save in main table result
    Results_cpsd.voxelsizedependence_lvldetail = Table_ParticleLvlDescription_voxelsizedependence; 
    if opt.save.xls
        filename = 'D50_Cpsd_voxel_size_dependence'; % Filename without extension
        % Prepare the data
        clear DATA_writetable
        DATA_writetable.sheet(1).name='D50_Cpsd';
        DATA_writetable.sheet(1).table=Table_Meandiameter_voxelsizedependence;
        DATA_writetable.sheet(2).name='Particle_lvl_detail';
        DATA_writetable.sheet(2).table=Table_ParticleLvlDescription_voxelsizedependence;        
        % Save function
        Function_Writetable(Current_folder,filename,DATA_writetable)
    end
    
    %% FIGURES
    parameters_figure.plotlog = false;
    parameters_figure.propertyname = 'Mean diameter';
    parameters_figure.method = 'C-PSD';
    parameters_figure.property_voxelsizedependence = property_voxelsizedependence(:,:,1);
    parameters_figure.number_phase = number_phase_todo;
    parameters_figure.str_ylabel = ['D_{50} ' axisunit];
    parameters_figure.propertynameunit = Dunit;
    parameters_figure.interpolation_voxelsize = interpolation_voxelsize(:,1);
    parameters_figure.Current_folder = Current_folder;
    parameters_figure.filename = 'D50_Cpsd_voxel_size_dependence';
    parameters_figure.infovol = infovol;
    parameters_figure.opt = opt;
    parameters_figure.todo = p.todo;
    Function_create_figure_voxelsizedependence(parameters_figure) % Figures    

    parameters_figure.propertyname = 'Particle level of details';
    parameters_figure.method = 'C-PSD';
    parameters_figure.property_voxelsizedependence = property_voxelsizedependence(:,:,2);
    parameters_figure.str_ylabel = 'Particle level of details [0,1]';
    parameters_figure.propertynameunit = [];
    parameters_figure.interpolation_voxelsize = interpolation_voxelsize(:,2);
    parameters_figure.Current_folder = Current_folder;
    parameters_figure.filename = 'ParticleLvlDetail_Cpsd_voxel_size_dependence';
    Function_create_figure_voxelsizedependence(parameters_figure) % Figures     

    %% FIGURES 2 (DISTRIBUTION)
    for current_phase_todo=1:1:number_phase_todo % Loop over all phases
        parameters_distributionfigure.figurename =  ['Particle diameter, ' char(phasename_todo(current_phase_todo,1))];
        parameters_distributionfigure.filename = ['Diameter_CPSD_voxelsize_' char(phasename_todo(current_phase_todo,1))];
        parameters_distributionfigure.subaxe1_title = 'Cumulative function';
        parameters_distributionfigure.subaxe2_title = 'Distribution function';
        parameters_distributionfigure.title = ['Particle diameter voxel size dependence (C-PSD), ' char(phasename_todo(current_phase_todo,1))];
        parameters_distributionfigure.xlabel = ['Particle diameter ' axisunit];
        function_probability_distribution_size_figure(PSDresized(current_phase_todo),parameters_distributionfigure);
    end
end

%%
%% REPRESENTATITVE VOLUME ELEMENT (RVE) AND CONVERGENCE ANALYSIS
%%

if p.RVE.number_RVE>0
    if infovol.isbackground && p.symmetry
        Phase_microstructure = Phase_microstructure_initial;
    end


    propertyname='Mean diameter';
    for k_RVE = 1:1:p.RVE.number_RVE % Loop over all RVE asked
        RVEparameters = p.RVE.RVE(k_RVE);
        RVE(k_RVE).RVEparameters = RVEparameters; % For result structure
        if opt.save.xls || opt.save.savefig
            Sub_folder_RVE = [Current_folder RVEparameters.savename separator];
            while exist(Sub_folder_RVE,'dir')
                RVEparameters.savename = [RVEparameters.savename '_bis'];
                Sub_folder_RVE = [Current_folder RVEparameters.savename separator];
            end
            mkdir(Sub_folder_RVE);
        end
        if strcmp(RVEparameters.type,'A') || strcmp(RVEparameters.type,'B') || strcmp(RVEparameters.type,'C') || strcmp(RVEparameters.type,'D')
            thresholds = RVEparameters.threshold_std;
        else
            thresholds = RVEparameters.threshold_reldiff;
        end
        n_threshold = length(thresholds);

        % Nested analysis ?
        if RVEparameters.donested % Yes
            [n_nestedRVE, xcrop] = Function_NestedRVE(RVEparameters,Domain_size);
            Result_nestedRVE = zeros(n_nestedRVE+1,n_threshold+1,number_phase_todo,3,3); % FOV size / number of threshold / phase / subdomain RVE or convergence size <, = , > /  size (both FOV and subdoamin) in cubic root (=1), in square root (=2), or lenght (=3)
        else % No
            n_nestedRVE = 0;
        end        

        for k_nestedRVE = 0:1:n_nestedRVE

            %% NESTED ANALYSIS
            if k_nestedRVE == 0
                Domain_size_nested = Domain_size;
            else
                x0 = xcrop(k_nestedRVE,1); x1 = xcrop(k_nestedRVE,2);
                y0 = xcrop(k_nestedRVE,3); y1 = xcrop(k_nestedRVE,4);
                z0 = xcrop(k_nestedRVE,5); z1 = xcrop(k_nestedRVE,6);
                Phase_microstructure_nested = Phase_microstructure(x0:x1,y0:y1,z0:z1);
                Domain_size_nested = size(Phase_microstructure_nested);
            end
            
            %% SUBDOMAINS
            [All_subdomain,GROUP_SUBDOMAIN, Wholevolume_size] = Function_get_Subdomains(RVEparameters, Domain_size_nested, Domain_size); % Location of all subdomains
            Wholevolume_size(1:2) = Wholevolume_size(1:2)*voxel_size;
            if RVEparameters.donested
                Result_nestedRVE(k_nestedRVE+1,1,:,:,1) = Wholevolume_size(1);
                if k_nestedRVE ==1
                    fprintf('       Nested analysis\n');
                end
                if k_nestedRVE > 0
                    fprintf('          Cropping iteration: #%i/%i (cubic root volume=%1.1f %s)\n',k_nestedRVE,n_nestedRVE,Wholevolume_size(1),infovol.unit);
                end                
                if strcmp(RVEparameters.type,'C')
                    Result_nestedRVE(k_nestedRVE+1,1,:,:,2) = Wholevolume_size(2);
                elseif strcmp(RVEparameters.type,'D')
                    Result_nestedRVE(k_nestedRVE+1,1,:,:,3) = Wholevolume_size(2);                    
                elseif strcmp(RVEparameters.type,'G')
                    Result_nestedRVE(k_nestedRVE+1,1,:,:,3) = Wholevolume_size(2);
                elseif strcmp(RVEparameters.type,'H')
                    Result_nestedRVE(k_nestedRVE+1,1,:,:,2) = Wholevolume_size(2);                    
                end
            end

            % Information about subdomains
            RVE(k_RVE).info = table(All_subdomain(:,1),All_subdomain(:,2),All_subdomain(:,3),All_subdomain(:,4),All_subdomain(:,5),All_subdomain(:,6),All_subdomain(:,7),All_subdomain(:,8),All_subdomain(:,9),All_subdomain(:,10),All_subdomain(:,11),All_subdomain(:,12),...
                'VariableNames',{'Subdomain Id' 'Group Id' 'Number subdomain' 'Equivalent cubic length' 'Equivalent section length' 'Length' 'x0' 'x1' 'y0' 'y1' 'z0' 'z1'});
            [number_subdomain,~] = size(All_subdomain); % The number of subdomain
            number_group_size = length(GROUP_SUBDOMAIN.id); % the number of group of subdomains sharing the same size

            %% ALGORITHM
            % Colunm 1 is the subdomain id
            % Colunm 2 and 3 are the sizes of the subdomain.
            Property_eachsubdomain = zeros(number_subdomain,number_phase_todo+4);
            % Property calculated for each subdomain
            for subdomain_id = 1:1:number_subdomain
                % Boundary of the subdomain
                x0 = All_subdomain(subdomain_id,7); x1 = All_subdomain(subdomain_id,8);
                y0 = All_subdomain(subdomain_id,9); y1 = All_subdomain(subdomain_id,10);
                z0 = All_subdomain(subdomain_id,11); z1 = All_subdomain(subdomain_id,12);
                clear current_subdomain;
                % Crop volume
                if k_nestedRVE == 0
                    current_subdomain = Phase_microstructure(x0:x1,y0:y1,z0:z1);
                else
                    current_subdomain = Phase_microstructure_nested(x0:x1,y0:y1,z0:z1);
                end                    
                Current_domain_size = size(current_subdomain);                

                % CPU and stopwatch time - start
                time_cpu_start_volume = cputime; % CPU start
                time_clock_start_volume = tic; % Stopwatch start
                % Number of voxel of the current resized microstructure
                voxel_number_tmp=numel(current_subdomain);

                Property_eachsubdomain(subdomain_id,1)=subdomain_id;
                % Equivalent size of the subdomain
                Property_eachsubdomain(subdomain_id,2)=All_subdomain(subdomain_id,4)*voxel_size; % Cubic root length
                Property_eachsubdomain(subdomain_id,3)=All_subdomain(subdomain_id,5)*voxel_size; % Square root length
                Property_eachsubdomain(subdomain_id,4)=All_subdomain(subdomain_id,6)*voxel_size; % Length

                current_phase_todo = 0;
                for current_phase=1:1:number_phase % Loop over all phases
                    if p.todo(current_phase)
                        time_cpu_start_phase = cputime; % CPU start
                        time_clock_start_phase = tic; % Stopwatch start
                        current_phase_todo=current_phase_todo+1;

                        % % Algorithm: SPECIFIC FOR EACH FILE
                        code_tmp = infovol.phaselabel(current_phase);
                        Numbervoxel_phase_tmp= sum(sum(sum(current_subdomain==code_tmp )));

                        if infovol.isbackground && p.symmetry
                            psym.Background = zeros(size(current_subdomain));
                            idx_background = find(current_subdomain == 0);
                            if ~isempty(idx_background)
                                psym.Background(idx_background)=1;
                                [current_subdomain] = fct_symmetry(current_subdomain,psym);
                            end
                        end
                        binary_phase=zeros(Current_domain_size); % Initialization
                        binary_phase(current_subdomain == code_tmp) = 1;                        

                        [Particle_size_subdomain, ~, ~] = Function_particle_size_CPSD_Algorithm(binary_phase,roundingCPDS); % Call algorithm
                        if infovol.isbackground && p.symmetry && ~isempty(idx_background)
                            binary_phase(idx_background) = 0;
                            Particle_size_subdomain(idx_background) = 0;
                        end

                        Particle_size_subdomain = Particle_size_subdomain*voxel_size;
                        all_diameters_subdomain = Particle_size_subdomain(binary_phase==1);
                        Property_eachsubdomain(subdomain_id,current_phase_todo+4)=mean(all_diameters_subdomain);

                        % % Time
                        timedata_perphase = [timedata_perphase; [Numbervoxel_phase_tmp (cputime-time_cpu_start_phase) toc(time_clock_start_phase)]];

                    end
                end
                % CPU and stopwatch time - end
                timedata_pervolume = [timedata_pervolume; [voxel_number_tmp (cputime-time_cpu_start_volume) toc(time_clock_start_volume)]];
            end

            %% STATISTICAL ANALYSIS and RVE SIZE
            [Property_subdomains_statistics, Size_RVE, derivative_convergence, relativedifference_convergence, Size_convergence] = Function_subdomains_statistical_analysis(number_group_size,number_phase_todo,GROUP_SUBDOMAIN,Property_eachsubdomain,voxel_size,RVEparameters);
            
            %% SAVE FOR CORRELATION
            if k_nestedRVE == 0
                for k_threshold=1:1:n_threshold
                    current_phase_todo = 0;
                    for current_phase=1:1:number_phase
                        if p.todo(current_phase)
                            current_phase_todo=current_phase_todo+1;
                            if strcmp(RVEparameters.type,'A') || strcmp(RVEparameters.type,'B') || strcmp(RVEparameters.type,'C') || strcmp(RVEparameters.type,'D')
                                if Size_RVE(1,current_phase_todo,2,1)~=0
                                    str_ = ['D50cpsd_RVE_cubicroot_thresh' num2str(thresholds(k_threshold),'%1.2f') '_' RVEparameters.savename];
                                    str_(str_=='.')='p';
                                    results_correlation(current_phase_todo).(str_) = Size_RVE(1,current_phase_todo,2,1);
                                end
                                if strcmp(RVEparameters.type,'C')
                                    if Size_RVE(1,current_phase_todo,2,2)~=0
                                        str_ = ['D50cpsd_RVE_squarerootFOV_thresh' num2str(thresholds(k_threshold),'%1.2f') '_' RVEparameters.savename];
                                        str_(str_=='.')='p';
                                        results_correlation(current_phase_todo).(str_) = Size_RVE(1,current_phase_todo,2,2);
                                    end
                                elseif strcmp(RVEparameters.type,'D')
                                    if Size_RVE(1,current_phase_todo,2,2)~=0
                                        str_ = ['D50cpsd_RVE_lengthFOV_thresh' num2str(thresholds(k_threshold),'%1.2f') '_' RVEparameters.savename];
                                        str_(str_=='.')='p';
                                        results_correlation(current_phase_todo).(str_) = Size_RVE(1,current_phase_todo,2,2);
                                    end
                                end  
                            else
                                if Size_convergence(1,current_phase_todo,2,1)~=0
                                    str_ = ['D50cpsd_conv_cubicroot_thresh' num2str(thresholds(k_threshold),'%1.2f') '_' RVEparameters.savename];
                                    str_(str_=='.')='p';
                                    results_correlation(current_phase_todo).(str_) = Size_convergence(1,current_phase_todo,2,1);
                                end
                                if strcmp(RVEparameters.type,'G')
                                    if Size_convergence(1,current_phase_todo,2,2)~=0
                                        str_ = ['D50cpsd_conv_lengthFOV_thresh' num2str(thresholds(k_threshold),'%1.2f') '_' RVEparameters.savename];
                                        str_(str_=='.')='p';
                                        results_correlation(current_phase_todo).(str_) = Size_convergence(1,current_phase_todo,2,2);
                                    end
                                elseif strcmp(RVEparameters.type,'H')
                                    if Size_convergence(1,current_phase_todo,2,2)~=0
                                        str_ = ['D50cpsd_conv_areaFOV_thresh' num2str(thresholds(k_threshold),'%1.2f') '_' RVEparameters.savename];
                                        str_(str_=='.')='p';
                                        results_correlation(current_phase_todo).(str_) = Size_convergence(1,current_phase_todo,2,2);
                                    end
                                end
                            end
                        end
                    end
                end
            end

            %% MANAGING RESULTS
            [RVE] = Function_subdomains_manage_results(Property_eachsubdomain, Property_subdomains_statistics, Size_RVE, derivative_convergence, relativedifference_convergence, Size_convergence, RVEparameters,RVE,k_RVE,number_phase,number_phase_todo,infovol,p);

            if RVEparameters.donested
                for k_threshold=1:1:n_threshold
                    current_phase_todo = 0;
                    for current_phase=1:1:number_phase
                        if p.todo(current_phase)
                            current_phase_todo=current_phase_todo+1;
                            if strcmp(RVEparameters.type,'A') || strcmp(RVEparameters.type,'B') || strcmp(RVEparameters.type,'C') || strcmp(RVEparameters.type,'D')
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,1,1) = Size_RVE(k_threshold,current_phase_todo,1,1);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,2,1) = Size_RVE(k_threshold,current_phase_todo,2,1);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,3,1) = Size_RVE(k_threshold,current_phase_todo,3,1);
                            else
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,1,1) = Size_convergence(k_threshold,current_phase_todo,1,1);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,2,1) = Size_convergence(k_threshold,current_phase_todo,2,1);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,3,1) = Size_convergence(k_threshold,current_phase_todo,3,1);
                            end
                            if strcmp(RVEparameters.type,'C')
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,1,2) = Size_RVE(k_threshold,current_phase_todo,1,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,2,2) = Size_RVE(k_threshold,current_phase_todo,2,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,3,2) = Size_RVE(k_threshold,current_phase_todo,3,2);
                            elseif strcmp(RVEparameters.type,'D')
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,1,3) = Size_RVE(k_threshold,current_phase_todo,1,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,2,3) = Size_RVE(k_threshold,current_phase_todo,2,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,3,3) = Size_RVE(k_threshold,current_phase_todo,3,2);                                   
                            elseif strcmp(RVEparameters.type,'F')
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,1,3) = Size_convergence(k_threshold,current_phase_todo,1,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,2,3) = Size_convergence(k_threshold,current_phase_todo,2,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,3,3) = Size_convergence(k_threshold,current_phase_todo,3,2);
                            elseif strcmp(RVEparameters.type,'H')
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,1,2) = Size_convergence(k_threshold,current_phase_todo,1,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,2,2) = Size_convergence(k_threshold,current_phase_todo,2,2);
                                Result_nestedRVE(k_nestedRVE+1,k_threshold+1,current_phase_todo,3,2) = Size_convergence(k_threshold,current_phase_todo,3,2);                                
                            end
                        end
                    end
                end
            end

            %% TEXT DISPLAY AND SAVE RESULTS
            if k_nestedRVE == 0
                RVEparameters.disp_parRVE = true;
                Function_subdomains_display_and_save(RVE,k_RVE,RVEparameters,number_phase,number_phase_todo,propertyname,Sub_folder_RVE,opt,infovol,p);
            end

            %% FIGURES
            if k_nestedRVE == 0
                parameters_figure.propertyname = propertyname;
                parameters_figure.propertynameunit = Dunit;
                parameters_figure.RVE = RVEparameters;
                parameters_figure.Criterion=[RVEparameters.threshold_std RVEparameters.threshold_numbersubvolumes];
                parameters_figure.savefolder = Sub_folder_RVE;
                parameters_figure.number_phase = number_phase;
                parameters_figure.number_phase_todo = number_phase_todo;
                parameters_figure.Property_subdomains_statistics = Property_subdomains_statistics;
                parameters_figure.Property_eachsubdomain = Property_eachsubdomain;
                parameters_figure.derivative_convergence = derivative_convergence;
                parameters_figure.relativedifference_convergence = relativedifference_convergence;
                parameters_figure.Size_RVE = Size_RVE;
                parameters_figure.convergence_criterion = RVEparameters.threshold_reldiff;
                parameters_figure.Size_convergence = Size_convergence;
                parameters_figure.Wholevolume_size = Wholevolume_size;
                parameters_figure.Wholevolume_results = PSD_results;
                parameters_figure.infovol = infovol;
                parameters_figure.todo = p.todo;
                parameters_figure.opt = opt;
                Function_create_figures_RVE(parameters_figure) % Figures
            end
        end

        %% NESTED ANALYSIS RESULT
        if RVEparameters.donested
            % Table
            [RVE] = Function_nestedtable(RVE,k_RVE,RVEparameters,number_phase,propertyname,Result_nestedRVE,Sub_folder_RVE,opt,infovol,p);
            % Figure
            parameters_figure.Result_nestedRVE = Result_nestedRVE;
            Function_create_figures_nestedRVE(parameters_figure) % Figures
            % Save
            RVE(k_RVE).nestedanalysis = Result_nestedRVE;
        end
        
    end
    Results_cpsd.RVE.meandiameter = RVE; % Save in main table result
end

%%
%% ENDING FUNCTION
%%

%% TIME
Table_time_pervolume = table(timedata_pervolume(:,1),timedata_pervolume(:,2),timedata_pervolume(:,3),...
    'VariableNames',{'Number of voxel','CPU time s' 'Stopwatch s'});
Results_cpsd.Table_time_pervolume = Table_time_pervolume; % Save in main table result
Table_time_perphase = table(timedata_perphase(:,1),timedata_perphase(:,2),timedata_perphase(:,3),...
    'VariableNames',{'Number of voxel','CPU time s' 'Stopwatch s'});
Results_cpsd.Table_time_perphase = Table_time_perphase; % Save in main table result

date_end = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss Z');
lasted_time = date_end-date_start;
Table_date = table({char(date_start)},{char(date_end)},{char(lasted_time)},...
    'VariableNames',{'Start date' 'End date' 'Lasted time'});
Results_cpsd.Table_date = Table_date;

if opt.save.xls
    % Prepare the data
    clear DATA_writetable
    % Time per volume
    DATA_writetable.sheet(1).name='Time per volume';
    DATA_writetable.sheet(1).table=Table_time_pervolume;
    % Time per phase
    DATA_writetable.sheet(2).name='Time per phase';
    DATA_writetable.sheet(2).table=Table_time_perphase;    
    % Data : Date
    DATA_writetable.sheet(3).name='Date';
    DATA_writetable.sheet(3).table=Table_date;
    % Save function
    Function_Writetable(Current_folder,'D50_Cpsd_calculation_time',DATA_writetable)
end
% Display
fprintf ('Finished the %s\n\n',date_end);
fprintf ('Lasted: %s\n\n',lasted_time);
function_time_figure(timedata_pervolume, timedata_perphase, Current_folder, 'D50_Cpsd_calculation_time', 'Diameter (C-psd)', opt);

%% SAVE CORRELATION
Current_folder = fullfile(infovol.volpath, 'Correlation');
if exist(Current_folder,'dir')==0 % Folder existence is checked, and created if necessary
    mkdir(Current_folder);
end
save([Current_folder 'Correlation_D50_cpsd'],'results_correlation');

%% SAVE RESULTS
if opt.save.mat
    Current_folder = fullfile(infovol.volpath, 'Summary');
    if exist(Current_folder,'dir')==0 % Folder existence is checked, and created if necessary
        mkdir(Current_folder);
    end
    save([Current_folder 'Results_D50_Cpsd'],'Results_cpsd')
end
%% SAVE VISUALIZATION
Current_folder = fullfile(infovol.volpath, 'Visualization');
if exist(Current_folder,'dir')==0 % Folder existence is checked, and created if necessary
    mkdir(Current_folder);
end
save([Current_folder 'Visualization_particlediameter_CPSD'],'results_visualization','-v7.3');    

end