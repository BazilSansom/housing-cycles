function make_fig_graph_fourier_topm_band(varargin)
%MAKE_FIG_GRAPH_FOURIER_TOPM_BAND
% Plot low-M vs top-M modal concentration diagnostics from
% graph_fourier_topm_<dataTag>_<bandTag>_K<Kuse>.mat
%
% Reads:
%   outputs/intermediate/graph_fourier_topm_<dataTag>_<bandTag>_K<Kuse>.mat
%
% Writes:
%   outputs/figures/Fig_graph_fourier_topm_<dataTag>.pdf/.png
%   (or single-band filename if only one band requested)
%
% Each panel (one per band) shows:
%   solid  = qLowM(t): first M non-constant modes
%   dashed = qTopM(t): best M modes regardless of order
%
% This is intended as a compact diagnostic:
%   - qLowM ~= qTopM  => smooth / low-mode structure
%   - qTopM > qLowM   => structure is compressible, but not mainly in low modes

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v) iscell(v) || isstring(v));
p.addParameter('Mshow', [1 3 5], @(v) isnumeric(v) && isvector(v) && ...
    all(v >= 1) && all(abs(v-round(v)) < 1e-12));
p.addParameter('Overwrite', false, @(b) islogical(b) && isscalar(b));
p.addParameter('YearTickStep', 5, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();
if ~exist(cfg.paths.figures, 'dir')
    mkdir(cfg.paths.figures);
end

% -------------------------------------------------------------------------
% Canonical data tag
% -------------------------------------------------------------------------
assert(exist(cfg.outputs.processedMat,'file')==2, 'Missing %s', cfg.outputs.processedMat);
Sproc = load(cfg.outputs.processedMat);
[~,~,dataLabel] = hs.data.select_hpi_matrix(Sproc, cfg);
dataTag = hs.util.data_tag(dataLabel);
dataLabelStr = char(string(dataLabel));

% -------------------------------------------------------------------------
% Determine Kuse used in saved top-M diagnostics
% -------------------------------------------------------------------------
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);
G = load(cfg.outputs.geoMat);
assert(isfield(G,'geo'), 'geoMat does not contain variable "geo".');
geo = G.geo;
assert(isfield(geo,'V') && ~isempty(geo.V), ...
    'geo.V missing or empty. Re-run run_precompute_geo.');

Kmax = size(geo.V, 2);
if isinf(cfg.graphFourier.Kuse)
    Kfile = Kmax;
else
    Kfile = min(cfg.graphFourier.Kuse, Kmax);
end

bandKeys = string(opt.WhichBands(:)).';
nBands = numel(bandKeys);
assert(nBands >= 1, 'WhichBands must contain at least one band.');

% -------------------------------------------------------------------------
% Load all requested bands first
% -------------------------------------------------------------------------
B = struct([]);
for ib = 1:nBands
    bk = bandKeys(ib);
    assert(isfield(cfg.bands, bk), 'Unknown band key: %s', bk);

    bcfg = cfg.bands.(bk);
    lowF = bcfg.lowF;
    upF  = bcfg.upF;

    bandTag = hs.util.band_tag(lowF, upF);
    bandTagPretty = sprintf('%.0f--%.0fy', lowF, upF);

    inMat = fullfile(cfg.paths.intermediate, ...
        sprintf('graph_fourier_topm_%s_%s_K%d.mat', dataTag, bandTag, Kfile));
    assert(exist(inMat,'file')==2, ...
        'Missing %s (run run_graph_fourier_topm_band_data first).', inMat);

    tmp = load(inMat);
    assert(isfield(tmp,'topm'), 'Expected variable `topm` in %s.', inMat);
    topm = tmp.topm;

    req = {'dates','Mlist','qLowM','qTopM','Klow'};
    for i = 1:numel(req)
        assert(isfield(topm, req{i}), 'topm missing field `%s` in %s.', req{i}, inMat);
    end

    B(ib).bandKey = char(bk);
    B(ib).bandTag = bandTag;
    B(ib).bandTagPretty = bandTagPretty;
    B(ib).lowF = lowF;
    B(ib).upF = upF;
    B(ib).topm = topm;
    B(ib).inMat = inMat;
end

