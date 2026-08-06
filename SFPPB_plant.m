function [sys,x0,str,ts] = SFPPB_plant(t,x,u,flag)
% Level-1 MATLAB S-Function for paper Examples 1 and 2.
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 1, sys = mdlDerivatives(t,x,u);
    case 3, sys = x;
    case {2,4,9}, sys = [];
    otherwise, error('SFPPB_plant:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
global SFPPB_RL_P
p = SFPPB_RL_P;
sizes = simsizes;
sizes.NumContStates = 2;
sizes.NumDiscStates = 0;
sizes.NumOutputs = 2;
sizes.NumInputs = 1;
sizes.DirFeedthrough = 0;
sizes.NumSampleTimes = 1;
sys = simsizes(sizes);
x0 = [p.yd(0)+p.initial_error; p.initial_x2];
str = [];
ts = [0 0];
end

function sys = mdlDerivatives(~,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;
if p.input_saturation_enabled
    u_applied = min(max(u(1),-p.u_d),p.u_d);
else
    u_applied = u(1);
end
if p.example_id == 1
    f1 = -cos(2*x(1));
    f2 = cos(x(1))*sin(x(2));
    sys = [f1+x(2); f2+u_applied];
else
    q = x(1); dq = x(2);
    r = p.robot;
    sys = [dq; u_applied/r.M-r.m*r.g*r.l*sin(q)/(2*r.M)-r.B*dq/r.M];
end
end
