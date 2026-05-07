function [ ] = plot_along_direction(group,direction,optformat,optsave,folder)

ndir = length(direction);
for kgroup = 1:length(group)

    fig = figure;
    fig.Color = 'w';
    fig.Name = group(kgroup).yaxis_name;
    tiledlayout(1,ndir,'TileSpacing',optformat.tile_spacing,'Padding',optformat.layout_padding);

    h1 = optsave.Height_foroneplot;
    w1 = h1;
    optsave.Height = h1;
    optsave.Width = ndir*w1;

    clear DATA_writetable
    sheet = 0;

    for d=1:ndir
        ax = nexttile;
        hold(ax,'on');

        nplot = length(group(kgroup).direction(d).array);
        for kp=1:nplot

            plotit = true;
            if isfield(group(kgroup),'relevant') && ~isempty(group(kgroup).relevant) && ~sum(group(kgroup).relevant==kp)
                plotit = false;
            end
            if plotit

                sheet=sheet+1;
                [r,c] = size(group(kgroup).direction(d).array(kp).vals);
                if r==1 || c==1 || group(kgroup).std(kp)==0
                    if ~isfield(group(kgroup).direction(d).array(kp),'linestyle') || isempty(group(kgroup).direction(d).array(kp).linestyle)
                        group(kgroup).direction(d).array(kp).linestyle = '-';
                    end
                    if r==1 || c==1
                        y = group(kgroup).direction(d).array(kp).vals';
                    else
                        y = group(kgroup).direction(d).array(kp).vals(:,1);
                    end
                    h=plot(direction(d).xaxis, y, 'LineStyle', group(kgroup).direction(d).array(kp).linestyle, 'LineWidth',optformat.linewidth, 'Color', group(kgroup).direction(d).array(kp).color);

                    if kp <= length(group(kgroup).mean)
                        str = round(group(kgroup).mean(kp), group(kgroup).yaxis_round);
                        if ~isempty(group(kgroup).yaxis_unit)
                            set(h,'DisplayName',[group(kgroup).direction(d).array(kp).name ' (' num2str(str) ' ' group(kgroup).yaxis_unit ')'])
                        else
                            set(h,'DisplayName',[group(kgroup).direction(d).array(kp).name ' (' num2str(str) ')'])
                        end
                    else
                        set(h,'DisplayName','Background');
                    end
                    varnames = [{[char(direction(d).name) ' ' direction(d).xaxis_unit]} {[group(kgroup).direction(d).array(kp).name ' ' group(kgroup).yaxis_unit]}];
                    DATA_writetable.sheet(sheet).name = [char(direction(d).name) ' ' group(kgroup).direction(d).array(kp).name];
                    DATA_writetable.sheet(sheet).table = array2table([direction(d).xaxis' y],"VariableNames",varnames);
                else
                    % +/- standard deviation
                    x=direction(d).xaxis;
                    int_min = (group(kgroup).direction(d).array(kp).vals(:,1) - group(kgroup).direction(d).array(kp).vals(:,2))';
                    int_max = (group(kgroup).direction(d).array(kp).vals(:,1) + group(kgroup).direction(d).array(kp).vals(:,2))';
                    x2 = [x, fliplr(x)];
                    inBetween = [int_min, fliplr(int_max)];
                    h_=fill(x2, inBetween, group(kgroup).direction(d).array(kp).color,'HandleVisibility','off');
                    set(h_,'LineStyle','none','FaceAlpha',0.25);

                    % Mean
                    h=plot(x, group(kgroup).direction(d).array(kp).vals(:,1), 'LineStyle', '-', 'LineWidth',optformat.linewidth, 'Color', group(kgroup).direction(d).array(kp).color);
                    str = round(group(kgroup).mean(kp), group(kgroup).yaxis_round);
                    if ~isempty(group(kgroup).yaxis_unit)
                        set(h,'DisplayName',[group(kgroup).direction(d).array(kp).name ' (' num2str(str) ' ' group(kgroup).yaxis_unit ')'])
                    else
                        set(h,'DisplayName',[group(kgroup).direction(d).array(kp).name ' (' num2str(str) ')'])
                    end
                    % Extremums
                    h=plot(x, group(kgroup).direction(d).array(kp).vals(:,3), 'LineStyle', '--', 'LineWidth',optformat.linewidth/2, 'Color', group(kgroup).direction(d).array(kp).color,'HandleVisibility','off');
                    h=plot(x, group(kgroup).direction(d).array(kp).vals(:,4), 'LineStyle', '--', 'LineWidth',optformat.linewidth/2, 'Color', group(kgroup).direction(d).array(kp).color,'HandleVisibility','off');

                    % Table
                    varnames = [{[char(direction(d).name) ' ' direction(d).xaxis_unit]} {[group(kgroup).direction(d).array(kp).name ' mean ' group(kgroup).yaxis_unit]} {[group(kgroup).direction(d).array(kp).name ' std ' group(kgroup).yaxis_unit]} {[group(kgroup).direction(d).array(kp).name ' min ' group(kgroup).yaxis_unit]} {[group(kgroup).direction(d).array(kp).name ' max ' group(kgroup).yaxis_unit]}];
                    DATA_writetable.sheet(sheet).name = [char(direction(d).name) ' ' group(kgroup).direction(d).array(kp).name];
                    DATA_writetable.sheet(sheet).table = array2table([direction(d).xaxis' group(kgroup).direction(d).array(kp).vals(:,1) group(kgroup).direction(d).array(kp).vals(:,2) group(kgroup).direction(d).array(kp).vals(:,3) group(kgroup).direction(d).array(kp).vals(:,4)],"VariableNames",varnames);
                end
            end
        end

        hl = legend;
        hl.FontSize = optformat.legendfontsize;
        hl.Location = 'best';
        hl.IconColumnWidth = 20;
        hl.LineWidth = 1;

        % Common
        xlabel(ax,char(direction(d).name));
        if strcmp(direction(d).xaxis_unit,'um') || strcmpi(direction(d).xaxis_unit,'micrometers') || strcmpi(direction(d).xaxis_unit,'micrometer')
            xsecondarylabel(ax,'\mum');
        else
            xsecondarylabel(ax,direction(d).xaxis_unit);
        end
        ylabel(ax,group(kgroup).yaxis_name);
        ysecondarylabel(ax,group(kgroup).yaxis_unit);
        ax.XLabel.FontWeight = "bold";
        ax.YLabel.FontWeight = "bold";
        ax.LineWidth = optformat.linewidth;
        ax.FontName = optformat.fontname;
        ax.FontSize = optformat.axefontsize;
        if optformat.grid
            grid(ax,'on');
            set(ax,'XMinorGrid',optformat.minorgrid,'YMinorGrid',optformat.minorgrid,'GridLineWidth',1);
        end
        hold(ax,'on');
    end

    if optformat.includefilenameintitle
        if ndir==1
            title(group(1).inputfilename,'Interpreter','none','FontSize',optformat.titlefontsize);
        else
            sgtitle(group(1).inputfilename,'Interpreter','none','FontSize',optformat.sgtitlefontsize);
        end
    end

    if optsave.savefig % Save figure
        function_savefig(fig, folder, group(kgroup).filename, optsave); % Call function
    end
    if optsave.autoclosefig
        close(fig); % Do not keep open figures
    end

    if sheet>0
        Function_Writetable(folder,group(kgroup).filename,DATA_writetable)
    end


end

end