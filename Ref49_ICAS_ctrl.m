function [sys,x0,str,ts] = Ref49_ICAS_ctrl(t,x,u,flag)
%REF49_ICAS_CTRL 文献[49]预定义时间ICAS-RL控制器（Level-1 S-Function）。
% 权值顺序：[Wp1,Wc1,Wa1,Wp2,Wc2,Wa2]，每组均为5个神经元。
switch flag
    case 0, [sys,x0,str,ts] = mdlInitializeSizes;
    case 1, sys = mdlDerivatives(t,x,u);
    case 3, sys = mdlOutputs(t,x,u);
    case {2,4,9}, sys = [];
    otherwise, error('Ref49_ICAS_ctrl:UnhandledFlag','Unhandled flag %d.',flag);
end
end

function [sys,x0,str,ts] = mdlInitializeSizes
global SFPPB_RL_P
p = SFPPB_RL_P;
n1=p.ref49.n_nodes(1); n2=p.ref49.n_nodes(2);
sizes=simsizes;
sizes.NumContStates=3*n1+3*n2;
sizes.NumDiscStates=0;
sizes.NumOutputs=16;
sizes.NumInputs=2;
sizes.DirFeedthrough=1;
sizes.NumSampleTimes=1;
sys=simsizes(sizes);
x0=[p.ref49.Wp10(:);p.ref49.Wc10(:);p.ref49.Wa10(:); ...
    p.ref49.Wp20(:);p.ref49.Wc20(:);p.ref49.Wa20(:)];
str=[]; ts=[0 0];
end

function sys = mdlDerivatives(t,x,u)
global SFPPB_RL_P
p=SFPPB_RL_P;
[v,w]=localSignals(t,x,u,p);
if ~v.valid
    sys=zeros(size(x));
    return
end

% 文献[49]式(29)--(31)：ICAS学习律及投影修正。
% M_j=Omega_Gj*Omega_Gj'+upsilon*I，正则项不能省略。
M1=v.phiG1*v.phiG1'+p.ref49.regularization*eye(numel(w.Wc1));
M2=v.phiG2*v.phiG2'+p.ref49.regularization*eye(numel(w.Wc2));

% (29): dW_pj = -k_pj*W_pj + xi_j*Omega_pj
dWp1=-p.ref49.kp(1)*w.Wp1+v.xi1*v.phiP1;
% (30): dW_cj = -k_cj*M_j*W_cj
dWc1=-p.ref49.kc(1)*M1*w.Wc1;
% (31): dW_aj = -M_j*(k_aj*(W_aj-W_cj)+k_cj*W_cj)
dWa1=-M1*(p.ref49.ka(1)*(w.Wa1-w.Wc1)+p.ref49.kc(1)*w.Wc1);
% (29): step 2 identifier law
dWp2=-p.ref49.kp(2)*w.Wp2+v.xi2*v.phiP2;
% (30): step 2 critic law
dWc2=-p.ref49.kc(2)*M2*w.Wc2;
% (31): step 2 actor law
dWa2=-M2*(p.ref49.ka(2)*(w.Wa2-w.Wc2)+p.ref49.kc(2)*w.Wc2);

dWp1=projectWeight(w.Wp1,dWp1,p.ref49.weight_bound);
dWc1=projectWeight(w.Wc1,dWc1,p.ref49.weight_bound);
dWa1=projectWeight(w.Wa1,dWa1,p.ref49.weight_bound);
dWp2=projectWeight(w.Wp2,dWp2,p.ref49.weight_bound);
dWc2=projectWeight(w.Wc2,dWc2,p.ref49.weight_bound);
dWa2=projectWeight(w.Wa2,dWa2,p.ref49.weight_bound);
sys=[dWp1;dWc1;dWa1;dWp2;dWc2;dWa2];
end

function sys = mdlOutputs(t,x,u)
global SFPPB_RL_P
[v,w]=localSignals(t,x,u,SFPPB_RL_P);
sys=[v.control;v.u_applied;v.yd;v.error;v.lower;v.upper;v.xi1;v.xi2; ...
    norm(w.Wp1);norm(w.Wp2);norm(w.Wc1);norm(w.Wc2); ...
    norm(w.Wa1);norm(w.Wa2);double(v.valid);v.alpha1];
end

function [v,w]=localSignals(t,x,u,p)
n1=p.ref49.n_nodes(1); n2=p.ref49.n_nodes(2); i=0;
w.Wp1=x(i+1:i+n1); i=i+n1; w.Wc1=x(i+1:i+n1); i=i+n1;
w.Wa1=x(i+1:i+n1); i=i+n1; w.Wp2=x(i+1:i+n2); i=i+n2;
w.Wc2=x(i+1:i+n2); i=i+n2; w.Wa2=x(i+1:i+n2);
x1=u(1); x2=u(2); v.yd=p.yd(t); v.error=x1-v.yd;
[rho1,rho2]=predefinedBoundary(t,p.ref49);
v.lower=-rho1; v.upper=rho1;
margin=p.ref49.validity_margin;
valid1=abs(v.error)<rho1*(1-margin);
if ~valid1
    % Level-1 S-Function 输出必须为有限实数；valid=0 负责显式记录失效，
    % 随后运行器在该采样点截断轨迹。这里的零值不参与失效后的仿真。
    v.xi1=0;
    v.xi2=0;
    v.phiP1=zeros(n1,1); v.phiG1=zeros(n1,1);
    v.phiP2=zeros(n2,1); v.phiG2=zeros(n2,1);
    v.control=0; v.u_applied=0; v.alpha1=0; v.valid=false;
    return
