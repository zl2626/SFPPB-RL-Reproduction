function [sys,x0,str,ts] = SFPPB_sat(t,x,u,flag)
%SFPPB_SAT  Explicit input-saturation block S(u), Eq. (2).
%  Pass-through when p.input_saturation_enabled is false.
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 3, sys = mdlOutputs(t,x,u);
    case {1,2,4,9}, sys = [];
    otherwise, error('SFPPB_sat:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
sizes = simsizes;
sizes.NumContStates  = 0;
sizes.NumDiscStates  = 0;
sizes.NumOutputs     = 1;
sizes.NumInputs      = 1;
sizes.DirFeedthrough = 1;
sizes.NumSampleTimes = 1;
sys = simsizes(sizes);
x0 = [];
str = [];
ts  = [0 0];
end

function sys = mdlOutputs(t,x,u)
global SFPPB_RL_P
p = SFPPB_RL_P;
if p.input_saturation_enabled
    sys = min(max(u(1),-p.u_d),p.u_d);   % Eq. (2): S(u)
else
    sys = u(1);
end
end
