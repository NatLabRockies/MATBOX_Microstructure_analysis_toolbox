function [Property_subdomains_statistics, Size_RVE, Difference_convergence, Size_convergence] = RVE_statisticalanalysis(number_group_size,number_domain_todo,GROUP_SUBDOMAIN,Property_eachsubdomain,voxel_size,pRVE,dimension)

%% You have to have the Statistics Toolbox to use the tinv function
% To avoid this requirement, here is a replacement
% Source: https://www.mathworks.com/matlabcentral/answers/159417-how-to-calculate-the-confidence-interval
% Variables: 
% t: t-statistic
% v: degrees of freedom
tdist2T = @(t,v) (1-betainc(v/(v+t^2),v/2,0.5));    % 2-tailed t-distribution
tdist1T = @(t,v) 1-(1-tdist2T(t,v))/2;              % 1-tailed t-distribution
% This calculates the inverse t-distribution (parameters given the
%   probability ‘alpha’ and degrees of freedom ‘v’: 
t_inv = @(alpha,v) fzero(@(tval) (max(alpha,(1-alpha)) - tdist1T(tval,v)), 5);  % T-Statistic Given Probability ‘alpha’ & Degrees-Of-Freedom ‘v’

%% STATS
Property_subdomains_statistics = zeros(number_group_size,18,number_domain_todo);
% Each row corresponds to a different ideal size
% column 1 : size 1: equivalent cubic length
% column 2 : size 2: equivalent square root length
% column 3 : size 3: length
% column 4 : number of subdomains with the same size
% column 5 : mean value
% column 6 : standard deviation, only calculated if number of subdomains is >2
% column 7 : standard deviation expressed in % of the mean value
% column 8 : minimun
% column 9 : maximum
% column 10: maximum - minimum
% column 11-13: subdomain aspect ratio (AR)
% column 14: Standard Error Of The Mean std(y)/sqrt(N);
% column 15: 95% error interval
% column 16: number of volume required to have 1% error
% column 17: number of volume required to have 5% error
% column 18: number of volume required to have 10% error

for current_domain_todo=1:1:number_domain_todo
    for group_subdomain = 1:1:number_group_size
        AR = GROUP_SUBDOMAIN.id(group_subdomain).Aspectratio;
        % Number of subdomain sharing this size
        number_subdomain_withingroup = length(GROUP_SUBDOMAIN.id(group_subdomain).domain_id);
        value_tmp =[];
        for current_subdomain=1:1:number_subdomain_withingroup
            subdomain_id=GROUP_SUBDOMAIN.id(group_subdomain).domain_id(current_subdomain);
            value_tmp=[value_tmp Property_eachsubdomain(subdomain_id,current_domain_todo+4)];
        end
        Property_subdomains_statistics(group_subdomain,1,current_domain_todo)= GROUP_SUBDOMAIN.id(group_subdomain).equivalent_cubic_length;
        Property_subdomains_statistics(group_subdomain,2,current_domain_todo)= GROUP_SUBDOMAIN.id(group_subdomain).equivalent_square_length;
        Property_subdomains_statistics(group_subdomain,3,current_domain_todo)= GROUP_SUBDOMAIN.id(group_subdomain).length;
        Property_subdomains_statistics(group_subdomain,4,current_domain_todo)=number_subdomain_withingroup - sum(isnan(value_tmp));
        Property_subdomains_statistics(group_subdomain,5,current_domain_todo)=mean(value_tmp,"omitnan");
        Property_subdomains_statistics(group_subdomain,6,current_domain_todo)=std(value_tmp,"omitnan");
        Property_subdomains_statistics(group_subdomain,7,current_domain_todo)=Property_subdomains_statistics(group_subdomain,6,current_domain_todo)*100/Property_subdomains_statistics(group_subdomain,5,current_domain_todo);
        Property_subdomains_statistics(group_subdomain,8,current_domain_todo)=min(value_tmp);
        Property_subdomains_statistics(group_subdomain,9,current_domain_todo)=max(value_tmp);
        Property_subdomains_statistics(group_subdomain,10,current_domain_todo) = max(value_tmp)-min(value_tmp);
        Property_subdomains_statistics(group_subdomain,11,current_domain_todo)=AR(1);
        Property_subdomains_statistics(group_subdomain,12,current_domain_todo)=AR(2);
        if dimension == 3
            Property_subdomains_statistics(group_subdomain,13,current_domain_todo)=AR(3);
        else
            Property_subdomains_statistics(group_subdomain,13,current_domain_todo)=0;
        end
        Property_subdomains_statistics(group_subdomain,14,current_domain_todo)=Property_subdomains_statistics(group_subdomain,6,current_domain_todo)/sqrt(number_subdomain_withingroup);
        % ts = tinv([0.025  0.975],number_subdomain_withingroup-1);      % T-Score. Require Statistics Toolbox
        % Property_subdomains_statistics(group_subdomain,14,current_domain_todo) = abs(ts(1))*Property_subdomains_statistics(group_subdomain,13,current_domain_todo);   
        % Instead:
        if number_subdomain_withingroup>1
            ts = t_inv(0.025,number_subdomain_withingroup-1);
            Property_subdomains_statistics(group_subdomain,15,current_domain_todo) = ts*Property_subdomains_statistics(group_subdomain,14,current_domain_todo); % 2.5% confidence interval
        end
        %Property_subdomains_statistics(group_subdomain,15,current_domain_todo) = Property_subdomains_statistics(group_subdomain,6,current_domain_todo)^2 / (0.01^2 * Property_subdomains_statistics(group_subdomain,5,current_domain_todo)^2);
        %Property_subdomains_statistics(group_subdomain,16,current_domain_todo) = Property_subdomains_statistics(group_subdomain,6,current_domain_todo)^2 / (0.05^2 * Property_subdomains_statistics(group_subdomain,5,current_domain_todo)^2);
        %Property_subdomains_statistics(group_subdomain,17,current_domain_todo) = Property_subdomains_statistics(group_subdomain,6,current_domain_todo)^2 / (0.10^2 * Property_subdomains_statistics(group_subdomain,5,current_domain_todo)^2);

    end
    % Subdomains are sorted with size
    idx_size = find(Property_subdomains_statistics(1,1:3,1) ~= 0);
    Property_subdomains_statistics (:,:,current_domain_todo) = sortrows(Property_subdomains_statistics(:,:,current_domain_todo),idx_size(1));
end
% Size are set in pysical unit
Property_subdomains_statistics(:,1,:)=Property_subdomains_statistics(:,1,:)*voxel_size;
Property_subdomains_statistics(:,2,:)=Property_subdomains_statistics(:,2,:)*voxel_size;
Property_subdomains_statistics(:,3,:)=Property_subdomains_statistics(:,3,:)*voxel_size;

% Initialize
Size_RVE = [];
Difference_convergence = [];
Size_convergence = [];

idx_size = find(Property_subdomains_statistics(1,1:3,1) ~= 0);

if strcmp(pRVE.analysis,'Independent subvolumes')
    thresholds = pRVE.threshold_subs_val; % Subvolumes
    n_threshold = length(thresholds);
    if strcmp(pRVE.threshold_subs_choice,'Relative standard deviation')
        idx_threshold = 7;
    elseif strcmp(pRVE.threshold_subs_choice,'Standard deviation')
        idx_threshold = 6;
    elseif strcmp(pRVE.threshold_subs_choice,'Maximum - minimum')
        idx_threshold = 10;
    end

    % The representative volume element is reached when the standard deviation
    % is lower or equal to a pRVE.threshold_std percent of the mean value
    % and calculated with a number of subdomains >= pRVE.threshold_numbersubvolumes
    Size_RVE=zeros(n_threshold,number_domain_todo,3,2);
    % *,*,1 RVE size inferior to
    % *,*,2 RVE size equal to
    % *,*,3 RVE size is superior to
    % *,*,*,1: with size1
    % *,*,*,2: with size2
    % By definition, case D,E,F are not representativity analysis
    % If RVE size can't be defined, than inferior or superior limit are defined

    for k_size=1:1:length(idx_size)
        for k_threshold=1:1:n_threshold
            for current_domain_todo=1:1:number_domain_todo

                % Select value for current phase, and remove analys performed on a too low number of subdomains
                tmp = Property_subdomains_statistics(:,:,current_domain_todo);
                [n_group_size,~]=size(tmp);

                if ~isempty(tmp)
                    idx=find(tmp(:,idx_threshold) > thresholds(k_threshold));
                    if ~isempty(idx)
                        if idx(end)==n_group_size % RVE >
                            Size_RVE(k_threshold,current_domain_todo,1,k_size) = 0;
                            Size_RVE(k_threshold,current_domain_todo,2,k_size) = 0;
                            Size_RVE(k_threshold,current_domain_todo,3,k_size) = tmp(end,idx_size(k_size));
                        else % RVE =
                            x1 = tmp(idx(end),idx_size(k_size)); x2 = tmp(idx(end)+1,idx_size(k_size));
                            y1 = tmp(idx(end),idx_threshold); y2 = tmp(idx(end)+1,idx_threshold);
                            if ~isnan(x1) && ~isnan(x2) && ~isnan(y1) && ~isnan(y2)
                                x = interp1([y1 y2],[x1 x2],thresholds(k_threshold),'linear');
                                Size_RVE(k_threshold,current_domain_todo,1,k_size) = 0;
                                Size_RVE(k_threshold,current_domain_todo,2,k_size) = x;
                                Size_RVE(k_threshold,current_domain_todo,3,k_size) = 0;
                            else
                                Size_RVE(k_threshold,current_domain_todo,1,k_size) = 0;
                                Size_RVE(k_threshold,current_domain_todo,2,k_size) = NaN;
                                Size_RVE(k_threshold,current_domain_todo,3,k_size) = 0;
                            end
                        end
                    else % RVE <
                        Size_RVE(k_threshold,current_domain_todo,1,k_size) = tmp(1,idx_size(k_size));
                        Size_RVE(k_threshold,current_domain_todo,2,k_size) = 0;
                        Size_RVE(k_threshold,current_domain_todo,3,k_size) = 0;
                    end
                end

            end
        end
    end
    
else
    thresholds = pRVE.threshold_onesub_val; % One volume
    n_threshold = length(thresholds);

    Difference_convergence = zeros(number_group_size,number_domain_todo+2);
    Difference_convergence(:,1) = Property_subdomains_statistics(:,idx_size(1),1);
    if length(idx_size)==2
        Difference_convergence(:,2) = Property_subdomains_statistics(:,idx_size(2),1);
    end

    for current_domain_todo=1:1:number_domain_todo
        lastvalue = Property_subdomains_statistics(end,5,current_domain_todo);
        for k=1:1:number_group_size
            currentvalue = Property_subdomains_statistics(k,5,current_domain_todo);
            if strcmp(pRVE.threshold_onesub_choice,'Relative difference')
                Difference_convergence(k,current_domain_todo+2) = abs(100*(currentvalue-lastvalue)/lastvalue);
            elseif strcmp(pRVE.threshold_onesub_choice,'Difference')
                Difference_convergence(k,current_domain_todo+2) = abs(currentvalue-lastvalue);
            end
        end
    end

    % Find convergence threshold
    Size_convergence=zeros(n_threshold,number_domain_todo,3,2); % *,*, < = >, size 1 size 2
    for k_threshold=1:1:n_threshold
        for current_domain_todo=1:1:number_domain_todo
            idx=find(Difference_convergence(:,current_domain_todo+2) > thresholds(k_threshold));
            if ~isempty(idx)
                idx=[idx(end) idx(end)+1];
                if idx(end)+1 == number_group_size
                    Size_convergence(k_threshold,current_domain_todo,3,1)= Property_subdomains_statistics(end,idx_size(1),current_domain_todo); % Convergence size is > x
                    if length(idx_size)==2
                        Size_convergence(k_threshold,current_domain_todo,3,2)=Property_subdomains_statistics(end,idx_size(2),current_domain_todo); % Convergence size is > x
                    end
                else
                    x1 = Difference_convergence(idx(1),1); x2 = Difference_convergence(idx(2),1);
                    y1 = Difference_convergence(idx(1),current_domain_todo+2); y2 = Difference_convergence(idx(2),current_domain_todo+2);
                    x = interp1([y1 y2],[x1 x2],thresholds(k_threshold),'linear');
                    Size_convergence(k_threshold,current_domain_todo,2,1)=x; % Convergence size is = x
                    if length(idx_size)==2
                        x1 = Difference_convergence(idx(1),2); x2 = Difference_convergence(idx(2),2);
                        x = interp1([y1 y2],[x1 x2],thresholds(k_threshold),'linear');
                        Size_convergence(k_threshold,current_domain_todo,2,2)=x; % Convergence size is = x
                    end
                end
            else
                Size_convergence(k_threshold,current_domain_todo,1,1)=Property_subdomains_statistics(1,idx_size(1),current_domain_todo); % Convergence size is < x
                if length(idx_size)==2
                    Size_convergence(k_threshold,current_domain_todo,1,2)=Property_subdomains_statistics(1,idx_size(2),current_domain_todo); % Convergence size is < x
                end
            end
        end
    end
end

% We can also determine a RVE from the error analysis
% N = 4*std^2 / (relative error^2 * mean^2)
% For N=1 and a given relative error, what should be the std ?
% Knowing std=f(subdomain volume), deduce the RVE size.
% This method is proposed in : T. Kanit et al. / International Journal of Solids and Structures 40 (2003) 3647–3679, page 3672

end

