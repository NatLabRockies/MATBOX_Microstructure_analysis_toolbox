function [res,newtype,foo] = fct_call_SAM(M,p)

newtype = 'Segmented (instance)';
foo = [];

% Instantiate the app and pass the input argument
app = MATBOX_SAM3Segmenter(M);
% Pause execution of this function until uiresume(app.UIFigure) is called
uiwait(app.UIFigure);
% Extract the output data from the app's public property
res = app.SegOutput;
% Clean up and close the app window
delete(app);

if ~isempty(res)
    [res] = fct_intconvert(res);
end

end