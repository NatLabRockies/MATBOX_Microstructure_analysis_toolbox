function [] = function_savefig(Fig, Current_folder, filename, opt)
%function_savefig is a custom file to save figure

nargin; % Number of input variable when the function is call
if nargin == 3 
    opt.fig_infig = true;
    opt.fig_format = {'png'};
    opt.png_DPI = 300;
elseif nargin == 4
    if ~isfield(opt,'png_DPI')
        opt.png_DPI = 300;
    end
end

[ filename ] = function_remove_emptyandspecialcharacter_string(filename);

fullpath=fullfile(Current_folder, filename); % Path without extension

if ~isfield(opt,'allowoverwrite')
    opt.allowoverwrite=true;
end

% To be removed
% opt.fig_infig = true;
% opt.fig_format = {'png'};

if opt.fig_infig
    if ~isfile([fullpath '.fig']) || opt.allowoverwrite
        savefig(Fig,fullpath) % Save in fig format
    else
        tmp=fullpath;
        while isfile([tmp '.fig'])
            tmp=[tmp '_bis'];
        end
        savefig(Fig,tmp)
    end
end

if ~isfield(opt,'Width') || ~isfield(opt,'Height')
    opt.Width = "auto";
    opt.Height = "auto";
end
if ~isfield(opt,"Height_unit")
    opt.Height_unit = "auto";
end
if ~isfield(opt,"Padding")
    opt.Padding = "tight";
end

number_format = length(opt.fig_format); % Save the figure in different format
if number_format>0
    for k=1:1:number_format % Loop over the different format
        current_format = char(opt.fig_format(k)); % Select format
        switch current_format
            case 'png'
                if ~isfile([fullpath '.png']) || opt.allowoverwrite
                    %saveas(Fig,fullpath,'png');
                    exportgraphics(Fig,[fullpath '.png'],'Resolution',opt.png_DPI,Width=opt.Width,Height=opt.Height,Units=opt.Height_unit,Padding=opt.Padding);
                else
                    tmp=fullpath;
                    while isfile([tmp '.png'])
                        tmp=[tmp '_bis'];
                    end
                    %saveas(Fig,tmp,'png');
                    exportgraphics(Fig,[tmp '.png'],'Resolution',opt.png_DPI,Width=opt.Width,Height=opt.Height,Units=opt.Height_unit,Padding=opt.Padding);                    
                end

            case 'svg'
                if ~isfile([fullpath '.svg']) || opt.allowoverwrite
                    exportgraphics(Fig,[fullpath '.svg'],Width=opt.Width,Height=opt.Height,Units=opt.Height_unit,Padding=opt.Padding);
                else
                    tmp=fullpath;
                    while isfile([tmp '.svg'])
                        tmp=[tmp '_bis'];
                    end
                    exportgraphics(Fig,[tmp '.svg'],Width=opt.Width,Height=opt.Height,Units=opt.Height_unit,Padding=opt.Padding);                    
                end           
                
            otherwise
                warning('Unexpected format type. No save created.')
        end
    end
end

end

