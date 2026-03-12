function make_fig_relative_phase_snapshot_band(varargin)
%MAKE_FIG_RELATIVE_PHASE_SNAPSHOT_BAND
% Plot one or more snapshot maps of relative phase using saved phase intermediates.
%
% Reads:
%   outputs/intermediate/phase_<dataTag>_band_<bandTag>.mat
%   cfg.outputs.geoMat
%
% Writes:
%   If one band:
%     outputs/figures/Fig_relative_phase_snapshot_<bandTag>_<dataTag>_<yyyymm>.pdf/.png
%   If multiple bands:
%     outputs/figures/Fig_relative_phase_snapshot_compare_<dataTag>_<yyyymm>.pdf/.png
%
% Relative phase at date t is:
%   thetaRel_i(t) = angle(exp(1i * (theta_i(t) - phi(t))))
% where phi(t) is the global mean phase from hs.phase.kuramoto_r.
%
% Snapshot date:
%   1) 'SnapshotDate' override
%   2) cfg.snapshot.tstar_req

p = inputParser;
p.addParameter('WhichBands', {'long','main'}, @(v) iscell(v) || isstring(v));
p.addParameter('SnapshotDate', [], @(x) isempty(x) || isdatetime(x) || ischar(x) || isstring(x));
p.addParameter('Overwrite', false, @(b) islogical(b) && isscalar(b));
p.addParameter('ShowPhaseWheel', false, @(b) islogical(b) && isscalar(b));
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
% Load authoritative geo for map geometry
% -------------------------------------------------------------------------
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);
G = load(cfg.outputs.geoMat);
assert(isfield(G,'geo'), 'geoMat does not contain variable "geo".');
geo = G.geo;

assert(isfield(geo,'poly') && ~isempty(geo.poly), ...
    'geo.poly missing or empty. Re-run run_precompute_geo.');

bandKeys = string(opt.WhichBands(:)).';
assert(~isempty(bandKeys), 'WhichBands must contain at least one band key.');

% -------------------------------------------------------------------------
% Resolve one common requested snapshot date
% -------------------------------------------------------------------------
if ~isempty(opt.SnapshotDate)
    tReq = snapshotdate_to_datetime_(opt.SnapshotDate);
else
    assert(isfield(cfg,'snapshot') && isfield(cfg.snapshot,'tstar_req') && ~isempty(cfg.snapshot.tstar_req), ...
        'Config missing cfg.snapshot.tstar_req.');
    tReq = snapshotdate_to_datetime_(cfg.snapshot.tstar_req);
end

% -------------------------------------------------------------------------
% Collect snapshots
% -------------------------------------------------------------------------
snaps = struct([]);
for j = 1:numel(bandKeys)
    bk = bandKeys(j);
    assert(isfield(cfg.bands, bk), 'Unknown band key: %s', bk);

    bcfg = cfg.bands.(bk);
    lowF = bcfg.lowF;
    upF  = bcfg.upF;

    bandTag = hs.util.band_tag(lowF, upF);                 % e.g. 11_14y
    bandTagPretty = sprintf('%.0f--%.0fy', lowF, upF);

    inMat = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_%s_band_%s.mat', dataTag, bandTag));
    assert(exist(inMat,'file')==2, ...
        'Missing %s (run run_phase_band_data first).', inMat);

    tmp = load(inMat);
    assert(isfield(tmp,'out'), 'Expected variable `out` in %s.', inMat);
    out = tmp.out;

    assert(isfield(out,'dates') && isfield(out,'phaseX'), ...
        'Phase intermediate missing out.dates/out.phaseX: %s', inMat);

    dates  = out.dates(:);
    phaseX = out.phaseX;

    assert(size(phaseX,2) == numel(geo.poly), ...
        'phaseX columns (%d) do not match number of polygons in geo.poly (%d).', ...
        size(phaseX,2), numel(geo.poly));

    % Snap to nearest available observation
    [~, tIdx] = min(abs(dates - tReq));
    tUsed = dates(tIdx);

    % Relative phase snapshot
    phase_t = phaseX(tIdx,:);                    % 1 x N
    [~, phi] = hs.phase.kuramoto_r(phase_t);
    thetaRel = angle(exp(1i * (phase_t(:) - phi)));   % N x 1, in [-pi, pi]

    snaps(j).bandKey       = char(bk);
    snaps(j).lowF          = lowF;
    snaps(j).upF           = upF;
    snaps(j).bandTag       = bandTag;
    snaps(j).bandTagPretty = bandTagPretty;
    snaps(j).tUsed         = tUsed;
    snaps(j).thetaRel      = thetaRel;
