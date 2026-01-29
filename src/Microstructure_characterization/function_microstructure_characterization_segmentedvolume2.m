function [] = function_microstructure_characterization_segmentedvolume2(mode, segmentation_type, infovol, optc, opts_sem,opts_ins,tag,tag_unit)
% Calculate microstructure properties useful for energy storage macroscale models.
% For instance, for Pseudo-2D battery models (i.e., Doyle–Fuller–Newman models).
% Intended use of this function is through the GUI of src\Microstructure_characterization\Microstructure_characterization.mlapp
% Inputs:
%   infovol  : volume information
%   optc     : options common to all volumes
%   opts_sem : options volume specific for semantic segmentation file
%   opts_ins : options volume specific for instance segmentation file

% Tables below are re-created as they are saved in an excel file for each volume
date_start = datetime('now','TimeZone','local','Format','eeee, HH:mm:ss Z, MMMM d, y');
Table_date = table({char(date_start)},...
    'VariableNames',{'Date'});
Table_toolbox = table({'Toolbox';'Version';'GitHub repository';'Official webpage';'Journal article'},{optc.toolbox.toolboxname;optc.toolbox.version;optc.toolbox.githubrepo;optc.toolbox.officialwebpage;optc.toolbox.article},...
    'VariableNames',{'Item','Value'});
Table_author = table(optc.toolbox.authorlist(:,1),optc.toolbox.authorlist(:,2),...
    'VariableNames',{'Author','Affiliation'});
username = getenv('USERNAME');
computername = getenv('COMPUTERNAME');
os = getenv('OS');
Table_User = table({username},{computername},{os},...
    'VariableNames',{'User name','Computer name','Operating system'});

%% SAVE FOLDER
fprintf('Results will be saved in %s\n\n',infovol.volpath);

%% IMPORT
if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    disp('Semantic import(s)...');
    disp(['   - Loading semantic segmentation file: ' infovol.loadingpath_semantic]);
    fprintf('        Please wait...');
    [M_semantic,outcome] = function_load_tif(infovol.loadingpath_semantic,'uint8');
    if ~outcome % fail to import
        return
    end
    disp('   Import successful!');
    sz = size(M_semantic); % Size of the loaded domain (number of voxel)

    % Import bulk properties
    fprintf('   - Nanoporosity representation is: %s\n',infovol.nanoporosity_representation)
    if strcmp(infovol.nanoporosity_representation,'Mixed (heterogeneous)')
        disp(['     Loading nanoporosity file: ' infovol.loadingpath_nanoporosity]);
        fprintf('        Please wait...');
        [M_nanoporosity,outcome] = function_load_tif(infovol.loadingpath_nanoporosity,'single');
        if ~outcome % fail to import
            return
        end
        disp('   Import successful!');
    else
        M_nanoporosity = zeros(sz,'single')-1;
        if infovol.isbackground
            k0 = 2;
        else
            k0 = 1;
        end
        for k=k0:length(infovol.phaselabel_semantic)
            M_nanoporosity(M_semantic==infovol.phaselabel_semantic(k)) = cell2mat(infovol.nanoporosity(k));
        end 
    end

    fprintf('   - Wetting representation is: %s\n', infovol.partial_wetting_representation)
    if strcmp(infovol.partial_wetting_representation,'Heterogeneous')
        fprintf('     Loading %s file: %s\n', infovol.partial_wetting_value_is, infovol.loadingpath_wetting);
        fprintf('        Please wait...');
        [M_wetting,outcome] = function_load_tif(infovol.loadingpath_wetting,'single');
        if ~outcome % fail to import
            return
        end
        disp('   Import successful!');
        if strcmp(infovol.partial_wetting_value_is,'Air saturation') % Convert to wetting
            M_wetting = 1-M_wetting;
            fprintf('        Converted to wetting = 1 - air saturation.\n');
        end        
    elseif strcmp(infovol.partial_wetting_representation,'Ideal')
        M_wetting = ceil(M_nanoporosity); % 0 or 1
    elseif strcmp(infovol.partial_wetting_representation,'Uniform')
        M_wetting = zeros(sz,'single')-1;
        if infovol.isbackground
            k0 = 2;
        else
            k0 = 1;
        end
        for k=k0:length(infovol.phaselabel_semantic)
            if strcmp(infovol.partial_wetting_value_is,'Air saturation') % Convert to wetting
                M_wetting(M_semantic==infovol.phaselabel_semantic(k)) = 1-cell2mat(infovol.air_saturation(k));
            else
                M_wetting(M_semantic==infovol.phaselabel_semantic(k)) = cell2mat(infovol.wetting(k));
            end
        end
    end      

    if sum(opts_sem.tortuosity.todo)>=1 || opts_sem.tortuosity.pore_combined_todo || opts_sem.tortuosity.solid_combined_todo
        fprintf('   - Pore transport representation is: %s\n',infovol.poretransport_representation)
        if strcmp(infovol.poretransport_representation,'Diffusivity D (heterogeneous)')
            disp(['     Loading diffusivity file: ' infovol.loadingpath_diffusivity]);
            fprintf('        Please wait...');
            [M_bulkdiffusivity,outcome] = function_load_tif(infovol.loadingpath_diffusivity,'single');
            if ~outcome % fail to import
                return
            end
            disp('   Import successful!');
        else
            M_bulkdiffusivity = zeros(sz,'single')-1;
            if infovol.isbackground
                k0 = 2;
            else
                k0 = 1;
            end
            for k=k0:length(infovol.phaselabel_semantic)
                if ~ischar(cell2mat(infovol.poretransport(k)))
                    M_bulkdiffusivity(M_semantic==infovol.phaselabel_semantic(k)) = cell2mat(infovol.poretransport(k));
                end
            end
            if strcmp(infovol.poretransport_representation,'Bruggeman exponent p (uniform)') % Need to convert into diffusivity
                M_bulkdiffusivity = (M_nanoporosity.*M_wetting).^M_bulkdiffusivity;
            end
        end

        fprintf('   - Solid transport representation is: %s\n',infovol.solidtransport_representation)
        if strcmp(infovol.solidtransport_representation,'Conductivity K (heterogeneous)')
            disp(['     Loading diffusivity file: ' infovol.loadingpath_conductivity]);
            fprintf('        Please wait...');
            [M_bulkconductivity,outcome] = function_load_tif(infovol.loadingpath_conductivity,'single');
            if ~outcome % fail to import
                return
            end
            disp('   Import successful!');
        else
            M_bulkconductivity = zeros(sz,'single')-1;
            if infovol.isbackground
                k0 = 2;
            else
                k0 = 1;
            end
            for k=k0:length(infovol.phaselabel_semantic)
                if ~ischar(cell2mat(infovol.solidtransport(k)))
                    M_bulkconductivity(M_semantic==infovol.phaselabel_semantic(k)) = cell2mat(infovol.solidtransport(k));
                end
            end
            if strcmp(infovol.solidtransport_representation,'Bruggeman exponent p (uniform)') % Need to convert into diffusivity
                M_bulkconductivity = (1-M_nanoporosity).^M_bulkconductivity;
            end
        end
    else
        M_bulkdiffusivity = [];
        M_bulkconductivity = [];
    end
