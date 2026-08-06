function [sys,x0,str,ts] = SFPPB_aux(t,x,u,flag)
%SFPPB_AUX  Auxiliary states rho (11) and O (24) of the proposed method.
%
%  state x = [rho; O]
%  input  u = unconstrained control u(t)
%  output  = [rho; O]
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 1, sys = mdlDerivatives(t,x,u);
    case 3, sys = x;
    case {2,4,9}, sys = [];
    otherwise, error('SFPPB_aux:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
sizes = simsizes;
sizes.NumContStates  = 2;            % [rho; O]
sizes.NumDiscStates  = 0;
sizes.NumOutputs     = 2;
sizes.NumInputs      = 1;
sizes.DirFeedthrough = 0;
sizes.NumSampleTimes = 1;
sys = simsizes(sizes);
x0 = [0; 0];                         % rho(0)=0, O(0)=0
str = [];
ts  = [0 0];
end

function sys = mdlDerivatives(~,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;

rho = x(1);
O   = x(2);
v   = u(1);

if p.input_saturation_enabled
    % (3): k(u) = u_d*tanh(u/u_d)
    k = p.u_d*tanh(v/p.u_d);

    % (11): rho_dot = -p1*rho + p2*(omega_1+omega_2)
    omega_1 = (sign(v-p.u_d)+1)*(v-p.u_d);
    omega_2 = (sign(v+p.u_d)-1)*(v+p.u_d);
    rho_dot = -p.p_1*rho + p.p_2*(omega_1+omega_2);

    % (24): O_dot = -O + (k(u)-u)
    O_dot = -O + (k-v);
else
    % Without saturation: both auxiliary states decay to zero.
    rho_dot = -p.p_1*rho;
    O_dot   = -O;
end

sys = [rho_dot; O_dot];
end
