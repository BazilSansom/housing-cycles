function outAll = run_phase_band_data(varargin)
%RUN_PHASE_BAND_DATA  Compute and save band-averaged phase (and amplitude) for each band.
%
% Saves, for each band:
%   outputs/intermediate/phase_<dataTag>_band_<low>_<up>y.mat
%
% Outputs (per band file):
%   out.dates   : T x 1 datetime
%   out.phaseX  : T x N complex phase angles (radians)
%   out.ampX    : T x N band amplitude (optional but saved)
%   out.bandKey : char
%   out.band    : struct with lowF/upF/p_mid/name
%   out.geo     : minimal geo metadata for ordering/provenance
%   out.meta    : provenance including dataLabel/dataTag and wavelet/calibration configs
%
% Notes:
%   - This is intentionally "phase-only". Global synchrony r(t), mode-lock A/beta,
%     and graph-Fourier diagnostics should be computed downstream from phaseX.

p = inputParser;
p.addParameter('WhichBands', "all", @(v) isstring(v) || iscell(v));
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();

assert(isfield(cfg,'bands') && isstruct(cfg.bands), ...
    'Missing cfg.bands. Define cfg.bands.(bandKey).lowF/upF in config.');

% ---------- Load data ----------
assert(exist(cfg.outputs.processedMat,'file')==2, 'Missing %s', cfg.outputs.processedMat);
S = load(cfg.outputs.processedMat);
[X_all, dates, dataLabel] = hs.data.select_hpi_matrix(S, cfg);

% Canonical data tag for filenames (avoid hyphen/space mismatch)
dataLabel = string(dataLabel);
assert(strlength(dataLabel)>0, 'select_hpi_matrix returned empty dataLabel.');
dataTag = hs.util.data_tag(dataLabel);   % "nsa_yoy" not "nsa-yoy"
%dataTag = data_tag_(dataLabel);  % e.g. "sa", "nsa", "nsa_monthdemean", "nsa_yoy"

% ---------- Load geo (contiguous ordering) ----------
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing %s', cfg.outputs.geoMat);
G = load(cfg.outputs.geoMat);
geo = G.geo;
assert(isfield(geo,'colIdx'), 'geo.colIdx missing. Re-run run_precompute_geo.');

Xcc = X_all(:, geo.colIdx);   % T x N (contiguous states, order aligned to geo.V, geo.z, etc.)

% ---------- Wavelet config ----------
w = cfg.wave;

% Bands to run
if isstring(opt.WhichBands) && isscalar(opt.WhichBands) && opt.WhichBands == "all"
    bandKeys = string(fieldnames(cfg.bands)).';
else
    bandKeys = string(opt.WhichBands(:)).';
end

% Output container
outAll = struct();

% Ensure output dir exists
if ~exist(cfg.paths.intermediate,'dir'); mkdir(cfg.paths.intermediate); end

for bk = bandKeys
    bkChar = char(bk);
    assert(isfield(cfg.bands, bkChar), 'Unknown band key "%s" (not in cfg.bands).', bkChar);

    band = cfg.bands.(bkChar);
    assert(isfield(band,'lowF') && isfield(band,'upF'), ...
        'cfg.bands.%s must have fields lowF and upF.', bkChar);

    lowF = band.lowF;
    upF  = band.upF;

    % Filename band tag: consistent with the rest of pipeline
    tagBand = sprintf('%g_%g', lowF, upF);   % e.g. "8_10"
    outMat  = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_%s_band_%sy.mat', dataTag, tagBand));

    if exist(outMat,'file')==2 && ~opt.Overwrite
        tmp = load(outMat);
        out = tmp.out;
        fprintf('Exists (set Overwrite=true): %s\n', outMat);
        outAll.(bkChar) = out;
        continue;
    end

    % ---------- Wavelet band phase ----------
    [phaseX, ampX] = hs.wavelets.phase_band_awt( ...
        Xcc, w.dt, w.dj, w.low_period, w.up_period, w.mother, w.beta, w.gamma, w.sig_type, ...
        lowF, upF);

    % Phase-origin calibration (global rotation)
    cal = hs.wavelets.calibrate_phase_origin( ...
        w.dt, w.dj, w.low_period, w.up_period, w.mother, w.beta, w.gamma, w.sig_type, ...
        lowF, upF, ...
        'TestPeriodYears', cfg.phaseCal.testPeriodYears, ...
        'MakePlot', cfg.phaseCal.makePlot);

    phaseX = cal.apply(phaseX);

    % ---------- Pack output ----------
    p_mid = sqrt(lowF * upF);

    out = struct();
    out.bandKey = bkChar;
    out.band = band;
    out.band.p_mid = p_mid;
    out.band.name  = sprintf('%.0f--%.0fy', lowF, upF);

    out.dates  = dates(:);
    out.phaseX = phaseX;
    out.ampX   = ampX;

    % minimal geo provenance (avoid huge polygons)
    out.geo = struct();
    out.geo.colIdx = geo.colIdx;
    if isfield(geo,'codes'); out.geo.codes = geo.codes; end

    out.meta = struct();
    out.meta.dataLabel   = dataLabel;
    out.meta.dataTag     = string(dataTag);
    out.meta.dataSeries  = cfg.data.series;
    if isfield(cfg.data,'nsa_deseason'); out.meta.nsa_deseason = cfg.data.nsa_deseason; end
    out.meta.created     = datetime('now');
    out.meta.cfg_wave    = w;
    out.meta.cfg_phaseCal = cfg.phaseCal;

    save(outMat, 'out', '-v7.3');
    fprintf('Saved: %s (%s; %s)\n', outMat, out.band.name, dataLabel);

    outAll.(bkChar) = out;
end

end