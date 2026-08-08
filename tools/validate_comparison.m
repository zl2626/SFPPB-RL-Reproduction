function [report,acceptance] = validate_comparison(results)
%VALIDATE_COMPARISON  Comparison validation table + acceptance criteria.
%  Same columns as validate_main plus algorithm/group/failure fields.
n = numel(results);
report = table('Size',[n 20], ...
    'VariableTypes',{'string','string','double','double','logical','logical', ...
    'double','string','double','double','double','double','double','double', ...
    'double','double','double','double','double','double'}, ...
    'VariableNames',{'Algorithm','Group','Example','InitialError','Saturation', ...
    'Completed','FailureTime','FailureReason','PeakAbsError','IAE', ...
    'PeakRawInput','IntegralAppliedInput','SaturationDuration', ...
    'MaxBoundaryViolation','DeltaClampCount','DeltaClampFraction', ...
    'DeltaMaxViolation','QuadCost','ExcitedSJ1','ExcitedSJ2'});

for k = 1:n
    r = results(k);
    [peak_error,iae,peak_input,ju,saturation_duration,violation] = ...
        comparison_metrics(r.signals,r.stop_time);

    diag_algorithm = char(r.algorithm);
    if strcmp(diag_algorithm,'proposed'), diag_algorithm = 'main'; end
    p = SFPPB_params(diag_algorithm,r.example_id,r.initial_error, ...
        r.saturation_enabled);

    if r.algorithm=="ref49"
        [dcount,dfrac,dmax] = deal(NaN,NaN,NaN);
    else
        [dcount,dfrac,dmax] = delta_stats(r.signals,p.delta_margin);
    end
    J = quadratic_cost(r.signals);
    if r.algorithm=="ref42"
        [exc1,exc2] = deal(NaN,NaN);
    else
        [exc1,exc2] = excitation_directions(r.signals,p,diag_algorithm);
    end

    report(k,:) = {r.algorithm,r.comparison_group,r.example_id, ...
        r.initial_error,r.saturation_enabled,r.completed,r.failure_time, ...
        r.failure_reason,peak_error,iae,peak_input,ju,saturation_duration, ...
        violation,dcount,dfrac,dmax,J,exc1,exc2};
end

if any(report.DeltaClampFraction > 0.01)
    warning('validate_comparison:DeltaClamp', ...
        'delta clamp activated on >1%% of samples in comparison cases.');
end

acceptance = table('Size',[2 7], ...
    'VariableTypes',{'double','logical','logical','logical','logical', ...
    'logical','logical'}, ...
    'VariableNames',{'Example','Ref49FeasibleFreeCompleted', ...
    'Ref49SaturatedFailed','ProposedSaturatedCompleted', ...
    'ProposedErrorBelowRef42','ProposedInputBelowRef42', ...
    'ProposedInputIntegralBelowRef42'});

for example_id = 1:2
    free49 = pick_result(results,"ref49","ref49",example_id,0.05,false);
    sat49 = pick_result(results,"ref49","ref49",example_id,0.05,true);
    sat_proposed = pick_result(results,"proposed","ref49",example_id,0.05,true);
    ref42_e0 = ref42_init_error(example_id);
    ref42 = pick_result(results,"ref42","ref42",example_id,ref42_e0,true);
    proposed = pick_result(results,"proposed","ref42",example_id,ref42_e0,true);

    [~,iae42,peak42,ju42,~,~] = comparison_metrics(ref42.signals,ref42.stop_time);
    [~,iae_proposed,peak_proposed,ju_proposed,~,~] = ...
        comparison_metrics(proposed.signals,proposed.stop_time);

    acceptance(example_id,:) = {example_id,free49.completed, ...
        ~sat49.completed,sat_proposed.completed,iae_proposed<iae42, ...
        peak_proposed<peak42,ju_proposed<ju42};
end
end

function [peak_error,iae,peak_input,ju,saturation_duration,violation] = ...
        comparison_metrics(signals,stop_time)
peak_error = NaN; iae = NaN; peak_input = NaN; ju = NaN;
saturation_duration = NaN; violation = NaN;
if ~isfield(signals,'error') || isempty(signals.error.Time), return; end
t = signals.error.Time(:);
e = signals.error.Data(:);
peak_error = max(abs(e));
if numel(t)<2, iae = 0; else, iae = trapz(t,abs(e)); end
if t(end)<stop_time, iae = iae+(stop_time-t(end))*abs(e(end)); end
if isfield(signals,'u')
    peak_input = max(abs(signals.u.Data(:)));
    if isfield(signals,'u_sat')
        if numel(signals.u_sat.Time)<2
            ju = 0; saturation_duration = 0;
        else
            ju = trapz(signals.u_sat.Time(:),abs(signals.u_sat.Data(:)));
            saturation_duration = trapz(signals.u.Time(:), ...
                abs(signals.u.Data(:)-signals.u_sat.Data(:))>1e-8);
        end
    end
