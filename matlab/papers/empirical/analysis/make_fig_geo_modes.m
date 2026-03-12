function make_fig_geo_modes(varargin)
%MAKE_FIG_GEO_MODES  Plot Laplacian eigenmodes as US choropleths (v2..vK).
%
% Reads: cfg.outputs.geoMat (geo.V, geo.Z, geo.evals, geo.poly, geo.modeInfo optional)
% Writes: cfg.paths.figures/Fig_geo_modes_z2_zK.pdf/.png  (or v2..)
%
% Notes:
% - Uses a COMMON CLim across panels for comparability.
% - Suppresses per-panel colorbars and adds a single shared colorbar.

p = inputParser;
p.addParameter('K', 8, @(x)isnumeric(x)&&isscalar(x)&&x>=2);
p.addParameter('UseZ', true, @(b)islogical(b)&&isscalar(b));      % plot standardized modes
p.addParameter('CLimPercentile', 98, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<=100);
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);

G = load(cfg.outputs.geoMat);
geo = G.geo;

K = min(opt.K, size(geo.V,2));
seriesLabel = ternary_(opt.UseZ, 'z', 'v');

if opt.UseZ
    M = geo.Z(:,1:K);
else
    M = geo.V(:,1:K);
end

% -------- Common color limits across all plotted modes --------
vals = M(:,2:K);
vals = vals(:);
vals = vals(isfinite(vals));
if isempty(vals)
    error('No finite values in modes.');
end
s = prctile(abs(vals), opt.CLimPercentile);
if ~(isfinite(s) && s>0)
    s = max(abs(vals));
end
cl = [-s s];

% -------- Layout --------
nPlots = K-1;          % v2..vK
nCol = 3;
nRow = ceil(nPlots/nCol);

if ~exist(cfg.paths.figures,'dir'); mkdir(cfg.paths.figures); end
pdfOut = fullfile(cfg.paths.figures, sprintf('Fig_geo_modes_%s2_%s%d.pdf', seriesLabel, seriesLabel, K));
pngOut = fullfile(cfg.paths.figures, sprintf('Fig_geo_modes_%s2_%s%d.png', seriesLabel, seriesLabel, K));

if exist(pdfOut,'file')==2 && ~opt.Overwrite
    fprintf('Exists (set Overwrite=true): %s\n', pdfOut);
    return;
end

fig = figure('Color','w','Position',[100 100 1200 320*nRow]);
tiledlayout(fig, nRow, nCol, 'Padding','compact', 'TileSpacing','compact');

lastAx = [];
for k = 2:K
    ax = nexttile; lastAx = ax;

    % Title line
    ttl = sprintf('%s_%d  (\\lambda=%.3g)', seriesLabel, k, geo.evals(k));

    if isfield(geo,'modeInfo') && numel(geo.modeInfo) >= k
        mi = geo.modeInfo(k);
        if isfield(mi,'dir_label') && strlength(string(mi.dir_label))>0
            ttl = sprintf('%s  —  %s (%.1f^\\circ)', ttl, string(mi.dir_label), mi.angle_deg);
        end
    end

    hs.spatial.plot_us_choropleth(geo.poly, M(:,k), ...
        'Parent', ax, ...
        'Title', ttl, ...
        'Colormap', hs.plot.redblue(256), ...
        'CLim', cl, ...
        'ShowColorbar', false, ...
        'EdgeColor', [0.6 0.6 0.6], ...
        'LineWidth', 0.5);

    axis(ax,'off');
end

% One shared colorbar on the last axis (works because all axes share CLim/colormap)
cb = colorbar(lastAx, 'Location','eastoutside');
cb.Label.String = sprintf('%s-mode value (common scale; %gth pctile)', seriesLabel, opt.CLimPercentile);

sgtitle(fig, sprintf('Graph Laplacian modes (%s): %s2..%s%d', seriesLabel, seriesLabel, seriesLabel, K));

% Maps are patch-heavy → export as image for robustness
exportgraphics(fig, pdfOut, 'ContentType','image', 'Resolution', cfg.fig.dpi);
exportgraphics(fig, pngOut, 'Resolution', cfg.fig.dpi);
close(fig);

fprintf('Saved:\n  %s\n  %s\n', pdfOut, pngOut);
end

% ---- small helper ----
function y = ternary_(cond, a, b)
if cond, y = a; else, y = b; end
end
