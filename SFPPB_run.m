function output = SFPPB_run(scope)
%SFPPB_RUN 统一批量仿真、保存结果并执行自动验收。
%   SFPPB_RUN("all")        运行主方法与全部参考对比（默认）。
%   SFPPB_RUN("main")       只运行本文四个主工况。
%   SFPPB_RUN("comparison") 只运行 Fig.5、6、10、11 对比工况。
%
% 输出结构包含 main、comparison 及其验收表；MAT 文件接口保持不变。

arguments
    scope (1,1) string {mustBeMember(scope,["all","main","comparison"])} = "all"
end

project_dir=fileparts(mfilename('fullpath'));
addpath(project_dir);
old_dir=pwd;
cleanup=onCleanup(@()cd(old_dir));
cd(project_dir);
ensureModels(scope);

output=struct('main',[],'main_validation',[], ...
    'comparison',[],'comparison_report',[],'comparison_acceptance',[]);

if scope=="all" || scope=="main"
    output.main=simulateMainCases();
    output.main_validation=validateMain(output.main);
    results=output.main;
    report=output.main_validation;
    save('main_results.mat','results','-v7.3');
    save('main_validation.mat','report');
    disp(output.main_validation);
end

if scope=="all" || scope=="comparison"
    output.comparison=simulateComparisonCases();
    [output.comparison_report,output.comparison_acceptance]= ...
        validateComparison(output.comparison);
    results=output.comparison;
    report=output.comparison_report;
    acceptance=output.comparison_acceptance;
    save('comparison_results.mat','results','-v7.3');
    save('comparison_validation.mat','report','acceptance');
    disp(output.comparison_report);
    disp(output.comparison_acceptance);
end
clear cleanup
end

function ensureModels(scope)
main_missing=~isfile('SFPPB_RL_simulate.slx');
comparison_missing=~isfile('Ref42_SFPPC_compare.slx') ...
    || ~isfile('Ref49_ICAS_compare.slx');
if (scope=="all" || scope=="main") && main_missing
    SFPPB_build("main");
end
if (scope=="all" || scope=="comparison") && comparison_missing
    SFPPB_build("comparison");
end
end

function results=simulateMainCases
% 本文两个算例、正负两种初始误差，共四个主工况。
global SFPPB_RL_P
cases=[1 0.3;1 -0.3;2 0.3;2 -0.3];
template=struct('example_id',NaN,'initial_error',NaN,'out',[]);
results=repmat(template,size(cases,1),1);
for k=1:size(cases,1)
    example_id=cases(k,1);
    initial_error=cases(k,2);
    SFPPB_RL_P=SFPPB_params("main",example_id,initial_error,true);
    out=sim('SFPPB_RL_simulate','StopTime',num2str(SFPPB_RL_P.stop_time));
    results(k)=struct('example_id',example_id, ...
        'initial_error',initial_error,'out',out);
end
end

function results=simulateComparisonCases
% 每个算例10个工况：Fig.5/10八个，[42]对比两个。
template=emptyComparisonResult();
results=repmat(template,20,1);
cursor=0;
for example_id=1:2
    ref49_stop=15+5*double(example_id==2);
    ref42_stop=15+10*double(example_id==2);
    ref42_initial_error = ref42InitialError(example_id);

    % Fig.5/10(a)(b)：无饱和，三种初始误差。
    for initial_error=[0.3 0.05 -0.3]
        cursor=cursor+1;
        results(cursor)=runReference("ref49","ref49",example_id, ...
            initial_error,false,ref49_stop,'Ref49_ICAS_compare');
        cursor=cursor+1;
        results(cursor)=runProposed("ref49",example_id, ...
            initial_error,false,ref49_stop);
    end

    % Fig.5/10(c)(d)：固定PPB失效与本文SFPPB成功。
    cursor=cursor+1;
    results(cursor)=runReference("ref49","ref49",example_id, ...
        0.05,true,ref49_stop,'Ref49_ICAS_compare');
    cursor=cursor+1;
    results(cursor)=runProposed("ref49",example_id,0.05,true,ref49_stop);

    % Fig.6/11：本文方法与文献[42]。
    cursor=cursor+1;
    results(cursor)=runReference("ref42","ref42",example_id, ...
        ref42_initial_error,true,ref42_stop,'Ref42_SFPPC_compare');
    cursor=cursor+1;
    results(cursor)=runProposed("ref42",example_id, ...
        ref42_initial_error,true,ref42_stop);
end
end

function result=runReference(algorithm,group,example_id,initial_error, ...
        saturation,stop_time,model)
global SFPPB_RL_P
SFPPB_RL_P=SFPPB_params(algorithm,example_id,initial_error,saturation);
SFPPB_RL_P.stop_time=stop_time;
result=baseComparisonResult(algorithm,group,example_id, ...
    initial_error,saturation,stop_time);
