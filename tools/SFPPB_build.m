function models = SFPPB_build(scope)
%SFPPB_BUILD  Rebuild the Simulink models from the S-function sources.
%   SFPPB_BUILD("all")         builds all three models (default)
%   SFPPB_BUILD("main")        builds SFPPB_RL_simulate.slx
%   SFPPB_BUILD("comparison")  builds comparison/*.slx
%
%   Top level shows the physical loop:
%     Reference yd -> SFPPB-RL Controller -> u -> Saturation S(u) -> Plant
%     Plant states x1,x2 -> feedback; rho/O auxiliary dynamics are separate.
%   Data recording is wrapped inside the "Simulation Logging" subsystem.
%
%   All models use fixed-step ode4 with step 0.001 s.
arguments
    scope (1,1) string {mustBeMember(scope,["all","main","comparison"])} = "all"
end

project_dir = fileparts(fileparts(mfilename('fullpath')));
comparison_dir = fullfile(project_dir,'comparison');
tools_dir = fileparts(mfilename('fullpath'));
addpath(project_dir, comparison_dir, tools_dir);
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

% ---------------- Reference block ----------------
add_block('simulink/User-Defined Functions/S-Function',[model '/Reference yd'], ...
    'FunctionName','SFPPB_ref', ...
    'Position',[70 130 190 175]);

% ---------------- Plant ----------------
add_block('simulink/User-Defined Functions/S-Function',[model '/Plant'], ...
    'FunctionName','SFPPB_plant','Position',[570 125 700 190]);
add_block('simulink/Signal Routing/Demux',[model '/Plant states'], ...
    'Outputs','2','Position',[740 120 745 195]);

% ---------------- Controller inputs: [x1; x2; rho; O; yd] ----------------
add_block('simulink/Signal Routing/Mux',[model '/Controller inputs'], ...
    'Inputs','5','Position',[250 90 255 250]);
controller_name = ['SFPPB-RL Controller',newline, ...
    'Eqs. (7)-(16),(40),(43)-(46)'];
add_block('simulink/User-Defined Functions/S-Function', ...
    [model '/' controller_name],'FunctionName','SFPPB_ctrl', ...
    'Position',[330 110 470 230]);

% ---------------- Auxiliary dynamics (rho and O) ----------------
aux_name = ['Auxiliary Dynamics',newline, ...
    'rho: SFPPB relaxation, Eq.(11)',newline, ...
    'O: saturation compensation, Eq.(24)'];
add_block('simulink/User-Defined Functions/S-Function',[model '/' aux_name], ...
    'FunctionName','SFPPB_aux','Position',[330 310 470 390]);
add_block('simulink/Signal Routing/Demux',[model '/Auxiliary states'], ...
    'Outputs','2','Position',[510 315 515 385]);

% ---------------- Explicit input saturation S(u) ----------------
sat_name = ['Input Saturation S(u)',newline,'Eq. (2)'];
add_block('simulink/User-Defined Functions/S-Function',[model '/' sat_name], ...
    'FunctionName','SFPPB_sat','Position',[570 250 700 300]);

% ---------------- Controller output split: u | rest (19) ----------------
add_block('simulink/Signal Routing/Demux',[model '/Controller outputs'], ...
    'Outputs','[1 19]','Position',[510 105 515 240]);

% ---------------- Simulation logging subsystem ----------------
controller_rest = {'u_sat','yd','error','lower','upper','z1','z2', ...
    'Wc1_norm','Wc2_norm','Wa1_norm','Wa2_norm','WF1_norm','WF2_norm', ...
    'alpha1','delta','ctrl_x1','ctrl_x2','Wdiff1_norm','Wdiff2_norm'};
addLoggingSubsystem(model, ...
    {{'u',{'u'}}, ...
     {'controller',controller_rest}, ...
     {'plant',{'x1','x2'}}, ...
     {'aux',{'rho','O'}}, ...
     {'S_u',{'u_sat_block'}}});

% ---------------- Wiring: physical loop ----------------
add_line(model,'Plant/1','Plant states/1','autorouting','on');
add_line(model,'Plant states/1','Controller inputs/1','autorouting','on');
add_line(model,'Plant states/2','Controller inputs/2','autorouting','on');
add_line(model,'Auxiliary states/1','Controller inputs/3','autorouting','on');
add_line(model,'Auxiliary states/2','Controller inputs/4','autorouting','on');
add_line(model,'Reference yd/1','Controller inputs/5','autorouting','on');
add_line(model,'Controller inputs/1',[controller_name '/1'],'autorouting','on');
add_line(model,[controller_name '/1'],'Controller outputs/1','autorouting','on');
add_line(model,'Controller outputs/1',[sat_name '/1'],'autorouting','on');
add_line(model,'Controller outputs/1',[aux_name '/1'],'autorouting','on');
add_line(model,[aux_name '/1'],'Auxiliary states/1','autorouting','on');
add_line(model,[sat_name '/1'],'Plant/1','autorouting','on');

% ---------------- Wiring: logging ----------------
add_line(model,'Controller outputs/1','Simulation Logging/1','autorouting','on');
add_line(model,'Controller outputs/2','Simulation Logging/2','autorouting','on');
add_line(model,'Plant/1','Simulation Logging/3','autorouting','on');
add_line(model,[aux_name '/1'],'Simulation Logging/4','autorouting','on');
add_line(model,[sat_name '/1'],'Simulation Logging/5','autorouting','on');

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
    'FunctionName','SFPPB_plant','Position',[500 125 630 190]);
add_block('simulink/Signal Routing/Demux',[model '/Plant states'], ...
    'Outputs','2','Position',[670 120 675 195]);

add_block('simulink/Signal Routing/Mux',[model '/Controller inputs'], ...
    'Inputs','2','Position',[180 120 185 200]);
if algorithm=="ref42"
    controller_name = 'Ref42 SFPPC Controller';
else
    controller_name = 'Ref49 ICAS Controller';
end
ctrl_block = [model '/' controller_name];
add_block('simulink/User-Defined Functions/S-Function', ctrl_block, ...
    'FunctionName',controller, ...
    'Position',[240 110 380 230]);
set_param(ctrl_block,'Description', ...
    'Reference [42] SFPPC: Eqs. (24)-(25),(33),(39)-(40)');

add_block('simulink/Signal Routing/Demux',[model '/Controller outputs'], ...
    'Outputs',['[1 ' num2str(numel(signal_names)-1) ']'], ...
    'Position',[420 105 425 240]);

sat_name = 'Input Saturation S(u)';
sat_block = [model '/' sat_name];
add_block('simulink/User-Defined Functions/S-Function',sat_block, ...
    'FunctionName','SFPPB_sat','Position',[500 250 630 300]);
set_param(sat_block,'Description','Eq. (2): S(u) = sgn(u)*u_d if |u|>u_d');

addLoggingSubsystem(model, ...
    {{'u',{'u'}}, ...
     {'controller',signal_names(2:end)}, ...
     {'plant',{'x1','x2'}}});

add_line(model,'Plant/1','Plant states/1','autorouting','on');
add_line(model,'Plant states/1','Controller inputs/1','autorouting','on');
add_line(model,'Plant states/2','Controller inputs/2','autorouting','on');
add_line(model,'Controller inputs/1',[controller_name '/1'],'autorouting','on');
add_line(model,[controller_name '/1'],'Controller outputs/1','autorouting','on');
add_line(model,'Controller outputs/1',[sat_name '/1'],'autorouting','on');
add_line(model,[sat_name '/1'],'Plant/1','autorouting','on');

add_line(model,'Controller outputs/1','Simulation Logging/1','autorouting','on');
add_line(model,'Controller outputs/2','Simulation Logging/2','autorouting','on');
add_line(model,'Plant/1','Simulation Logging/3','autorouting','on');

finishModel(model);
end

function addLoggingSubsystem(model,groups)
%ADDLOGGINGSUBSYSTEM  One subsystem that demuxes and logs every signal.
log_block = [model '/Simulation Logging'];
add_block('simulink/Ports & Subsystems/Subsystem',log_block, ...
    'Position',[830 60 1030 620]);
delete_block([log_block '/In1']);
delete_block([log_block '/Out1']);

for g = 1:numel(groups)
    in_name = groups{g}{1};
    names = groups{g}{2};
    y0 = 40 + 130*(g-1);
    add_block('simulink/Sources/In1',[log_block '/' in_name], ...
        'Port',num2str(g),'Position',[30 y0 60 y0+20]);
    demux_name = ['Demux ' in_name];
    add_block('simulink/Signal Routing/Demux',[log_block '/' demux_name], ...
        'Outputs',num2str(numel(names)),'Position',[100 y0 105 y0+20]);
    add_line(log_block,[in_name '/1'],[demux_name '/1'],'autorouting','on');
    for k = 1:numel(names)
        tw = [log_block '/To Workspace ' names{k}];
        y = y0 + 24*(k-1);
        add_block('simulink/Sinks/To Workspace',tw,'VariableName',names{k}, ...
            'SaveFormat','Timeseries','Position',[170 y 300 y+20]);
        add_line(log_block,sprintf('%s/%d',demux_name,k), ...
            ['To Workspace ' names{k} '/1'],'autorouting','on');
    end
end
end

function resetModel(model)
if bdIsLoaded(model), close_system(model,1); end
model_file = [model '.slx'];
if isfile(model_file), delete(model_file); end
new_system(model);
end

function setSolver(model,stop_time)
set_param(model,'SolverType','Fixed-step','Solver','ode4','FixedStep','0.001', ...
    'StopTime',num2str(stop_time),'ReturnWorkspaceOutputs','on');
end

function finishModel(model)
Simulink.BlockDiagram.arrangeSystem(model);
save_system(model);
close_system(model,0);
end
