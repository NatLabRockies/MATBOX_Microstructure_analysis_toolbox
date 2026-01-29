function [x2,inBetween] = Create_transparent_area(x,y_above,y_below)
% [x2,inBetween] = Create_transparent_area(x,y_above,y_below)
% And then add in your plot:
% h_=fill(x2, inBetween, 'r');
% set(h_,'LineStyle','none','FaceAlpha',0.25);

x = reshape(x,[1 length(x)]);
y_above = reshape(y_above,[1 length(y_above)]);
y_below = reshape(y_below,[1 length(y_below)]);

y_above(isnan(y_above)) = 0;
y_below(isnan(y_below)) = 0;

x2 = [x, fliplr(x)];
inBetween = [y_below, fliplr(y_above)];

end