try
    out=sim(model,'StopTime',num2str(stop_time));
    result.signals=collectSignals(out);
    [result.completed,result.failure_time,result.failure_reason,result.signals]= ...
        assessReferenceRun(result.signals,algorithm,stop_time, ...
        initial_error,saturation);
catch exception
    result.completed=false;
    result.failure_reason="simulation_error: "+string(exception.message);
end
end

function result=runProposed(group,example_id,initial_error,saturation,stop_time)
global SFPPB_RL_P
SFPPB_RL_P=SFPPB_params("main",example_id,initial_error,saturation);
SFPPB_RL_P.stop_time=stop_time;
if group=="ref49"
    % 与[49]使用相同完整初始状态，而非只保持 e1(0) 相同。
    SFPPB_RL_P.initial_x2=0.6;
end
result=baseComparisonResult("proposed",group,example_id, ...
    initial_error,saturation,stop_time);
try
    out=sim('SFPPB_RL_simulate','StopTime',num2str(stop_time));
    result.signals=collectSignals(out);
    finite_signals=all(isfinite(result.signals.error.Data));
    boundary_violation=max([result.signals.error.Data-result.signals.upper.Data; ...
        result.signals.lower.Data-result.signals.error.Data;0]);
    result.completed=finite_signals && boundary_violation<=1e-8;
    if ~finite_signals
        result.failure_reason="nonfinite_signal";
    elseif boundary_violation>1e-8
        result.failure_reason="proposed_method_boundary_violation";
    end
catch exception
    result.completed=false;
    result.failure_reason="simulation_error: "+string(exception.message);
end
end

function [completed,failure_time,reason,signals]=assessReferenceRun( ...
        signals,algorithm,stop_time,initial_error,saturation)
completed=true;
failure_time=NaN;
reason="";
if algorithm=="ref49" && isfield(signals,'valid')
    bad=find(signals.valid.Data(:)<0.5,1,'first');
    if ~isempty(bad)
        completed=false;
        failure_time=signals.valid.Time(bad);
        if failure_time<=1e-9 && abs(initial_error)>0.05
            reason="initial_error_outside_fixed_ppb";
        elseif saturation
            reason="input_saturation_singularity";
        else
            reason="transformed_error_reached_fixed_ppb";
        end
        signals=trimSignals(signals,failure_time);
    end
end
if completed && (~isfield(signals,'error') || isempty(signals.error.Time) ...
        || signals.error.Time(end)<stop_time-2e-3)
    completed=false;
    reason="simulation_ended_early";
end
end

function signals=collectSignals(out)
names={'x1','x2','u','u_sat','yd','error','lower','upper','z1','z2', ...
    'theta1','theta2','rho','O','Wp1_norm','Wp2_norm','Wc1_norm', ...
    'Wc2_norm','Wa1_norm','Wa2_norm','WF1_norm','WF2_norm','valid'};
signals=struct;
available=out.who;
for k=1:numel(names)
    if any(strcmp(available,names{k}))
        signals.(names{k})=out.get(names{k});
    end
end
if ~isfield(signals,'valid') && isfield(signals,'error')
    signals.valid=timeseries(ones(size(signals.error.Data)),signals.error.Time);
end
end

function signals=trimSignals(signals,failure_time)
names=fieldnames(signals);
for k=1:numel(names)
    value=signals.(names{k});
    if isa(value,'timeseries')
        keep=value.Time<=failure_time+1e-12;
        if ~any(keep), keep(1)=true; end
        signals.(names{k})=timeseries(value.Data(keep,:),value.Time(keep));
    end
end
end

function result=baseComparisonResult(algorithm,group,example_id, ...
        initial_error,saturation,stop_time)
result=emptyComparisonResult();
result.algorithm=string(algorithm);
result.comparison_group=string(group);
result.example_id=example_id;
result.initial_error=initial_error;
result.saturation_enabled=logical(saturation);
result.stop_time=stop_time;
end

function result=emptyComparisonResult
result=struct('algorithm',"",'comparison_group',"",'example_id',NaN, ...
    'initial_error',NaN,'saturation_enabled',true,'stop_time',NaN, ...
    'completed',false,'failure_time',NaN,'failure_reason',"",'signals',struct);
end

function report=validateMain(results)
report=table('Size',[numel(results) 7], ...
    'VariableTypes',{'double','double','double','double','double','logical','logical'}, ...
    'VariableNames',{'Example','InitialError','MaxBoundaryViolation', ...
    'MaxSaturatedInput','FinalAbsError','BoundarySatisfied','InputSatisfied'});
