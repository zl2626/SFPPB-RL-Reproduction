%% plot_comparison.m  对比绘图（论文 Fig.5/6/10/11）
%  从 results/comparison_results.mat 读取数据并生成 figures/paper_fig*.fig。
%  用法：在项目根目录运行 comparison/plot_comparison。
close all; clc;

project_dir = fileparts(fileparts(mfilename('fullpath')));
comparison_dir = fileparts(mfilename('fullpath'));
addpath(project_dir, comparison_dir, fullfile(project_dir,'tools'));

result_file = fullfile(project_dir,'results','comparison_results.mat');
if ~isfile(result_file)
    run(fullfile(comparison_dir,'run_comparison.m'));
end
data = load(result_file,'results');
results = data.results;

figure_dir = fullfile(project_dir,'figures');
if ~isfolder(figure_dir), mkdir(figure_dir); end

composite_style = comparison_plot_style(true);
single_style = comparison_plot_style(false);

for example_id = 1:2
    if example_id==1
        ref49_number = 5; ref42_number = 6;
    else
        ref49_number = 10; ref42_number = 11;
    end

    % ---------- Fig.5/10：固定 PPB 与本文 SFPPB 四面板对比 ----------
    fig = figure('Color','w','Position',[100 80 1080 760], ...
        'Name',sprintf('Paper Fig. %d',ref49_number));
    layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    for panel = 1:4
        draw_ref49_panel(nexttile(layout),results,example_id,panel,composite_style);
    end
    xlabel(layout,'Time (sec)','FontSize',composite_style.axis_font_size);
    savefig(fig,fullfile(figure_dir, ...
        sprintf('paper_fig%d_ref49_composite.fig',ref49_number)));

    for panel = 1:4
        fig = figure('Color','w','Position',[100 100 720 500], ...
            'Name',sprintf('Paper Fig. %d(%c)',ref49_number,char('a'+panel-1)));
        draw_ref49_panel(gca,results,example_id,panel,single_style);
        xlabel('Time (sec)','FontSize',single_style.axis_font_size);
        savefig(fig,fullfile(figure_dir, ...
            sprintf('paper_fig%d_panel_%c.fig',ref49_number,char('a'+panel-1))));
    end

    % ---------- Fig.6/11：本文与 [42] 误差/输入对比 ----------
    ref42_e0 = ref42_init_error(example_id);
    fig = figure('Color','w','Position',[100 100 1080 440], ...
        'Name',sprintf('Paper Fig. %d',ref42_number));
    layout = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    draw_ref42_panel(nexttile(layout),results,example_id,1,composite_style,ref42_e0);
    draw_ref42_panel(nexttile(layout),results,example_id,2,composite_style,ref42_e0);
    xlabel(layout,'Time (sec)','FontSize',composite_style.axis_font_size);
    savefig(fig,fullfile(figure_dir, ...
        sprintf('paper_fig%d_ref42_composite.fig',ref42_number)));

    names = {'error_comparison','input_comparison'};
    for panel = 1:2
        fig = figure('Color','w','Position',[100 100 720 500], ...
            'Name',sprintf('Paper Fig. %d panel %d',ref42_number,panel));
        draw_ref42_panel(gca,results,example_id,panel,single_style,ref42_e0);
        xlabel('Time (sec)','FontSize',single_style.axis_font_size);
        savefig(fig,fullfile(figure_dir, ...
            sprintf('paper_fig%d_%s.fig',ref42_number,names{panel})));
    end
end

function value = ref42_init_error(example_id)
value = -0.3*double(example_id==2)+0.3*double(example_id==1);
end

function style = comparison_plot_style(is_composite)
style.line_width = 2;
style.blue = [0 0.35 0.80];
style.red = [0.85 0.10 0.10];
style.magenta = [0.72 0.15 0.72];
style.green = [0 0.55 0.25];
style.failure = [0.30 0.30 0.30];
style.reference_line = '-';
style.proposed_line = ':';
style.raw_line = ':';
style.applied_line = '-';
style.upper_boundary = 'k:';
style.lower_boundary = 'k-';
style.boundary_line_width = 1.2;
style.metric_font_size = 9;
style.is_composite = is_composite;
if is_composite
    style.axis_font_size = 12;
    style.legend_font_size = 9;
    style.title_font_size = 11;
    style.panel_label_font_size = 12;
