function result = SFPPB_tune(algorithm, example_id, n_evals, schedule)
%SFPPB_TUNE  Same-budget Sobol tuning for proposed / [42] / [49].
%
%   RESULT = SFPPB_TUNE(ALGORITHM, EXAMPLE_ID, N_EVALS)
%
%   Every algorithm receives the same budget (default 120 evaluations),
%   the same number of scalar knobs (4), and the same objective:
%   the true quadratic stage cost
%       J_Q = int(z1^2+alpha1^2)dt + int(z2^2+u^2)dt
%   summed over each algorithm's actual paper comparison scenarios:
%     main  : Fig.6/11 saturated cases + Fig.5/10 feasible cases
%     ref42 : Fig.6/11 saturated cases
%     ref49 : Fig.5/10 feasible (no-saturation) cases
%   Failed runs (boundary violation, [49] singularity, NaN, ||W||>bound) are Inf.
arguments
    algorithm (1,1) string {mustBeMember(algorithm,["main","ref42","ref49"])}
    example_id (1,1) double {mustBeMember(example_id,[1 2])}
    n_evals (1,1) double = 120
    schedule (1,1) logical = false
end

project_dir = fileparts(fileparts(mfilename('fullpath')));
tools_dir = fileparts(mfilename('fullpath'));
comparison_dir = fullfile(project_dir,'comparison');
addpath(project_dir, tools_dir, comparison_dir);
old_dir = pwd;
cleanup = onCleanup(@()cd(old_dir));
cd(project_dir);

scenarios = tuningScenarios(algorithm, example_id);

switch algorithm
    case "main"
        model = 'SFPPB_RL_simulate';
        if schedule
            lb = [0 0 0];
            ub = [2 2 2];
            labels = {'tau_c','tau_a','tau_upsilon'};
        else
            lb = [0.5 0.5 0.5 0.1];
            ub = [2.0 2.0 2.0 1.0];
            labels = {'s_gamma_c','s_gamma_a','s_upsilon','initial_weight'};
        end
        weight_bound = 5;
    case "ref42"
        model = 'Ref42_SFPPC_compare';
        lb = [0.5 0.5 0.5 1.0];
        ub = [2.0 2.0 2.0 2.0];
        labels = {'s_r','s_sigma','s_theta0','l_shift'};
        weight_bound = Inf;      % [42] has no NN weights to bound
    otherwise
        model = 'Ref49_ICAS_compare';
        lb = [0.5 0.5 0.5 0.015];
        ub = [1.5 1.5 1.5 0.045];
        labels = {'s_kp','s_kc','s_ka','rl_blend'};
        weight_bound = 25;       % [49] projection bound
end

% Scrambled Sobol design, skip the degenerate first point.
q = sobolset(numel(lb),'Skip',1,'Leap',0);
q = scramble(q,'MatousekAffineOwen');
X = net(q,n_evals);
X = lb + (ub-lb).*X;

if n_evals >= 8
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local',4);
    end
    par_results = struct('J',cell(n_evals,1),'x',cell(n_evals,1));
    parfor k = 1:n_evals
        x = X(k,:);
        par_results(k).J = evaluateScenarioSet(model, algorithm, ...
            example_id, x, schedule, weight_bound, scenarios);
        par_results(k).x = x;
    end
    J_all = [par_results.J]';
    [best_J, best_idx] = min(J_all);
    best_x = par_results(best_idx).x;
else
    J_all = nan(n_evals,1);
    best_J = Inf;
    best_x = [];
    for k = 1:n_evals
        x = X(k,:);
        J = evaluateScenarioSet(model, algorithm, example_id, x, ...
            schedule, weight_bound, scenarios);
        J_all(k) = J;
        if J < best_J
            best_J = J;
            best_x = x;
        end
        if mod(k,20)==0
            fprintf('%s/Ex%d %3d/%d J=%.4g best=%.4g\n', ...
                algorithm, example_id, k, n_evals, J, best_J);
        end
    end
