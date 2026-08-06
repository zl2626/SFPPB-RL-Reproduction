function phi = sfppb_rbf(z, node_count, width)
%SFPPB_RBF Gaussian basis vector using the centers reported in the paper.
% Eq. (5): s_j(Z) = exp(-||Z - zeta_j||^2 / a_j^2)
% Section IV: 24 nodes use 8-(2/3)j, 32 nodes use 8-(1/2)j.
% 本文算例的中心轴由论文 Section IV 明确给出：
%   24 节点：8-(2/3)j, j=1,...,24；
%   32 节点：8-(1/2)j, j=1,...,32。
% 其他节点数仅供对比算法使用，沿 [-8,8] 等距配置。每个中心位于
% 输入空间的对角线上。PDF 文本提取丢失了指数中的负号，此处按
% Gaussian RBF 的正确形式恢复。
z = z(:);
if node_count == 24
    center_axis = 8-(2/3)*(1:24);
elseif node_count == 32
    center_axis = 8-(1/2)*(1:32);
else
    center_axis = linspace(-8,8,node_count);
end
centers = repmat(center_axis, numel(z), 1);
distance_sq = sum((z - centers).^2, 1);
phi = exp(-distance_sq(:)/(width^2));
end
