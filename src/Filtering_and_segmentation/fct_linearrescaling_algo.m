function [M] = fct_linearrescaling_algo(M,p)

max_=max(max(max(M)));
min_=min(min(min(M)));
initial_delta=max_-min_;
final_delta=p.nvalues-1;

M =  round( ((double((M-min_)) ./ double(initial_delta)) .* final_delta) );

end