function [v2, evals, idx_cc, names_cc] = fiedler_mode(A, names)
%HS.SPATIAL.FIEDLER_MODE  Fiedler vector of an undirected graph.
% Returns v2 on the largest connected component.
%
% Inputs:
%   A     (n x n) adjacency (binary or weighted, symmetric)
%   names (n x 1) cellstr (optional)
%
% Outputs:
%   v2       (m x 1) normalized Fiedler vector on largest CC
%   evals    eigenvalues computed (sorted ascending)
%   idx_cc   indices of nodes in largest CC
%   names_cc names restricted to CC (if provided)

A = double(A);
n = size(A,1);
A(1:n+1:end) = 0;
A = (A + A')/2;
A(A<0) = 0;

if nargin < 2 || isempty(names)
    names = arrayfun(@(k)sprintf('n%d',k), 1:n, 'UniformOutput', false)';
end

G = graph(sparse(A), names);
bins = conncomp(G);
comp_sizes = accumarray(bins(:), 1);
[~, biggest] = max(comp_sizes);
idx_cc = find(bins == biggest);

A = A(idx_cc, idx_cc);
names_cc = names(idx_cc);
m = size(A,1);

d = sum(A,2);
L = spdiags(d,0,m,m) - sparse(A);

opts.isreal = true;
opts.issym  = true;
opts.tol    = 1e-10;
opts.maxit  = 1e4;

k = min(6, m);
try
    [V,E] = eigs(L, k, 'smallestreal', opts);
catch
    [V,E] = eigs(L, k, 'sm', opts); % older MATLAB
end

[evals, ord] = sort(diag(E), 'ascend');
V = V(:, ord);

% Fiedler is 2nd-smallest for connected graphs; handle near-zero mult.
zero_tol = 1e-8;
i0 = find(evals <= zero_tol, 1, 'last');
if isempty(i0), i0 = 1; end
i2 = i0 + 1;
if i2 > size(V,2)
    error('Not enough eigenpairs; increase k.');
end

v2 = V(:, i2);
v2 = (v2 - mean(v2)) / std(v2); % normalize
end