% -------------------------------------------------------------------------
% Figure
% -------------------------------------------------------------------------
figH = 320 + 240 * nBands;
fig = figure('Color','w','Position',[100 100 1100 figH]);
tl = tiledlayout(fig, nBands, 1, 'Padding','compact', 'TileSpacing','compact');

for ib = 1:nBands
    ax = nexttile(tl, ib);
    hold(ax, 'on');

    topm = B(ib).topm;
    dates = topm.dates(:);
    Mlist = topm.Mlist(:).';
    qLowM = topm.qLowM;
    qTopM = topm.qTopM;
    Klow  = topm.Klow;

    Mshow = unique(sort(round(opt.Mshow(:).')));
    Mshow = Mshow(ismember(Mshow, Mlist));
    assert(~isempty(Mshow), ...
        'None of requested Mshow values are present in saved Mlist for band %s.', B(ib).bandTag);

    % Use matching colors for solid/dashed pairs
    cols = lines(numel(Mshow));

    leg = cell(1, 2*numel(Mshow));
    h = gobjects(1, 2*numel(Mshow));
    jj = 0;

    for j = 1:numel(Mshow)
        M = Mshow(j);
        colIdx = find(Mlist == M, 1, 'first');

        jj = jj + 1;
        h(jj) = plot(ax, dates, qLowM(:,colIdx), ...
            'LineWidth', 1.5, ...
            'Color', cols(j,:), ...
            'LineStyle', '-');
        leg{jj} = sprintf('$q_{\\mathrm{low},%d}(t)$', M);

        jj = jj + 1;
        h(jj) = plot(ax, dates, qTopM(:,colIdx), ...
            'LineWidth', 1.3, ...
            'Color', cols(j,:), ...
            'LineStyle', '--');
        leg{jj} = sprintf('$q_{\\mathrm{top},%d}(t)$', M);
    end

    hold(ax, 'off');
    grid(ax, 'on');
    ax.Box = 'on';
    ax.Layer = 'top';
    ylim(ax, [0 1]);
    ylabel(ax, 'share of total dispersion');

    title(ax, sprintf('%s band: low-mode vs best-%s modal concentration (%s)', ...
        B(ib).bandTagPretty, 'M', dataLabelStr));

    legend(ax, h, leg, 'Interpreter','latex', 'Location','eastoutside');
    set_year_ticks_(ax, dates, opt.YearTickStep);

    if ib == nBands
        xlabel(ax, 'Date');
    end

    % Small annotation with Klow
    txt = sprintf('Low set = modes 2..%d', Klow);
    text(ax, 0.99, 0.96, txt, ...
        'Units','normalized', ...
        'HorizontalAlignment','right', ...
        'VerticalAlignment','top', ...
        'BackgroundColor','w', ...
        'Margin',2, ...
        'FontSize',9);
end

sgtitle(fig, sprintf('Low-mode vs best-M modal concentration of phase dispersion (%s)', ...
    dataLabelStr));

% -------------------------------------------------------------------------
% Export
% -------------------------------------------------------------------------
if nBands == 1
    outStem = sprintf('Fig_graph_fourier_topm_%s_%s', B(1).bandTag, dataTag);
else
    outStem = sprintf('Fig_graph_fourier_topm_%s', dataTag);
end

outPdf = fullfile(cfg.paths.figures, [outStem '.pdf']);
outPng = fullfile(cfg.paths.figures, [outStem '.png']);

if exist(outPdf,'file')==2 && ~opt.Overwrite
    fprintf('Exists (set Overwrite=true): %s\n', outPdf);
    close(fig);
    return;
end

exportgraphics(fig, outPdf, 'ContentType','vector');
exportgraphics(fig, outPng, 'Resolution', cfg.fig.dpi);
close(fig);

fprintf('Saved:\n  %s\n  %s\n', outPdf, outPng);
end

% -------------------------------------------------------------------------
function set_year_ticks_(ax, dates, stepYears)
ax.XLim = [dates(1) dates(end)];
y0 = year(dateshift(dates(1), 'start', 'year'));
y1 = year(dateshift(dates(end), 'start', 'year'));
yt = y0:stepYears:y1;
ax.XTick = datetime(yt,1,1);
ax.XAxis.TickLabelFormat = 'yyyy';
end