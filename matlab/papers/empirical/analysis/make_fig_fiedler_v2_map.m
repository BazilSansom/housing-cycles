function make_fig_fiedler_v2_map(varargin)
%MAKE_FIG_FIEDLER_V2_MAP  Plot the Fiedler mode as a standalone US choropleth.
%
% Reads:
%   cfg.outputs.geoMat
%
% Writes:
%   cfg.paths.figures/Fig_fiedler_v2_map.pdf
%   cfg.paths.figures/Fig_fiedler_v2_map.png
%
% Notes:
% - By default plots the standardised Fiedler mode z_2 (geo.Z(:,2)).
% - If geo.modeInfo is available, adds directional annotation to the title.
% - Intended as the paper-facing appendix figure; keep make_fig_geo_modes
%   as the multi-mode diagnostic/gallery figure.

p = inputParser;
p.addParameter('UseZ', true, @(b)islogical(b)&&isscalar(b));            % true => plot z_2, false => v_2
p.addParameter('CLimPercentile', 98, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<=100);
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);

G = load(cfg.outputs.geoMat);
assert(isfield(G,'geo'), 'Expected variable `geo` in %s.', cfg.outputs.geoMat);
geo = G.geo;

% Basic checks
need = {'poly','V','evals'};
for k = 1:numel(need)
    assert(isfield(geo, need{k}), 'geo missing field: %s', need{k});
end
assert(size(geo.V,2) >= 2, 'geo.V must contain at least two eigenmodes.');

if opt.UseZ
    assert(isfield(geo,'Z'), 'UseZ=true but geo.Z is missing.');
    vals = geo.Z(:,2);
    modeLabel = 'z_2';
    cbLabel   = 'standardised Fiedler mode';
else
    vals = geo.V(:,2);
    modeLabel = 'v_2';
    cbLabel   = 'Fiedler mode';
end

vals = vals(:);
assert(numel(vals) == numel(geo.poly), ...
    'Mode vector length (%d) does not match number of polygons (%d).', ...
    numel(vals), numel(geo.poly));

% Common symmetric colour scale from percentile
vv = vals(isfinite(vals));
assert(~isempty(vv), 'No finite values in Fiedler mode.');
s = prctile(abs(vv), opt.CLimPercentile);
if ~(isfinite(s) && s > 0)
    s = max(abs(vv));
end
cl = [-s s];

% Output paths
if ~exist(cfg.paths.figures,'dir'); mkdir(cfg.paths.figures); end
pdfOut = fullfile(cfg.paths.figures, 'Fig_fiedler_v2_map.pdf');
pngOut = fullfile(cfg.paths.figures, 'Fig_fiedler_v2_map.png');

if exist(pdfOut,'file')==2 && ~opt.Overwrite
    fprintf('Exists (set Overwrite=true): %s\n', pdfOut);
    return;
end

% Title
ttl = sprintf('Fiedler mode %s of the contiguous-state adjacency graph', modeLabel);

%{
ttl = sprintf('Fiedler mode %s', modeLabel);
if isfield(geo,'evals') && numel(geo.evals) >= 2
    ttl = sprintf('%s  (\\lambda=%.3g)', ttl, geo.evals(2));
end
if isfield(geo,'modeInfo') && numel(geo.modeInfo) >= 2
    mi = geo.modeInfo(2);
    if isfield(mi,'dir_label') && strlength(string(mi.dir_label)) > 0
        ttl = sprintf('%s  ---  %s (%.1f^\\circ)', ttl, string(mi.dir_label), mi.angle_deg);
    end
end
%}

% Figure
fig = figure('Color','w','Position',[100 100 900 560]);
ax = axes('Parent', fig);

hs.spatial.plot_us_choropleth(geo.poly, vals, ...
    'Parent', ax, ...
    'Title', ttl, ...
    'Colormap', hs.plot.redblue(256), ...
    'CLim', cl, ...
    'ShowColorbar', true, ...
    'ColorbarLabel', cbLabel, ...
    'EdgeColor', [0.6 0.6 0.6], ...
    'LineWidth', 0.5);

axis(ax,'off');
colormap(ax, hs.plot.redblue(256));
clim(ax, cl);

exportgraphics(fig, pdfOut, 'ContentType','image', 'Resolution', cfg.fig.dpi);
exportgraphics(fig, pngOut, 'Resolution', cfg.fig.dpi);
close(fig);

fprintf('Saved:\n  %s\n  %s\n', pdfOut, pngOut);
end