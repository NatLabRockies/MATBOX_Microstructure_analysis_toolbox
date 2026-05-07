function [threshold_lowervalue, threshold_highervalue] = fct_contrastsaturation_algo(M,p)

% % Threshold will be identified using a Dichotomy approach.
% Faster than compute histogram.
max_=max(M);
min_=min(M);
number_voxel = numel(M);

threshold_lowervalue = [];
threshold_highervalue = [];

if p.volumethreshold_above~=0
    threshold_highervalue=max_;
    error_=1e9; iteration_no=0;
    while error_>p.target_error && iteration_no<p.max_iteration % Dichotomy loop
        iteration_no=iteration_no+1; % Update iteration number
        current_threshold=min_+round((max_-min_)/2); % Current threshold
        % Calculate volume
        volume_ratio = 100*sum(sum(sum(M>current_threshold)))/number_voxel;
        % Check error
        rel_error=volume_ratio-p.volumethreshold_above;
        error_=abs(rel_error);
        % Keep going if error is still too high
        if error_<p.target_error
            % Exit the while loop
            break
        else
            % Update the interval
            if rel_error>0
                min_= current_threshold;
            else
                max_=current_threshold;
            end
        end
    end
    threshold_highervalue=current_threshold;
end

if p.volumethreshold_below~=0
    max_=max(max(max(M)));
    min_=min(min(min(M)));
    threshold_lowervalue=min_;
    error_=1e9; iteration_no=0;
    while error_>p.target_error && iteration_no<p.max_iteration % Dichotomy loop
        iteration_no=iteration_no+1; % Update iteration number
        current_threshold=min_+round((max_-min_)/2); % Current threshold
        % Calculate volume
        volume_ratio = 100*sum(sum(sum(M<current_threshold)))/number_voxel;
        % Check error
        rel_error=volume_ratio-p.volumethreshold_below;
        error_=abs(rel_error);
        % Keep going if error is still too high
        if error_<p.target_error
            % Exit the while loop
            break
        else
            % Update the interval
            if rel_error>0
                max_= current_threshold;
            else
                min_=current_threshold;
            end
        end
    end
    threshold_lowervalue=current_threshold;
end

end