end

result = struct('algorithm',algorithm,'example_id',example_id, ...
    'n_evals',n_evals,'best_J',best_J,'best_knobs',best_x, ...
    'labels',{labels},'J_all',J_all, ...
    'stop_time',scenarios(1).stop_time, ...
    'initial_error',scenarios(1).initial_error, ...
    'saturation_enabled',scenarios(1).saturation, ...
    'scenario_count',numel(scenarios),'schedule',schedule);
results_dir = fullfile(project_dir,'results');
if ~isfolder(results_dir), mkdir(results_dir); end
if schedule
    result_file = fullfile(project_dir,'results','tuning_schedule_results.mat');
else
    result_file = fullfile(project_dir,'results','tuning_results.mat');
end
if isfile(result_file)
    d = load(result_file,'tuning_results');
    tuning_results = d.tuning_results;
else
    tuning_results = repmat(result,0,1);
end
tuning_results(end+1) = result;
save(result_file,'tuning_results');
disp(result);
end

function scenarios = tuningScenarios(algorithm, example_id)
%TUNINGSCENARIOS  The paper comparison cases used for tuning.
%  Fields: example_id, initial_error, saturation, stop_time, initial_x2.
if algorithm == "ref42"
    scenarios(1) = struct('example_id',example_id, ...
        'initial_error',-0.3*double(example_id==2)+0.3*double(example_id==1), ...
        'saturation',true,'stop_time',15+10*double(example_id==2), ...
        'initial_x2',double(example_id==1));
elseif algorithm == "ref49"
    scenarios(1) = struct('example_id',example_id, ...
        'initial_error',0.05,'saturation',false, ...
        'stop_time',15+5*double(example_id==2),'initial_x2',0.6);
else
    scenarios(1) = struct('example_id',example_id, ...
        'initial_error',-0.3*double(example_id==2)+0.3*double(example_id==1), ...
        'saturation',true,'stop_time',15+10*double(example_id==2), ...
        'initial_x2',double(example_id==1));
    scenarios(2) = struct('example_id',example_id, ...
        'initial_error',0.05,'saturation',false, ...
        'stop_time',15+5*double(example_id==2),'initial_x2',0.6);
end
end

function J = evaluateScenarioSet(model, algorithm, example_id, x, ...
        schedule, weight_bound, scenarios)
%EVALUATESCENARIOSET  Sum J_Q over the scenario set; any failure -> Inf.
J = 0;
for k = 1:numel(scenarios)
    sc = scenarios(k);
    p = SFPPB_params(algorithm, sc.example_id, sc.initial_error, ...
        sc.saturation);
    p.initial_x2 = sc.initial_x2;
    p.stop_time = sc.stop_time;
    if schedule
        p = applyTunedMainBase(p, algorithm, example_id);
    end
    p = applyKnobs(p, algorithm, x, schedule);
    J_scenario = evaluateTuning(model,p,algorithm,sc.stop_time,weight_bound);
    if ~isfinite(J_scenario)
        J = Inf;
        return;
    end
    J = J + J_scenario;
end
end

function J = evaluateTuning(model,p,algorithm,stop_time,weight_bound)
%EVALUATETUNING  Run one candidate and return J_Q (Inf on any failure).
global SFPPB_RL_P
SFPPB_RL_P = p;
J = Inf;
try
    out = sim(model,'StopTime',num2str(stop_time));
    s = collectSignalsTune(out);
    if isfield(s,'error') && ~isempty(s.error.Time) ...
            && s.error.Time(end) >= stop_time-2e-3
        J = quadraticCostTune(s);
        if boundaryViolated(s) || weightsUnbounded(s,weight_bound) ...
                || any(~isfinite(s.error.Data(:)))
            J = Inf;
        end
        if algorithm == "ref49" && isfield(s,'valid') ...
                && any(s.valid.Data(:)<0.5)
            J = Inf;
        end
    end