else
    style.axis_font_size = 16;
    style.legend_font_size = 12;
    style.title_font_size = 14;
    style.panel_label_font_size = 14;
end
end

function draw_ref49_panel(ax,results,example_id,panel,style)
hold(ax,'on');
switch panel
    case 1
        cases = arrayfun(@(e)find_comparison_case(results,"ref49","ref49", ...
            example_id,e,false),[0.3 0.05 -0.3],'UniformOutput',false);
        error_handles = plot_initial_error_set(ax,cases,style);
        bound = cases{2}.signals;
        upper = plot_timeseries(ax,bound.upper,style.upper_boundary,style.line_width);
        lower = plot_timeseries(ax,bound.lower,style.lower_boundary,style.line_width);
        legend(ax,[error_handles upper lower], ...
            '$e_1(0)=0.3$','$e_1(0)=0.05$','$e_1(0)=-0.3$', ...
            '$\overline B(t)$','$\underline B(t)$','Interpreter','latex', ...
            'Location','best','NumColumns',2);
        title(ax,'The Method Proposed in [49]','FontWeight','normal', ...
            'FontSize',style.title_font_size);
        xlim(ax,[0 15]); ylim(ax,[-0.4 0.4]);

    case 2
        cases = arrayfun(@(e)find_comparison_case(results,"proposed","ref49", ...
            example_id,e,false),[0.3 0.05 -0.3],'UniformOutput',false);
        error_handles = plot_initial_error_set(ax,cases,style);
        for k = 1:3
            upper_handle = plot_timeseries(ax,cases{k}.signals.upper, ...
                style.upper_boundary,style.boundary_line_width);
            lower_handle = plot_timeseries(ax,cases{k}.signals.lower, ...
                style.lower_boundary,style.boundary_line_width);
            if k==1
                upper_legend = upper_handle; lower_legend = lower_handle;
            end
        end
        legend(ax,[error_handles upper_legend lower_legend], ...
            '$e_1(0)=0.3$','$e_1(0)=0.05$','$e_1(0)=-0.3$', ...
            '$\overline B(t)$','$\underline B(t)$', ...
            'Interpreter','latex','Location','best','NumColumns',2);
        title(ax,'The Proposed Method','FontWeight','normal', ...
            'FontSize',style.title_font_size);
        xlim(ax,[0 15]); ylim(ax,[-0.4 0.4]);

    case 3
        result = find_comparison_case(results,"ref49","ref49", ...
            example_id,0.05,true);
        error_handle = plot_timeseries(ax,result.signals.error,'-', ...
            'Color',style.red,'LineWidth',style.line_width);
        upper = plot_timeseries(ax,result.signals.upper, ...
            style.upper_boundary,style.line_width);
        lower = plot_timeseries(ax,result.signals.lower, ...
            style.lower_boundary,style.line_width);
        failure = mark_comparison_failure(ax,result,style);
        legend(ax,[error_handle upper lower failure], ...
            '$e_1(0)=0.05$','$\overline B(t)$','$\underline B(t)$','Failure', ...
            'Interpreter','latex','Location','best','NumColumns',2);
        title(ax,'The Method Proposed in [49] under Input Saturation', ...
            'FontWeight','normal','FontSize',style.title_font_size);
        if example_id==1, xlim(ax,[0 1]); else, xlim(ax,[0 1.5]); end
        ylim(ax,[-0.2 0.2]);

    case 4
        fig10_d_e0 = 0.05 + 0.25*double(example_id==2);   % Fig.10(d) 论文用 0.3
        result = find_comparison_case(results,"proposed","ref49", ...
            example_id,fig10_d_e0,true);
        plot_timeseries(ax,result.signals.error,'-', ...
            'Color',style.red,'LineWidth',style.line_width);
        plot_timeseries(ax,result.signals.upper, ...
            style.upper_boundary,style.line_width);
        plot_timeseries(ax,result.signals.lower, ...
            style.lower_boundary,style.line_width);
        legend(ax,sprintf('$e_1(0)=%.2f$',fig10_d_e0), ...
            '$\overline B(t)$','$\underline B(t)$','Interpreter','latex', ...
            'Location','best');
        title(ax,'The Proposed Method under Input Saturation', ...
            'FontWeight','normal','FontSize',style.title_font_size);
        if example_id==1, xlim(ax,[0 15]); else, xlim(ax,[0 20]); end
        ylim(ax,[-0.2 0.2]);