end

if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    disp('Instance import...');
    disp(['   - Loading instance segmentation file: ' infovol.loadingpath_instance]);
    fprintf('        Please wait...');
    [M_instance,outcome] = function_load_tif(infovol.loadingpath_instance,'uint32');
    if ~outcome % fail to import
        return
    end
    [M_instance] = fct_intconvert(M_instance);
    disp('   Import successful!');
    sz = size(M_instance); % Size of the loaded domain (number of voxel)
end

%% OVERWRITTE IF infovol NOT RELEVANT
if ~strcmp(mode,'Set parameters for each volume independently')

    TO BE REDONE

    % Dimension
    number_direction = length(sz);
    if number_direction<length(infovol.directionname)
        infovol.directionname = infovol.directionname(1:number_direction);
    elseif number_direction>length(infovol.directionname)
        for k = length(infovol.directionname)+1:1:number_direction
            infovol.directionname(k) = {['Direction ' num2str(k)]};
        end
    end

    if (strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')) && (isempty(infovol.nphase) || ~isfield(infovol,'phasename_semantic'))
        unis = unique(M_semantic);
        infoval.nphase = length(unis);

        if ~isfield(infovol,'phasename_semantic')
            infovol.phasename_semantic = infovol.phasename_semantic;
            infovol.phaselabel_semantic = infovol.initial_phaselabel_semantic(:,1);
        end

        if infoval.nphase < length(infovol.phasename_semantic)
            infovol.phasename_semantic = infovol.phasename_semantic(1:infoval.nphase);
            infovol.phasename_semantic = infovol.phasename_semantic(1:infoval.nphase);
            infovol.initial_phaselabel_semantic = infovol.initial_phaselabel_semantic(1:infoval.nphase,:);
            infovol.phaselabel_semantic = infovol.phaselabel_semantic(1:infoval.nphase);
            infovol.phasecolor_semantic = infovol.phasecolor_semantic(1:infoval.nphase,:);
        elseif infoval.nphase > length(infovol.phasename_semantic)
            for k = length(infovol.phasename_semantic)+1:1:infoval.nphase
                infovol.phasename_semantic(k) = {['Label ' num2str(unis(k))]};
                infovol.phasename_semantic(k) = {['Label ' num2str(unis(k))]};
                infovol.initial_phaselabel_semantic(k,:) = [unis(k) unis(k)];
                infovol.phaselabel_semantic(k) = unis(k);
                if k<7
                    tmp = colororder;
                    infovol.phasecolor_semantic(k,:) = tmp(k,:);
                else
                    infovol.phasecolor_semantic(k,:) = rand(1,3);
                end
            end
        end

    elseif (strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')) && isempty(infovol.ninstance)
        % No issue here: it is always a binary image
        foo = 1;
    end
end

%% FOLDER
if ~exist(infovol.volpath,'dir') % Check existence of the main folder
    mkdir(infovol.volpath); % Create folder if not exist
end

%% SAVE LOADED VOLUME
if optc.save.inputfiles
    volume_folder = fullfile(infovol.volpath,'Volume');
    if ~exist(volume_folder,'dir')
        mkdir(volume_folder);
    end
    disp(' ');
    fprintf('Save imported files in folder: %s\n',volume_folder);
    fprintf('        Please wait...');
    
    if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
        function_save_tif(M_semantic, fullfile(volume_folder,'Imported_semanticvolume.tif'));
        if strcmp(infovol.nanoporosity_representation,'Mixed (heterogeneous)')
            function_save_tif(M_nanoporosity, fullfile(volume_folder,'Imported_nanoporosity.tif'));
        end
        if strcmp(infovol.partial_wetting_representation,'Heterogeneous')
            function_save_tif(M_wetting, fullfile(volume_folder,'Imported_wetting.tif'));
        end        
        if ~isempty(M_bulkdiffusivity)
            if strcmp(infovol.poretransport_representation,'Diffusivity D (heterogeneous)')
                function_save_tif(M_bulkdiffusivity, fullfile(volume_folder,'Imported_bulkdiffusivity.tif'));
            end
        end
        if ~isempty(M_bulkconductivity)
            if strcmp(infovol.solidtransport_representation,'Conductivity K (heterogeneous)')
                function_save_tif(M_bulkconductivity, fullfile(volume_folder,'Imported_bulkconductivity.tif'));
            end
        end
    end
    if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
        function_save_tif(M_instance, fullfile(volume_folder,'Imported_instancevolume.tif'));
    end
    fprintf('   Done!\n');
end

%% GENERAL INFORMATION ABOUT THE VOLUME
Domain_size_unit = sz*infovol.initial_voxelsize; % Size of the loaded domain
number_direction = length(sz); % Number of direction (2D or 3D)
initial_numbervoxel = prod(sz);
% Create table
if number_direction==2
    equivalent_square_size_unit = prod(Domain_size_unit)^(1/2);
    Table_domainsize = table([1;2],[infovol.directionname(1); infovol.directionname(2)], [sz(1); sz(2)],[Domain_size_unit(1); Domain_size_unit(2)], [equivalent_square_size_unit;equivalent_square_size_unit],...
        'VariableNames',{'Direction', 'Name', 'Number of voxel' ['Length ' infovol.unit] ['Equivalent squareroot length ' infovol.unit]});
else
    equivalent_cubic_size_unit = prod(Domain_size_unit)^(1/3);
    Table_domainsize = table([1;2;3],[infovol.directionname(1); infovol.directionname(2); infovol.directionname(3)], [sz(1); sz(2); sz(3)],[Domain_size_unit(1); Domain_size_unit(2); Domain_size_unit(3)], [equivalent_cubic_size_unit; equivalent_cubic_size_unit; equivalent_cubic_size_unit],...
        'VariableNames',{'Direction', 'Name', 'Number of voxel' ['Length ' infovol.unit] ['Equivalent cubicroot length ' infovol.unit]});
end
Table_voxel = table([{['Voxel size (' infovol.unit ')']};{'Number of voxel'}], [infovol.initial_voxelsize; prod(sz)],...
    'VariableNames',{'Information', 'Value'});

% Size of the loaded data
c1 = {}; c2 = {}; c3 = {}; c4 = {};
if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    c1(end+1,1) = {'Semantic phases'};
    c2(end+1,1) = {infovol.loadingpath_semantic};
    tmp=whos('M_semantic'); data_MB_sem=tmp.bytes*9.53674e-7;
    c3(end+1,1) = {tmp.class};
    c4(end+1,1) = {num2str(data_MB_sem,'%1.1f')};
    if strcmp(infovol.nanoporosity_representation,'Mixed (heterogeneous)')
        c1(end+1,1) = {'Nanoporosity'};
        c2(end+1,1) = {infovol.loadingpath_nanoporosity};
        tmp=whos('M_nanoporosity'); data_MB=tmp.bytes*9.53674e-7;
        c3(end+1,1) = {tmp.class};
        c4(end+1,1) = {num2str(data_MB,'%1.1f')};
    end
    if ~isempty(M_bulkdiffusivity)
        if strcmp(infovol.poretransport_representation,'Diffusivity D (heterogeneous)')
            c1(end+1,1) = {'Diffusivity'};
            c2(end+1,1) = {infovol.loadingpath_diffusivity};
            tmp=whos('M_bulkdiffusivity'); data_MB=tmp.bytes*9.53674e-7;
            c3(end+1,1) = {tmp.class};
            c4(end+1,1) = {num2str(data_MB,'%1.1f')};
        end
    end
    if ~isempty(M_bulkconductivity)
        if strcmp(infovol.solidtransport_representation,'Conductivity K (heterogeneous)')
            c1(end+1,1) = {'Conductivity'};
            c2(end+1,1) = {infovol.loadingpath_conductivity};
            tmp=whos('M_bulkconductivity'); data_MB=tmp.bytes*9.53674e-7;
            c3(end+1,1) = {tmp.class};
            c4(end+1,1) = {num2str(data_MB,'%1.1f')};
        end
    end
    if strcmp(infovol.partial_wetting_representation,'Heterogeneous')
        c1(end+1,1) = {'Wetting'};
        c2(end+1,1) = {infovol.loadingpath_wetting};
        tmp=whos('M_wetting'); data_MB=tmp.bytes*9.53674e-7;
        c3(end+1,1) = {tmp.class};
        c4(end+1,1) = {num2str(data_MB,'%1.1f')};
    end
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    c1(end+1,1) = {'Instance labels'};
    c2(end+1,1) = {infovol.loadingpath_instance};
    tmp=whos('M_instance'); data_MB_ins=tmp.bytes*9.53674e-7;
    c3(end+1,1) = {tmp.class};
    c4(end+1,1) = {num2str(data_MB_ins,'%1.1f')};
end
Table_imported = table(c1, c2, c3, c4, 'VariableNames',{'Imported file', 'Path', 'Format', 'Size (MB)'});

if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    Table_phase_semantic = table(infovol.phasename_semantic,infovol.phaselabel_semantic,...
        'VariableNames',{'Phase name (semantic)' 'Phase label'});
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    Table_phase_BWinstance = table(infovol.phasename_instance,infovol.phaselabel_instance(:,1),...
        'VariableNames',{'Phase name (binary instance)' 'Phase label'});
    Table_phase_instance = table([{'Min label'};{'Max label'};{'Number of labels'}],[min(min(min(M_instance)));max(max(max(M_instance)));infovol.ninstance],...
        'VariableNames',{'Phase info (instance)' 'Value'});    
end

Table_volumeinformation = table(infovol.volumeinformation(:,1),infovol.volumeinformation(:,2),...
    'VariableNames',{'Information' 'Text'});

disp ' ';
if infovol.isbackground
    disp('First label is background and will be excluded from the analysis');
end
if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    disp(Table_phase_semantic);disp ' ';
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    disp(Table_phase_instance);disp ' ';
    disp(Table_phase_BWinstance);disp ' ';
end
disp(Table_domainsize);disp ' ';

if optc.save.xls
    % Intialization
    sheet_number=0;
    clear DATA_writetable
    % Input/output
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='Imported_files';
    DATA_writetable.sheet(sheet_number).table=Table_imported;
    % Volume information
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='Volume_information';
    DATA_writetable.sheet(sheet_number).table=Table_volumeinformation;
    % Phase name
    if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='Phase (semantic)';
        DATA_writetable.sheet(sheet_number).table=Table_phase_semantic;
    end
    if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='Phase (instance)';
        DATA_writetable.sheet(sheet_number).table=Table_phase_instance;
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='Phase (binary instance)';
        DATA_writetable.sheet(sheet_number).table=Table_phase_BWinstance;
    end 
    % Domain size
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='sz';
    DATA_writetable.sheet(sheet_number).table=Table_domainsize;
    % Voxel
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='Voxel';
    DATA_writetable.sheet(sheet_number).table=Table_voxel;
    % User information
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='User_information';
    DATA_writetable.sheet(sheet_number).table=Table_User;
    % Date
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='Start_date';
    DATA_writetable.sheet(sheet_number).table=Table_date;
    % Version information
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='MATBOX version';
    DATA_writetable.sheet(sheet_number).table=Table_toolbox;
    % Author information
    sheet_number=sheet_number+1;
    DATA_writetable.sheet(sheet_number).name='MATBOX authors';
    DATA_writetable.sheet(sheet_number).table=Table_author;

    % Filename without extension
    filename = 'General_information';
    % Save function
    Function_Writetable(infovol.volpath,filename,DATA_writetable)
end


%% TIME
time_cpu_start = cputime; % CPU start
tStart = tic; % Stopwatch start
date_start = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss Z'); % Date start

%%
%% SETUP VOLUME
%%
disp '********************';
disp '>>> SETUP VOLUME <<<';
disp '********************';
disp ' ';

%% REGION OF INTEREST
ROI_do = false;
if strcmp(mode,'Set parameters for each volume independently')
    ROI_size = infovol.ROI(:,2)-infovol.ROI(:,1)+1;    
    ROI_size_unit = ROI_size*infovol.initial_voxelsize;
    if number_direction==2
        equivalent_squareROI_size_unit = prod(ROI_size_unit)^(1/2);
        Table_domainsize_ROI = table([1;2],[infovol.directionname(1); infovol.directionname(2)], infovol.ROI(:,1),infovol.ROI(:,2), ROI_size, ROI_size_unit, [equivalent_squareROI_size_unit; equivalent_squareROI_size_unit],...
            'VariableNames',{'Direction', 'Name', 'ROI Start', 'ROI End', 'Number of voxel', ['Length ' infovol.unit], ['Equivalent squareroot length ' infovol.unit]});
    else
        equivalent_cubicROI_size_unit = prod(ROI_size_unit)^(1/3);
        Table_domainsize_ROI = table([1;2;3],[infovol.directionname(1); infovol.directionname(2); infovol.directionname(3)], infovol.ROI(:,1),infovol.ROI(:,2), ROI_size, ROI_size_unit, [equivalent_cubicROI_size_unit; equivalent_cubicROI_size_unit; equivalent_cubicROI_size_unit],...
            'VariableNames',{'Direction', 'Name', 'ROI Start', 'ROI End', 'Number of voxel', ['Length ' infovol.unit], ['Equivalent cubicroot length ' infovol.unit]});
    end

    % Check if crop required
    if number_direction==2
        check_ROI_start = min(infovol.ROI(:,1)==[1;1]);
        check_ROI_end = min(infovol.ROI(:,2)==[sz(1);sz(2)]);
    else
        check_ROI_start = min(infovol.ROI(:,1)==[1;1;1]);
        check_ROI_end = min(infovol.ROI(:,2)==[sz(1);sz(2);sz(3)]);
    end

    if check_ROI_start*check_ROI_end==0 % Compare with region of interest
        % Crop
        ROI_do = true;
        if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
            if number_direction==2
                M_semantic = M_semantic( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2));
                M_nanoporosity = M_nanoporosity( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2));
                if ~isempty(M_bulkdiffusivity)
                    M_bulkdiffusivity = M_bulkdiffusivity( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2));
                end
                if ~isempty(M_bulkconductivity)
                    M_bulkconductivity = M_bulkconductivity( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2));
                end
                M_wetting = M_wetting( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2));
            else
                M_semantic = M_semantic( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2) , infovol.ROI(3,1):infovol.ROI(3,2));
                M_nanoporosity = M_nanoporosity( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2) , infovol.ROI(3,1):infovol.ROI(3,2));
                if ~isempty(M_bulkdiffusivity)
                    M_bulkdiffusivity = M_bulkdiffusivity( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2) , infovol.ROI(3,1):infovol.ROI(3,2));
                end
                if ~isempty(M_bulkconductivity)
                    M_bulkconductivity = M_bulkconductivity( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2) , infovol.ROI(3,1):infovol.ROI(3,2));
                end
                M_wetting = M_wetting( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2) , infovol.ROI(3,1):infovol.ROI(3,2));
            end
            sz = size(M_semantic);
        end
        if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
            if number_direction==2
                M_instance = M_instance( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2));
            else
                M_instance = M_instance( infovol.ROI(1,1):infovol.ROI(1,2) , infovol.ROI(2,1):infovol.ROI(2,2) , infovol.ROI(3,1):infovol.ROI(3,2));
            end
            sz = size(M_instance);
        end        

        Table_voxel_ROI = table([{['Voxel size (' infovol.unit ')']};{'Number of voxel'}], [infovol.initial_voxelsize; prod(sz)],...
            'VariableNames',{'Information', 'Value'});

        disp 'Volume has been cropped'; disp ' ';
        disp(Table_domainsize_ROI); disp ' ';
        disp(Table_voxel_ROI);disp ' ';
    else
        disp 'Volume has NOT been crooped';  disp ' ';
        Table_voxel_ROI = Table_voxel;
        Table_domainsize_ROI = Table_domainsize;
    end
