function [sys,x0,str,ts] = SFPPB_RL_ctrl(t,x,u,flag)
%SFPPB_RL_CTRL  Two-step SFPPB-ICAS controller (Level-1 S-Function).
%
%  Signal flow (see SFPPB_RL_simulate.slx):
%    input  u = [x1; x2; rho; O]
%    state  x = [W_F1; W_c1; W_a1; W_F2; W_c2; W_a2]
%    output = [u; S(u); yd; e1; B_lower; B_upper; z1; z2;
%              ||W_c1||; ||W_c2||; ||W_a1||; ||W_a2||;
%              ||W_F1||; ||W_F2||; alpha_hat_1; delta; x1; x2]
%
%  Paper formulas:
%    SFPPB and NMT .......... (7)-(16)
%    Identifier law ......... (40)
%    Critic law ............. (43)
%    Actor law .............. (46)
%    Virtual control ........ (44)
%    Actual control ......... (45)
%    Saturation estimator ... (2)-(3), (24)
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 1, sys = mdlDerivatives(t,x,u);
    case 3, sys = mdlOutputs(t,x,u);
    case {2,4,9}, sys = [];
    otherwise, error('SFPPB_RL_ctrl:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
global SFPPB_RL_P
p = SFPPB_RL_P;
n1 = p.n_nodes(1);
n2 = p.n_nodes(2);

sizes = simsizes;
sizes.NumContStates  = 3*(n1+n2);          % six weight groups, two steps
sizes.NumDiscStates  = 0;
sizes.NumOutputs     = 18;
sizes.NumInputs      = 4;                  % [x1; x2; rho; O]
sizes.DirFeedthrough = 1;
sizes.NumSampleTimes = 1;
sys = simsizes(sizes);

% Paper: W_c1 = W_a1 = W_F1 = [0.4] (24 or 32 neurons).
x0 = p.initial_weight*ones(sizes.NumContStates,1);
str = [];
ts  = [0 0];
end

function sys = mdlDerivatives(t,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;
[v,W] = modelSignals(t,x,u,p);

% (40) Identifier:  dW_Fj = upsilon*(z_j*S_Fj - sigma_j*W_Fj)
dW_F1 = p.upsilon*(v.z{1}*v.S_F{1} - p.sigma(1)*W.W_F{1});
dW_F2 = p.upsilon*(v.z{2}*v.S_F{2} - p.sigma(2)*W.W_F{2});

% (43) Critic:  dW_cj = -gamma_cj*S_Jj*S_Jj'*W_cj
dW_c1 = -p.gamma_c(1)*v.S_J{1}*(v.S_J{1}'*W.W_c{1});
dW_c2 = -p.gamma_c(2)*v.S_J{2}*(v.S_J{2}'*W.W_c{2});

% (46) Actor:  dW_aj = -S_Jj*S_Jj'*(gamma_aj*(W_aj-W_cj)+gamma_cj*W_cj)
dW_a1 = -v.S_J{1}*(v.S_J{1}'*(p.gamma_a(1)*(W.W_a{1}-W.W_c{1}) ...
    + p.gamma_c(1)*W.W_c{1}));
dW_a2 = -v.S_J{2}*(v.S_J{2}'*(p.gamma_a(2)*(W.W_a{2}-W.W_c{2}) ...
    + p.gamma_c(2)*W.W_c{2}));

sys = [dW_F1; dW_c1; dW_a1; dW_F2; dW_c2; dW_a2];
end

function sys = mdlOutputs(t,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;
[v,W] = modelSignals(t,x,u,p);

% (2): actual saturated input S(u)
if p.input_saturation_enabled
    S_u = min(max(v.u,-p.u_d),p.u_d);
else
    S_u = v.u;
end

sys = [v.u; S_u; v.yd; v.e1; v.B_lower; v.B_upper; v.z{1}; v.z{2}; ...
    norm(W.W_c{1}); norm(W.W_c{2}); norm(W.W_a{1}); norm(W.W_a{2}); ...
    norm(W.W_F{1}); norm(W.W_F{2}); v.alpha_hat{1}; v.delta; v.x1; v.x2];
end

function [v,W] = modelSignals(t,x,u,p)
%MODELSIGNALS  Rebuild every paper variable used by the control laws.
n1 = p.n_nodes(1);
n2 = p.n_nodes(2);
i  = 0;
W.W_F{1} = x(i+1:i+n1); i = i+n1;   W.W_c{1} = x(i+1:i+n1); i = i+n1;
W.W_a{1} = x(i+1:i+n1); i = i+n1;   W.W_F{2} = x(i+1:i+n2); i = i+n2;
W.W_c{2} = x(i+1:i+n2); i = i+n2;   W.W_a{2} = x(i+1:i+n2);

v.x1 = u(1);
v.x2 = u(2);
rho  = u(3);
O    = u(4);
v.yd = p.yd(t);
v.e1 = v.x1 - v.yd;                          % e1(t) = x1 - yd

% (9)-(10): kappa(t) and shifting function S(t)
[shift, kappa] = performanceFunctions(t,p);

% (8): sliding part [b_lower,b_upper]^T = kappa*P*Q + e1(0)*S(t)*I
P = [-1 -p.eta; p.eta 1];
if p.initial_error >= 0, Q = [0;1]; else, Q = [1;0]; end
base = kappa*(P*Q);

% (7): FPPB relaxation tanh(rho)*Lambda, Lambda = [-lambda_1; lambda_2]
b_lower = base(1) - p.lambda_1*tanh(rho);    % unshifted lower boundary
b_upper = base(2) + p.lambda_2*tanh(rho);    % unshifted upper boundary
v.B_lower = b_lower + p.initial_error*shift; % B_lower(t) for plotting
v.B_upper = b_upper + p.initial_error*shift; % B_upper(t) for plotting

% (12)-(13): relative error epsilon and NMT variable delta
epsilon    = v.e1 - p.initial_error*shift;
gap        = max(b_upper - b_lower, 1e-10);  % numerical margin only
v.delta    = (epsilon - b_lower)/gap;
delta_safe = min(max(v.delta,1e-10),1-1e-10);

% (14): z1 = ln(delta/(1-delta))
v.z{1} = log(delta_safe/(1-delta_safe));

% (16): A = 1/(delta*(1-delta)*(b_upper-b_lower))
A = 1/(delta_safe*(1-delta_safe)*gap);

% (5)/(33): S_F1([x1]);  (5)/(34): S_J1([x1,z1])
v.S_F{1} = sfppb_rbf(v.x1, n1, p.rbf_width);
v.S_J{1} = sfppb_rbf([v.x1; v.z{1}], n1, p.rbf_width);

% (39): F_hat_1 = W_F1'*S_F1
F_hat_1 = W.W_F{1}'*v.S_F{1};

% (44): alpha_hat_1 = -c1*z1/A - F_hat_1/A - W_a1'*S_J1/(2A)
v.alpha_hat{1} = -p.c(1)*v.z{1}/A - F_hat_1/A ...
    - (W.W_a{1}'*v.S_J{1})/(2*A);

% (15): z2 = x2 - alpha_hat_1 - O
v.z{2} = v.x2 - v.alpha_hat{1} - O;

% (5)/(33): S_F2([x1,x2]);  (5)/(34): S_J2([x1,x2,z2])
v.S_F{2} = sfppb_rbf([v.x1; v.x2], n2, p.rbf_width);
v.S_J{2} = sfppb_rbf([v.x1; v.x2; v.z{2}], n2, p.rbf_width);

% (39): F_hat_2 = W_F2'*S_F2
F_hat_2 = W.W_F{2}'*v.S_F{2};

% (45): u = -c2*z2 - F_hat_2 - W_a2'*S_J2/2
v.u = -p.c(2)*v.z{2} - F_hat_2 - (W.W_a{2}'*v.S_J{2})/2;
end

function [shift,kappa] = performanceFunctions(t,p)
%PERFORMANCEFUNCTIONS  Eqs. (9)-(10) of the paper.
if t < p.T
    s     = sin(pi*t/(2*p.T));
    shift = (1-s)^p.l_shift;
    kappa = p.kappa_0 + (p.kappa_T-p.kappa_0)*s^p.l_kappa;
else
    shift = 0;
    kappa = p.kappa_T;
end
end
