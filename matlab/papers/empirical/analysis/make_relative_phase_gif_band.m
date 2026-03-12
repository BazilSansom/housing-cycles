function make_relative_phase_gif_band(varargin)
%MAKE_RELATIVE_PHASE_GIF_BAND  Animate relative phase as a US choropleth GIF.
%
% Reads:
%   cfg.outputs.geoMat
%   outputs/intermediate/phase_<dataTag>_band_<bandTag>.mat
%
% Writes:
%   outputs/figures/RelativePhaseGIF_<bandTag>_<dataTag>.gif
%
% Relative phase is:
%   thetaRel_i(t) = angle(exp(1i*(theta_i(t) - phi(t))))
% where phi(t) is the global mean phase from hs.phase.kuramoto_r.
%
% Visual conventions:
%   - diverging colormap centered at 0
%   - blue = negative relative phase (lagging)
%   - white = near national phase
%   - red  = positive relative phase (leading)
%
% Notes:
%   - A diverging map is most informative when the displayed values are
%     concentrated away from the wrap boundary ±pi.
%   - To avoid frame-to-frame colour flicker, the default CLim is chosen
%     once globally over the whole animation using a robust symmetric rule.

p = inputParser;
p.addParameter('BandKey', "long", @(s)isstring(s)||ischar(s));
p.addParameter('Stride', 1, @(x)isnumeric(x)&&isscalar(x)&&x>=1);
p.addParameter('DelayTime', 0.08, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('LoopCount', inf, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('ShowTitle', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('ShowColorbar', true, @(b)islogical(b)&&isscalar(b));

% CLim options:
%   'robust-global' : symmetric limit from global percentile of |thetaRel|
%   'fixed-pi'      : [-pi pi]
%   numeric [a b]   : explicit limits
p.addParameter('CLimMode', 'robust-global', ...
    @(x)(ischar(x)||isstring(x)) || (isnumeric(x)&&numel(x)==2));
p.addParameter('CLimPrctile', 95, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<=100);
p.addParameter('CLimFloor', pi/6, @(x)isnumeric(x)&&isscalar(x)&&x>0);

p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();
bandKey = string(opt.BandKey);

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
% Load authoritative geo
% -------------------------------------------------------------------------
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);
G = load(cfg.outputs.geoMat);
assert(isfield(G,'geo'), 'geoMat does not contain variable "geo".');
geo = G.geo;

assert(isfield(geo,'poly') && ~isempty(geo.poly), ...
    'geo.poly missing or empty. Re-run run_precompute_geo.');
poly = geo.poly;

% -------------------------------------------------------------------------
% Resolve band and phase intermediate
% -------------------------------------------------------------------------
assert(isfield(cfg,'bands') && isfield(cfg.bands, bandKey), ...
    'cfg.bands.%s missing.', bandKey);

band = cfg.bands.(bandKey);
lowF = band.lowF;
upF  = band.upF;
bandTag = hs.util.band_tag(lowF, upF);
bandTagPretty = sprintf('%.0f--%.0fy', lowF, upF);

phaseMat = fullfile(cfg.paths.intermediate, ...
    sprintf('phase_%s_band_%s.mat', dataTag, bandTag));
assert(exist(phaseMat,'file')==2, ...
    'Missing %s (run run_phase_band_data first).', phaseMat);

P = load(phaseMat);
assert(isfield(P,'out'), 'Expected variable `out` in %s.', phaseMat);
out = P.out;

assert(isfield(out,'dates') && isfield(out,'phaseX'), ...
    'Phase intermediate missing out.dates/out.phaseX: %s', phaseMat);

dates = out.dates(:);
theta = out.phaseX;              % T x N
[T,N] = size(theta);

assert(numel(poly) == N, ...
    'Number of polygons in geo.poly (%d) does not match phaseX columns (%d).', ...
    numel(poly), N);

% -------------------------------------------------------------------------
% Relative phase over time
% -------------------------------------------------------------------------
[r, phi] = hs.phase.kuramoto_r(theta); %#ok<ASGLU>
phi = phi(:);
thetaRel = angle(exp(1i * (theta - phi)));   % T x N, in [-pi, pi]

% -------------------------------------------------------------------------
% Colormap and global CLim
% -------------------------------------------------------------------------
assert(~isempty(which('hs.plot.redblue')), ...
    'hs.plot.redblue not found on path.');
cmap = hs.plot.redblue(256);

if isnumeric(opt.CLimMode) && numel(opt.CLimMode)==2
    climVals = opt.CLimMode(:).';
elseif strcmpi(string(opt.CLimMode), "fixed-pi")
    climVals = [-pi pi];
elseif strcmpi(string(opt.CLimMode), "robust-global")
    q = prctile(abs(thetaRel(:)), opt.CLimPrctile);
    q = max(q, opt.CLimFloor);
    q = min(q, pi);
    climVals = [-q q];
else
    error('Unknown CLimMode: %s', string(opt.CLimMode));
end

% -------------------------------------------------------------------------
% Output path
% -------------------------------------------------------------------------
outGif = fullfile(cfg.paths.figures, ...
    sprintf('RelativePhaseGIF_%s_%s.gif', bandTag, dataTag));

if exist(outGif,'file')==2 && ~opt.Overwrite
    fprintf('Exists (set Overwrite=true): %s\n', outGif);
    return;
end
if exist(outGif,'file')==2
    delete(outGif);
end

% -------------------------------------------------------------------------
% Figure
% -------------------------------------------------------------------------
fig = figure('Color','w','Units','pixels','Position',[100 100 1250 760]);
set(fig,'Renderer','opengl');
ax = axes('Parent', fig);

% Draw first frame once
hs.spatial.plot_us_choropleth(poly, thetaRel(1,:).', ...
    'Parent', ax, ...
    'Colormap', cmap, ...
    'CLim', climVals, ...
    'ShowColorbar', opt.ShowColorbar, ...
    'ColorbarLabel', 'relative phase (radians)', ...
    'Title', '');

% Force intended colormap / limits in case helper resets them
colormap(ax, cmap);
clim(ax, climVals);

% Collect fill patches (those tagged with UserData=i in plot_us_choropleth)
patches = findobj(ax, 'Type', 'patch');
patches = patches(arrayfun(@(h) ~isempty(h.UserData) && isnumeric(h.UserData), patches));

% Standardize colorbar ticks if present
cb = findall(fig, 'Type', 'ColorBar');
if ~isempty(cb)
    cb = cb(1);
    if isequal(climVals, [-pi pi])
        cb.Ticks = [-pi -pi/2 0 pi/2 pi];
        cb.TickLabels = {'-\pi','-\pi/2','0','\pi/2','\pi'};
    else
        % keep honest labels when using robust/global limits
        cb.Ticks = [climVals(1), 0, climVals(2)];
        cb.TickLabels = {sprintf('%.2f', climVals(1)), '0', sprintf('%.2f', climVals(2))};
    end
end

drawnow;

% -------------------------------------------------------------------------
% Write frames
% -------------------------------------------------------------------------
first = true;
for t = 1:opt.Stride:T
    vals = thetaRel(t,:).';

    % Update patch colors
    for h = patches.'
        i = h.UserData;
        h.CData = vals(i);
    end

    if opt.ShowTitle
        title(ax, sprintf('Relative phase (%s, %s), %s', ...
            bandTagPretty, dataLabelStr, datestr(dates(t), 'mmm yyyy')));
    end

    drawnow;

    fr = getframe(fig);
    [im, ~] = frame2im(fr);

    % Fixed indexed palette for stable colours across frames
    [Aind, map] = rgb2ind(im, cmap, 'nodither');

    if first
        imwrite(Aind, map, outGif, 'gif', ...
            'LoopCount', opt.LoopCount, 'DelayTime', opt.DelayTime);
        first = false;
    else
        imwrite(Aind, map, outGif, 'gif', ...
            'WriteMode', 'append', 'DelayTime', opt.DelayTime);
    end
end

close(fig);
fprintf('Wrote GIF: %s\n', outGif);
fprintf('CLim used: [%.3f, %.3f]\n', climVals(1), climVals(2));

end