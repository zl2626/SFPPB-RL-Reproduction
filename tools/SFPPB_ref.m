function [sys,x0,str,ts] = SFPPB_ref(t,x,u,flag)
%SFPPB_REF  Reference signal block: yd = p.yd(t) from SFPPB_params.m.
%  Keeps the top-level Simulink diagram showing "Reference yd -> Controller".
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 3, sys = mdlOutputs(t,x,u);
    case {1,2,4,9}, sys = [];
    otherwise, error('SFPPB_ref:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
sizes = simsizes;
sizes.NumContStates  = 0;
sizes.NumDiscStates  = 0;
sizes.NumOutputs     = 1;
sizes.NumInputs      = 0;
sizes.DirFeedthrough = 0;
sizes.NumSampleTimes = 1;
sys = simsizes(sizes);
x0 = [];
str = [];
ts  = [0 0];
end

function sys = mdlOutputs(t,x,u)
global SFPPB_RL_P
sys = SFPPB_RL_P.yd(t);
end