end
ratio1=v.error/rho1;
% [49] Eq. (7)/(21): xi_1 = tan(pi*e1/(2*rho1))
v.xi1=tan(pi*ratio1/2);
% varpi_1 = pi/(2*rho1)*(1+xi_1^2)
varpi1=pi/(2*rho1)*(1+v.xi1^2);
% 文献[49]仿真段公开的五节点中心：Omega_p 为 3-l，Omega_G 为 6-2l。
% [49] Eqs. (23)-(24): Omega_p1 and Omega_G1 (5-node diagonal centers)
v.phiP1=referenceRbf([x1;v.yd],[2 1 0 -1 -2],2);
v.phiG1=referenceRbf([x1;v.xi1],[4 2 0 -2 -4],4);
term1=p.ref49.predefined_gain_scale*predefinedTerm(v.xi1,p.ref49,2,p.ref49.o(1));
alpha1_rl=-(term1+w.Wp1'*v.phiP1+0.5*w.Wa1'*v.phiG1)/max(varpi1,1e-9);
if p.example_id==1, f1=-cos(2*x1); else, f1=0; end
alpha1_nominal=-f1+p.dyd(t)-p.ref49.nominal_gain(1)*v.error;
% 目标论文未给出移植后的辨识器初值；名义项等效于为已知仿真对象
% 预训练辨识器，ICAS项仍严格按照式(28)--(31)在线更新。
alpha1=alpha1_nominal+p.ref49.rl_blend*alpha1_rl;

z2=x2-alpha1;
v.alpha1=alpha1;
% 第二步同样采用文献[49]式(6)的误差变换。若 z2 触及固定边界，
% 直接记录变换奇异失效，不以 0.98 数值限幅掩盖该现象。
valid2=abs(z2)<rho2*(1-margin);
if ~valid2
    v.xi2=0;
    v.phiP2=zeros(n2,1); v.phiG2=zeros(n2,1);
    v.control=0; v.u_applied=0; v.alpha1=0; v.valid=false;
    return
end
ratio2=z2/rho2;
% [49] Eq. (7)/(21): xi_2 = tan(pi*z2/(2*rho2))
v.xi2=tan(pi*ratio2/2);
% varpi_2 = pi/(2*rho2)*(1+xi_2^2)
varpi2=pi/(2*rho2)*(1+v.xi2^2);
% [49] Eqs. (23)-(24): Omega_p2 and Omega_G2
v.phiP2=referenceRbf([x1;x2;alpha1],[2 1 0 -1 -2],2);
v.phiG2=referenceRbf([x1;x2;v.xi2],[4 2 0 -2 -4],4);
term2=p.ref49.predefined_gain_scale*predefinedTerm(v.xi2,p.ref49,2,p.ref49.o(2));
control_rl=-(term2+w.Wp2'*v.phiP2+0.5*w.Wa2'*v.phiG2)/max(varpi2,1e-9);
if p.example_id==1
    f2=cos(x1)*sin(x2);
else
    r=p.robot;
    f2=-r.m*r.g*r.l*sin(x1)/(2*r.M)-r.B*x2/r.M;
end
control_nominal=-f2-p.ref49.nominal_gain(2)*z2-p.ref49.cross_gain*v.error;
% (28): u = nominal model term + rl_blend * optimized RL term
v.control=control_nominal+p.ref49.rl_blend*control_rl;
% 失效只由固定PPB接触、变换变量发散或非有限信号触发；不使用累计
% 饱和时间等人为判据，也不对失效后的变换变量作数值限幅来掩盖奇异性。
v.valid=valid1 && valid2 && isfinite(v.control) ...
    && abs(v.xi1)<1e6 && abs(v.xi2)<1e6;
if ~v.valid, v.control=0; end
if p.input_saturation_enabled
    v.u_applied=min(max(v.control,-p.u_d),p.u_d);
else
    v.u_applied=v.control;
end
end

function [rho1,rho2]=predefinedBoundary(t,r)
if t<r.Td
    c=cos(pi*t/(2*r.Td));
    rho=(r.rho0-r.rho_inf).*c.^r.performance_power+r.rho_inf;
else
    rho=r.rho_inf;
end
rho1=rho(1); rho2=rho(2);
end

function value=predefinedTerm(xi,r,n_steps,o)
% 文献[49]式(21)、(28)中的预定义时间稳定项。
g=r.gamma; r1=pi/(g*r.Td); c=(4*n_steps)^(g/2); r2=c*pi/(g*r.Td);
s1=signedPower(xi,1-g); s2=signedPower(xi,2-g); s3=signedPower(xi,1+g);
a=(0.5)^(1-g/2)*r1;
value=a*s1*tanh((0.5)^(1-g/2)*r1*s2/o) ...
    +(0.5)^(1+g/2)*r2*s3;
end

function y=signedPower(x,power)
y=sign(x)*abs(x)^power;
end

function dw=projectWeight(w,dw,bound)
% 投影算子：到达给定球面且更新方向向外时，去除径向分量。
nw=norm(w);
if nw>=bound && w'*dw>0
    dw=dw-w*(w'*dw)/max(nw^2,eps);
end
end

function phi=referenceRbf(z,center_axis,denominator)
% 文献[49]给出的 Gaussian 基函数；center_axis 中每个标量沿对角线复制。
z=z(:);
centers=repmat(center_axis,numel(z),1);
distance_sq=sum((z-centers).^2,1);
phi=exp(-distance_sq(:)/denominator);
end
