function out = make_fig_single_state_example(varargin)
%MAKE_FIG_SINGLE_STATE_EXAMPLE  Single-state illustrative series + WPS figure.
%
% Figure panels:
%   (A) Transformed state-level series chosen by cfg.data.series
%   (B) Wavelet power spectrum of that same transformed series
%
% Reads:
%   cfg.outputs.processedMat
%
% Saves (tagged):
%   cfg.paths.figures/Fig_single_state_example_<state>_<dataTag>.pdf (+ .png)
%   cfg.paths.intermediate/single_state_example_<state>_<dataTag>.mat
%
% Optionally also saves canonical paper filenames:
%   cfg.paths.figures/Fig_single_state_example.pdf (+ .png)
%   cfg.paths.intermediate/single_state_example.mat
%
% Options:
%   'StateCode'     : override cfg.exampleState.code
%   'Overwrite'     : accepted for pipeline compatibility (we always recompute)
%   'PicEnh'        : 0.4
%   'SaveCanonical' : true

%% Options
p = inputParser;
p.addParameter('StateCode', "", @(s)isstring(s)||ischar(s));
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b)); %#ok<NASGU>
p.addParameter('PicEnh', 0.4, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('SaveCanonical', true, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results;

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
    "wave.mother","wave.beta","wave.gamma","wave.sig_type", ...
    "data.series" ...
    };
for k = 1:numel(req)
    if ~hasNestedField_(cfg, req{k})
        error('Missing cfg field: %s', req{k});
    end
end

% Tooling dependencies
assert(exist('AWT','file')==2, 'ASToolbox missing from path: function AWT not found.');
assert(~isempty(which('hs.wavelets.wps_awt')), 'Missing helper: hs.wavelets.wps_awt');
assert(~isempty(which('hs.wavelets.plot_wps')), 'Missing helper: hs.wavelets.plot_wps');
assert(~isempty(which('hs.data.select_hpi_matrix')), 'Missing helper: hs.data.select_hpi_matrix');

%% Paths
figDir = cfg.paths.figures;
intDir = cfg.paths.intermediate;
if ~exist(figDir,'dir'); mkdir(figDir); end
if ~exist(intDir,'dir'); mkdir(intDir); end

%% Load processed data
assert(exist(cfg.outputs.processedMat,'file')==2, 'Missing %s', cfg.outputs.processedMat);
S = load(cfg.outputs.processedMat);

codesAll = string(S.stateCodes(:));
namesAll = string(S.stateNames(:));

[Xall, t, dataLabel] = hs.data.select_hpi_matrix(S, cfg);   % Xall: T x Nstates
dataLabel = string(dataLabel);
assert(strlength(dataLabel)>0, 'select_hpi_matrix returned empty dataLabel.');

dataTag = hs.util.data_tag(dataLabel);

%% Resolve example state
if strlength(string(opt.StateCode)) > 0
    stateCode = upper(string(opt.StateCode));
else
    assert(isfield(cfg,'exampleState') && isfield(cfg.exampleState,'code') ...
        && strlength(string(cfg.exampleState.code))>0, ...
        'Set cfg.exampleState.code or pass StateCode explicitly.');
    stateCode = upper(string(cfg.exampleState.code));
end

idx = find(codesAll == stateCode, 1);
assert(~isempty(idx), 'State code %s not found in processed data.', stateCode);

x = Xall(:, idx);
stateName = namesAll(idx);

%% Compute WPS
outWPS = hs.wavelets.wps_awt(x, cfg);

%% Output paths
figPdf_tag = fullfile(figDir, sprintf('Fig_single_state_example_%s_%s.pdf', lower(char(stateCode)), char(dataTag)));
figPng_tag = fullfile(figDir, sprintf('Fig_single_state_example_%s_%s.png', lower(char(stateCode)), char(dataTag)));
intermediateMat_tag = fullfile(intDir, sprintf('single_state_example_%s_%s.mat', lower(char(stateCode)), char(dataTag)));

figPdf = fullfile(figDir, 'Fig_single_state_example.pdf');
figPng = fullfile(figDir, 'Fig_single_state_example.png');
intermediateMat = fullfile(intDir, 'single_state_example.mat');

%% Plot
fig = figure('Color','w','Position',[100 100 980 860]);
tl = tiledlayout(fig, 2, 1, 'Padding','compact', 'TileSpacing','compact');

% Human-readable series label for axes / captions
seriesYLabel = series_ylabel_(cfg, dataLabel);

% Panel A: transformed series
ax1 = nexttile(tl, 1);
if isprop(ax1,'Toolbar'); ax1.Toolbar.Visible = 'off'; end
plot(ax1, t, x, 'LineWidth', 1.2);
grid(ax1, 'on');
box(ax1, 'off');
xlim(ax1, [t(1) t(end)]);
ylabel(ax1, seriesYLabel, 'Interpreter','none');
title(ax1, sprintf('A. %s state house-price series', char(stateName)), ...
    'Interpreter','none');

% Panel B: WPS
ax2 = nexttile(tl, 2);
if isprop(ax2,'Toolbar'); ax2.Toolbar.Visible = 'off'; end
hs.wavelets.plot_wps(t, outWPS, ...
    'Parent', ax2, ...
    'Title', sprintf('B. %s state wavelet power spectrum', char(stateName)), ...
    'Colormap', jet(256), ...
    'PicEnh', opt.PicEnh, ...
    'ShowSignif', false, ...
    'ShowRidges', true, ...
    'RidgeArgs', {2, 0.1});

exportgraphics(fig, figPdf_tag, 'ContentType','vector');
exportgraphics(fig, figPng_tag, 'Resolution', cfg.fig.dpi);
close(fig);

if opt.SaveCanonical
    copyfile(figPdf_tag, figPdf, 'f');
    copyfile(figPng_tag, figPng, 'f');
end

%% Pack + save intermediate
out = struct();
out.t = t;
out.x = x;
out.stateCode = stateCode;
out.stateName = stateName;
out.dataLabel = dataLabel;
out.dataSeries = cfg.data.series;
out.wps = outWPS;
out.cfg_wave = cfg.wave;

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

% -------------------------------------------------------------------------
function tf = hasNestedField_(s, pathStr)
parts = split(string(pathStr), ".");
tf = true;
x = s;
for i = 1:numel(parts)
    p = char(parts(i));
    if ~isstruct(x) || ~isfield(x, p)
        tf = false;
        return;
    end
    x = x.(p);
end
end


% -------------------------------------------------------------------------
function lbl = series_ylabel_(cfg, dataLabel)
% Human-readable label for transformed series shown in panel A.
%
% Prefer cfg-driven interpretation, fall back to dataLabel if needed.

series = "";
if isfield(cfg, 'data') && isfield(cfg.data, 'series')
    series = upper(string(cfg.data.series));
end

nsaDeseason = "";
if isfield(cfg, 'data') && isfield(cfg.data, 'nsa_deseason')
    nsaDeseason = lower(string(cfg.data.nsa_deseason));
end

switch series
    case "SA"
        lbl = 'YoY log growth';
    case "NSA"
        switch nsaDeseason
            case "yoy_diff"
                lbl = 'YoY log growth';
            case "month_demean"
                lbl = 'Log growth (month-demeaned NSA)';
            otherwise
                % If NSA selection still corresponds to the yoy transform,
                % this label remains the most reader-friendly paper choice.
                lbl = 'YoY log growth';
        end
    otherwise
        % Fall back to whatever select_hpi_matrix returned
        lbl = char(string(dataLabel));
end
end