catch
    J = Inf;
end
end

function p = applyKnobs(p, algorithm, x, schedule)
%APPLYKNOBS  Map the four normalized knobs to each algorithm's parameters.
if algorithm == "main" && schedule
    p.tau_c = x(1);
    p.tau_a = x(2);
    p.tau_upsilon = x(3);
    return;
end
switch algorithm
    case "main"
        p.gamma_c = p.gamma_c*x(1);
        p.gamma_a = p.gamma_a*x(2);
        p.upsilon = p.upsilon*x(3);
        p.initial_weight = x(4);
        % Fair comparison uses constant rates; schedule tuning is separate.
        p.tau_c = 0; p.tau_a = 0; p.tau_upsilon = 0;
    case "ref42"
        p.ref42.r = p.ref42.r*x(1);
        p.ref42.sigma = p.ref42.sigma*x(2);
        p.ref42.theta0 = p.ref42.theta0*x(3);
        p.ref42.l_shift = x(4);
    otherwise
        p.ref49.kp = p.ref49.kp*x(1);
        p.ref49.kc = p.ref49.kc*x(2);
        p.ref49.ka = p.ref49.ka*x(3);
        p.ref49.rl_blend = x(4);
end
end

function p = applyTunedMainBase(p, algorithm, example_id)
%APPLYTUNEDMAINBASE  Start the schedule search from the fair-tuned main knobs.
if algorithm ~= "main", return; end
result_file = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'results','tuning_results.mat');
if ~isfile(result_file), return; end
d = load(result_file,'tuning_results');
idx = find(arrayfun(@(r) r.algorithm=="main" && r.example_id==example_id ...
    && (~isfield(r,'schedule') || ~r.schedule), d.tuning_results),1);
if ~isempty(idx)
    p = applyKnobs(p, algorithm, d.tuning_results(idx).best_knobs, false);
end
end

function s = collectSignalsTune(out)
%COLLECTSIGNALSTUNE  Minimal signal collection for the tuning loop.
names = {'x1','x2','u','u_sat','error','lower','upper','z1','z2', ...
    'alpha1','theta1','theta2','Wp1_norm','Wp2_norm','Wc1_norm', ...
    'Wc2_norm','Wa1_norm','Wa2_norm','WF1_norm','WF2_norm','valid'};
s = struct;
available = out.who;
for k = 1:numel(names)
    if any(strcmp(available,names{k}))
        s.(names{k}) = out.get(names{k});
    end
end
if ~isfield(s,'valid') && isfield(s,'error')
    s.valid = timeseries(ones(size(s.error.Data)),s.error.Time);
end
end

function J = quadraticCostTune(s)
%QUADRATICCOSTTUNE  J_Q = int(z1^2+alpha1^2)dt + int(z2^2+u^2)dt.
names = {'z1','alpha1','z2','u'};
t = s.z1.Time(:);
if numel(t)<2, J=0; return; end
J = 0;
for k = 1:numel(names)
    ts = s.(names{k}).Time(:);
    v = s.(names{k}).Data(:);
    if isempty(v), v=zeros(size(t)); end
    if numel(ts)~=numel(t) || any(abs(ts-t)>1e-12)
        v = interp1(ts,v,t,'linear','extrap');
    end
    J = J + trapz(t,v.^2);
end
end

function flag = boundaryViolated(s)
e = s.error.Data(:);
flag = max([e-s.upper.Data(:); s.lower.Data(:)-e; 0]) > 1e-8;
end

function flag = weightsUnbounded(s,weight_bound)
names = {'Wc1_norm','Wc2_norm','Wa1_norm','Wa2_norm', ...
    'WF1_norm','WF2_norm','Wp1_norm','Wp2_norm'};
flag = false;
for k = 1:numel(names)
    if isfield(s,names{k}) && any(s.(names{k}).Data(:)>weight_bound+1e-8)
        flag = true;
        return;
    end
end
end