for k=1:numel(results)
    out=results(k).out;
    e=out.error.Data(:);
    violation=max([e-out.upper.Data(:);out.lower.Data(:)-e;0]);
    max_input=max(abs(out.u_sat.Data(:)));
    final_error=abs(e(end));
    report(k,:)={results(k).example_id,results(k).initial_error,violation, ...
        max_input,final_error,violation<=1e-8,max_input<=2+1e-8};
end
end

function [report,acceptance]=validateComparison(results)
n=numel(results);
report=table('Size',[n 14], ...
    'VariableTypes',{'string','string','double','double','logical','logical', ...
    'double','string','double','double','double','double','double','double'}, ...
    'VariableNames',{'Algorithm','Group','Example','InitialError','Saturation', ...
    'Completed','FailureTime','FailureReason','PeakAbsError','IAE', ...
    'PeakRawInput','IntegralAppliedInput','SaturationDuration','MaxBoundaryViolation'});
for k=1:n
    r=results(k);
    [peak_error,iae,peak_input,ju,saturation_duration,violation]= ...
        comparisonMetrics(r.signals,r.stop_time);
    report(k,:)={r.algorithm,r.comparison_group,r.example_id,r.initial_error, ...
        r.saturation_enabled,r.completed,r.failure_time,r.failure_reason, ...
        peak_error,iae,peak_input,ju,saturation_duration,violation};
end

acceptance=table('Size',[2 7], ...
    'VariableTypes',{'double','logical','logical','logical','logical','logical','logical'}, ...
    'VariableNames',{'Example','Ref49FeasibleFreeCompleted','Ref49SaturatedFailed', ...
    'ProposedSaturatedCompleted','ProposedErrorBelowRef42','ProposedInputBelowRef42', ...
    'ProposedInputIntegralBelowRef42'});
for example_id=1:2
    free49=pickResult(results,"ref49","ref49",example_id,0.05,false);
    sat49=pickResult(results,"ref49","ref49",example_id,0.05,true);
    sat_proposed=pickResult(results,"proposed","ref49",example_id,0.05,true);
    ref42_initial_error = ref42InitialError(example_id);
    ref42=pickResult(results,"ref42","ref42",example_id, ...
        ref42_initial_error,true);
    proposed=pickResult(results,"proposed","ref42",example_id, ...
        ref42_initial_error,true);
    [~,iae42,peak42,ju42,~,~]=comparisonMetrics(ref42.signals,ref42.stop_time);
    [~,iae_proposed,peak_proposed,ju_proposed,~,~]= ...
        comparisonMetrics(proposed.signals,proposed.stop_time);
    acceptance(example_id,:)={example_id,free49.completed,~sat49.completed, ...
        sat_proposed.completed,iae_proposed<iae42,peak_proposed<peak42, ...
        ju_proposed<ju42};
end
end

function [peak_error,iae,peak_input,ju,saturation_duration,violation]= ...
        comparisonMetrics(signals,stop_time)
peak_error=NaN; iae=NaN; peak_input=NaN; ju=NaN;
saturation_duration=NaN; violation=NaN;
if ~isfield(signals,'error') || isempty(signals.error.Time), return; end
t=signals.error.Time(:);
e=signals.error.Data(:);
peak_error=max(abs(e));
if numel(t)<2, iae=0; else, iae=trapz(t,abs(e)); end
if t(end)<stop_time, iae=iae+(stop_time-t(end))*abs(e(end)); end
if isfield(signals,'u')
    peak_input=max(abs(signals.u.Data(:)));
    if isfield(signals,'u_sat')
        if numel(signals.u_sat.Time)<2
            ju=0;
            saturation_duration=0;
        else
            ju=trapz(signals.u_sat.Time(:),abs(signals.u_sat.Data(:)));
            saturation_duration=trapz(signals.u.Time(:), ...
                abs(signals.u.Data(:)-signals.u_sat.Data(:))>1e-8);
        end
    end
end
if isfield(signals,'lower') && isfield(signals,'upper')
    violation=max([e-signals.upper.Data(:);signals.lower.Data(:)-e;0]);
end
end

function result=pickResult(results,algorithm,group,example_id, ...
        initial_error,saturation)
index=find([results.example_id]==example_id ...
    & [results.initial_error]==initial_error ...
    & [results.saturation_enabled]==saturation ...
    & [results.algorithm]==algorithm ...
    & [results.comparison_group]==group,1);
assert(~isempty(index),'缺少对比工况：%s/%s/Example%d。', ...
    algorithm,group,example_id);
result=results(index);
end

function value=ref42InitialError(example_id)
%REF42INITIALERROR Paper Fig.6 (Example 1) uses e1(0)=+0.3, Fig.11 (Example 2)
%uses e1(0)=-0.3 according to the paper's y-axis ranges.
value = -0.3*double(example_id==2)+0.3*double(example_id==1);
end
