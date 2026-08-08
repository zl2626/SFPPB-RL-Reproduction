%% plot_main.m  主方法绘图（论文 Fig.2-4 / Fig.7-9）
%  从 results/main_results.mat 读取数据并生成 figures/*.fig。
%  用法：在项目根目录运行 plot_main。
close all; clc;

project_dir = fileparts(mfilename('fullpath'));
addpath(project_dir, fullfile(project_dir,'tools'));

result_file = fullfile(project_dir,'results','main_results.mat');
if ~isfile(result_file)
    run_main;
end
load(result_file,'results');

figure_dir = fullfile(project_dir,'figures');
if ~isfolder(figure_dir), mkdir(figure_dir); end

% ---------------- 统一绘图参数（AGV_TFS 风格） ----------------
paper.blue = 'b';
paper.red = 'r';
paper.black = 'k';
paper.tracking_positive = 'b-';
paper.tracking_negative = 'r-';
paper.reference = 'k--';
paper.error = 'r-';
paper.upper_boundary = 'k:';
paper.lower_boundary = 'k-';
paper.raw_input = 'k-.';
paper.applied_input = 'r-';
paper.first_step = 'r-';
paper.second_step = 'k:';
paper.deadline_color = [1 0.35 0];
paper.line_width = 2;
paper.weight_line_width = 3;
paper.axis_font_size = 16;
paper.legend_font_size = 14;
paper.composite_axis_font_size = 13;
paper.composite_legend_font_size = 10;
paper.panel_label_font_size = 13;
paper.inset_font_size = 9;
paper.title_font_size = 14;

for example_id = 1:2
    idx = find([results.example_id] == example_id);
    positive_case = results(idx([results(idx).initial_error] > 0)).out;
    negative_case = results(idx([results(idx).initial_error] < 0)).out;
    time_limits = [0,25+5*double(example_id==2)];

    % ---------- 跟踪曲线（Fig.2 / Fig.7） ----------
    fig = figure('Color','w','Position',[100 100 760 520], ...
        'Name',sprintf('Example %d tracking',example_id));
    hold on;
    plot(positive_case.yd.Time,positive_case.yd.Data+positive_case.error.Data, ...
        paper.tracking_positive,'LineWidth',paper.line_width);
    plot(negative_case.yd.Time,negative_case.yd.Data+negative_case.error.Data, ...
        paper.tracking_negative,'LineWidth',paper.line_width);
    plot(positive_case.yd.Time,positive_case.yd.Data,paper.reference, ...
        'LineWidth',paper.line_width);
    add_deadline(gca,paper);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    ylabel('$y,\,y_d$','FontSize',paper.axis_font_size,'Interpreter','latex');
    legend('$e_1(0)=0.3$','$e_1(0)=-0.3$','$y_d$', ...
        'FontSize',paper.legend_font_size,'FontAngle','italic', ...
        'Interpreter','latex','IconColumnWidth',50,'Location','best');
    grid on; box on;
    xlim(time_limits);
    ylim([-0.2 0.4+0.2*double(example_id==2)]);
    apply_paper_style(gca,paper);
    save_paper_figure(fig,figure_dir,sprintf('example%d_tracking',example_id));

    % ---------- 误差/SFPPB/输入总览（Fig.3 / Fig.8） ----------
    cases_out = {positive_case,negative_case};
    fig = figure('Color','w','Position',[100 80 1000 720], ...
        'Name',sprintf('Example %d boundary and input',example_id));
    layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    for k=1:2
        out = cases_out{k};
        error_ax = nexttile(2*k-1); hold(error_ax,'on');
        error_line = plot(error_ax,out.error.Time,out.error.Data,paper.error, ...
            'LineWidth',paper.line_width);
        upper_line = plot(error_ax,out.upper.Time,out.upper.Data, ...
            paper.upper_boundary,'LineWidth',paper.line_width);
        lower_line = plot(error_ax,out.lower.Time,out.lower.Data, ...
            paper.lower_boundary,'LineWidth',paper.line_width);
        add_deadline(error_ax,paper);
        ylabel(error_ax,'$e_1$ and SFPPB','FontSize',paper.axis_font_size, ...
            'Interpreter','latex');
        title(error_ax,sprintf('$e_1(0)=%+.1f$',out.error.Data(1)), ...
            'Interpreter','latex','FontSize',paper.title_font_size, ...
            'FontWeight','normal');
        add_panel_label(error_ax,2*k-1,paper.panel_label_font_size);
        if k==1
            legend(error_ax,[error_line upper_line lower_line], ...
                '$e_1$','$\overline{B}(t)$','$\underline{B}(t)$', ...
                'Interpreter','latex','Location','best','NumColumns',1);
        end
        grid(error_ax,'on'); box(error_ax,'on');
        xlim(error_ax,time_limits);
        apply_paper_style(error_ax,paper,true);

        input_ax = nexttile(2*k); hold(input_ax,'on');
        raw_line = plot(input_ax,out.u.Time,out.u.Data,paper.raw_input, ...
            'LineWidth',paper.line_width);
        applied_line = plot(input_ax,out.u_sat.Time,out.u_sat.Data, ...
            paper.applied_input,'LineWidth',paper.line_width);
        ylabel(input_ax,'$u,\,S(u)$','FontSize',paper.axis_font_size, ...
            'Interpreter','latex');
        title(input_ax,sprintf('$e_1(0)=%+.1f$',out.error.Data(1)), ...
            'Interpreter','latex','FontSize',paper.title_font_size, ...
            'FontWeight','normal');
        add_panel_label(input_ax,2*k,paper.panel_label_font_size);
        if k==1
            legend(input_ax,[raw_line applied_line],'$u$','$S(u)$', ...
                'Interpreter','latex','Location','best','NumColumns',1);
        end
        grid(input_ax,'on'); box(input_ax,'on');
        xlim(input_ax,time_limits);
        ylim(input_ax,[-10 10]);
        apply_paper_style(input_ax,paper,true);
    end
    xlabel(layout,'Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir, ...
        sprintf('example%d_boundary_input_overview',example_id));

    % ---------- ICAS 权值范数总览（Fig.4 / Fig.9） ----------
    out = positive_case;
    fig = figure('Color','w','Position',[100 60 900 760], ...
        'Name',sprintf('Example %d ICAS weights',example_id));
    layout = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
    weight_view = struct('time_limits',time_limits,'compact',true, ...
        'show_inset',false,'panel_index',1);
    weight_axes = gobjects(1,3);
    weight_axes(1) = nexttile;
    plot_pair(weight_axes(1),out.Wc1_norm,out.Wc2_norm,'$\|\hat W_c\|$', ...
        '$\|\hat W_{c1}\|$','$\|\hat W_{c2}\|$',paper,weight_view);
    weight_view.panel_index = 2;
    weight_axes(2) = nexttile;
    plot_pair(weight_axes(2),out.Wa1_norm,out.Wa2_norm,'$\|\hat W_a\|$', ...
        '$\|\hat W_{a1}\|$','$\|\hat W_{a2}\|$',paper,weight_view);
    weight_view.panel_index = 3;
    weight_axes(3) = nexttile;
    plot_pair(weight_axes(3),out.WF1_norm,out.WF2_norm,'$\|\hat W_F\|$', ...
        '$\|\hat W_{F1}\|$','$\|\hat W_{F2}\|$',paper,weight_view);
    xlabel(layout,'Time (sec)','FontSize',paper.axis_font_size);
    drawnow;
    add_weight_inset(weight_axes(1),out.Wc1_norm,out.Wc2_norm,paper,[0 0.25]);
    add_weight_inset(weight_axes(2),out.Wa1_norm,out.Wa2_norm,paper,[0 0.25]);
    add_weight_inset(weight_axes(3),out.WF1_norm,out.WF2_norm,paper,[0.5 5]);
    save_paper_figure(fig,figure_dir, ...
        sprintf('example%d_weight_norms_overview',example_id));

    % ---------- 按 AGV_TFS 风格分别绘制重要信号 ----------
    case_tags = {'positive_initial_error','negative_initial_error'};
    for k=1:2
        out = cases_out{k};
        tag = case_tags{k};

        fig = figure('Color','w','Name', ...
            sprintf('Example %d %s error',example_id,tag));
        hold on;
        plot(out.error.Time,out.error.Data,paper.error, ...
            'LineWidth',paper.line_width);
        plot(out.upper.Time,out.upper.Data,paper.upper_boundary, ...
            'LineWidth',paper.line_width);
        plot(out.lower.Time,out.lower.Data,paper.lower_boundary, ...
            'LineWidth',paper.line_width);
        add_deadline(gca,paper);
        xlabel('Time (sec)','FontSize',paper.axis_font_size);
        ylabel('$e_1$','FontSize',paper.axis_font_size,'Interpreter','latex');
        legend('$e_1$','$\overline{B}(t)$','$\underline{B}(t)$', ...
            'FontSize',paper.legend_font_size,'FontAngle','italic', ...
            'Interpreter','latex','IconColumnWidth',50,'Location','best');
        grid on; box on; apply_paper_style(gca,paper);
        xlim(time_limits);
        save_paper_figure(fig,figure_dir, ...
            sprintf('example%d_%s_error_boundary',example_id,tag));

        fig = figure('Color','w','Name', ...
            sprintf('Example %d %s input',example_id,tag));
        hold on;
        plot(out.u.Time,out.u.Data,paper.raw_input,'LineWidth',paper.line_width);
        plot(out.u_sat.Time,out.u_sat.Data,paper.applied_input, ...
            'LineWidth',paper.line_width);
        xlabel('Time (sec)','FontSize',paper.axis_font_size);
        ylabel('$u$','FontSize',paper.axis_font_size,'Interpreter','latex');
        legend('$u$','$S(u)$','FontSize',paper.legend_font_size, ...
            'FontAngle','italic','Interpreter','latex', ...
            'IconColumnWidth',50,'Location','best');
        grid on; box on; apply_paper_style(gca,paper);
        xlim(time_limits);
        ylim([-10 10]);
        save_paper_figure(fig,figure_dir, ...
            sprintf('example%d_%s_control_input',example_id,tag));

        create_single_signal_figure(out.rho,'$\rho$', ...
            'Flexible-boundary auxiliary state',figure_dir, ...
            sprintf('example%d_%s_rho',example_id,tag),paper,time_limits);
        create_single_signal_figure(out.O,'$O$', ...
            'Input-saturation compensation state',figure_dir, ...
            sprintf('example%d_%s_O',example_id,tag),paper,time_limits);
        create_single_signal_figure(out.z1,'$z_1$', ...
            'Transformed prescribed-performance error',figure_dir, ...
            sprintf('example%d_%s_z1',example_id,tag),paper,time_limits);
        create_single_signal_figure(out.z2,'$z_2$', ...
            'Backstepping error',figure_dir, ...
            sprintf('example%d_%s_z2',example_id,tag),paper,time_limits);
    end

    % ---------- 分别绘制 Critic / Actor / Identifier 权值 ----------
    out = positive_case;
    weight_view = struct('time_limits',time_limits,'compact',false, ...
        'show_inset',true,'panel_index',[],'inset_window',[0 0.25]);
    fig = figure('Color','w','Name', ...
        sprintf('Example %d critic weights',example_id));
    plot_pair(gca,out.Wc1_norm,out.Wc2_norm,'$\|\hat W_c\|$', ...
        '$\|\hat W_{c1}\|$','$\|\hat W_{c2}\|$',paper,weight_view);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir, ...
        sprintf('example%d_critic_weights',example_id));

    fig = figure('Color','w','Name', ...
        sprintf('Example %d actor weights',example_id));
    plot_pair(gca,out.Wa1_norm,out.Wa2_norm,'$\|\hat W_a\|$', ...
        '$\|\hat W_{a1}\|$','$\|\hat W_{a2}\|$',paper,weight_view);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir, ...
        sprintf('example%d_actor_weights',example_id));

    fig = figure('Color','w','Name', ...
        sprintf('Example %d identifier weights',example_id));
    weight_view.inset_window = [0.5 5];
    plot_pair(gca,out.WF1_norm,out.WF2_norm,'$\|\hat W_F\|$', ...
        '$\|\hat W_{F1}\|$','$\|\hat W_{F2}\|$',paper,weight_view);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir, ...
        sprintf('example%d_identifier_weights',example_id));
end

function plot_pair(ax,first,second,label_text,legend_1,legend_2,paper,view)
hold(ax,'on');
plot(ax,first.Time,first.Data,paper.first_step, ...
    'LineWidth',paper.weight_line_width);
plot(ax,second.Time,second.Data,paper.second_step, ...
    'LineWidth',paper.weight_line_width);
ylabel(ax,label_text,'FontSize',paper.axis_font_size,'Interpreter','latex');
if view.compact
    legend_font_size = paper.composite_legend_font_size;
else
    legend_font_size = paper.legend_font_size;
end
legend(ax,legend_1,legend_2,'FontSize',legend_font_size, ...
    'FontAngle','italic','Interpreter','latex', ...
    'IconColumnWidth',50,'Location','best');
grid(ax,'on'); box(ax,'on');
xlim(ax,view.time_limits);
apply_paper_style(ax,paper,view.compact);
if ~isempty(view.panel_index)
    add_panel_label(ax,view.panel_index,paper.panel_label_font_size);
end
if view.show_inset
    drawnow;
    add_weight_inset(ax,first,second,paper,view.inset_window);
end
end

function add_deadline(ax,paper)
xline(ax,5,'-.','$T=5\,\mathrm{s}$','Interpreter','latex', ...
    'Color',paper.deadline_color,'LineWidth',1.4, ...
    'LabelVerticalAlignment','bottom','HandleVisibility','off');
end

function apply_paper_style(ax,paper,is_composite)
if nargin<3, is_composite = false; end
if is_composite
    axis_font_size = paper.composite_axis_font_size;
    legend_font_size = paper.composite_legend_font_size;
else
    axis_font_size = paper.axis_font_size;
    legend_font_size = paper.legend_font_size;
end
set(ax,'FontName','Times New Roman','FontSize',axis_font_size, ...
    'LineWidth',1,'TickDir','out','Layer','top');
lgd = ax.Legend;
if ~isempty(lgd)
    set(lgd,'FontSize',legend_font_size,'FontAngle','italic', ...
        'IconColumnWidth',36,'Box','on');
end
axtoolbar(ax,'Visible','off');
end

function create_single_signal_figure(signal,y_label,title_text,figure_dir, ...
        file_name,paper,time_limits)
fig = figure('Color','w','Position',[100 100 720 500],'Name',title_text);
plot(signal.Time,signal.Data,'Color',paper.blue,'LineWidth',paper.line_width);
xlabel('Time (sec)','FontSize',paper.axis_font_size);
ylabel(y_label,'FontSize',paper.axis_font_size,'Interpreter','latex');
title(title_text,'FontSize',paper.title_font_size,'FontWeight','normal');
grid on; box on; apply_paper_style(gca,paper);
xlim(time_limits);
save_paper_figure(fig,figure_dir,file_name);
end

function add_weight_inset(parent_ax,first,second,paper,time_window)
old_units = parent_ax.Units;
parent_ax.Units = 'normalized';
parent_position = parent_ax.Position;
parent_ax.Units = old_units;

inset_position = [parent_position(1)+0.61*parent_position(3), ...
    parent_position(2)+0.12*parent_position(4), ...
    0.34*parent_position(3),0.38*parent_position(4)];
inset_ax = axes('Parent',ancestor(parent_ax,'figure'),'Units','normalized', ...
    'Position',inset_position,'Color','w');
hold(inset_ax,'on');
plot(inset_ax,first.Time,first.Data,paper.first_step, ...
    'LineWidth',max(1.2,0.55*paper.weight_line_width));
plot(inset_ax,second.Time,second.Data,paper.second_step, ...
    'LineWidth',max(1.2,0.55*paper.weight_line_width));
time_window(2) = min(time_window(2),max(first.Time(end),second.Time(end)));
xlim(inset_ax,time_window);
fit_inset_y_limits(inset_ax,first,second,time_window);
title(inset_ax,sprintf('$t\\in[%g,%g]\\,\\mathrm{s}$', ...
    time_window(1),time_window(2)),'Interpreter','latex', ...
    'FontSize',paper.inset_font_size,'FontWeight','normal');
grid(inset_ax,'on'); box(inset_ax,'on');
set(inset_ax,'FontName','Times New Roman','FontSize',paper.inset_font_size, ...
    'LineWidth',0.8,'TickDir','out','Layer','top');
axtoolbar(inset_ax,'Visible','off');
set(ancestor(parent_ax,'figure'),'CurrentAxes',parent_ax);
end

function fit_inset_y_limits(ax,first,second,time_window)
first_mask = first.Time>=time_window(1) & first.Time<=time_window(2);
second_mask = second.Time>=time_window(1) & second.Time<=time_window(2);
values = [first.Data(first_mask); second.Data(second_mask)];
values = values(isfinite(values));
if isempty(values), return; end
lower = min(values); upper = max(values);
data_range = upper-lower;
scale = max(1,max(abs(values)));
if data_range<=100*eps(scale)
    padding = max(1e-6,0.005*scale);
else
    padding = 0.10*data_range;
end
ylim(ax,[lower-padding,upper+padding]);
end

function add_panel_label(ax,panel_index,font_size)
text(ax,-0.075,1.025,sprintf('(%c)',char('a'+panel_index-1)), ...
    'Units','normalized','HorizontalAlignment','left', ...
    'VerticalAlignment','bottom','FontName','Times New Roman', ...
    'FontSize',font_size,'FontWeight','bold','Clipping','off');
end

function save_paper_figure(fig,figure_dir,file_name)
savefig(fig,fullfile(figure_dir,[file_name '.fig']));
end
