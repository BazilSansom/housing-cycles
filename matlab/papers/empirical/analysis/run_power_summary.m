function out = run_power_summary(varargin)
%RUN_POWER_SUMMARY  Mean wavelet power spectrum across states + national US YoY WPS (two-panel, paper-grade).
%
% Always recomputes (no caching) to avoid stale/mismatched outputs.
%
% Figure panels:
%   (A) WPS of national US series dlog12_nsa_US (YoY log-diff, NSA)
%   (B) Mean WPS across selected states for the series chosen by cfg.data.series
%
% Saves (tagged by dataLabel):
%   cfg.paths.figures/Fig_power_mean_wps_<tagData>.pdf (+ .png)
%   cfg.paths.intermediate/power_summary_<tagData>.mat
%
% Optionally also saves canonical paper filenames:
%   cfg.paths.figures/Fig_power_mean_wps.pdf (+ .png)
%   cfg.paths.intermediate/power_summary.mat
%
% Options:
%   'Overwrite'            : accepted for pipeline compatibility (ignored; we always recompute)
%   'PicEnh'              : 0.4
%   'SaveAllWPS'           : false
%   'ComputePeakDensity'   : true
%   'KeepUnmaskedPeaks'    : true
%   'RidgeArgs'            : {2,0.1}
%   'IncludeUSPS'          : []
%   'ExcludeUSPS'          : []
%   'UseDefaultExclusions' : true
%   'SaveCanonical'        : true

