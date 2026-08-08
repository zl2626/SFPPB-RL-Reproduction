# SFPPB-RL-Reproduction

面向 MATLAB/Simulink R2025b 的论文复现项目：**滑模柔性规定性能边界引导的强化学习控制（SFPPB-RL）**。
代码按“论文推导顺序”组织：打开 `SFPPB_ctrl.m`，左边放论文公式，右边就能从上往下读。

## 最快上手

```matlab
run_main                 % 主方法仿真（Fig.2-4 / Fig.7-9）
comparison/run_comparison  % 对比仿真（Fig.5/6/10/11）
plot_main                % 主方法绘图
comparison/plot_comparison % 对比绘图
```

所有图只保存为可编辑的 `.fig`，不生成 PNG。

## 论文公式 → 代码对照

| 论文内容 | 公式 | 代码位置 |
|---|---|---|
| 被控对象（两个算例） | (70)-(71) | `SFPPB_plant.m` |
| 饱和估计 `S(u)=k(u)+l(u)` | (2)-(3) | `SFPPB_aux.m`, `SFPPB_ctrl.m` |
| 柔性性能边界 `B(t),B̄(t)` | (7)-(10) | `SFPPB_ctrl.m`（顺序第一步） |
| 辅助变量 `ε(t)` | (12)-(13) | `SFPPB_ctrl.m` |
| 非线性映射 `w=ln(δ/(1-δ))` | (14) | `SFPPB_ctrl.m` |
| 变换导数 `A` | (16) | `SFPPB_ctrl.m` |
| Gaussian RBF 基 `S_F,S_J` | (5),(33)-(34) | `SFPPB_rbf.m` |
| Identifier 更新律 | (40) | `SFPPB_ctrl.m`（每步一段） |
| Critic 更新律 | (43) | `SFPPB_ctrl.m` |
| Actor 更新律 | (46) | `SFPPB_ctrl.m` |
| 虚拟控制 `α̂1` | (44) | `SFPPB_ctrl.m` |
| 第二步误差 `z2` | (15) | `SFPPB_ctrl.m` |
| 实际控制 `u` | (45) | `SFPPB_ctrl.m` |
| 辅助状态 `ρ,O` | (11),(24) | `SFPPB_aux.m` |
| 参数唯一入口 | — | `SFPPB_params.m` |

## 推荐阅读顺序

1. 先读 `SFPPB_ctrl.m`：状态解包 → 跟踪误差 → SFPPB → 误差变换 → RBF →
   Identifier/Critic/Actor → 虚拟控制 → 实际控制 → 饱和，每一段都标注论文式号。
2. 再看 `SFPPB_aux.m`：`ρ` 驱动边界松弛，`O` 补偿饱和。
3. 回到 `SFPPB_params.m`：所有可调参数集中在此，来源用注释标明。
4. 跑 `run_main` + `plot_main` 看主方法效果。
5. 最后读 `comparison/`：`[42]` 滑模柔性 PPC 与 `[49]` 预定义时间 ICAS-RL 的移植。

## 目录结构

```
SFPPB_RL_Reproduction/
├─ SFPPB_plant.m          论文被控对象
├─ SFPPB_aux.m            辅助状态 rho/O
├─ SFPPB_ctrl.m           本文两步 SFPPB-ICAS 控制器（平铺直读）
├─ SFPPB_rbf.m            Gaussian RBF 工具
├─ SFPPB_params.m         唯一参数入口
├─ SFPPB_RL_simulate.slx  主方法 Simulink 模型
├─ run_main.m             主方法仿真入口
├─ plot_main.m            主方法绘图入口
├─ comparison/            [42]/[49] 控制器、模型、对比运行与绘图
├─ tools/                 建模、验证、调参等工程工具
├─ results/               仿真与验收结果 (.mat)
└─ figures/               52 个可编辑 .fig
```

## Simulink 顶层结构（物理闭环）

```
Reference yd ──> SFPPB-RL Controller ── u ──> Input Saturation S(u) ──> Plant
                     ▲   ▲                       │                    │
                     │   └─────── rho, O ────────┤                    │
                     └────────── x1, x2 (反馈) ──┘                    │
                                                    x1, x2 ────────────┘
```

- `Reference yd`：显式参考信号块（`tools/SFPPB_ref.m`，由 `SFPPB_params.m` 的 `p.yd` 驱动）。
- `SFPPB-RL Controller`：块名直接标注 `Eqs. (7)-(16),(40),(43)-(46)`，公式在
  `SFPPB_ctrl.m` 中按论文顺序平铺。
- `Input Saturation S(u)`：独立的 `Eq. (2)` 饱和块（`tools/SFPPB_sat.m`）；
  Plant 只接收 `S(u)`，饱和不再藏在 Plant 内部。
- `Auxiliary Dynamics`：`rho`（Eq.(11)，边界松弛）与 `O`（Eq.(24)，饱和补偿）
  独立显示并标注作用。
- `Simulation Logging`：18 路控制器输出、状态、辅助量和饱和量全部收进一个
  日志子系统，顶层只画控制框架。

## 工程工具（tools/）

- `SFPPB_build.m`：重建三个 Simulink 模型（ode4，固定步长 0.001 s）。
- `SFPPB_ref.m` / `SFPPB_sat.m`：顶层 Reference 与 Saturation 块。
- `validate_main.m` / `validate_comparison.m`：验收表，包含边界/输入检查、
  delta 截断诊断、真实二次代价 `J_Q`、秩一激励方向数。
- `SFPPB_tune.m`：同预算 Sobol 公平调参（120 次/算法/算例，目标 `J_Q`），
  另含主方法学习率调度搜索（τ，N=60）。

## 结果与验收（公平调参后）

- 主方法四工况：边界零越界、输入限幅满足、终值误差约 `4e-3`（Ex1）/
  `5e-4`（Ex2）。
- [49]：无饱和边界内可行工况完成；饱和工况按设计奇异失效；本文同工况成功。
- [42] 公平调参后 IAE 小于本文（Ex1 `0.349 vs 0.580`，Ex2 `0.393 vs 0.560`），
  验收表 `ProposedErrorBelowRef42=false`；本文仍在原始输入峰值与实际输入积分上更小。
  结论以真实仿真为准，未修改验收标准迁就论文。
- delta 截断在本轮全部工况激活 0 次；`ExcitedSJ1/SJ2` 表明主方法仅激励 2–3 个
  RBF 方向，定量印证式(43)/(46) 秩一更新的理论局限（按“忠于论文公式”不引入 χI）。

## 已知边界与说明

- 论文式(43)/(46) 为秩一更新，无 `χI` 正则；权值范数不会像论文 Fig.4/9 那样
  全部降至 `1e-3`，本项目如实展示。
- delta 截断仅作浮点安全网（本文 `1e-10`，[42] `1e-8`），不参与稳定性理论。
- 主方法学习率使用 `γ(t)=γ0/(1+τt)` 调度（工程层，更新方向不变）；公平对比
  阶段 τ=0，保证旋钮数量与其他算法一致。
- [42] 式(33) 的 `O` 动态使用 `g(u)=u_d·tanh(u/u_d)`；第一步模糊基按式(22)
  使用 `[x1,x2,yd]`（原文式(23) 漏写 `x2`，已注明）。