else
    disp 'Volume has NOT been crooped';  disp ' ';
    Table_voxel_ROI = Table_voxel;
    Table_domainsize_ROI = Table_domainsize;
end

if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    tmp=whos('M_semantic'); data_cropMB_sem=tmp.bytes*9.53674e-7;
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    tmp=whos('M_instance'); data_cropMB_ins=tmp.bytes*9.53674e-7;
end
cropped_numbervoxel = prod(sz);


%% SCALING (IMAGE RESOLUTION)
if infovol.scaling_factor ~= 1.0
    parameters_scaling.scaling_factor = infovol.scaling_factor;

    % Scale
    if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
        parameters_scaling.background = min(infovol.phaselabel_semantic);
        parameters_scaling.label_or_greylevel = 'Label';
        M_semantic_rescaled = function_scaling(M_semantic,parameters_scaling);
        sz = size(M_semantic_rescaled);        
        
        if strcmp(infovol.nanoporosity_representation,'Mixed (heterogeneous)')
            parameters_scaling.label_or_greylevel = 'Grey level';
            if parameters_scaling.scaling_factor<=1
                M_nanoporosity = function_scaling(M_nanoporosity,parameters_scaling);
            else
                [~,M_nanoporosity] = function_downscaling_perlabel(M_semantic,M_nanoporosity,parameters_scaling);
            end
        else
            M_nanoporosity = zeros(sz,'single')-1;
            if infovol.isbackground
                k0 = 2;
            else
                k0 = 1;
            end
            for k=k0:length(infovol.phaselabel_semantic)
                M_nanoporosity(M_semantic_rescaled==infovol.phaselabel_semantic(k)) = cell2mat(infovol.nanoporosity(k));
            end
        end

        if strcmp(infovol.partial_wetting_representation,'Heterogeneous')
            parameters_scaling.label_or_greylevel = 'Grey level';
            if parameters_scaling.scaling_factor<=1
                M_wetting = function_scaling(M_wetting,parameters_scaling);
            else
                [~,M_wetting] = function_downscaling_perlabel(M_semantic,M_wetting,parameters_scaling);
            end
        elseif strcmp(infovol.partial_wetting_representation,'Ideal')
            M_wetting = ceil(M_nanoporosity); % 0 or 1
        elseif strcmp(infovol.partial_wetting_representation,'Uniform')
            M_wetting = zeros(sz,'single')-1;
            if infovol.isbackground
                k0 = 2;
            else
                k0 = 1;
            end
            for k=k0:length(infovol.phaselabel_semantic)
                if strcmp(infovol.partial_wetting_value_is,'Air saturation') % Convert to wetting
                    M_wetting(M_semantic_rescaled==infovol.phaselabel_semantic(k)) = 1-cell2mat(infovol.air_saturation(k));
                else
                    M_wetting(M_semantic_rescaled==infovol.phaselabel_semantic(k)) = cell2mat(infovol.wetting(k));
                end
            end
        end

        if ~isempty(M_bulkdiffusivity)
            if strcmp(infovol.poretransport_representation,'Diffusivity D (heterogeneous)')
                parameters_scaling.label_or_greylevel = 'Grey level';
                if parameters_scaling.scaling_factor<=1
                    M_bulkdiffusivity = function_scaling(M_bulkdiffusivity,parameters_scaling);
                else
                    [~,M_bulkdiffusivity] = function_downscaling_perlabel(M_semantic,M_bulkdiffusivity,parameters_scaling);
                end
            else
                M_bulkdiffusivity = zeros(sz,'single')-1;
                if infovol.isbackground
                    k0 = 2;
                else
                    k0 = 1;
                end
                for k=k0:length(infovol.phaselabel_semantic)
                    if ~ischar(cell2mat(infovol.poretransport(k)))
                        M_bulkdiffusivity(M_semantic_rescaled==infovol.phaselabel_semantic(k)) = cell2mat(infovol.poretransport(k));
                    end
                end
                if strcmp(infovol.poretransport_representation,'Bruggeman exponent p (uniform)') % Need to convert into diffusivity
                    M_bulkdiffusivity = (M_nanoporosity.*M_wetting).^M_bulkdiffusivity;
                end
            end
        end

        if ~isempty(M_bulkconductivity)
            if strcmp(infovol.solidtransport_representation,'Conductivity K (heterogeneous)')
                parameters_scaling.label_or_greylevel = 'Grey level';
                if parameters_scaling.scaling_factor<=1
                    M_bulkconductivity = function_scaling(M_bulkconductivity,parameters_scaling);
                else
                    [~,M_bulkconductivity] = function_downscaling_perlabel(M_semantic,M_bulkconductivity,parameters_scaling);
                end
            else
                M_bulkconductivity = zeros(sz,'single')-1;
                if infovol.isbackground
                    k0 = 2;
                else
                    k0 = 1;
                end
                for k=k0:length(infovol.phaselabel_semantic)
                    if ~ischar(cell2mat(infovol.solidtransport(k)))
                        M_bulkconductivity(M_semantic_rescaled==infovol.phaselabel_semantic(k)) = cell2mat(infovol.solidtransport(k));
                    end
                end
                if strcmp(infovol.solidtransport_representation,'Bruggeman exponent p (uniform)') % Need to convert into diffusivity
                    M_bulkconductivity = (1-M_nanoporosity).^M_bulkconductivity;
                end
            end
        end        

        M_semantic = M_semantic_rescaled;
        clear M_semantic_rescaled;
    end
    if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
        parameters_scaling.label_or_greylevel = 'Label';
        parameters_scaling.background = min(infovol.phaselabel_instance);
        M_instance = function_scaling(M_instance,parameters_scaling);
        sz = size(M_semantic);
    end
    Domain_size_unit = sz*infovol.voxelsize;
    % Create table
    if number_direction==2
        equivalent_square_size_unit = prod(Domain_size_unit)^(1/2);
        Table_domainsize_ROI_scaling = table([1;2],[infovol.directionname(1); infovol.directionname(2)], [sz(1); sz(2)],[Domain_size_unit(1); Domain_size_unit(2)], [equivalent_square_size_unit;equivalent_square_size_unit],...
            'VariableNames',{'Direction', 'Name', 'Number of voxel' ['Length ' infovol.unit] ['Equivalent squareroot length ' infovol.unit]});
    else
        equivalent_cubic_size_unit = prod(Domain_size_unit)^(1/3);
        Table_domainsize_ROI_scaling = table([1;2;3],[infovol.directionname(1); infovol.directionname(2); infovol.directionname(3)], [sz(1); sz(2); sz(3)],[Domain_size_unit(1); Domain_size_unit(2); Domain_size_unit(3)], [equivalent_cubic_size_unit; equivalent_cubic_size_unit; equivalent_cubic_size_unit],...
            'VariableNames',{'Direction', 'Name', 'Number of voxel' ['Length ' infovol.unit] ['Equivalent cubicroot length ' infovol.unit]});
    end
    Table_voxel_ROI_scaling = table([{['Voxel size (' infovol.unit ')']};{'Number of voxel'}], [infovol.voxelsize; prod(sz)],...
        'VariableNames',{'Information', 'Value'});

    disp 'Voxel size has been changed';  disp ' ';
    disp(Table_domainsize_ROI_scaling);disp ' ';
    disp(Table_voxel_ROI_scaling);disp ' ';
