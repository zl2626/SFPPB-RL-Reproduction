%% run_comparison.m  对比实验入口（论文 Fig.5/6/10/11）
%  运行 20 个对比工况（[49] 8 个 + [42] 4 个 + 对应本文工况 8 个），
%  保存 results/comparison_results.mat 与 comparison_validation.mat。
%  用法：在项目根目录运行 run_comparison。
clear; clc;

project_dir = fileparts(fileparts(mfilename('fullpath')));
comparison_dir = fileparts(mfilename('fullpath'));
addpath(project_dir, comparison_dir, fullfile(project_dir,'tools'));

% 确保 Simulink 对比模型存在（位于 comparison/ 目录）
if ~isfile(fullfile(comparison_dir,'Ref42_SFPPC_compare.slx')) ...
        || ~isfile(fullfile(comparison_dir,'Ref49_ICAS_compare.slx'))
    SFPPB_build("comparison");
end

template = empty_comparison_result();
results = repmat(template,20,1);
cursor = 0;

for example_id = 1:2
    ref49_stop = 15+5*double(example_id==2);
    ref42_stop = 15+10*double(example_id==2);
    ref42_e0 = ref42_init_error(example_id);

    % Fig.5/10(a)(b)：无饱和，三种初始误差
    for initial_error = [0.3 0.05 -0.3]
        cursor = cursor+1;
        results(cursor) = run_reference("ref49","ref49",example_id, ...
            initial_error,false,ref49_stop,'Ref49_ICAS_compare');
        cursor = cursor+1;
        results(cursor) = run_proposed("ref49",example_id, ...
            initial_error,false,ref49_stop);
    end

    % Fig.5/10(c)(d)：固定 PPB 饱和失效 vs 本文成功
    cursor = cursor+1;
    results(cursor) = run_reference("ref49","ref49",example_id, ...
        0.05,true,ref49_stop,'Ref49_ICAS_compare');
    cursor = cursor+1;
    results(cursor) = run_proposed("ref49",example_id,0.05,true,ref49_stop);

    % Fig.6/11：本文 vs [42]
    cursor = cursor+1;
    results(cursor) = run_reference("ref42","ref42",example_id, ...
        ref42_e0,true,ref42_stop,'Ref42_SFPPC_compare');
    cursor = cursor+1;
    results(cursor) = run_proposed("ref42",example_id, ...
        ref42_e0,true,ref42_stop);
end

results_dir = fullfile(project_dir,'results');
if ~isfolder(results_dir), mkdir(results_dir); end
save(fullfile(results_dir,'comparison_results.mat'),'results','-v7.3');

[report,acceptance] = validate_comparison(results);
save(fullfile(results_dir,'comparison_validation.mat'),'report','acceptance');
disp(report);
disp(acceptance);

function result = run_reference(algorithm,group,example_id,initial_error, ...
        saturation,stop_time,model)
global SFPPB_RL_P
SFPPB_RL_P = SFPPB_params(algorithm,example_id,initial_error,saturation);
SFPPB_RL_P.stop_time = stop_time;
result = base_comparison_result(algorithm,group,example_id, ...
    initial_error,saturation,stop_time);
try
    out = sim(model,'StopTime',num2str(stop_time));
    result.signals = collect_signals(out);
    [result.completed,result.failure_time,result.failure_reason,result.signals] ...
        = assess_reference_run(result.signals,algorithm,stop_time, ...
        initial_error,saturation);
catch exception
    result.completed = false;
    result.failure_reason = "simulation_error: "+string(exception.message);
end
end

function result = run_proposed(group,example_id,initial_error,saturation,stop_time)
global SFPPB_RL_P
SFPPB_RL_P = SFPPB_params("main",example_id,initial_error,saturation);
SFPPB_RL_P.stop_time = stop_time;
if group=="ref49"
    SFPPB_RL_P.initial_x2 = 0.6;   % 与 [49] 使用相同完整初始状态
end
result = base_comparison_result("proposed",group,example_id, ...
    initial_error,saturation,stop_time);
try
    out = sim('SFPPB_RL_simulate','StopTime',num2str(stop_time));
    result.signals = collect_signals(out);
    finite_signals = all(isfinite(result.signals.error.Data));
    boundary_violation = max([result.signals.error.Data-result.signals.upper.Data; ...
        result.signals.lower.Data-result.signals.error.Data;0]);
    result.completed = finite_signals && boundary_violation<=1e-8;
    if ~finite_signals
        result.failure_reason = "nonfinite_signal";
    elseif boundary_violation>1e-8
        result.failure_reason = "proposed_method_boundary_violation";
    end
catch exception
    result.completed = false;
    result.failure_reason = "simulation_error: "+string(exception.message);
end
end

function [completed,failure_time,reason,signals] = assess_reference_run( ...
        signals,algorithm,stop_time,initial_error,saturation)
completed = true;
failure_time = NaN;
reason = "";
if algorithm=="ref49" && isfield(signals,'valid')
    bad = find(signals.valid.Data(:)<0.5,1,'first');
    if ~isempty(bad)
        completed = false;
        failure_time = signals.valid.Time(bad);
        if failure_time<=1e-9 && abs(initial_error)>0.05
            reason = "initial_error_outside_fixed_ppb";
        elseif saturation
            reason = "input_saturation_singularity";
        else
            reason = "transformed_error_reached_fixed_ppb";
        end
        signals = trim_signals(signals,failure_time);
    end
end
if completed && (~isfield(signals,'error') || isempty(signals.error.Time) ...
        || signals.error.Time(end)<stop_time-2e-3)
    completed = false;
    reason = "simulation_ended_early";
end
end

function signals = collect_signals(out)
names = {'x1','x2','u','u_sat','yd','error','lower','upper','z1','z2', ...
    'theta1','theta2','rho','O','Wp1_norm','Wp2_norm','Wc1_norm', ...
    'Wc2_norm','Wa1_norm','Wa2_norm','WF1_norm','WF2_norm','valid', ...
    'alpha1','delta'};
signals = struct;
available = out.who;
for k = 1:numel(names)
    if any(strcmp(available,names{k}))
        signals.(names{k}) = out.get(names{k});
    end
end
if ~isfield(signals,'valid') && isfield(signals,'error')
    signals.valid = timeseries(ones(size(signals.error.Data)),signals.error.Time);
end
end

function signals = trim_signals(signals,failure_time)
names = fieldnames(signals);
for k = 1:numel(names)
    value = signals.(names{k});
    if isa(value,'timeseries')
        keep = value.Time<=failure_time+1e-12;
        if ~any(keep), keep(1) = true; end
        signals.(names{k}) = timeseries(value.Data(keep,:),value.Time(keep));
    end
end
end

function result = base_comparison_result(algorithm,group,example_id, ...
        initial_error,saturation,stop_time)
result = empty_comparison_result();
result.algorithm = string(algorithm);
result.comparison_group = string(group);
result.example_id = example_id;
result.initial_error = initial_error;
result.saturation_enabled = logical(saturation);
result.stop_time = stop_time;
end

function result = empty_comparison_result
result = struct('algorithm',"",'comparison_group',"",'example_id',NaN, ...
    'initial_error',NaN,'saturation_enabled',true,'stop_time',NaN, ...
    'completed',false,'failure_time',NaN,'failure_reason',"",'signals',struct);
end

function value = ref42_init_error(example_id)
value = -0.3*double(example_id==2)+0.3*double(example_id==1);
end
