function make_fig_neighbor_coherence_band(varargin)
%MAKE_FIG_NEIGHBOR_COHERENCE_BAND
% Plot neighbor coherence relative to a permutation null.
%
% Reads:
%   outputs/intermediate/neighbor_coherence_<dataTag>_band_<bandTag>.mat
%
% Writes:
%   outputs/figures/Fig_neighbor_coherence_<dataTag>.pdf/.png
%   (or single-band filename if only one band requested)
%
% Per panel (one per band):
%   left axis:  observed edge coherence and permutation-null mean
%   right axis: excess coherence = observed - null mean
%
% Interpretation:
%   - edgeCoherence high: neighboring states are phase-aligned
%   - edgeExcess > 0: more aligned than expected under random relabeling

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v) iscell(v) || isstring(v));
p.addParameter('SmoothMonths', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('ShowZ', false, @(b) islogical(b) && isscalar(b));  % if true, right axis is zEdge instead of edgeExcess
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

bandKeys = string(opt.WhichBands(:)).';
nBands = numel(bandKeys);
assert(nBands >= 1, 'WhichBands must contain at least one band.');

% -------------------------------------------------------------------------
% Load all requested bands
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
        sprintf('neighbor_coherence_%s_band_%s.mat', dataTag, bandTag));
    assert(exist(inMat,'file')==2, ...
        'Missing %s (run run_neighbor_coherence_band_data first).', inMat);

    tmp = load(inMat);
    assert(isfield(tmp,'res'), 'Expected variable `res` in %s.', inMat);
    res = tmp.res;

    req = {'dates','edgeCoherence','nullMean','edgeExcess','zEdge','edgeCount'};
    for i = 1:numel(req)
        assert(isfield(res, req{i}), 'res missing field `%s` in %s.', req{i}, inMat);
    end

    B(ib).bandKey = char(bk);
    B(ib).bandTag = bandTag;
    B(ib).bandTagPretty = bandTagPretty;
    B(ib).res = res;
    B(ib).inMat = inMat;
end

% -------------------------------------------------------------------------
% Figure layout
% -------------------------------------------------------------------------
figH = 320 + 240 * nBands;
fig = figure('Color','w','Position',[100 100 1100 figH]);
tl = tiledlayout(fig, nBands, 1, 'Padding','compact', 'TileSpacing','compact');

for ib = 1:nBands
    ax = nexttile(tl, ib);

    res = B(ib).res;
    dates = res.dates(:);

    yObs   = res.edgeCoherence(:);
    yNull  = res.nullMean(:);
    yEx    = res.edgeExcess(:);
    yZ     = res.zEdge(:);
    nEdges = res.edgeCount;

    % Optional smoothing for presentation
    if opt.SmoothMonths > 1
        wlen = opt.SmoothMonths;
        yObs  = movmean(yObs,  wlen, 'omitnan');
        yNull = movmean(yNull, wlen, 'omitnan');
        yEx   = movmean(yEx,   wlen, 'omitnan');
        yZ    = movmean(yZ,    wlen, 'omitnan');
    end

    % Left axis: observed and null
    yyaxis(ax, 'left');
    hold(ax, 'on');
    h1 = plot(ax, dates, yObs,  'LineWidth', 1.4, 'DisplayName', 'Observed neighbor coherence');
    h2 = plot(ax, dates, yNull, 'LineWidth', 1.2, 'LineStyle', '--', ...
        'DisplayName', 'Permutation-null mean');
    hold(ax, 'off');

    grid(ax, 'on');
    ax.Box = 'on';
    ax.Layer = 'top';
    ylabel(ax, 'edge coherence');
    ylim(ax, [min(0, min([yObs; yNull], [], 'omitnan') - 0.05), 1]);

    % Right axis: excess or z-score
    yyaxis(ax, 'right');
    if opt.ShowZ
        h3 = plot(ax, dates, yZ, 'LineWidth', 1.3, 'DisplayName', 'zEdge');
        ylabel(ax, 'zEdge');
        yline(ax, 0, '--', 'LineWidth', 1.0);
    else
        h3 = plot(ax, dates, yEx, 'LineWidth', 1.3, 'DisplayName', 'Excess coherence');
        ylabel(ax, 'excess coherence');
        yline(ax, 0, '--', 'LineWidth', 1.0);
    end

    title(ax, sprintf('%s band: neighbor coherence vs permutation null (%s)', ...
        B(ib).bandTagPretty, dataLabelStr), 'Interpreter', 'tex');

    legend(ax, [h1 h2 h3], 'Location', 'eastoutside');
    set_year_ticks_(ax, dates, opt.YearTickStep);

    if ib == nBands
        xlabel(ax, 'Date');
    end

    % Small annotation
    if opt.ShowZ
        txt = sprintf('Edges = %d   |   right axis: zEdge', nEdges);
    else
        txt = sprintf('Edges = %d   |   right axis: observed - null', nEdges);
    end
    yyaxis(ax, 'left');
    text(ax, 0.99, 0.96, txt, ...
        'Units','normalized', ...
        'HorizontalAlignment','right', ...
        'VerticalAlignment','top', ...
        'BackgroundColor','w', ...
        'Margin',2, ...
        'FontSize',9);
end

if opt.ShowZ
    sgtitle(fig, sprintf('Neighbor phase coherence relative to permutation null (%s)', dataLabelStr));
else
    sgtitle(fig, sprintf('Neighbor phase coherence and excess relative to permutation null (%s)', dataLabelStr));
end

% -------------------------------------------------------------------------
% Export
% -------------------------------------------------------------------------
if nBands == 1
    outStem = sprintf('Fig_neighbor_coherence_%s_%s', B(1).bandTag, dataTag);
else
    outStem = sprintf('Fig_neighbor_coherence_%s', dataTag);
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