else
    Table_domainsize_ROI_scaling = Table_domainsize_ROI;
    Table_voxel_ROI_scaling = Table_voxel_ROI;
    disp 'Voxel size has NOT been changed';  disp ' ';
end

if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    tmp=whos('M_semantic'); data_voxelresizeMB_sem=tmp.bytes*9.53674e-7;
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    tmp=whos('M_instance'); data_voxelresizeMB_ins=tmp.bytes*9.53674e-7;
end
voxelresize_numbervoxel = prod(sz);

%% MEMORY
if strcmp(segmentation_type,'semantic')
    Table_memory = table([{'Loaded data'};{'Region of interest'};{'Voxel resize'}],[initial_numbervoxel;cropped_numbervoxel;voxelresize_numbervoxel], [data_MB_sem;data_cropMB_sem;data_voxelresizeMB_sem],...
        'VariableNames',{'Microstructure array','Number of voxel', 'Memory MB'});
elseif strcmp(segmentation_type,'instance')
    Table_memory = table([{'Loaded data'};{'Region of interest'};{'Voxel resize'}],[initial_numbervoxel;cropped_numbervoxel;voxelresize_numbervoxel], [data_MB_ins;data_cropMB_ins;data_voxelresizeMB_ins],...
        'VariableNames',{'Microstructure array','Number of voxel', 'Memory MB'});