end
if isfield(signals,'lower') && isfield(signals,'upper')
    violation = max([e-signals.upper.Data(:);signals.lower.Data(:)-e;0]);
end
end

function result = pick_result(results,algorithm,group,example_id, ...
        initial_error,saturation)
index = find([results.example_id]==example_id ...
    & [results.initial_error]==initial_error ...
    & [results.saturation_enabled]==saturation ...
    & [results.algorithm]==algorithm ...
    & [results.comparison_group]==group,1);
assert(~isempty(index),'Missing comparison case %s/%s/Example%d.', ...
    algorithm,group,example_id);
result = results(index);
end

function value = ref42_init_error(example_id)
value = -0.3*double(example_id==2)+0.3*double(example_id==1);
end

function [count,fraction,maxviol] = delta_stats(s,margin)
count = NaN; fraction = NaN; maxviol = NaN;
if ~isfield(s,'error') || ~isfield(s,'lower') || ~isfield(s,'upper') ...
        || isempty(s.error.Time)
    return;
end
e = s.error.Data(:); lo = s.lower.Data(:); hi = s.upper.Data(:);
delta = (e-lo)./(hi-lo);
finite = isfinite(delta);
lo_viol = finite & delta<margin;
hi_viol = finite & delta>1-margin;
count = sum(lo_viol)+sum(hi_viol);
fraction = count/numel(delta);
maxviol = 0;
if any(lo_viol), maxviol = max(maxviol, margin-min(delta(lo_viol))); end
if any(hi_viol), maxviol = max(maxviol, max(delta(hi_viol))-(1-margin)); end
end

function J = quadratic_cost(s)
J = NaN;
names = {'z1','alpha1','z2','u'};
if ~all(isfield(s,names)) || isempty(s.z1.Time), return; end
t = s.z1.Time(:);
if numel(t)<2, J = 0; return; end
J = 0;
for k = 1:numel(names)
    ts = s.(names{k}).Time(:);
    v  = s.(names{k}).Data(:);
    if isempty(v), v = zeros(size(t)); end
    if numel(ts)~=numel(t) || any(abs(ts-t)>1e-12)
        v = interp1(ts,v,t,'linear','extrap');
    end
    J = J + trapz(t,v.^2);
end
end

function [n1,n2] = excitation_directions(s,p,algorithm)
n1 = NaN; n2 = NaN;
if strcmp(algorithm,'ref42'), return; end
if ~isfield(s,'z1') || ~isfield(s,'x1') || isempty(s.z1.Time), return; end
idx = downsample_indexes(numel(s.z1.Time),2000);
x1 = s.x1.Data(:);
if strcmp(algorithm,'main')
    z1 = s.z1.Data(:); z2 = s.z2.Data(:); x2 = s.x2.Data(:);
    M1 = zeros(numel(idx),p.n_nodes(1));
    M2 = zeros(numel(idx),p.n_nodes(2));
    for m = 1:numel(idx)
        i = idx(m);
        M1(m,:) = SFPPB_rbf([x1(i);z1(i)],p.n_nodes(1),p.rbf_width)';
        M2(m,:) = SFPPB_rbf([x1(i);x2(i);z2(i)],p.n_nodes(2),p.rbf_width)';
    end
else
    xi1 = s.z1.Data(:); xi2 = s.z2.Data(:); x2 = s.x2.Data(:);
    M1 = zeros(numel(idx),5);
    M2 = zeros(numel(idx),5);
    for m = 1:numel(idx)
        i = idx(m);
        M1(m,:) = ref49_rbf([x1(i);xi1(i)],[4 2 0 -2 -4],4)';
        M2(m,:) = ref49_rbf([x1(i);x2(i);xi2(i)],[4 2 0 -2 -4],4)';
    end
end
n1 = effective_rank(M1);
n2 = effective_rank(M2);
end

function n = effective_rank(M)
s = svd(M,'econ');
if isempty(s), n = 0; return; end
n = sum(s > 0.01*max(s));
end

function idx = downsample_indexes(n,max_n)
if n<=max_n
    idx = (1:n)';
else
    idx = round(linspace(1,n,max_n))';
end
end

function phi = ref49_rbf(z,center_axis,denominator)
z = z(:);
centers = repmat(center_axis,numel(z),1);
phi = exp(-sum((z-centers).^2,1)'/denominator);
end