%% Options
p = inputParser;
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b)); %#ok<NASGU>
p.addParameter('SaveAllWPS', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('PicEnh', 0.4, @(x)isnumeric(x)&&isscalar(x)&&x>0);

p.addParameter('IncludeUSPS', string.empty(0,1));
p.addParameter('ExcludeUSPS', string.empty(0,1));
p.addParameter('UseDefaultExclusions', true, @(b)islogical(b)&&isscalar(b));

p.addParameter('ComputePeakDensity', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('KeepUnmaskedPeaks', true, @(b)islogical(b)&&isscalar(b));

p.addParameter('RidgeArgs', {2, 0.1}, @(x) ...
    (iscell(x) && numel(x)==2 && isnumeric(x{1}) && isnumeric(x{2})) || ...
    (isnumeric(x) && numel(x)==2));

p.addParameter('SaveCanonical', true, @(b)islogical(b)&&isscalar(b));

p.parse(varargin{:});
opt = p.Results;

% Normalise RidgeArgs to cell {nb, factor}
if isnumeric(opt.RidgeArgs)
    opt.RidgeArgs = {opt.RidgeArgs(1), opt.RidgeArgs(2)};
end

%% Config
assert(exist('config_empirical','file')==2, ...
    'config_empirical.m not found on path.');

cfg = config_empirical();

% Minimal required fields
req = { ...
    "outputs.processedMat", ...
    "paths.figures", ...
    "paths.intermediate", ...
    "wave.dt","wave.dj","wave.low_period","wave.up_period","wave.pad", ...
    "wave.mother","wave.beta","wave.gamma","wave.sig_type" ...
    };
for k = 1:numel(req)
    if ~hasNestedField(cfg, req{k})
        error('Missing cfg field: %s', req{k});
    end
end

% Tooling dependencies (fail fast)
assert(exist('AWT','file')==2, 'ASToolbox missing from path: function AWT not found.');
assert(~isempty(which('hs.wavelets.wps_awt')), 'Missing helper: hs.wavelets.wps_awt');
assert(~isempty(which('hs.wavelets.plot_wps')), 'Missing helper: hs.wavelets.plot_wps');
assert(~isempty(which('hs.spatial.select_states')), 'Missing helper: hs.spatial.select_states');
assert(~isempty(which('hs.data.select_hpi_matrix')), 'Missing helper: hs.data.select_hpi_matrix');

if opt.ComputePeakDensity
    assert(exist('MatrixMax','file')==2, ...
        'ComputePeakDensity=true but MatrixMax not found (ASToolbox).');
end

%% Paths
figDir = cfg.paths.figures;
intDir = cfg.paths.intermediate;
if ~exist(figDir,'dir'); mkdir(figDir); end
if ~exist(intDir,'dir'); mkdir(intDir); end

%% Load data and choose series from cfg
assert(exist(cfg.outputs.processedMat,'file')==2, 'Missing %s', cfg.outputs.processedMat);
S = load(cfg.outputs.processedMat);

% --- National US YoY series (always panel A) ---
assert(isfield(S,'dlog12_nsa_US') && isfield(S,'dates_dlog12'), ...
    'processedMat must contain dlog12_nsa_US and dates_dlog12. Rebuild dataset if needed.');
xUS12 = S.dlog12_nsa_US(:);
tUS12 = S.dates_dlog12(:);

% --- State panel series chosen by cfg (panel B) ---
codesAll = string(S.stateCodes(:));
[Xall, t, dataLabel] = hs.data.select_hpi_matrix(S, cfg);   % Xall: T x 51, t: T x 1
dataLabel = string(dataLabel);
assert(strlength(dataLabel)>0, 'select_hpi_matrix returned empty dataLabel.');

tagData = lower(regexprep(char(dataLabel), '[^a-z0-9]+', '_'));
tagData = regexprep(tagData, '^_+|_+$', '');
if isempty(tagData), tagData = 'data'; end

% Tagged outputs (won’t clobber SA vs NSA)
intermediateMat_tag = fullfile(intDir, sprintf('power_summary_%s.mat', tagData));
figPdf_tag = fullfile(figDir, sprintf('Fig_power_mean_wps_%s.pdf', tagData));
figPng_tag = fullfile(figDir, sprintf('Fig_power_mean_wps_%s.png', tagData));

% Canonical “paper” outputs (easy LaTeX include)
intermediateMat = fullfile(intDir, 'power_summary.mat');
figPdf = fullfile(figDir, 'Fig_power_mean_wps.pdf');
figPng = fullfile(figDir, 'Fig_power_mean_wps.png');

%% Select states (contiguous US by default)
[keep, codes, selMeta] = hs.spatial.select_states(codesAll, cfg, ...
    'IncludeUSPS', opt.IncludeUSPS, ...
    'ExcludeUSPS', opt.ExcludeUSPS, ...
    'UseDefaultExclusions', opt.UseDefaultExclusions, ...
    'Strict', true);

X = Xall(:, keep);
N = numel(codes);
fprintf('Power summary selection: reason=%s, N=%d states, data=%s\n', ...
    string(selMeta.reason), N, dataLabel);

%% Panel A: WPS of national US YoY NSA series
outUS12 = hs.wavelets.wps_awt(xUS12, cfg);

%% Panel B: Compute WPS per state and average
out1 = hs.wavelets.wps_awt(X(:,1), cfg);
periods = out1.periods(:);
coi     = out1.coi(:);

WPSsum = zeros(size(out1.WPS), 'like', out1.WPS);

if opt.SaveAllWPS
    WPSall = zeros([size(out1.WPS), N], 'like', out1.WPS);
else
    WPSall = [];
end

if opt.ComputePeakDensity
    args = opt.RidgeArgs; nb = args{1}; factor = args{2};
    peakCount = zeros(size(out1.WPS), 'single');                 % COI-masked
    if opt.KeepUnmaskedPeaks
        peakCount_unmasked = zeros(size(out1.WPS), 'single');    % unmasked
    else
        peakCount_unmasked = [];
    end
end

for i = 1:N
    oi = hs.wavelets.wps_awt(X(:,i), cfg);

    if numel(oi.periods) ~= numel(periods) || ~isequal(size(oi.WPS), size(WPSsum))
        error('Inconsistent WPS grid across states (state %s).', codes(i));
    end

    WPSsum = WPSsum + oi.WPS;

    if opt.SaveAllWPS
        WPSall(:,:,i) = oi.WPS;
    end

    if opt.ComputePeakDensity
        lm = single(MatrixMax(oi.WPS, nb, factor));   % nP x T, 0/1
        if opt.KeepUnmaskedPeaks
            peakCount_unmasked = peakCount_unmasked + lm;
        end

        safe = periods(:) <= oi.coi(:)';              % nP x T
        lm(~safe) = 0;
        peakCount = peakCount + lm;
    end
end

meanWPS = WPSsum / N;

outMean = struct();
outMean.periods = periods;
outMean.coi     = coi;
outMean.WPS     = meanWPS;
outMean.pv_WPS  = [];

%% Plot two-panel figure: (A) US YoY NSA, (B) mean WPS across states
titleA = 'A. National US HPI: YoY log-diff (NSA), wavelet power';
titleB = sprintf('B. Mean wavelet power across states (N=%d; %s)', N, char(dataLabel));

fig = figure('Color','w','Position',[100 100 980 860]);
tl = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');

ax1 = nexttile(tl,1);
if isprop(ax1,'Toolbar'); ax1.Toolbar.Visible = 'off'; end
hs.wavelets.plot_wps(tUS12, outUS12, ...
    'Parent', ax1, ...
    'Title', titleA, ...
    'Colormap', jet(256), ...
    'PicEnh', opt.PicEnh, ...
    'ShowSignif', false, ...
    'ShowRidges', true, ...
    'RidgeArgs', opt.RidgeArgs);

ax2 = nexttile(tl,2);
if isprop(ax2,'Toolbar'); ax2.Toolbar.Visible = 'off'; end
hs.wavelets.plot_wps(t, outMean, ...
    'Parent', ax2, ...
    'Title', titleB, ...
    'Colormap', jet(256), ...
    'PicEnh', opt.PicEnh, ...
    'ShowSignif', false, ...
    'ShowRidges', true, ...
    'RidgeArgs', opt.RidgeArgs);

exportgraphics(fig, figPdf_tag, 'ContentType','vector');
exportgraphics(fig, figPng_tag, 'Resolution', 300);
close(fig);

% Also write canonical filenames for the paper
if opt.SaveCanonical
    copyfile(figPdf_tag, figPdf, 'f');
    copyfile(figPng_tag, figPng, 'f');
end

%% Pack + save intermediate
out = struct();

% Panel A payload
out.us = struct();
out.us.t = tUS12;
out.us.x = xUS12;
out.us.wps = outUS12;

% Panel B payload
out.t = t;
out.codesAll      = codesAll;
out.codesIncluded = codes;

out.periods = periods;
out.coi     = coi;
out.meanWPS = meanWPS;
out.outMean = outMean;

out.cfg_wave = cfg.wave;
out.cfg_geo  = cfg.geo;

out.meta = struct();
out.meta.dataLabel  = dataLabel;
out.meta.dataSeries = cfg.data.series;
if isfield(cfg.data,'nsa_deseason'); out.meta.nsa_deseason = cfg.data.nsa_deseason; end

out.selection = selMeta;

if opt.SaveAllWPS
    out.WPSall = WPSall;
end

if opt.ComputePeakDensity
    out.peaks = struct();
    out.peaks.peakCount = peakCount;
    out.peaks.ridgeArgs = opt.RidgeArgs;
    out.peaks.N = N;
    if opt.KeepUnmaskedPeaks
        out.peaks.peakCount_unmasked = peakCount_unmasked;
    end
end

out.files = struct();
out.files.intermediate_tag = intermediateMat_tag;
out.files.figPdf_tag = figPdf_tag;
out.files.figPng_tag = figPng_tag;
out.files.intermediate = intermediateMat;
out.files.figPdf = figPdf;
out.files.figPng = figPng;

save(intermediateMat_tag, 'out', '-v7.3');
if opt.SaveCanonical
    save(intermediateMat, 'out', '-v7.3');
end

fprintf('Saved:\n  %s\n  %s\n  %s\n', figPdf_tag, figPng_tag, intermediateMat_tag);
if opt.SaveCanonical
    fprintf('Also wrote canonical:\n  %s\n  %s\n  %s\n', figPdf, figPng, intermediateMat);
end

end

% ------------------------------
function tf = hasNestedField(s, pathStr)
parts = split(string(pathStr), ".");
tf = true;
x = s;
for i = 1:numel(parts)
    p = char(parts(i));
    if ~isstruct(x) || ~isfield(x, p)
        tf = false; return;
    end
    x = x.(p);
end
end