%% run_main.m  主方法仿真入口（论文 Fig.2-4 / Fig.7-9）
%  运行四个主工况：Example 1/2 x e1(0)=±0.3，保存
%  results/main_results.mat 与 results/main_validation.mat。
%  用法：在项目根目录直接运行 run_main。
clear; clc;

project_dir = fileparts(mfilename('fullpath'));
addpath(project_dir, fullfile(project_dir,'tools'));

% 确保 Simulink 模型存在
if ~isfile(fullfile(project_dir,'SFPPB_RL_simulate.slx'))
    SFPPB_build("main");
end

global SFPPB_RL_P
cases = [1 0.3; 1 -0.3; 2 0.3; 2 -0.3];
template = struct('example_id',NaN,'initial_error',NaN,'out',[]);
results = repmat(template,size(cases,1),1);

for k = 1:size(cases,1)
    example_id    = cases(k,1);
    initial_error = cases(k,2);
    SFPPB_RL_P    = SFPPB_params("main", example_id, initial_error, true);
    out = sim('SFPPB_RL_simulate','StopTime',num2str(SFPPB_RL_P.stop_time));
    results(k) = struct('example_id',example_id, ...
        'initial_error',initial_error,'out',out);
    fprintf('Example %d, e1(0)=%+.1f done\n', example_id, initial_error);
end

results_dir = fullfile(project_dir,'results');
if ~isfolder(results_dir), mkdir(results_dir); end
save(fullfile(results_dir,'main_results.mat'),'results','-v7.3');

report = validate_main(results);
save(fullfile(results_dir,'main_validation.mat'),'report');
disp(report);
