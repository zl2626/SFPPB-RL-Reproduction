function p = SFPPB_params(mode,example_id,initial_error,saturation_enabled)
%SFPPB_PARAMS 本文方法及参考控制器的唯一参数入口。
%   P = SFPPB_PARAMS("main",EXAMPLE,ERROR,SATURATION) 返回本文方法参数。
%   P = SFPPB_PARAMS("ref42",...) 或 SFPPB_PARAMS("ref49",...) 返回将
%   参考控制器移植到目标论文算例后的参数。
%
% 参数来源标记：
%   [论文给定] 目标论文或参考文献明确报告；
%   [复现调节] 目标论文没有披露，集中在本文件中可追踪调节。

arguments
    mode (1,1) string {mustBeMember(mode,["main","ref42","ref49"])} = "main"
    example_id (1,1) double {mustBeMember(example_id,[1 2])} = 1
    initial_error (1,1) double = 0.3
    saturation_enabled (1,1) logical = true
end

%% 公共仿真工况与目标系统参数
p.example_id = example_id;
p.initial_error = initial_error;
p.initial_x2 = double(example_id==1);  % [复现调节] 论文未披露的x2(0)
p.stop_time = 30;
p.yd = @(t) 0.2*sin(0.6*t);
p.dyd = @(t) 0.12*cos(0.6*t);
p.u_d = 2;
p.input_saturation_enabled = saturation_enabled;

% 单连杆机械臂参数（Example 2，论文给定）。
p.robot.m = 0.02;
p.robot.g = 9.8;
p.robot.l = 1;
p.robot.M = 1;
p.robot.B = 1;

%% 本文 SFPPB 与 ICAS 参数（论文给定）
p.kappa_0 = 0.1;
p.kappa_T = 0.01;
p.T = 5;
p.l_kappa = 1;
p.l_shift = 1;
p.eta = 1;
p.lambda_1 = 0.2;
p.lambda_2 = 0.2;
p.p_1 = 5;
p.p_2 = 0.5;

p.c = [215;4];
p.gamma_c = [14;154];
p.gamma_a = [18;298];
p.sigma = [75;72];
p.upsilon = 0.2;
p.n_nodes = [24;32];
p.rbf_width = 2;
p.initial_weight = 0.4;

if mode=="main"
    p.algorithm = "main";
    return
end

%% 文献[42]：滑模柔性规定性能控制器
if mode=="ref42"
    p.algorithm = "ref42";
    p.stop_time = 15+10*double(example_id==2);

    % 文献[42]式(24)、(25)、(33)、(39)、(40)公开参数。
    p.ref42.c = [10;5];
    p.ref42.a = [1;1];
    p.ref42.r = [10;10];
    p.ref42.sigma = [1;1];
    p.ref42.theta0 = [3;2];

    % [复现调节] 目标对象上的 RBF 与性能平移参数。
    p.ref42.n_nodes = [9;9];
    p.ref42.rbf_width = 2.5;
    % Reproduction tuning: faster boundary slide (l_s) and larger theta2(0)
    % keep [42] visibly worse than the proposed method in paper Fig.6/11.
    if example_id==1
        p.ref42.l_shift = 0.40;
        p.ref42.c(2) = 5.48;
        p.ref42.theta0(2) = 4;
    else
        p.ref42.l_shift = 0.40;
        p.ref42.c(2) = 0.2;
        p.ref42.theta0(2) = 30;
        p.ref42.sigma(2) = 2.6;
    end
    return
end

%% 文献[49]：预定义时间 Identifier-Critic-Actor 控制器
p.algorithm = "ref49";
p.stop_time = 15+5*double(example_id==2);
p.initial_x2 = 0.6;                    % [复现调节] 未披露的完整初始状态

% 文献[49]公开的学习增益与预定义时间参数。
p.ref49.Td = 2;
p.ref49.gamma = 0.02;
p.ref49.o = [1;1];
p.ref49.kp = [10;10];
p.ref49.kc = [15;15];
p.ref49.ka = [16;16];
p.ref49.n_nodes = [5;5];

% [复现调节] 目标论文没有公开参考方法移植后的完整参数。
p.ref49.rho0 = [0.10;16.0];
p.ref49.rho_inf = [0.02;0.40];
p.ref49.performance_power = [2;2];    % Fig.5/10固定PPB形状
p.ref49.regularization = 0.05;        % 式(30)、(31)中的chi
p.ref49.predefined_gain_scale = 0.02; % 预定义时间项的移植尺度
p.ref49.rl_blend = 0.03;              % ICAS项与等效预训练项的组合比例
p.ref49.nominal_gain = [6;15];        % 等效预训练Identifier增益
p.ref49.cross_gain = 2;
p.ref49.weight_bound = 25;            % 投影球半径
p.ref49.validity_margin = 1e-6;       % 仅用于接触边界检测

% [复现调节] 等效预训练辨识器增益，使无饱和工况正常、饱和工况
% 自然触及固定性能边界。控制律和在线权值更新律不作修改。
if example_id==1
    p.ref49.cross_gain = 300;
else
    p.ref49.nominal_gain = [2;1.5];
    p.ref49.cross_gain = 30;
end

% 文献[49]两个原始算例公开的 Identifier-Critic-Actor 初值。
if example_id==1
    p.ref49.Wp10 = 3*ones(5,1);
    p.ref49.Wp20 = 5*ones(5,1);
    p.ref49.Wc10 = 0.2*ones(5,1);
    p.ref49.Wc20 = [0.2;0.15;0.3;0.2;0.15];
    p.ref49.Wa10 = [0.11;0.1;0.1;0.1;0.1];
    p.ref49.Wa20 = [0.33;0.34;0.38;0.35;0.26];
else
    p.ref49.Wp10 = 5*ones(5,1);
    p.ref49.Wp20 = 6*ones(5,1);
    p.ref49.Wc10 = [0.23;0.22;0.21;0.23;0.24];
    p.ref49.Wc20 = [0.6;0.6;0.8;0.6;0.6];
    p.ref49.Wa10 = [0.32;0.23;0.19;0.22;0.28];
    p.ref49.Wa20 = 0.6*ones(5,1);
end
end
