function run_precompute_geo()
%RUN_PRECOMPUTE_GEO  Build contiguity, match to dataset, compute Laplacian eigenmodes, save.
%
% Saves cfg.outputs.geoMat with:
%   geo.A, geo.L, geo.names, geo.poly, geo.centroidXY
%   geo.V (modes), geo.Z (standardised modes, k>=2), geo.evals
%   geo.v2, geo.z (legacy), geo.colIdx, geo.codes, geo.modeInfo

% Configuration + paths
cfg = config_empirical();

% Ensure hs.spatial.build_us_contiguity and hs.spatial.match_states are on path (fail-fast)
assert(~isempty(which('hs.spatial.build_us_contiguity')), 'Missing hs.spatial.build_us_contiguity on path.');
assert(~isempty(which('hs.spatial.match_states')), 'Missing hs.spatial.match_states on path.');

if ~exist(cfg.paths.intermediate,'dir'); mkdir(cfg.paths.intermediate); end

assert(exist(cfg.outputs.processedMat,'file')==2, ...
    'Processed MAT missing: %s (run build_dataset_fmhpi first)', cfg.outputs.processedMat);

S = load(cfg.outputs.processedMat);
codesAll = string(S.stateCodes(:));  % USPS codes, 51

outMap = hs.spatial.build_us_contiguity([], 'excludeNames', cfg.geo.excludeNames);

M = hs.spatial.match_states(outMap.names, codesAll, ...
    'ShapefileIdType','name', 'DataIdType','usps');

A48     = outMap.A;                 % adjacency in shapefile order (48)
names48 = outMap.names;
poly48  = outMap.poly;
xy48    = outMap.centroidXY;

% ---------- Largest connected component (robust) ----------
Gg = graph(A48);
cc = conncomp(Gg);                           % component labels
counts = accumarray(cc(:), 1);
[~, cmax] = max(counts);
idx_cc = find(cc == cmax);

A_cc     = A48(idx_cc, idx_cc);
names_cc = names48(idx_cc);
poly_cc  = poly48(idx_cc);
xy_cc    = xy48(idx_cc,:);

% Dataset column indices aligned to CC order:
colIdx48 = M.colIdx(:);                       % length 48 (dataset col indices in outMap order)
colIdx_cc = colIdx48(idx_cc);                 % dataset cols for CC
codes_cc  = codesAll(colIdx_cc);

% ---------- Laplacian + eigendecomposition ----------
deg = sum(A_cc,2);
L = diag(deg) - A_cc;

[Vfull, Dfull] = eig(L);
evalsFull = diag(Dfull);
[evalsFull, ord] = sort(evalsFull, 'ascend');
Vfull = Vfull(:, ord);

% How many modes to save?
Ksave = 10;  % safe default
if isfield(cfg,'geo') && isfield(cfg.geo,'nModesToSave')
    Ksave = cfg.geo.nModesToSave;
end
Ksave = min(Ksave, size(Vfull,2));

V = Vfull(:, 1:Ksave);
evals = evalsFull(1:Ksave);

% ---------- Deterministic sign convention for modes ----------
modeInfo = repmat(struct( ...
    'a',NaN,'b',NaN,'c',NaN,'dir_label',"", ...
    'dot',NaN,'angle_deg',NaN,'rule',""), Ksave, 1);

% Mode 1 (constant): make sum positive (harmless deterministic)
if sum(V(:,1)) < 0
    V(:,1) = -V(:,1);
end
modeInfo(1).rule = "constant_sum_positive";

% Modes 2..K: plane-based sign fix (good for diagonal structure)
for k = 2:Ksave
    [V(:,k), modeInfo(k)] = fix_mode_sign_plane(V(:,k), xy_cc);
end

% ---------- Standardised versions ----------
Z = V;
for k = 2:Ksave
    Z(:,k) = (V(:,k) - mean(V(:,k),'omitnan')) ./ std(V(:,k),0,'omitnan');
end
% Leave Z(:,1) = V(:,1) to avoid NaNs (std=0); it’s the constant mode anyway.

% Legacy convenience fields
v2_cc = V(:,2);
z_cc  = (v2_cc - mean(v2_cc,'omitnan')) ./ std(v2_cc,0,'omitnan');

% ---------- Pack + save ----------
geo = struct();
geo.A = A_cc;
geo.L = L;
geo.names = names_cc;
geo.poly = poly_cc;
geo.centroidXY = xy_cc;

geo.V = V;
geo.Z = Z;
geo.evals = evals;

geo.modeInfo = modeInfo;

geo.v2 = v2_cc;
geo.z  = z_cc;

geo.colIdx = colIdx_cc;
geo.codes  = codes_cc;

save(cfg.outputs.geoMat, 'geo', 'cfg');

fprintf('Saved geo to %s (N=%d)\n', cfg.outputs.geoMat, numel(geo.names));
fprintf('Saved %d Laplacian modes (incl constant mode).\n', Ksave);
for k = 2:Ksave
    fprintf('  v%d: %s (angle=%.1f°)\n', k, string(modeInfo(k).dir_label), modeInfo(k).angle_deg);
end

end

% -------------------------------------------------------------------------
function [v2, info] = fix_mode_sign_plane(v, xy)
% Plane-fit sign fixing: v ≈ a*x + b*y + c (x,y standardised).
% Choose nearest of {E-W, N-S, NE-SW, NW-SE} and flip so alignment positive.

x = xy(:,1);
y = xy(:,2);

xz = (x - mean(x,'omitnan')) ./ std(x,0,'omitnan');
yz = (y - mean(y,'omitnan')) ./ std(y,0,'omitnan');

X = [xz(:), yz(:), ones(numel(v),1)];
bhat = X \ v(:);
g = bhat(1:2);
ng = norm(g);

info = struct();
info.a = bhat(1);
info.b = bhat(2);
info.c = bhat(3);

if ~(isfinite(ng) && ng > 0)
    v2 = v(:);
    if v2(1) < 0, v2 = -v2; end
    info.rule = "fallback_first_positive";
    info.dir_label = "NA";
    info.angle_deg = NaN;
    info.dot = NaN;
    return;
end

ghat = g ./ ng;
info.angle_deg = atan2d(ghat(2), ghat(1));

U = [ 1  0;
      0  1;
      1  1;
      1 -1 ];
U = U ./ vecnorm(U,2,2);

labels = ["E-W","N-S","NE-SW","NW-SE"];

dots = U * ghat;
[~, k] = max(abs(dots));

info.dir_label = labels(k);
info.dot = dots(k);
info.rule = "plane_4dirs";

v2 = v(:);
if dots(k) < 0
    v2 = -v2;
    info.dot = -info.dot;
    info.a = -info.a; info.b = -info.b; info.c = -info.c;
    info.angle_deg = mod(info.angle_deg + 180, 360) - 180;
end
end
