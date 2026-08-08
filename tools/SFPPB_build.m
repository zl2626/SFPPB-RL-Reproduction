function models = SFPPB_build(scope)
%SFPPB_BUILD  Rebuild the Simulink models from the S-function sources.
%   SFPPB_BUILD("all")         builds all three models (default)
%   SFPPB_BUILD("main")        builds SFPPB_RL_simulate.slx
%   SFPPB_BUILD("comparison")  builds comparison/*.slx
%
%   All models use fixed-step ode4 with step 0.001 s.
arguments
    scope (1,1) string {mustBeMember(scope,["all","main","comparison"])} = "all"
end

project_dir = fileparts(fileparts(mfilename('fullpath')));
comparison_dir = fullfile(project_dir,'comparison');
addpath(project_dir, comparison_dir, fileparts(mfilename('fullpath')));
old_dir = pwd;
cleanup = onCleanup(@()cd(old_dir));
cd(project_dir);

models = strings(0,1);
if scope=="all" || scope=="main"
    buildMainModel();
    models(end+1) = "SFPPB_RL_simulate";
end
if scope=="all" || scope=="comparison"
    cd(comparison_dir);
    buildComparisonModel("Ref42_SFPPC_compare","Ref42_SFPPC_ctrl", ...
        {'u','u_sat','yd','error','lower','upper','z1','z2', ...
         'theta1','theta2','rho','O','alpha1'},"ref42");
    buildComparisonModel("Ref49_ICAS_compare","Ref49_ICAS_ctrl", ...
        {'u','u_sat','yd','error','lower','upper','z1','z2', ...
         'Wp1_norm','Wp2_norm','Wc1_norm','Wc2_norm', ...
         'Wa1_norm','Wa2_norm','valid','alpha1'},"ref49");
    models = [models; "Ref42_SFPPC_compare"; "Ref49_ICAS_compare"];
end
end

function buildMainModel
global SFPPB_RL_P
SFPPB_RL_P = SFPPB_params("main",1,0.3,true);
model = 'SFPPB_RL_simulate';
resetModel(model);
setSolver(model,30);

add_block('simulink/User-Defined Functions/S-Function',[model '/Plant'], ...
    'FunctionName','SFPPB_plant','Position',[90 130 220 190]);
add_block('simulink/Signal Routing/Demux',[model '/Plant states'], ...
    'Outputs','2','Position',[260 125 265 195]);
add_block('simulink/Signal Routing/Mux',[model '/Controller inputs'], ...
    'Inputs','4','Position',[340 105 345 235]);
add_block('simulink/User-Defined Functions/S-Function',[model '/SFPPB controller'], ...
    'FunctionName','SFPPB_ctrl','Position',[400 125 560 195]);
add_block('simulink/Signal Routing/Demux',[model '/Controller signals'], ...
    'Outputs','18','Position',[610 60 615 330]);
add_block('simulink/User-Defined Functions/S-Function',[model '/Auxiliary systems'], ...
    'FunctionName','SFPPB_aux','Position',[400 310 560 365]);
add_block('simulink/Signal Routing/Demux',[model '/Auxiliary states'], ...
    'Outputs','2','Position',[610 315 615 365]);

add_line(model,'Plant/1','Plant states/1','autorouting','on');
add_line(model,'Plant states/1','Controller inputs/1','autorouting','on');
add_line(model,'Plant states/2','Controller inputs/2','autorouting','on');
add_line(model,'Controller inputs/1','SFPPB controller/1','autorouting','on');
add_line(model,'SFPPB controller/1','Controller signals/1','autorouting','on');
add_line(model,'Controller signals/1','Plant/1','autorouting','on');
add_line(model,'Controller signals/1','Auxiliary systems/1','autorouting','on');
add_line(model,'Auxiliary systems/1','Auxiliary states/1','autorouting','on');
add_line(model,'Auxiliary states/1','Controller inputs/3','autorouting','on');
add_line(model,'Auxiliary states/2','Controller inputs/4','autorouting','on');

addWorkspaceSignals(model,'Plant states',{'x1','x2'},[90 70]);
controller_names = {'u','u_sat','yd','error','lower','upper','z1','z2', ...
    'Wc1_norm','Wc2_norm','Wa1_norm','Wa2_norm','WF1_norm','WF2_norm', ...
    'alpha1','delta','ctrl_x1','ctrl_x2'};
addWorkspaceSignals(model,'Controller signals',controller_names,[720 67]);
addWorkspaceSignals(model,'Auxiliary states',{'rho','O'},[720 610]);
finishModel(model);
end

function buildComparisonModel(model,controller,signal_names,algorithm)
global SFPPB_RL_P
if algorithm=="ref42"
    SFPPB_RL_P = SFPPB_params("ref42",1,0.3,true);
else
    SFPPB_RL_P = SFPPB_params("ref49",1,0.05,true);
end
model = char(model);
resetModel(model);
setSolver(model,20);

add_block('simulink/User-Defined Functions/S-Function',[model '/Plant'], ...
    'FunctionName','SFPPB_plant','Position',[80 130 210 190]);
add_block('simulink/Signal Routing/Demux',[model '/Plant states'], ...
    'Outputs','2','Position',[250 125 255 195]);
add_block('simulink/Signal Routing/Mux',[model '/Controller inputs'], ...
    'Inputs','2','Position',[325 120 330 200]);
add_block('simulink/User-Defined Functions/S-Function',[model '/Comparison controller'], ...
    'FunctionName',char(controller),'Position',[390 125 565 195]);
add_block('simulink/Signal Routing/Demux',[model '/Controller signals'], ...
    'Outputs',num2str(numel(signal_names)),'Position',[615 55 620 440]);

add_line(model,'Plant/1','Plant states/1','autorouting','on');
add_line(model,'Plant states/1','Controller inputs/1','autorouting','on');
add_line(model,'Plant states/2','Controller inputs/2','autorouting','on');
add_line(model,'Controller inputs/1','Comparison controller/1','autorouting','on');
add_line(model,'Comparison controller/1','Controller signals/1','autorouting','on');
add_line(model,'Controller signals/1','Plant/1','autorouting','on');

addWorkspaceSignals(model,'Plant states',{'x1','x2'},[75 70]);
addWorkspaceSignals(model,'Controller signals',signal_names,[710 56]);
finishModel(model);
end

function resetModel(model)
if bdIsLoaded(model), close_system(model,0); end
model_file = [model '.slx'];
if isfile(model_file), delete(model_file); end
new_system(model);
end

function setSolver(model,stop_time)
set_param(model,'SolverType','Fixed-step','Solver','ode4','FixedStep','0.001', ...
    'StopTime',num2str(stop_time),'ReturnWorkspaceOutputs','on');
end

function addWorkspaceSignals(model,source,signal_names,origin)
for k = 1:numel(signal_names)
    name = signal_names{k};
    block = [model '/To Workspace ' name];
    y = origin(2)+32*(k-1);
    add_block('simulink/Sinks/To Workspace',block,'VariableName',name, ...
        'SaveFormat','Timeseries','Position',[origin(1) y origin(1)+130 y+20]);
    add_line(model,sprintf('%s/%d',source,k),['To Workspace ' name '/1'], ...
        'autorouting','on');
end
end

function finishModel(model)
Simulink.BlockDiagram.arrangeSystem(model);
save_system(model);
close_system(model,0);
end