elseif strcmp(segmentation_type,'semantic and instance')
    Table_memory = table([{'Loaded data'};{'Region of interest'};{'Voxel resize'}],[initial_numbervoxel;cropped_numbervoxel;voxelresize_numbervoxel], [{[num2str(data_MB_sem) '/' num2str(data_MB_ins)]};{[num2str(data_cropMB_sem) '/' num2str(data_cropMB_ins)]};{[num2str(data_voxelresizeMB_sem) '/' num2str(data_voxelresizeMB_ins)]}],...
        'VariableNames',{'Microstructure array','Number of voxel', 'Memory MB (semantic/instance)'});
end

%% SAVE INVESTIGATED VOLUME
if (ROI_do || infovol.scaling_factor ~= 1.0) && optc.save.modified_inputfiles
    volume_folder = fullfile(infovol.volpath,'Volume');
    if ~exist(volume_folder,'dir')
        mkdir(volume_folder);
    end

    disp(' ');
    fprintf('Save modified files in folder: %s\n',volume_folder);
    fprintf('        Please wait...');

    if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
        function_save_tif(M_semantic, fullfile(volume_folder,'Modified_semanticvolume.tif'));
        if strcmp(infovol.nanoporosity_representation,'Mixed (heterogeneous)')
            function_save_tif(M_nanoporosity, fullfile(volume_folder,'Modified_nanoporosity.tif'));
        end
        if ~isempty(M_bulkdiffusivity)
            function_save_tif(M_bulkdiffusivity, fullfile(volume_folder,'Modified_bulkdiffusivity.tif'));
        end
        if ~isempty(M_bulkconductivity)
            function_save_tif(M_bulkconductivity, fullfile(volume_folder,'Modified_bulkconductivity.tif'));
        end
        if strcmp(infovol.partial_wetting_representation,'Heterogeneous')
            function_save_tif(M_wetting, fullfile(volume_folder,'Modified_wetting.tif'));
        end
    end
    if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
        function_save_tif(M_instance, fullfile(volume_folder,'Modified_instancevolume.tif'));
    end
    fprintf('   Done!\n');
