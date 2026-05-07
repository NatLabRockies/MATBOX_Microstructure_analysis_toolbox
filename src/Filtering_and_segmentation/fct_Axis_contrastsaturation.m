function [M,newtype,foo] = fct_Axis_contrastsaturation(M,p)

foo=[];
newtype = 'same';

if strcmp(p.choice,'Cartesian')
    [M] = fct_CartesianAxis_contrastsaturation(M,p);
elseif strcmp(p.choice,'Radial')
    [M] = fct_RadialAxis_contrastsaturation(M,p);
end

end