end
ylabel(ax,'$e_1$','Interpreter','latex');
apply_comparison_style(ax,style);
add_panel_label(ax,panel,style.panel_label_font_size);
end

function draw_ref42_panel(ax,results,example_id,panel,style,ref42_e0)
proposed = find_comparison_case(results,"proposed","ref42", ...
    example_id,ref42_e0,true);
ref42 = find_comparison_case(results,"ref42","ref42", ...
    example_id,ref42_e0,true);
hold(ax,'on');
if panel==1
    ref_error = plot_timeseries(ax,ref42.signals.error,style.reference_line, ...
        'Color',style.blue,'LineWidth',style.line_width);
    proposed_error = plot_timeseries(ax,proposed.signals.error, ...
        style.proposed_line,'Color',style.red,'LineWidth',style.line_width);
    upper = plot_timeseries(ax,proposed.signals.upper, ...
        style.upper_boundary,style.line_width);
    lower = plot_timeseries(ax,proposed.signals.lower, ...
        style.lower_boundary,style.line_width);
    legend(ax,[ref_error proposed_error upper lower], ...
        '$e_1$: [42]','$e_1$: proposed','$\overline B(t)$','$\underline B(t)$', ...
        'Interpreter','latex','Location','northeast','NumColumns',2);
    add_integral_text(ax,ref42,proposed,'error',style);
    ylabel(ax,'$e_1$','Interpreter','latex');
    if example_id==1, ylim(ax,[-0.05 0.45]); else, ylim(ax,[-0.45 0.10]); end
    title(ax,'Tracking-error comparison','FontWeight','normal', ...
        'FontSize',style.title_font_size);
else
    % 论文 Fig.6/11 的四条输入曲线：原始 u 与饱和 S(u)，两种算法各一条。
    ref_raw = plot_timeseries(ax,ref42.signals.u,style.raw_line, ...
        'Color',style.green,'LineWidth',style.line_width);
    ref_applied = plot_timeseries(ax,ref42.signals.u_sat, ...
        style.applied_line,'Color',style.blue,'LineWidth',style.line_width);
    proposed_raw = plot_timeseries(ax,proposed.signals.u,style.raw_line, ...
        'Color',[0.15 0.15 0.15],'LineWidth',style.line_width);
    proposed_applied = plot_timeseries(ax,proposed.signals.u_sat, ...
        style.applied_line,'Color',style.red,'LineWidth',style.line_width);
    legend(ax,[ref_raw ref_applied proposed_raw proposed_applied], ...
        '$u$: [42]','$S(u)$: [42]','$u$: proposed','$S(u)$: proposed', ...
        'Interpreter','latex', ...
        'Location','northeast','NumColumns',2);
    add_integral_text(ax,ref42,proposed,'u_sat',style);
    ylabel(ax,'$u,\,S(u)$','Interpreter','latex');
    if example_id==1, ylim(ax,[-10 8]); else, ylim(ax,[-6 4]); end
    title(ax,'Control-input comparison','FontWeight','normal', ...
        'FontSize',style.title_font_size);
end
xlim(ax,[0 15+10*double(example_id==2)]);
apply_comparison_style(ax,style);
add_panel_label(ax,panel,style.panel_label_font_size);
end

