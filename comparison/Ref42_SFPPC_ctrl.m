function [sys,x0,str,ts] = Ref42_SFPPC_ctrl(t,x,u,flag)
%REF42_SFPPC_CTRL  Reference [42] sliding flexible PPC controller.
%
%  state x = [Psi_hat_1; Psi_hat_2; rho; o]
%  input  u = [x1; x2]
%  output  = [u; S(u); yd; e1; B_lower; B_upper; z1; z2;
%             Psi_hat_1; Psi_hat_2; rho; o; alpha_1]
%
%  Paper [42] formulas:
%    SFPCB ................. (9)-(13)
%    NMT .................... (17)
%    Virtual control ........ (24)
%    Adaptive law (step 1) .. (25)
%    Auxiliary system ....... (11), (33)
%    Actual control ......... (39)
%    Adaptive law (step n) .. (40)
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 1, sys = mdlDerivatives(t,x,u);
    case 3, sys = mdlOutputs(t,x,u);
    case {2,4,9}, sys = [];
    otherwise, error('Ref42_SFPPC_ctrl:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
global SFPPB_RL_P
p = SFPPB_RL_P;

sizes = simsizes;
sizes.NumContStates  = 4;            % [Psi_hat_1; Psi_hat_2; rho; o]
sizes.NumDiscStates  = 0;
sizes.NumOutputs     = 13;
sizes.NumInputs      = 2;
sizes.DirFeedthrough = 1;
sizes.NumSampleTimes = 1;
sys = simsizes(sizes);
x0 = [p.ref42.theta0(:); 0; 0];      % rho(0)=0, o(0)=0
str = [];
ts  = [0 0];
end

function sys = mdlDerivatives(t,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;
v = localSignals(t,x,u,p);

Psi_hat_1 = x(1);
Psi_hat_2 = x(2);
rho       = x(3);
o         = x(4);

% (25): dPsi_hat_1 = r1*mu^2*z1^2*||phi_1||^2/(2a1) - sigma1*Psi_hat_1
dPsi_hat_1 = p.ref42.r(1)*v.A^2*v.z1^2*v.phi_1_norm2/(2*p.ref42.a(1)) ...
    - p.ref42.sigma(1)*Psi_hat_1;

% (40): dPsi_hat_2 = r2*z2^2*||phi_2||^2/(2a2) - sigma2*Psi_hat_2
dPsi_hat_2 = p.ref42.r(2)*v.z2^2*v.phi_2_norm2/(2*p.ref42.a(2)) ...
    - p.ref42.sigma(2)*Psi_hat_2;

% (11): rho_dot = -p1*rho + p2*(omega_1+omega_2)
if p.input_saturation_enabled
    omega_1 = (sign(v.u-p.u_d)+1)*(v.u-p.u_d);
    omega_2 = (sign(v.u+p.u_d)-1)*(v.u+p.u_d);
    drho = -p.p_1*rho + p.p_2*(omega_1+omega_2);
    % (33): o_dot = -o + (g(u)-u),  g(u)=u_d*tanh(u/u_d) from [42] Eq. (3)
    g_u = p.u_d*tanh(v.u/p.u_d);
    do  = -o + (g_u - v.u);
else
    drho = -p.p_1*rho;
    do   = -o;
end

sys = [dPsi_hat_1; dPsi_hat_2; drho; do];
end

function sys = mdlOutputs(t,x,u)
global SFPPB_RL_P
v = localSignals(t,x,u,SFPPB_RL_P);
sys = [v.u; v.S_u; v.yd; v.e1; v.B_lower; v.B_upper; ...
    v.z1; v.z2; x(1); x(2); x(3); x(4); v.alpha_1];
end

function v = localSignals(t,x,u,p)
%LOCALSIGNALS  Rebuild the [42] variables from states and plant outputs.
x1 = u(1);
x2 = u(2);
Psi_hat_1 = max(x(1),0);             % fuzzy parameter estimates are positive
Psi_hat_2 = max(x(2),0);
rho = x(3);
o   = x(4);

v.yd = p.yd(t);
v.e1 = x1 - v.yd;                    % e1(t) = x1 - yd

% (9)-(13): SFPCB with the [42] shifting exponent l_shift
[shift, kappa] = localBoundary(t,p);
P = [-1 -p.eta; p.eta 1];
if p.initial_error >= 0, Q = [0;1]; else, Q = [1;0]; end
base = kappa*(P*Q);
b_lower = base(1) - p.lambda_1*tanh(rho);
b_upper = base(2) + p.lambda_2*tanh(rho);
v.B_lower = b_lower + p.initial_error*shift;
v.B_upper = b_upper + p.initial_error*shift;

% (12)-(13): relative error and NMT variable
epsilon = v.e1 - p.initial_error*shift;
gap     = max(b_upper-b_lower, 1e-9);
delta   = min(max((epsilon-b_lower)/gap, p.delta_margin), 1-p.delta_margin);
v.z1    = log(delta/(1-delta));      % (17)
v.A     = 1/(delta*(1-delta)*gap);   % mu = A

% [42] Eq. (22): Z1 = [x1,x2,yd]^T (Eq. (23) omits x2, a source typo).
phi_1 = normalizedFuzzyBasis([x1;x2;v.yd],p.ref42.n_nodes(1), ...
    p.ref42.rbf_width);
v.phi_1_norm2 = phi_1'*phi_1;

% (24): alpha_1 = -c1*z1/mu - mu*z1*Psi_hat_1/(2a1*||phi_1||^2)
v.alpha_1 = -p.ref42.c(1)*v.z1/v.A ...
    - v.A*v.z1*Psi_hat_1*v.phi_1_norm2/(2*p.ref42.a(1));

% (18): z2 = x2 - alpha_1 - o
v.z2 = x2 - v.alpha_1 - o;

phi_2 = normalizedFuzzyBasis([x1;x2;v.yd],p.ref42.n_nodes(2), ...
    p.ref42.rbf_width);
v.phi_2_norm2 = phi_2'*phi_2;

% (39): u = -c2*z2 - o - z2*Psi_hat_2/(2a2*||phi_2||^2)
v.u = -p.ref42.c(2)*v.z2 - o ...
    - v.z2*Psi_hat_2*v.phi_2_norm2/(2*p.ref42.a(2));

% (2): actual saturated input S(u)
if p.input_saturation_enabled
    v.S_u = min(max(v.u,-p.u_d),p.u_d);
else
    v.S_u = v.u;
end
end

function [shift,kappa] = localBoundary(t,p)
%LOCALBOUNDARY  [42] Eqs. (9)-(10) with the transferred l_shift.
if t < p.T
    s     = sin(pi*t/(2*p.T));
    shift = (1-s)^p.ref42.l_shift;
    kappa = p.kappa_0 + (p.kappa_T-p.kappa_0)*s^p.l_kappa;
else
    shift = 0;
    kappa = p.kappa_T;
end
end

function phi = normalizedFuzzyBasis(z,node_count,width)
%NORMALIZEDFUZZYBASIS  [42] fuzzy membership, normalized by its sum.
membership = SFPPB_rbf(z,node_count,width);
phi = membership/max(sum(membership),eps);
end
