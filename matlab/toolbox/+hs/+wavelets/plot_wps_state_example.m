function out = plot_wps_state_example(stateUSPS, varargin)
%HS.WAVELETS.PLOT_WPS_STATE_EXAMPLE  Plot (and optionally save) a WPS example for one state.
%
% out = hs.wavelets.plot_wps_state_example("WA", 'Save', true)
%
% Uses:
%   - config_empirical_rsue() for paths + wavelet settings
%   - processed dataset (fmhpi_state_hpi.mat)
%   - hs.wavelets.wps_awt and hs.wavelets.plot_wps
%
% Options:
%   'SeriesField'    : 'dlog_sa_states' (default) or another (T x N) field in processed mat
%   'DateField'      : 'dates_dlog'     (default)
%   'ShowSeries'     : true            (default) include top time-series panel
%   'TitlePrefix'    : ""              (default)
%   'PicEnh'         : 0.4             (default)
%   'CLimQuantile'   : 95              (default)
%   'ShowCOI'        : true            (default)
%   'ShowRidges'     : true            (default; requires MatrixMax)
%   'ShowSignif'     : true            (default)
%   'SignifLevel'    : 0.05            (default)
%   'Colormap'       : jet(256)        (default)
%   'ShowColorbar'   : false           (default)
%   'XTickStepYears' : 5               (default) round-year tick spacing for both panels
%   'XTickYearOrigin': []              (default) let function choose next multiple
%   'Save'           : false           (default)
%   'OutDir'         : ""              (default) <proj>/outputs/figures/examples
%   'FileStem'       : ""              (default) auto like "WPS_WA"
%   'Resolution'     : 300             (default) png dpi

p = inputParser;
p.addRequired('stateUSPS', @(s) isstring(s) || ischar(s));