function handles = plot_initial_error_set(ax,cases,style)
colors = {style.magenta,style.red,style.green};
handles = gobjects(1,3);
for k = 1:3
    signal = cases{k}.signals.error;
    if isscalar(signal.Time)
        handles(k) = plot(ax,signal.Time,signal.Data,'o','Color',colors{k}, ...
            'MarkerFaceColor',colors{k},'LineWidth',2,'MarkerSize',6);
    else
        handles(k) = plot(ax,signal.Time,signal.Data,'-','Color',colors{k}, ...
            'LineWidth',style.line_width);
    end
end
end

function handle = plot_timeseries(ax,signal,varargin)
if numel(varargin)==2 && (ischar(varargin{1}) || isstring(varargin{1})) ...
        && isnumeric(varargin{2})
    handle = plot(ax,signal.Time,signal.Data,varargin{1}, ...
        'LineWidth',varargin{2});
else
    handle = plot(ax,signal.Time,signal.Data,varargin{:});
end
end

function handle = mark_comparison_failure(ax,result,style)
time = result.signals.error.Time(end);
value = result.signals.error.Data(end);
handle = plot(ax,time,value,'o','Color',style.failure,'MarkerSize',14, ...
    'LineWidth',1.6,'MarkerFaceColor','none');
end

function result = find_comparison_case(results,algorithm,group,example_id, ...
        initial_error,saturation)
index = find([results.algorithm]==algorithm & [results.comparison_group]==group ...
    & [results.example_id]==example_id & [results.initial_error]==initial_error ...
    & [results.saturation_enabled]==saturation,1);
assert(~isempty(index),'Missing comparison case %s/%s/Example%d.', ...
    algorithm,group,example_id);
result = results(index);
end

function apply_comparison_style(ax,style)
grid(ax,'on'); box(ax,'on');
set(ax,'FontName','Times New Roman','FontSize',style.axis_font_size, ...
    'LineWidth',1,'TickDir','out','Layer','top');
lgd = ax.Legend;
if ~isempty(lgd)
    set(lgd,'FontSize',style.legend_font_size,'FontAngle','italic', ...
        'IconColumnWidth',36,'Box','on');
end
axtoolbar(ax,'Visible','off');
end

function add_panel_label(ax,panel_index,font_size)
text(ax,-0.075,1.025,sprintf('(%c)',char('a'+panel_index-1)), ...
    'Units','normalized','HorizontalAlignment','left', ...
    'VerticalAlignment','bottom','FontName','Times New Roman', ...
    'FontSize',font_size,'FontWeight','bold','Clipping','off');
end

function add_integral_text(ax,ref42,proposed,field_name,style)
%ADD_INTEGRAL_TEXT  Annotate the measured integral of each method.
ref_value = integral_abs(ref42.signals.(field_name));
proposed_value = integral_abs(proposed.signals.(field_name));
if strcmp(field_name,'error')
    symbol = 'e_1';
else
    symbol = 'S(u)';
end
text(ax,0.98,0.20,sprintf('$\\int_0^{%g}|%s|dt=%.2f$ in [42]', ...
    ref42.stop_time,symbol,ref_value),'Units','normalized', ...
    'Interpreter','latex','Color',style.blue, ...
    'FontSize',style.metric_font_size,'HorizontalAlignment','right', ...
    'BackgroundColor','w','Margin',1);
text(ax,0.98,0.10,sprintf('$\\int_0^{%g}|%s|dt=%.2f$ proposed', ...
    proposed.stop_time,symbol,proposed_value),'Units','normalized', ...
    'Interpreter','latex','Color',style.red, ...
    'FontSize',style.metric_font_size,'HorizontalAlignment','right', ...
    'BackgroundColor','w','Margin',1);
end

function value = integral_abs(signal)
if numel(signal.Time)<2
    value = 0;
else
    value = trapz(signal.Time(:),abs(signal.Data(:)));
end
end
