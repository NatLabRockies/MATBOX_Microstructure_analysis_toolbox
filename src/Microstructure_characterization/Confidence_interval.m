function [CI,st,n] = Confidence_interval(vals,percent)
% Set percent = 2.5 (not 0.025) for +/- 2.5%
% Return confidence interval, standard deviation, and number of samples

% You need to have the Statistics Toolbox to use the tinv function
% To avoid this requirement, here is a replacement
% Source: https://www.mathworks.com/matlabcentral/answers/159417-how-to-calculate-the-confidence-interval
% Variables: 
% t: t-statistic
% v: degrees of freedom
tdist2T = @(t,v) (1-betainc(v/(v+t^2),v/2,0.5));    % 2-tailed t-distribution
tdist1T = @(t,v) 1-(1-tdist2T(t,v))/2;              % 1-tailed t-distribution
% This calculates the inverse t-distribution (parameters given the
%   probability 'alpha' and degrees of freedom 'v': 
t_inv = @(alpha,v) fzero(@(tval) (max(alpha,(1-alpha)) - tdist1T(tval,v)), 5);  % T-Statistic Given Probability 'alpha' & Degrees-Of-Freedom 'v'

CI = NaN; 
st = NaN;
n = 0;

if ~isempty(vals)
    n_tot = length(vals);
    n_nan = sum(isnan(vals));
    n = n_tot - n_nan;
    if n>1
        st = std(vals,"omitmissing");
        ts = t_inv(percent/100,n-1);
        CI = ts*st/sqrt(n);
    end
end

end