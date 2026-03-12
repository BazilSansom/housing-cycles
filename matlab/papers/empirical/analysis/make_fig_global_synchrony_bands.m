function out = make_fig_global_synchrony_bands(varargin)
%MAKE_FIG_GLOBAL_SYNCHRONY_BANDS  Plot Kuramoto r(t) for phase bands on one axis.
%
% Requires phase intermediates produced by run_phase_band_data:
%   cfg.paths.intermediate/phase_<tagData>_band_<low>_<up>y.mat

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(c)iscell(c)||isstring(c));
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('SaveCanonical', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('YLim', [0 1], @(x)isnumeric(x)&&numel(x)==2);
p.addParameter('LineWidth', 1.4, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('YearTickStep', 5, @(x)isnumeric(x)&&isscalar(x)&&x>=1);
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();

figDir = cfg.paths.figures;
intDir = cfg.paths.intermediate;
if ~exist(figDir,'dir'); mkdir(figDir); end
if ~exist(intDir,'dir'); mkdir(intDir); end

% --- canonical data tag ---
Sproc = load(cfg.outputs.processedMat);
[~,~,dataLabel] = hs.data.select_hpi_matrix(Sproc, cfg);
dataLabel = string(dataLabel);
tagData = hs.util.data_tag(dataLabel);

figPdf_tag = fullfile(figDir, sprintf('Fig_global_synchrony_%s.pdf', tagData));
figPng_tag = fullfile(figDir, sprintf('Fig_global_synchrony_%s.png', tagData));
figPdf     = fullfile(figDir, 'Fig_global_synchrony.pdf');
figPng     = fullfile(figDir, 'Fig_global_synchrony.png');

if exist(figPdf_tag,'file')==2 && ~opt.Overwrite
    fprintf('Exists (set Overwrite=true): %s\n', figPdf_tag);
    out = struct('files', struct('pdf', figPdf_tag, 'png', figPng_tag), ...
                 'dataLabel', dataLabel, 'tagData', tagData);
    return;
end

bands = string(opt.WhichBands(:));
assert(isfield(cfg,'bands'), 'cfg.bands missing.');

series = struct([]);
for bi = 1:numel(bands)
    bk = bands(bi);
    assert(isfield(cfg.bands, bk), 'cfg.bands.%s not found', bk);

    band = cfg.bands.(bk);
    tagBand = sprintf('%g_%g', band.lowF, band.upF);  % e.g. "8_10"
    inMat = fullfile(intDir, sprintf('phase_%s_band_%sy.mat', tagData, tagBand));
    assert(exist(inMat,'file')==2, 'Missing %s (run run_phase_band_data for %s).', inMat, bk);

    P = load(inMat);
    if isfield(P,'out'); o = P.out; else; o = P; end

    [r, ~] = hs.phase.kuramoto_r(o.phaseX);

    series(bi).bandKey = char(bk);
    series(bi).lowF  = band.lowF;
    series(bi).upF   = band.upF;
    series(bi).dates = o.dates(:);
    series(bi).r     = r(:);
end

% --- plot ---
fig = figure('Color','w','Position',[120 120 980 420]);
ax = axes(fig);
hold(ax,'on');
for bi = 1:numel(series)
    plot(ax, series(bi).dates, series(bi).r, 'LineWidth', opt.LineWidth);
end
hold(ax,'off');

box(ax,'on');
ax.Layer = 'top';
ax.LineWidth = 1.0;
grid(ax,'on');
ylim(ax, opt.YLim);

% ticks every opt.YearTickStep years
xlim(ax, [series(1).dates(1) series(1).dates(end)]);
y0 = year(dateshift(series(1).dates(1),'start','year'));
y1 = year(dateshift(series(1).dates(end),'start','year'));
yt = y0:opt.YearTickStep:y1;
ax.XTick = datetime(yt,1,1);
ax.XAxis.TickLabelFormat = 'yyyy';

leg = strings(numel(series),1);
for bi = 1:numel(series)
    leg(bi) = sprintf('%g–%gy', series(bi).lowF, series(bi).upF);
end
legend(ax, leg, 'Location','best');

title(ax, sprintf('Global synchronisation r(t) (%s)', char(dataLabel)));
ylabel(ax,'r(t)');
xlabel(ax,'Date');

if isprop(ax,'Toolbar'); ax.Toolbar.Visible = 'off'; end

exportgraphics(ax, figPdf_tag, 'ContentType','vector');
exportgraphics(ax, figPng_tag, 'Resolution', 300);
close(fig);

if opt.SaveCanonical
    copyfile(figPdf_tag, figPdf, 'f');
    copyfile(figPng_tag, figPng, 'f');
end

out = struct();
out.dataLabel = dataLabel;
out.tagData   = tagData;
out.series    = series;
out.files = struct('pdf_tag', figPdf_tag, 'png_tag', figPng_tag, ...
                   'pdf', figPdf, 'png', figPng);

fprintf('Saved:\n  %s\n  %s\n', figPdf_tag, figPng_tag);
end