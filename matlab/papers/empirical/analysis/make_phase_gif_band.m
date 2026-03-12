function make_phase_gif_band(varargin)
%MAKE_PHASE_GIF_BAND  Animate instantaneous band phase as a US choropleth GIF.
%
% Reads:
%   cfg.outputs.geoMat
%   outputs/intermediate/phase_<dataTag>_band_<low>_<up>y.mat
%     (from run_phase_band_data)
%
% Writes:
%   outputs/figures/PhaseGIF_<bandTag>_<dataTag>.gif
%
% Notes:
%   - Single-band function by design. Call once per band from run_all.
%   - Phase is wrapped to [-pi, pi].
%   - By convention, phase 0 (peak) is blue and phase ±pi (trough) is red.

p = inputParser;
p.addParameter('BandKey', "main", @(s)isstring(s)||ischar(s));
p.addParameter('Stride', 1, @(x)isnumeric(x)&&isscalar(x)&&x>=1);
p.addParameter('DelayTime', 0.08, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('LoopCount', inf, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('ShowTitle', true, @(b)islogical(b)&&isscalar(b));

% Legend / display options
p.addParameter('ShowWheel', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('WheelPos', [0.78 0.10 0.14 0.14], @(v)isnumeric(v)&&numel(v)==4);
p.addParameter('ShowLinearColorbar', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('CLim', [-pi pi], @(v)isnumeric(v)&&numel(v)==2);

p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();
bandKey = char(string(opt.BandKey));

assert(isfield(cfg, 'bands') && isfield(cfg.bands, bandKey), ...
    'cfg.bands.%s missing.', bandKey);

if ~exist(cfg.paths.figures, 'dir')
    mkdir(cfg.paths.figures);
end

% --- Load geo ---
assert(exist(cfg.outputs.geoMat,'file') == 2, ...
    'Missing geoMat: %s', cfg.outputs.geoMat);
G = load(cfg.outputs.geoMat);
geo = G.geo;
poly = geo.poly;

% --- Resolve band from config ---
band = cfg.bands.(bandKey);
lowF = band.lowF;
upF  = band.upF;

tagBand    = sprintf('%g_%g', lowF, upF);    % for intermediate .mat files
gifBandTag = hs.util.band_tag(lowF, upF);    % for GIF filename / display

% --- Resolve current data tag consistently with rest of pipeline ---
assert(exist(cfg.outputs.processedMat,'file') == 2, ...
    'Missing processed MAT: %s', cfg.outputs.processedMat);
S = load(cfg.outputs.processedMat);
[~,~,dataLabel] = hs.data.select_hpi_matrix(S, cfg);
dataLabel = string(dataLabel);
dataTag   = hs.util.data_tag(dataLabel);

% --- Load phase intermediate (authoritative source) ---
phaseMat = fullfile(cfg.paths.intermediate, ...
    sprintf('phase_%s_band_%sy.mat', dataTag, tagBand));

if exist(phaseMat,'file') ~= 2
    fprintf('Missing %s; running run_phase_band_data for band "%s"...\n', phaseMat, bandKey);
    run_phase_band_data('WhichBands', string(bandKey), 'Overwrite', opt.Overwrite);
end

assert(exist(phaseMat,'file') == 2, ...
    'Phase intermediate still missing after run_phase_band_data: %s', phaseMat);

P = load(phaseMat);
assert(isfield(P,'out'), 'Expected variable `out` in %s.', phaseMat);
out = P.out;

assert(isfield(out,'dates') && isfield(out,'phaseX'), ...
    'Phase intermediate missing out.dates/out.phaseX: %s', phaseMat);

dates  = out.dates(:);
phaseX = out.phaseX;   % T x N
[T, N] = size(phaseX); %#ok<ASGLU>

assert(size(phaseX,2) == numel(poly), ...
    'phaseX columns (%d) do not match number of polygons (%d).', ...
    size(phaseX,2), numel(poly));

% --- Output path ---
outGif = fullfile(cfg.paths.figures, ...
    sprintf('GIF_phase_%s_%s.gif', gifBandTag, char(dataTag)));

if exist(outGif,'file') == 2 && ~opt.Overwrite
    fprintf('Exists (set Overwrite=true): %s\n', outGif);
    return;
end
if exist(outGif,'file') == 2
    delete(outGif);
end

% --- Figure setup ---
fig = figure('Color','w', 'Units','pixels', 'Position',[100 100 1200 700]);
set(fig, 'Renderer', 'opengl');
ax = axes('Parent', fig);

% trough red, peak blue
cmap = hs.plot.customcolormap([0 0.5 1], [0 0 1; 1 1 1; 1 0 0], 256);

wrapToPiLocal = @(a) angle(exp(1i*a));

% Initial frame creates the patch objects
hs.spatial.plot_us_choropleth(poly, wrapToPiLocal(phaseX(1,:)).', ...
    'Parent', ax, ...
    'Colormap', cmap, ...
    'CLim', opt.CLim, ...
    'ShowColorbar', opt.ShowLinearColorbar, ...
    'Title', '');

patches = findobj(ax, 'Type', 'patch');
patches = patches(arrayfun(@(h) ~isempty(h.UserData) && isnumeric(h.UserData), patches));

colormap(ax, cmap);
clim(ax, opt.CLim);

if opt.ShowWheel
    axW = hs.plot.phasecolbar(ax, ...
        'Location', 'se', ...
        'Size', 0.22, ...
        'Labels', {'peak','trough'}, ...
        'LabelAngles', [0 pi], ...
        'ShowDirection', true, ...
        'Direction', 'ccw');

    set(axW, 'Units', 'normalized');
    axW.Position = opt.WheelPos;
    uistack(axW, 'top');
end

drawnow;

% --- Write frames ---
first = true;
for t = 1:opt.Stride:T
    vals = wrapToPiLocal(phaseX(t,:)).';

    for h = patches.'
        i = h.UserData;
        h.CData = vals(i);
    end

    if opt.ShowTitle
        title(ax, sprintf('Instantaneous phase (%s, %.0f--%.0fy), %s', ...
            bandKey, lowF, upF, datestr(dates(t), 'mmm yyyy')));
    end

    drawnow;

    fr = getframe(fig);
    [im, ~] = frame2im(fr);
    [Aind, map] = rgb2ind(im, cmap, 'nodither');

    if first
        imwrite(Aind, map, outGif, 'gif', ...
            'LoopCount', opt.LoopCount, ...
            'DelayTime', opt.DelayTime);
        first = false;
    else
        imwrite(Aind, map, outGif, 'gif', ...
            'WriteMode', 'append', ...
            'DelayTime', opt.DelayTime);
    end
end

close(fig);
fprintf('Wrote GIF: %s\n', outGif);

end