end


%% SAVE INFORMATION IN EXCEL SHEET
if (ROI_do || infovol.scaling_factor ~= 1.0)
    if optc.save.xls
        % Intialization
        sheet_number=0;
        clear DATA_writetable
        % Region of interest: domain size
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='ROI_domainsize';
        DATA_writetable.sheet(sheet_number).table=Table_domainsize_ROI;
        % Region of interest: Voxel
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='ROI_voxelsize';
        DATA_writetable.sheet(sheet_number).table=Table_voxel_ROI;
        % Voxel resize: domain size
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='Scaling_domainsize';
        DATA_writetable.sheet(sheet_number).table=Table_domainsize_ROI_scaling;
        % Voxel resize: Voxel
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='Scaling_voxelsize';
        DATA_writetable.sheet(sheet_number).table=Table_voxel_ROI_scaling;
        % Size
        sheet_number=sheet_number+1;
        DATA_writetable.sheet(sheet_number).name='Memory';
        DATA_writetable.sheet(sheet_number).table=Table_memory;

        % Filename without extension
        filename = 'Volume_setup';
        % Save function
        Function_Writetable(infovol.volpath,filename,DATA_writetable)
    end
end


%%
%% CHARACTERIZATION
%%

disp '********************';
disp '>>> CALCULATIONS <<<';
disp '********************';
disp ' ';

