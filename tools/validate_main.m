function report = validate_main(results)
%VALIDATE_MAIN  Main-method validation table.
%  Columns: boundary/input checks, delta-clamp diagnostics, true quadratic
%  cost J_Q, and the effective number of excited RBF directions.
n = numel(results);
report = table('Size',[n 15], ...
    'VariableTypes',{'double','double','double','double','double', ...
    'logical','logical','double','double','double','double','double', ...
    'double','double','double'}, ...
    'VariableNames',{'Example','InitialError','MaxBoundaryViolation', ...
    'MaxSaturatedInput','FinalAbsError','BoundarySatisfied','InputSatisfied', ...
    'DeltaClampCount','DeltaClampFraction','DeltaMaxViolation','QuadCost', ...
    'ExcitedSJ1','ExcitedSJ2','FinalWdiff1','FinalWdiff2'});

for k = 1:n
    s = collect_signals(results(k).out);
    e = s.error.Data(:);
    violation = max([e-s.upper.Data(:); s.lower.Data(:)-e; 0]);
    max_input = max(abs(s.u_sat.Data(:)));
    final_error = abs(e(end));

    p = SFPPB_params("main", results(k).example_id, ...
        results(k).initial_error, true);
    [dcount,dfrac,dmax] = delta_stats(s, p.delta_margin);
    J = quadratic_cost(s);
    [exc1,exc2] = excitation_directions(s, p, "main");
    if isfield(s,'Wdiff1_norm') && ~isempty(s.Wdiff1_norm.Data)
        wd1 = s.Wdiff1_norm.Data(end);
        wd2 = s.Wdiff2_norm.Data(end);
    else
        wd1 = NaN; wd2 = NaN;
    end

    report(k,:) = {results(k).example_id, results(k).initial_error, ...
        violation, max_input, final_error, violation<=1e-8, ...
        max_input<=2+1e-8, dcount, dfrac, dmax, J, exc1, exc2, wd1, wd2};
end

if any(report.DeltaClampFraction > 0.01)
    warning('validate_main:DeltaClamp', ...
        'delta clamp activated on >1%% of samples in main cases.');
end
end

function s = collect_signals(out)
names = {'x1','x2','u','u_sat','yd','error','lower','upper','z1','z2', ...
    'theta1','theta2','rho','O','Wp1_norm','Wp2_norm','Wc1_norm', ...
    'Wc2_norm','Wa1_norm','Wa2_norm','WF1_norm','WF2_norm','valid', ...
    'alpha1','delta','Wdiff1_norm','Wdiff2_norm'};
s = struct;
available = out.who;
for k = 1:numel(names)
    if any(strcmp(available,names{k}))
        s.(names{k}) = out.get(names{k});
    end
end
if ~isfield(s,'valid') && isfield(s,'error')
    s.valid = timeseries(ones(size(s.error.Data)), s.error.Time);
end
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
%QUADRATIC_COST  J_Q = int(z1^2+alpha1^2)dt + int(z2^2+u^2)dt.
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
