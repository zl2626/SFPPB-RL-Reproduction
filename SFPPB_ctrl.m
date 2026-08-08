function [sys,x0,str,ts] = SFPPB_ctrl(t,x,u,flag)
%SFPPB_CTRL  Two-step SFPPB-ICAS controller of the paper (Level-1 S-Function).
%
%  Reading order follows the paper derivation:
%    states -> tracking error -> SFPPB (7)-(10) -> NMT (12)-(14),(16)
%    -> RBF (5),(33)-(34) -> Identifier (40) -> Critic (43) -> Actor (46)
%    -> virtual control (44) -> z2 (15) -> RBF step 2
%    -> Identifier/Critic/Actor step 2 -> actual control (45) -> saturation (2)
%
%  input  u = [x1; x2; rho; O; yd]  (yd comes from the Reference block)
%  state  x = [WF1; Wc1; Wa1; WF2; Wc2; Wa2]
%  output = [u; S(u); yd; e1; B_lower; B_upper; z1; z2;
%            ||Wc1||; ||Wc2||; ||Wa1||; ||Wa2||;
%            ||WF1||; ||WF2||; alpha1; delta; x1; x2;
%            ||Wa1-Wc1||; ||Wa2-Wc2||]
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 1, sys = mdlDerivatives(t,x,u);
    case 3, sys = mdlOutputs(t,x,u);
    case {2,4,9}, sys = [];
    otherwise, error('SFPPB_ctrl:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
global SFPPB_RL_P
p = SFPPB_RL_P;
n1 = p.n_nodes(1);
n2 = p.n_nodes(2);

sizes = simsizes;
sizes.NumContStates  = 3*(n1+n2);
sizes.NumDiscStates  = 0;
sizes.NumOutputs     = 20;
sizes.NumInputs      = 5;
sizes.DirFeedthrough = 1;
sizes.NumSampleTimes = 1;
sys = simsizes(sizes);

% Paper: W_c1 = W_a1 = W_F1 = [0.4] (24/32 neurons).
x0 = p.initial_weight*ones(sizes.NumContStates,1);
str = [];
ts  = [0 0];
end

function sys = mdlDerivatives(t,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;
n1 = p.n_nodes(1);
n2 = p.n_nodes(2);

% ---------- states: six weight groups (paper notation) ----------
WF1 = x(1:n1);              Wc1 = x(n1+1:2*n1);        Wa1 = x(2*n1+1:3*n1);
WF2 = x(3*n1+1:3*n1+n2);    Wc2 = x(3*n1+n2+1:3*n1+2*n2);
Wa2 = x(3*n1+2*n2+1:3*n1+3*n2);

% ---------- plant inputs and reference ----------
x1  = u(1);
x2  = u(2);
rho = u(3);
O   = u(4);
yd  = u(5);

% ---------- tracking error ----------
e1 = x1 - yd;

% ---------- learning-rate schedule (engineering layer, direction unchanged)
gamma_c = p.gamma_c./(1+p.tau_c*t);
gamma_a = p.gamma_a./(1+p.tau_a*t);
upsilon = p.upsilon./(1+p.tau_upsilon*t);

% ---------- SFPPB, Eqs. (9)-(10): kappa(t) and shifting S(t) ----------
if t < p.T
    s     = sin(pi*t/(2*p.T));
    shift = (1-s)^p.l_shift;
    kappa = p.kappa_0 + (p.kappa_T-p.kappa_0)*s^p.l_kappa;
else
    shift = 0;
    kappa = p.kappa_T;
end

% ---------- SFPPB, Eq. (8): sliding part [b_lower,b_upper]^T = kappa*P*Q
P = [-1 -p.eta; p.eta 1];
if p.initial_error >= 0, Q = [0;1]; else, Q = [1;0]; end
base = kappa*(P*Q);

% ---------- SFPPB, Eq. (7): FPPB relaxation tanh(rho)*Lambda ----------
b_lower = base(1) - p.lambda_1*tanh(rho);
b_upper = base(2) + p.lambda_2*tanh(rho);
B_lower = b_lower + p.initial_error*shift;   %#ok<NASGU> % 仅输出端用于绘图
B_upper = b_upper + p.initial_error*shift;   %#ok<NASGU> % 仅输出端用于绘图

% ---------- NMT, Eqs. (12)-(14),(16): epsilon, delta, z1, A ----------
epsilon = e1 - p.initial_error*shift;
gap     = max(b_upper - b_lower, p.delta_margin);
delta   = (epsilon - b_lower)/gap;
delta_safe = min(max(delta, p.delta_margin), 1-p.delta_margin);
z1 = log(delta_safe/(1-delta_safe));
A  = 1/(delta_safe*(1-delta_safe)*gap);

% ---------- RBF bases, Eqs. (5),(33)-(34): step 1 ----------
SF1 = SFPPB_rbf(x1, n1, p.rbf_width);
SJ1 = SFPPB_rbf([x1; z1], n1, p.rbf_width);

% ---------- Identifier, Eq. (40): dWF1 = upsilon*(z1*SF1 - sigma1*WF1)
dWF1 = upsilon*(z1*SF1 - p.sigma(1)*WF1);

% ---------- Critic, Eq. (43): dWc1 = -gamma_c1*SJ1*SJ1'*Wc1 ----------
dWc1 = -gamma_c(1)*SJ1*(SJ1'*Wc1);

% ---------- Actor, Eq. (46): dWa1 = -SJ1*SJ1'*(gamma_a1*(Wa1-Wc1)+gamma_c1*Wc1)
dWa1 = -SJ1*(SJ1'*(gamma_a(1)*(Wa1-Wc1) + gamma_c(1)*Wc1));

% ---------- Virtual control, Eqs. (39),(44): alpha1 ----------
F1_hat  = WF1'*SF1;
alpha1  = -p.c(1)*z1/A - F1_hat/A - (Wa1'*SJ1)/(2*A);

% ---------- Eq. (15): z2 = x2 - alpha1 - O ----------
z2 = x2 - alpha1 - O;

% ---------- RBF bases, Eqs. (5),(33)-(34): step 2 ----------
SF2 = SFPPB_rbf([x1; x2], n2, p.rbf_width);
SJ2 = SFPPB_rbf([x1; x2; z2], n2, p.rbf_width);

% ---------- Identifier, Eq. (40): step 2 ----------
dWF2 = upsilon*(z2*SF2 - p.sigma(2)*WF2);

% ---------- Critic, Eq. (43): step 2 ----------
dWc2 = -gamma_c(2)*SJ2*(SJ2'*Wc2);

% ---------- Actor, Eq. (46): step 2 ----------
dWa2 = -SJ2*(SJ2'*(gamma_a(2)*(Wa2-Wc2) + gamma_c(2)*Wc2));

sys = [dWF1; dWc1; dWa1; dWF2; dWc2; dWa2];
end

function sys = mdlOutputs(t,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;
n1 = p.n_nodes(1);
n2 = p.n_nodes(2);

% Same paper-order computation as mdlDerivatives (readability over DRY).
WF1 = x(1:n1);              Wc1 = x(n1+1:2*n1);        Wa1 = x(2*n1+1:3*n1);
WF2 = x(3*n1+1:3*n1+n2);    Wc2 = x(3*n1+n2+1:3*n1+2*n2);
Wa2 = x(3*n1+2*n2+1:3*n1+3*n2);

x1  = u(1);
x2  = u(2);
rho = u(3);
O   = u(4);
yd  = u(5);

e1 = x1 - yd;

if t < p.T
    s     = sin(pi*t/(2*p.T));
    shift = (1-s)^p.l_shift;
    kappa = p.kappa_0 + (p.kappa_T-p.kappa_0)*s^p.l_kappa;
else
    shift = 0;
    kappa = p.kappa_T;
end

P = [-1 -p.eta; p.eta 1];
if p.initial_error >= 0, Q = [0;1]; else, Q = [1;0]; end
base = kappa*(P*Q);

b_lower = base(1) - p.lambda_1*tanh(rho);
b_upper = base(2) + p.lambda_2*tanh(rho);
B_lower = b_lower + p.initial_error*shift;
B_upper = b_upper + p.initial_error*shift;

epsilon = e1 - p.initial_error*shift;
gap     = max(b_upper - b_lower, p.delta_margin);
delta   = (epsilon - b_lower)/gap;
delta_safe = min(max(delta, p.delta_margin), 1-p.delta_margin);
z1 = log(delta_safe/(1-delta_safe));
A  = 1/(delta_safe*(1-delta_safe)*gap);

SF1 = SFPPB_rbf(x1, n1, p.rbf_width);
SJ1 = SFPPB_rbf([x1; z1], n1, p.rbf_width);

F1_hat = WF1'*SF1;
alpha1 = -p.c(1)*z1/A - F1_hat/A - (Wa1'*SJ1)/(2*A);

z2 = x2 - alpha1 - O;

SF2 = SFPPB_rbf([x1; x2], n2, p.rbf_width);
SJ2 = SFPPB_rbf([x1; x2; z2], n2, p.rbf_width);
F2_hat = WF2'*SF2;

% ---------- Actual control, Eq. (45): u = -c2*z2 - F2_hat - Wa2'*SJ2/2
u_ctrl = -p.c(2)*z2 - F2_hat - (Wa2'*SJ2)/2;

% ---------- Saturation, Eq. (2): S(u) ----------
if p.input_saturation_enabled
    S_u = min(max(u_ctrl,-p.u_d),p.u_d);
else
    S_u = u_ctrl;
end

sys = [u_ctrl; S_u; yd; e1; B_lower; B_upper; z1; z2; ...
    norm(Wc1); norm(Wc2); norm(Wa1); norm(Wa2); ...
    norm(WF1); norm(WF2); alpha1; delta; x1; x2; ...
    norm(Wa1-Wc1); norm(Wa2-Wc2)];
end