p.addParameter('SeriesField', 'dlog_sa_states', @(s)ischar(s)||isstring(s));
p.addParameter('DateField',   'dates_dlog',     @(s)ischar(s)||isstring(s));
p.addParameter('ShowSeries', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('TitlePrefix', "", @(s)ischar(s)||isstring(s));

p.addParameter('PicEnh', 0.4, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('CLimQuantile', 95, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<100);

p.addParameter('ShowCOI', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('ShowRidges', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('ShowSignif', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('SignifLevel', 0.05, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<1);

p.addParameter('Colormap', jet(256));
p.addParameter('ShowColorbar', false, @(b)islogical(b)&&isscalar(b));

p.addParameter('XTickStepYears', 5, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('XTickYearOrigin', [], @(x) isempty(x) || (isnumeric(x)&&isscalar(x)));

p.addParameter('Save', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('OutDir', "", @(s)ischar(s)||isstring(s));
p.addParameter('FileStem', "", @(s)ischar(s)||isstring(s));
p.addParameter('Resolution', 300, @(x)isnumeric(x)&&isscalar(x)&&x>0);

p.parse(stateUSPS, varargin{:});
opt = p.Results;

stateUSPS = upper(string(stateUSPS));

%% ---- config (strict) ----
assert(exist('config_empirical_rsue','file')==2, 'config_empirical_rsue.m not found on path.');
cfg = config_empirical_rsue();
assert(isfield(cfg,'outputs') && isfield(cfg.outputs,'processedMat'), 'cfg.outputs.processedMat missing');
assert(isfield(cfg,'wave'), 'cfg.wave missing');

%% ---- load processed dataset ----
assert(exist(cfg.outputs.processedMat,'file')==2, 'Processed MAT not found: %s', cfg.outputs.processedMat);
S = load(cfg.outputs.processedMat);

seriesField = char(opt.SeriesField);
dateField   = char(opt.DateField);

assert(isfield(S, seriesField), 'Field not found in processed MAT: %s', seriesField);
assert(isfield(S, dateField),   'Field not found in processed MAT: %s', dateField);
assert(isfield(S, 'stateCodes'), 'Processed MAT missing stateCodes');

X = S.(seriesField);
t = S.(dateField);
codes = upper(string(S.stateCodes(:)));

idx = find(codes == stateUSPS, 1);
assert(~isempty(idx), 'State code %s not found in dataset stateCodes.', stateUSPS);

% Prefer stateNames if available, else just use USPS code
if isfield(S,'stateNames') && numel(S.stateNames) == numel(S.stateCodes)
    names = string(S.stateNames(:));
    stateLabel = sprintf('%s (%s)', names(idx), codes(idx));
else
    stateLabel = char(stateUSPS);
end

y = X(:, idx);

%% ---- compute WPS ----
assert(~isempty(which('hs.wavelets.wps_awt')), 'Missing helper: hs.wavelets.wps_awt');
outW = hs.wavelets.wps_awt(y, cfg);

%% ---- figure layout ----
if opt.ShowSeries
    fig = figure('Color','w','Position',[100 100 1100 750]);
    tl = tiledlayout(fig, 2, 1, 'TileSpacing','compact','Padding','compact');

    % Top panel: time series
    ax1 = nexttile(tl, 1);
    plot(ax1, t, y, 'LineWidth', 1);
    grid(ax1,'on');
    ylabel(ax1, 'd log HPI');

    % Apply the SAME round-year tick scheme as plot_wps
    apply_round_year_ticks_(ax1, t, opt.XTickStepYears, opt.XTickYearOrigin);

    title(ax1, sprintf('%s%s', string(opt.TitlePrefix), stateLabel), 'Interpreter','none');

    % Bottom panel: WPS
    ax2 = nexttile(tl, 2);
else
    fig = figure('Color','w','Position',[100 100 1100 520]);
    ax2 = axes(fig);
end

%% ---- WPS plot (delegate ticks to plot_wps) ----
assert(~isempty(which('hs.wavelets.plot_wps')), 'Missing helper: hs.wavelets.plot_wps');

hs.wavelets.plot_wps(t, outW, ...
    'Parent', ax2, ...
    'Title', sprintf('WPS: %s', stateLabel), ...
    'Colormap', opt.Colormap, ...
    'PicEnh', opt.PicEnh, ...
    'CLimQuantile', opt.CLimQuantile, ...
    'ShowColorbar', opt.ShowColorbar, ...
    'ShowCOI', opt.ShowCOI, ...
    'ShowRidges', opt.ShowRidges, ...
    'ShowSignif', opt.ShowSignif, ...
    'SignifLevel', opt.SignifLevel, ...
    'XTickStepYears', opt.XTickStepYears, ...
    'XTickYearOrigin', opt.XTickYearOrigin, ...
    'SetRoundYearTicks', true);

%% ---- save (optional) ----
if opt.Save
    outDir = string(opt.OutDir);
    if strlength(outDir)==0
        procDir = fileparts(cfg.outputs.processedMat);
        projDir = fileparts(fileparts(procDir)); % .../empirical_rsue
        outDir = fullfile(projDir, 'outputs', 'figures', 'examples');
    end
    if ~exist(outDir,'dir'); mkdir(outDir); end

    stem = string(opt.FileStem);
    if strlength(stem)==0
        stem = "WPS_" + stateUSPS;
    end

    pdfPath = fullfile(outDir, stem + ".pdf");
    pngPath = fullfile(outDir, stem + ".png");

    exportgraphics(fig, pdfPath, 'ContentType','vector');
    exportgraphics(fig, pngPath, 'Resolution', opt.Resolution);

    fprintf('Saved:\n  %s\n  %s\n', pdfPath, pngPath);
end

%% ---- return ----
out = struct();
out.stateUSPS = stateUSPS;
out.idx = idx;
out.stateLabel = string(stateLabel);
out.t = t;
out.y = y;
out.wps = outW;

end

% ============================
% Local helper (mirror plot_wps)
% ============================
function apply_round_year_ticks_(ax, t, stepYears, yearOrigin)
if ~isdatetime(t), return; end
t = t(:);
tmin = min(t); tmax = max(t);

if isempty(yearOrigin)
    y0 = year(tmin);
    y0 = stepYears * ceil(y0/stepYears);   % next multiple of stepYears
else
    y0 = yearOrigin;
end

y1 = year(tmax);
tickYears = y0:stepYears:y1;
ticksDt = datetime(tickYears,1,1);

if ~isempty(ticksDt)
    ax.XTick = ticksDt;
    ax.XTickLabel = cellstr(datestr(ticksDt,'yyyy')); %#ok<DATST>
end
xlim(ax, [tmin tmax]);
end