foo=1; % Un-used inputs to have a different number of argument between GUI and standalone use for some functions.

if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    infovol_sem = infovol;
    [~,tmp1,tmp2]=fileparts(infovol.loadingpath_semantic);
    infovol_sem.filename = [tmp1 tmp2];
    if strcmp(segmentation_type,'semantic and instance')
        infovol_sem.sub = 'semantic';
    else
        infovol_sem.sub = [];
    end        
    infovol_sem.phaselabel = infovol.phaselabel_semantic;
    infovol_sem.phasename = infovol.phasename_semantic;
    infovol_sem.phasecolor = infovol.phasecolor_semantic;
end

if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    infovol_ins = infovol;
    [~,tmp1,tmp2]=fileparts(infovol.loadingpath_instance);
    infovol_ins.filename = [tmp1 tmp2];    
    if strcmp(segmentation_type,'semantic and instance')
        infovol_ins.sub = 'Instance';
    else
        infovol_ins.sub = [];
    end    
    infovol_ins.phaselabel = infovol.phaselabel_instance;
    infovol_ins.phasename = infovol.phasename_instance;
    infovol_ins.phasecolor = infovol.phasecolor_instance;

    M_binaryinstance = M_instance;
    if infovol.isbackground
        M_binaryinstance(M_binaryinstance>1)=2;
    else        
        M_binaryinstance(M_binaryinstance~=0)=1;
    end
end

%% VOLUME FRACTIONS
if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    if sum(opts_sem.volumefraction.todo)
        disp '    VOLUME FRACTIONS: semantic file';
        disp '    -------------------------------';
        disp ' ';
        Charact_Volumefractions_main(M_semantic, M_nanoporosity, M_wetting, infovol_sem, optc, opts_sem.volumefraction) % Call function
    end
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    if sum(opts_ins.volumefraction.todo)
        disp '    VOLUME FRACTIONS: Binary instance file';
        disp '    --------------------------------------';
        disp ' ';        
        Charact_Volumefractions_main(M_binaryinstance, [], [], infovol_ins, optc, opts_ins.volumefraction) % Call function
    end
end

%% TORTUOSITY
if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    if sum(opts_sem.tortuosity.todo)>=1 || opts_sem.tortuosity.pore_combined_todo || opts_sem.tortuosity.solid_combined_todo
        disp '    TORTUOSITY FACTOR: semantic file';
        disp '    --------------------------------';
        disp ' ';
        Charact_Tortuosity_main(M_semantic, M_nanoporosity, M_wetting, M_bulkdiffusivity, M_bulkconductivity, infovol_sem, optc, opts_sem.tortuosity) % Call function
    end
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    if sum(opts_ins.tortuosity.todo)
        disp '    TORTUOSITY FACTOR: Binary instance file';
        disp '    ---------------------------------------';
        disp ' ';        
        Charact_Tortuosity_main(M_binaryinstance, [], [], [], [], infovol_ins, optc, opts_ins.tortuosity) % Call function
    end
end

%% Continuous particle size distribution CPSD
if strcmp(segmentation_type,'semantic') || strcmp(segmentation_type,'semantic and instance')
    if sum(opts_sem.cpsd.todo)
        disp '    Continuous particle size distribution (CPSD): semantic file';
        disp '    -----------------------------------------------------------';
        disp ' ';
        Charact_Cpsd_main(M_semantic, infovol_sem, optc, opts_sem.cpsd, foo) % Call function
    end
end
if strcmp(segmentation_type,'instance') || strcmp(segmentation_type,'semantic and instance')
    if sum(opts_ins.cpsd.todo)
        disp '    Continuous particle size distribution (CPSD): Binary instance file';
        disp '    ------------------------------------------------------------------';
        disp ' ';        
        Charact_Cpsd_main(M_binaryinstance, infovol_ins, optc, opts_ins.cpsd, M_instance) % Call function
    end
end
% 
% %% METRICS PER PARTICLE
% if ~isempty(opts_ins) && opts_ins.metricsperparticle.todo
%     if strcmp(segmentation_type,'instance')
%         disp '    Metrics per particle (instance only)';
%         disp '    ------------------------------------';
%         disp ' ';        
%         Charact_Metricsperparticle(M_instance, [], infovol_ins, optc, opts_ins.metricsperparticle) % Call function
%     elseif strcmp(segmentation_type,'semantic and instance')
%         disp '    Metrics per particle (semantic and instance)';
%         disp '    --------------------------------------------';
%         disp ' ';           
%         Charact_Metricsperparticle(M_instance, M_semantic, infovol_ins, optc, opts_ins.metricsperparticle) % Call function
%     end
% end


%% TAG
if ~isempty(tag)
    results_correlation(1).tag = tag;
    results_correlation(1).tag_unit = tag_unit;
    correlation_folder = fullfile(infovol.volpath, 'Correlation');
    if exist(correlation_folder,'dir')==0 % Folder existence is checked, and created if necessary
        mkdir(correlation_folder);
    end
    save(fullfile(correlation_folder, 'Correlation_tag.mat'),'results_correlation');