end

% -------------------------------------------------------------------------
% Output naming
% -------------------------------------------------------------------------
titleFmt = resolve_title_fmt_(cfg);
tTitle   = datestr(snaps(1).tUsed, titleFmt);
snapTag  = datestr(snaps(1).tUsed, 'yyyymm');

if numel(snaps) == 1
    outStem = sprintf('Fig_relative_phase_snapshot_%s_%s_%s', ...
        snaps(1).bandTag, dataTag, snapTag);
else
    outStem = sprintf('Fig_relative_phase_snapshot_compare_%s_%s', ...
        dataTag, snapTag);
end

outPdf = fullfile(cfg.paths.figures, [outStem '.pdf']);
outPng = fullfile(cfg.paths.figures, [outStem '.png']);

if exist(outPdf,'file')==2 && ~opt.Overwrite
    fprintf('Exists (set Overwrite=true): %s\n', outPdf);
    return;
end

% -------------------------------------------------------------------------
% Figure
% -------------------------------------------------------------------------
nPanels = numel(snaps);
figW = 520 * nPanels + 120;
figH = 560;
fig = figure('Color','w','Position',[100 100 figW figH]);

tlo = tiledlayout(fig, 1, nPanels, 'TileSpacing','compact', 'Padding','compact');

cmapPhase = hs.plot.redblue(256);
lastAx = [];

for j = 1:nPanels
    ax = nexttile(tlo, j);
    lastAx = ax;

    hs.spatial.plot_us_choropleth(geo.poly, snaps(j).thetaRel, ...
        'Parent', ax, ...
        'Title', sprintf('%s band', snaps(j).bandTagPretty), ...
        'Colormap', cmapPhase, ...
        'CLim', [-pi pi], ...
        'ShowColorbar', false);

    colormap(ax, cmapPhase);
    clim(ax, [-pi pi]);
    axis(ax, 'off');
end

% Shared colorbar
cb = colorbar(lastAx, 'Location', 'eastoutside');
cb.Label.String = 'relative phase (radians)';
cb.Ticks = [-pi -pi/2 0 pi/2 pi];
cb.TickLabels = {'-\pi','-\pi/2','0','\pi/2','\pi'};

% Optional one phase wheel on the last panel
if opt.ShowPhaseWheel && exist('hs.plot.phasecolbar','file') == 2
    try
        axW = hs.plot.phasecolbar(lastAx, ...
            'Location','se', 'Size',0.22, ...
            'Labels', {'peak','trough'}, ...
            'LabelAngles', [0 pi], ...
            'ShowDirection', true, 'Direction','ccw');
        set(axW, 'Units','normalized');
        axW.Position = [0.83 0.12 0.10 0.10];
        uistack(axW, 'top');
    catch ME
        warning('Phase wheel could not be drawn: %s', ME.message);
    end
end

sgtitle(tlo, sprintf('Relative phase snapshots (%s), %s', dataLabelStr, tTitle));

% Small annotation with requested / used date
txt = sprintf('Requested: %s\nUsed: %s', ...
    datestr(tReq, 'mmm yyyy'), datestr(snaps(1).tUsed, 'mmm yyyy'));
annotation(fig, 'textbox', [0.02 0.02 0.12 0.08], ...
    'String', txt, ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', 'w', ...
    'EdgeColor', [0.7 0.7 0.7], ...
    'FontSize', 9);

exportgraphics(fig, outPdf, 'ContentType','vector');
exportgraphics(fig, outPng, 'Resolution', cfg.fig.dpi);
close(fig);

fprintf('Saved:\n  %s\n  %s\n', outPdf, outPng);

end

% =========================================================================
function t = snapshotdate_to_datetime_(x)
if isdatetime(x)
    t = x;
elseif isstring(x) || ischar(x)
    t = datetime(x);
else
    error('Snapshot date must be datetime or string/char.');
end
t = t(:);
t = t(1);
end

% =========================================================================
function titleFmt = resolve_title_fmt_(cfg)
if isfield(cfg,'snapshot') && isfield(cfg.snapshot,'titleFmt') && ~isempty(cfg.snapshot.titleFmt)
    titleFmt = char(string(cfg.snapshot.titleFmt));
else
    titleFmt = 'mmm yyyy';
end
end