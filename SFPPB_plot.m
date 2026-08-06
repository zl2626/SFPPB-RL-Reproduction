%% SFPPB-RL 绘图程序
% 绘图结构、中文注释、LaTeX 标注、颜色和线型参考 AGV_TFS/AGV_plot.m。
% 每一类信号单独保存为 .fig，便于后续在 MATLAB 中继续修改。
close all;

%% 从工作区文件读取仿真结果
project_dir = fileparts(mfilename('fullpath'));
result_file = fullfile(project_dir,'main_results.mat');
if ~isfile(result_file)
    run_output = SFPPB_run("main");
    results = run_output.main;
else
    load(result_file,'results');
end

figure_dir = fullfile(project_dir,'figures');
if ~isfolder(figure_dir), mkdir(figure_dir); end

%% 统一绘图参数（与 AGV_TFS 保持相近风格）
paper.blue = 'b';
paper.red = 'r';
paper.black = 'k';
% 线型语义与目标论文 Fig.2--4、Fig.7--9 保持一致。
paper.tracking_positive = 'b-';   % 正初值输出
paper.tracking_negative = 'r-';   % 负初值输出（同类响应均用实线）
paper.reference = 'k--';          % 参考信号
paper.error = 'r-';               % 跟踪误差
paper.upper_boundary = 'k-.';     % 上边界：黑色点划线
paper.lower_boundary = 'k:';      % 下边界：黑色点线
paper.raw_input = 'k-.';          % 不可实现的原始输入：黑色点划线
paper.applied_input = 'r-';       % 实际饱和输入
paper.first_step = 'r-';          % 网络第1步
paper.second_step = 'k:';         % 网络第2步
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

    %% 绘制系统输出跟踪曲线（对应论文 Fig. 2 和 Fig. 7）
    fig = figure('Color','w','Position',[100 100 760 520], ...
        'Name',sprintf('Example %d tracking',example_id));
    hold on;
    plot(positive_case.yd.Time,positive_case.yd.Data+positive_case.error.Data, ...
        paper.tracking_positive,'LineWidth',paper.line_width);
    plot(negative_case.yd.Time,negative_case.yd.Data+negative_case.error.Data, ...
        paper.tracking_negative,'LineWidth',paper.line_width);
    plot(positive_case.yd.Time,positive_case.yd.Data,paper.reference,'LineWidth',paper.line_width);
    add_deadline(gca,paper);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    ylabel('$y,\,y_d$','FontSize',paper.axis_font_size,'Interpreter','latex');
    legend('$e_1(0)=0.3$','$e_1(0)=-0.3$','$y_d$', ...
        'FontSize',paper.legend_font_size,'FontAngle','italic', ...
        'Interpreter','latex','IconColumnWidth',50,'Location','best');
    grid on; box on;
    xlim(time_limits);
    apply_paper_style(gca,paper);
    save_paper_figure(fig,figure_dir,sprintf('example%d_tracking',example_id));

    %% 绘制误差、SFPPB 与控制输入总览（对应论文 Fig. 3 和 Fig. 8）
    cases_out = {positive_case,negative_case};
    fig = figure('Color','w','Position',[100 80 1000 720], ...
        'Name',sprintf('Example %d boundary and input',example_id));
    layout = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    for k=1:2
        out=cases_out{k};
        error_ax=nexttile(2*k-1); hold(error_ax,'on');
        error_line=plot(error_ax,out.error.Time,out.error.Data,paper.error, ...
            'LineWidth',paper.line_width);
        upper_line=plot(error_ax,out.upper.Time,out.upper.Data, ...
            paper.upper_boundary,'LineWidth',paper.line_width);
        lower_line=plot(error_ax,out.lower.Time,out.lower.Data, ...
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

        input_ax=nexttile(2*k); hold(input_ax,'on');
        raw_line=plot(input_ax,out.u.Time,out.u.Data,paper.raw_input, ...
            'LineWidth',paper.line_width);
        applied_line=plot(input_ax,out.u_sat.Time,out.u_sat.Data, ...
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
        apply_paper_style(input_ax,paper,true);
    end
    xlabel(layout,'Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir,sprintf('example%d_boundary_input_overview',example_id));

    %% 绘制 ICAS 网络权重范数（对应论文 Fig. 4 和 Fig. 9）
    out=positive_case;
    fig=figure('Color','w','Position',[100 60 900 760], ...
        'Name',sprintf('Example %d ICAS weights',example_id));
    layout = tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
    weight_view=struct('time_limits',time_limits,'compact',true, ...
        'show_inset',false,'panel_index',1);
    weight_axes=gobjects(1,3);
    weight_axes(1)=nexttile;
    plot_pair(weight_axes(1),out.Wc1_norm,out.Wc2_norm,'$\|\hat W_c\|$', ...
        '$\|\hat W_{c1}\|$','$\|\hat W_{c2}\|$',paper,weight_view);
    weight_view.panel_index=2;
    weight_axes(2)=nexttile;
    plot_pair(weight_axes(2),out.Wa1_norm,out.Wa2_norm,'$\|\hat W_a\|$', ...
        '$\|\hat W_{a1}\|$','$\|\hat W_{a2}\|$',paper,weight_view);
    weight_view.panel_index=3;
    weight_axes(3)=nexttile;
    plot_pair(weight_axes(3),out.WF1_norm,out.WF2_norm,'$\|\hat W_F\|$', ...
        '$\|\hat W_{F1}\|$','$\|\hat W_{F2}\|$',paper,weight_view);
    xlabel(layout,'Time (sec)','FontSize',paper.axis_font_size);
    drawnow;
    add_weight_inset(weight_axes(1),out.Wc1_norm,out.Wc2_norm,paper,[0 0.25]);
    add_weight_inset(weight_axes(2),out.Wa1_norm,out.Wa2_norm,paper,[0 0.25]);
    add_weight_inset(weight_axes(3),out.WF1_norm,out.WF2_norm,paper,[0.5 5]);
    save_paper_figure(fig,figure_dir,sprintf('example%d_weight_norms_overview',example_id));

    %% 按 AGV_TFS 风格分别绘制每一个重要信号
    case_tags = {'positive_initial_error','negative_initial_error'};
    for k=1:2
        out=cases_out{k};
        tag=case_tags{k};

        fig=figure('Color','w','Name',sprintf('Example %d %s error',example_id,tag));
        hold on;
        plot(out.error.Time,out.error.Data,paper.error,'LineWidth',paper.line_width);
        plot(out.upper.Time,out.upper.Data,paper.upper_boundary,'LineWidth',paper.line_width);
        plot(out.lower.Time,out.lower.Data,paper.lower_boundary,'LineWidth',paper.line_width);
        add_deadline(gca,paper);
        xlabel('Time (sec)','FontSize',paper.axis_font_size);
        ylabel('$e_1$','FontSize',paper.axis_font_size,'Interpreter','latex');
        legend('$e_1$','$\overline{B}(t)$','$\underline{B}(t)$', ...
            'FontSize',paper.legend_font_size,'FontAngle','italic', ...
            'Interpreter','latex','IconColumnWidth',50,'Location','best');
        grid on; box on; apply_paper_style(gca,paper);
        xlim(time_limits);
        save_paper_figure(fig,figure_dir,sprintf('example%d_%s_error_boundary',example_id,tag));

        fig=figure('Color','w','Name',sprintf('Example %d %s input',example_id,tag));
        hold on;
        plot(out.u.Time,out.u.Data,paper.raw_input,'LineWidth',paper.line_width);
        plot(out.u_sat.Time,out.u_sat.Data,paper.applied_input,'LineWidth',paper.line_width);
        xlabel('Time (sec)','FontSize',paper.axis_font_size);
        ylabel('$u$','FontSize',paper.axis_font_size,'Interpreter','latex');
        legend('$u$','$S(u)$', ...
            'FontSize',paper.legend_font_size,'FontAngle','italic', ...
            'Interpreter','latex','IconColumnWidth',50,'Location','best');
        grid on; box on; apply_paper_style(gca,paper);
        xlim(time_limits);
        save_paper_figure(fig,figure_dir,sprintf('example%d_%s_control_input',example_id,tag));

        create_single_signal_figure(out.rho,'$\rho$','Flexible-boundary auxiliary state', ...
            figure_dir,sprintf('example%d_%s_rho',example_id,tag),paper,time_limits);
        create_single_signal_figure(out.O,'$O$','Input-saturation compensation state', ...
            figure_dir,sprintf('example%d_%s_O',example_id,tag),paper,time_limits);
        create_single_signal_figure(out.z1,'$z_1$','Transformed prescribed-performance error', ...
            figure_dir,sprintf('example%d_%s_z1',example_id,tag),paper,time_limits);
        create_single_signal_figure(out.z2,'$z_2$','Backstepping error', ...
            figure_dir,sprintf('example%d_%s_z2',example_id,tag),paper,time_limits);
    end

    %% 分别绘制 Critic、Actor 和 Identifier 权重
    out=positive_case;
    fig=figure('Color','w','Name',sprintf('Example %d critic weights',example_id));
    weight_view=struct('time_limits',time_limits,'compact',false, ...
        'show_inset',true,'panel_index',[],'inset_window',[0 0.25]);
    plot_pair(gca,out.Wc1_norm,out.Wc2_norm,'$\|\hat W_c\|$', ...
        '$\|\hat W_{c1}\|$','$\|\hat W_{c2}\|$',paper,weight_view);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir,sprintf('example%d_critic_weights',example_id));

    fig=figure('Color','w','Name',sprintf('Example %d actor weights',example_id));
    plot_pair(gca,out.Wa1_norm,out.Wa2_norm,'$\|\hat W_a\|$', ...
        '$\|\hat W_{a1}\|$','$\|\hat W_{a2}\|$',paper,weight_view);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir,sprintf('example%d_actor_weights',example_id));

    fig=figure('Color','w','Name',sprintf('Example %d identifier weights',example_id));
    weight_view.inset_window=[0.5 5];
    plot_pair(gca,out.WF1_norm,out.WF2_norm,'$\|\hat W_F\|$', ...
        '$\|\hat W_{F1}\|$','$\|\hat W_{F2}\|$',paper,weight_view);
    xlabel('Time (sec)','FontSize',paper.axis_font_size);
    save_paper_figure(fig,figure_dir,sprintf('example%d_identifier_weights',example_id));
end

%% 文献[42]/[49]对比图（Fig.5、6、10、11及独立面板）
% 与 AGV_plot.m 一样，所有论文图由一个总绘图入口统一生成。
plot_comparison_figures(project_dir,figure_dir);

function plot_pair(ax,first,second,label_text,legend_1,legend_2,paper,view)
%PLOT_PAIR 绘制两步网络权值，并按需添加早期动态局部放大图。
hold(ax,'on');
plot(ax,first.Time,first.Data,paper.first_step,'LineWidth',paper.weight_line_width);
plot(ax,second.Time,second.Data,paper.second_step,'LineWidth',paper.weight_line_width);
ylabel(ax,label_text,'FontSize',paper.axis_font_size,'Interpreter','latex');
if view.compact
    legend_font_size=paper.composite_legend_font_size;
else
    legend_font_size=paper.legend_font_size;
end
legend(ax,legend_1,legend_2,'FontSize',legend_font_size, ...
    'FontAngle','italic','Interpreter','latex','IconColumnWidth',50,'Location','best');
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
%APPLY_PAPER_STYLE 主方法图的统一坐标轴与图例格式。
if nargin<3, is_composite=false; end
if is_composite
    axis_font_size=paper.composite_axis_font_size;
    legend_font_size=paper.composite_legend_font_size;
else
    axis_font_size=paper.axis_font_size;
    legend_font_size=paper.legend_font_size;
end
set(ax,'FontName','Times New Roman','FontSize',axis_font_size,'LineWidth',1, ...
    'TickDir','out','Layer','top');
lgd=ax.Legend;
if ~isempty(lgd)
    set(lgd,'FontSize',legend_font_size,'FontAngle','italic', ...
        'IconColumnWidth',36,'Box','on');
end
axtoolbar(ax,'Visible','off');
end

function create_single_signal_figure(signal,y_label,title_text,figure_dir, ...
        file_name,paper,time_limits)
%CREATE_SINGLE_SIGNAL_FIGURE 生成便于二次编辑的单信号图。
fig=figure('Color','w','Position',[100 100 720 500],'Name',title_text);
plot(signal.Time,signal.Data,'Color',paper.blue,'LineWidth',paper.line_width);
xlabel('Time (sec)','FontSize',paper.axis_font_size);
ylabel(y_label,'FontSize',paper.axis_font_size,'Interpreter','latex');
title(title_text,'FontSize',paper.title_font_size,'FontWeight','normal');
grid on; box on; apply_paper_style(gca,paper);
xlim(time_limits);
save_paper_figure(fig,figure_dir,file_name);
end

function add_weight_inset(parent_ax,first,second,paper,time_window)
%ADD_WEIGHT_INSET 放大指定时窗，分别呈现快速衰减和小量级稳态变化。
old_units=parent_ax.Units;
parent_ax.Units='normalized';
parent_position=parent_ax.Position;
parent_ax.Units=old_units;

inset_position=[parent_position(1)+0.61*parent_position(3), ...
    parent_position(2)+0.12*parent_position(4), ...
    0.34*parent_position(3),0.38*parent_position(4)];
inset_ax=axes('Parent',ancestor(parent_ax,'figure'),'Units','normalized', ...
    'Position',inset_position,'Color','w');
hold(inset_ax,'on');
plot(inset_ax,first.Time,first.Data,paper.first_step, ...
    'LineWidth',max(1.2,0.55*paper.weight_line_width));
plot(inset_ax,second.Time,second.Data,paper.second_step, ...
    'LineWidth',max(1.2,0.55*paper.weight_line_width));
time_window(2)=min(time_window(2),max(first.Time(end),second.Time(end)));
xlim(inset_ax,time_window);
fit_inset_y_limits(inset_ax,first,second,time_window);
inset_title=sprintf('$t\\in[%g,%g]\\,\\mathrm{s}$', ...
    time_window(1),time_window(2));
title(inset_ax,inset_title, ...
    'Interpreter','latex','FontSize',paper.inset_font_size, ...
    'FontWeight','normal');
grid(inset_ax,'on'); box(inset_ax,'on');
set(inset_ax,'FontName','Times New Roman','FontSize',paper.inset_font_size, ...
    'LineWidth',0.8,'TickDir','out','Layer','top');
axtoolbar(inset_ax,'Visible','off');
set(ancestor(parent_ax,'figure'),'CurrentAxes',parent_ax);
end

function fit_inset_y_limits(ax,first,second,time_window)
%FIT_INSET_Y_LIMITS 依据局部数据自动留白，平坦曲线也能显示微小变化。
first_mask=first.Time>=time_window(1) & first.Time<=time_window(2);
second_mask=second.Time>=time_window(1) & second.Time<=time_window(2);
first_data=first.Data(first_mask);
second_data=second.Data(second_mask);
values=[first_data(:);second_data(:)];
values=values(isfinite(values));
if isempty(values), return; end

lower=min(values);
upper=max(values);
data_range=upper-lower;
scale=max(1,max(abs(values)));
if data_range<=100*eps(scale)
    padding=max(1e-6,0.005*scale);
else
    padding=0.10*data_range;
end
ylim(ax,[lower-padding,upper+padding]);
end

function add_panel_label(ax,panel_index,font_size)
%ADD_PANEL_LABEL 在所有复合图中统一使用粗体 (a)、(b)... 面板标识。
text(ax,-0.075,1.025,sprintf('(%c)',char('a'+panel_index-1)), ...
    'Units','normalized','HorizontalAlignment','left', ...
    'VerticalAlignment','bottom','FontName','Times New Roman', ...
    'FontSize',font_size,'FontWeight','bold','Clipping','off');
end

function save_paper_figure(fig,figure_dir,file_name)
% 仅保存可编辑的 MATLAB .fig 文件，不再生成 PNG。
savefig(fig,fullfile(figure_dir,[file_name '.fig']));
end

function plot_comparison_figures(project_dir,figure_dir)
%PLOT_COMPARISON_FIGURES 统一生成文献[42]/[49]全部对比图。
result_file=fullfile(project_dir,'comparison_results.mat');
if ~isfile(result_file)
    run_output=SFPPB_run("comparison");
    results=run_output.comparison;
else
    data=load(result_file,'results');
    results=data.results;
end

% 复合图与独立面板使用相同线型语义，只调整字号和图例密度。
composite_style=comparison_plot_style(true);
single_style=comparison_plot_style(false);

for example_id=1:2
    if example_id==1
        ref49_number=5; ref42_number=6;
    else
        ref49_number=10; ref42_number=11;
    end

    % Fig.5/10：固定PPB与本文SFPPB的四面板对比。
    fig=figure('Color','w','Position',[100 80 1080 760], ...
        'Name',sprintf('Paper Fig. %d',ref49_number));
    layout=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    for panel=1:4
        draw_ref49_panel(nexttile(layout),results,example_id,panel,composite_style);
    end
    xlabel(layout,'Time (sec)','FontSize',composite_style.axis_font_size);
    savefig(fig,fullfile(figure_dir,sprintf('paper_fig%d_ref49_composite.fig', ...
        ref49_number)));

    for panel=1:4
        fig=figure('Color','w','Position',[100 100 720 500], ...
            'Name',sprintf('Paper Fig. %d(%c)',ref49_number,char('a'+panel-1)));
        draw_ref49_panel(gca,results,example_id,panel,single_style);
        xlabel('Time (sec)','FontSize',single_style.axis_font_size);
        savefig(fig,fullfile(figure_dir,sprintf('paper_fig%d_panel_%c.fig', ...
            ref49_number,char('a'+panel-1))));
    end

    % Fig.6/11：本文与文献[42]的误差及输入对比。
    fig=figure('Color','w','Position',[100 100 1080 440], ...
        'Name',sprintf('Paper Fig. %d',ref42_number));
    layout=tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    % Paper Fig.6 uses e1(0)=+0.3 (Example 1), Fig.11 uses e1(0)=-0.3 (Example 2).
    ref42_initial_error = -0.3*double(example_id==2)+0.3*double(example_id==1);
    draw_ref42_panel(nexttile(layout),results,example_id,1,composite_style, ...
        ref42_initial_error);
    draw_ref42_panel(nexttile(layout),results,example_id,2,composite_style, ...
        ref42_initial_error);
    xlabel(layout,'Time (sec)','FontSize',composite_style.axis_font_size);
    savefig(fig,fullfile(figure_dir,sprintf('paper_fig%d_ref42_composite.fig', ...
        ref42_number)));

    names={'error_comparison','input_comparison'};
    for panel=1:2
        fig=figure('Color','w','Position',[100 100 720 500], ...
            'Name',sprintf('Paper Fig. %d panel %d',ref42_number,panel));
        draw_ref42_panel(gca,results,example_id,panel,single_style, ...
            ref42_initial_error);
        xlabel('Time (sec)','FontSize',single_style.axis_font_size);
        savefig(fig,fullfile(figure_dir,sprintf('paper_fig%d_%s.fig', ...
            ref42_number,names{panel})));
    end
end
end

function style=comparison_plot_style(is_composite)
%COMPARISON_PLOT_STYLE 对比图的颜色、线型和版式语义。
% 颜色区分算法，线型区分原始/实际信号；性能边界统一使用黑色点划线族。
style.line_width=2;
style.blue=[0 0.35 0.80];
style.red=[0.85 0.10 0.10];
style.magenta=[0.72 0.15 0.72];
style.green=[0 0.55 0.25];
style.failure=[0.30 0.30 0.30];
style.reference_line='-';
style.proposed_line=':';
style.applied_line='-';
style.upper_boundary='k:';
style.lower_boundary='k-';
style.boundary_line_width=1.2;
style.is_composite=is_composite;
if is_composite
    style.axis_font_size=12;
    style.legend_font_size=9;
    style.title_font_size=11;
    style.panel_label_font_size=12;
else
    style.axis_font_size=16;
    style.legend_font_size=12;
    style.title_font_size=14;
    style.panel_label_font_size=14;
end
end

function draw_ref49_panel(ax,results,example_id,panel,style)
%DRAW_REF49_PANEL Fig.5/10 的单个面板。
hold(ax,'on');
switch panel
    case 1
        cases=arrayfun(@(e)find_comparison_case(results,"ref49","ref49", ...
            example_id,e,false),[0.3 0.05 -0.3],'UniformOutput',false);
        error_handles=plot_initial_error_set(ax,cases,style);
        bound=cases{2}.signals;
        upper=plot_timeseries(ax,bound.upper,style.upper_boundary,style.line_width);
        lower=plot_timeseries(ax,bound.lower,style.lower_boundary,style.line_width);
        legend(ax,[error_handles upper lower], ...
            '$e_1(0)=0.3$','$e_1(0)=0.05$','$e_1(0)=-0.3$', ...
            '$\overline B(t)$','$\underline B(t)$','Interpreter','latex', ...
            'Location','best','NumColumns',2);
        title(ax,'The Method Proposed in [49]','FontWeight','normal', ...
            'FontSize',style.title_font_size);
        xlim(ax,[0 15]); ylim(ax,[-0.4 0.4]);

    case 2
        cases=arrayfun(@(e)find_comparison_case(results,"proposed","ref49", ...
            example_id,e,false),[0.3 0.05 -0.3],'UniformOutput',false);
        error_handles=plot_initial_error_set(ax,cases,style);
        % Flexible SFPPB boundaries of all three initial-error cases (paper Fig.5/10(b)).
        for k=1:3
            upper_handle=plot_timeseries(ax,cases{k}.signals.upper, ...
                style.upper_boundary,style.boundary_line_width);
            lower_handle=plot_timeseries(ax,cases{k}.signals.lower, ...
                style.lower_boundary,style.boundary_line_width);
            if k==1
                upper_legend=upper_handle; lower_legend=lower_handle;
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
        result=find_comparison_case(results,"ref49","ref49", ...
            example_id,0.05,true);
        error_handle=plot_timeseries(ax,result.signals.error,'-', ...
            'Color',style.red,'LineWidth',style.line_width);
        upper=plot_timeseries(ax,result.signals.upper,style.upper_boundary,style.line_width);
        lower=plot_timeseries(ax,result.signals.lower,style.lower_boundary,style.line_width);
        failure=mark_comparison_failure(ax,result,style);
        legend(ax,[error_handle upper lower failure], ...
            '$e_1(0)=0.05$','$\overline B(t)$','$\underline B(t)$','Failure', ...
            'Interpreter','latex','Location','best','NumColumns',2);
        title(ax,'The Method Proposed in [49] under Input Saturation', ...
            'FontWeight','normal','FontSize',style.title_font_size);
        if example_id==1, xlim(ax,[0 1]); else, xlim(ax,[0 1.5]); end
        ylim(ax,[-0.2 0.2]);

    case 4
        result=find_comparison_case(results,"proposed","ref49", ...
            example_id,0.05,true);
        plot_timeseries(ax,result.signals.error,'-', ...
            'Color',style.red,'LineWidth',style.line_width);
        plot_timeseries(ax,result.signals.upper,style.upper_boundary,style.line_width);
        plot_timeseries(ax,result.signals.lower,style.lower_boundary,style.line_width);
        legend(ax,'$e_1(0)=0.05$','$\overline B(t)$','$\underline B(t)$', ...
            'Interpreter','latex','Location','best');
        title(ax,'The Proposed Method under Input Saturation', ...
            'FontWeight','normal','FontSize',style.title_font_size);
        if example_id==1, xlim(ax,[0 15]); else, xlim(ax,[0 20]); end
        % Paper Fig.5/10(d) uses the fixed y-axis [-0.2,0.2].
        ylim(ax,[-0.2 0.2]);
end
ylabel(ax,'$e_1$','Interpreter','latex');
apply_comparison_style(ax,style);
add_panel_label(ax,panel,style.panel_label_font_size);
end

function draw_ref42_panel(ax,results,example_id,panel,style,ref42_initial_error)
%DRAW_REF42_PANEL Fig.6/11：误差、边界、原始输入和实际输入。
proposed=find_comparison_case(results,"proposed","ref42", ...
    example_id,ref42_initial_error,true);
ref42=find_comparison_case(results,"ref42","ref42", ...
    example_id,ref42_initial_error,true);
hold(ax,'on');
if panel==1
    ref_error=plot_timeseries(ax,ref42.signals.error,style.reference_line, ...
        'Color',style.blue,'LineWidth',style.line_width);
    proposed_error=plot_timeseries(ax,proposed.signals.error,style.proposed_line, ...
        'Color',style.red,'LineWidth',style.line_width);
    upper=plot_timeseries(ax,proposed.signals.upper,style.upper_boundary,style.line_width);
    lower=plot_timeseries(ax,proposed.signals.lower,style.lower_boundary,style.line_width);
    legend(ax,[ref_error proposed_error upper lower], ...
        '$e_1$: [42]','$e_1$: proposed','$\overline B(t)$','$\underline B(t)$', ...
        'Interpreter','latex','Location','northeast','NumColumns',2);
    ylabel(ax,'$e_1$','Interpreter','latex');
    if example_id==1, ylim(ax,[-0.05 0.45]); else, ylim(ax,[-0.45 0.10]); end
    title(ax,'Tracking-error comparison','FontWeight','normal', ...
        'FontSize',style.title_font_size);
else
    % Paper Fig.6/11 shows only the applied saturated input S(u); the paper's
    % y-axis range cannot contain the raw control spikes of either method.
    ref_applied=plot_timeseries(ax,ref42.signals.u_sat,style.applied_line, ...
        'Color',style.blue,'LineWidth',style.line_width);
    proposed_applied=plot_timeseries(ax,proposed.signals.u_sat,style.applied_line, ...
        'Color',style.red,'LineWidth',style.line_width);
    legend(ax,[ref_applied proposed_applied], ...
        '$S(u)$: [42]','$S(u)$: proposed','Interpreter','latex','Location','northeast', ...
        'NumColumns',2);
    ylabel(ax,'$S(u)$','Interpreter','latex');
    if example_id==1, ylim(ax,[-10 8]); else, ylim(ax,[-6 4]); end
    title(ax,'Control-input comparison','FontWeight','normal', ...
        'FontSize',style.title_font_size);
end
xlim(ax,[0 15+10*double(example_id==2)]);
apply_comparison_style(ax,style);
add_panel_label(ax,panel,style.panel_label_font_size);
end

function handles=plot_initial_error_set(ax,cases,style)
colors={style.magenta,style.red,style.green};
handles=gobjects(1,3);
for k=1:3
    signal=cases{k}.signals.error;
    if isscalar(signal.Time)
        handles(k)=plot(ax,signal.Time,signal.Data,'o','Color',colors{k}, ...
            'MarkerFaceColor',colors{k},'LineWidth',2,'MarkerSize',6);
    else
        handles(k)=plot(ax,signal.Time,signal.Data,'-','Color',colors{k}, ...
            'LineWidth',style.line_width);
    end
end
end

function handle=plot_timeseries(ax,signal,varargin)
if numel(varargin)==2 && (ischar(varargin{1}) || isstring(varargin{1})) ...
        && isnumeric(varargin{2})
    handle=plot(ax,signal.Time,signal.Data,varargin{1}, ...
        'LineWidth',varargin{2});
else
    handle=plot(ax,signal.Time,signal.Data,varargin{:});
end
end

function handle=mark_comparison_failure(ax,result,style)
time=result.signals.error.Time(end);
value=result.signals.error.Data(end);
handle=plot(ax,time,value,'o','Color',style.failure,'MarkerSize',14, ...
    'LineWidth',1.6,'MarkerFaceColor','none');
end

function result=find_comparison_case(results,algorithm,group,example_id, ...
        initial_error,saturation)
index=find([results.algorithm]==algorithm & [results.comparison_group]==group ...
    & [results.example_id]==example_id & [results.initial_error]==initial_error ...
    & [results.saturation_enabled]==saturation,1);
assert(~isempty(index),'缺少绘图工况：%s/%s/Example%d。', ...
    algorithm,group,example_id);
result=results(index);
end

function apply_comparison_style(ax,style)
grid(ax,'on'); box(ax,'on');
set(ax,'FontName','Times New Roman','FontSize',style.axis_font_size, ...
    'LineWidth',1,'TickDir','out','Layer','top');
lgd=ax.Legend;
if ~isempty(lgd)
    set(lgd,'FontSize',style.legend_font_size,'FontAngle','italic', ...
        'IconColumnWidth',36,'Box','on');
end
axtoolbar(ax,'Visible','off');
end