end


%%
%% SUMMARY
%%

%% TIME
summary_folder = fullfile(infovol.volpath, 'Summary');
if ~exist(summary_folder,'dir')
    mkdir(summary_folder);
end

time_cpu_elapsed = cputime-time_cpu_start; % CPU elapsed time
time_stopwatch_elapsed = toc(tStart); % Stopwatch elapsed time
date_end = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss Z');
% time table
Table_time = table({'Date start';'Date end';'Elasped time (hh:mm:ss)';'Elasped time (s), tic-toc';'CPU time (s)'} ,{char(date_start);char(date_end);char(date_end-date_start);num2str(time_stopwatch_elapsed,'%1.1f');num2str(time_cpu_elapsed,'%1.1f')},...
    'VariableNames',{'Information' 'text'});
disp ' ';
disp '***********************';
disp '>>> RESULTS SUMMARY <<<';
disp '***********************';
disp ' ';
disp(Table_time)
if optc.save.xls
    filename = 'Time'; % Filename without extension
    % Prepare the data
    clear DATA_writetable
    DATA_writetable.sheet(1).name='Time';
    DATA_writetable.sheet(1).table=Table_time;
    % Save function
    Function_Writetable(summary_folder,filename,DATA_writetable)
end

%% SUMMARIZE RESULTS
if optc.save.mat              
    % function_summary_onevolume(summary_folder, infovol, optc);
end

end



% 
% 
% %% CONNECTIVITY
% if opts.connectivity.todo
%      Function_connectivity(M_semantic, infovol, optc, opts.connectivity) % Call function
% end
% 
% %% TORTUOSITY FACTORS
% if sum(opts.tortuosity.todo)
%     Function_Tortuosity_factor_taufactor(M_semantic, infovol, optc, opts.tortuosity) % Call function
% end
% 
% %% SPECIFIC SURFACE AREA, DIRECT
% if sum(opts.Sp_direct.todo)
%     Function_Specificsurface_direct(M_semantic, infovol, optc, opts.Sp_direct, foo, foo) % Call function
% end
% 
% %% SPECIFIC INTERFACE AREA, DIRECT
% if opts.Int_direct.todo
%     Function_Specificinterface_direct(M_semantic, infovol, optc, opts.Int_direct, foo, foo) % Call function
% end
% 
% %% TRIPLE PHASE BOUNDARY LENGTH, DIRECT
% if opts.TPBL_direct.todo
%     Function_TPBL_direct(M_semantic, infovol, optc, opts.TPBL_direct, foo, foo) % Call function
% end
% 
% %% DIAMETER, C-PSD
% if sum(opts.D_cpsd.todo)
%     Function_particle_size_CPSD(M_semantic, infovol, optc, opts.D_cpsd, foo) % Call function
% end
% 
% %% DIAMETER, EDMF
% if sum(opts.D_edmf.todo)
%     Function_particle_size_EDMF(M_semantic, infovol, optc, opts.D_edmf) % Call function
% end
% 
% %% DIAMETER, CHORD
% if sum(opts.D_chord.todo)
%     Function_particle_size_CHORD(M_semantic, infovol, optc, opts.D_chord) % Call function
% end
% 
% %% DIAMETER, WATERSHED
% if sum(opts.D_watershed.todo)
%     Function_particle_size_Watershed(M_semantic, infovol, optc, opts.D_watershed) % Call function
% end
% 
% % Chord: harmonize with EDMF
% 
% % Tau
% 
% % Convergence(RVE), and RVE(RVE)
% 
% % Article on RVE
% 
% % Article on fractal/voxel size
% % I know what fractal dimension will bring: we can compare Sp or TPBL from two different materials, only if they
% % share same voxel size, and same fractal dimension (indicator of the surface roughness)
% 
% % Publish on Github (legacy and new version in choice menu)
% 
% % Connectivity
% 
% % Publish on Github
% 
% % Watershed
% % PCRF
% 
% % Publish on Github
% 
% % Tutorial video
% 
% % Correlation module
% 
% %%
% %% SUMMARY
% %%
% 
% %% TIME
% summary_folder = [infovol.volpath 'Summary' separator]; 
% if ~exist(summary_folder,'dir') % Check existence of the main folder
%     mkdir(summary_folder); % Create folder if not exist
% end
% 
% time_cpu_elapsed = cputime-time_cpu_start; % CPU elapsed time
% time_stopwatch_elapsed = toc(tStart); % Stopwatch elapsed time
% date_end = datetime('now','TimeZone','local','Format','d-MMM-y HH:mm:ss Z');
% % time table
% Table_time = table({'Date start';'Date end';'Elasped time (hh:mm:ss)';'Elasped time (s), tic-toc';'CPU time (s)'} ,{char(date_start);char(date_end);char(date_end-date_start);num2str(time_stopwatch_elapsed,'%1.1f');num2str(time_cpu_elapsed,'%1.1f')},...
%     'VariableNames',{'Information' 'text'});
% disp ' ';
% disp '***********************';
% disp '>>> RESULTS SUMMARY <<<';
% disp '***********************';
% disp ' ';
% disp(Table_time)
% if optc.save.xls
%     filename = 'Time'; % Filename without extension
%     % Prepare the data
%     clear DATA_writetable
%     DATA_writetable.sheet(1).name='Time';
%     DATA_writetable.sheet(1).table=Table_time;
%     % Save function
%     Function_Writetable(summary_folder,filename,DATA_writetable)
% end
% 
% %% SUMMARIZE RESULTS
% if optc.save.mat              
%     function_summary_onevolume(summary_folder, infovol, optc, opts);
% end
% 
% end