function run_phase_gradient_band_data(varargin)
%RUN_PHASE_GRADIENT_BAND_DATA  Compute/save v2-gradient diagnostics from saved phase intermediates.
%
% Reads:
%   outputs/intermediate/phase_<dataTag>_band_<bandTag>.mat
%
% Writes:
%   outputs/intermediate/phase_gradient_<dataTag>_band_<bandTag>.mat
%
% Each saved file contains a struct `res` with:
%   dates, phaseX, ampX
%   r, phi
%   v2, v2z, dz_90_10
%   A, beta, fit
%   monthsPerRad, dt_1sigma, dt_90_10, useYears
%   dataLabel, dataTag, band, bandTag, geo, meta
%
% Notes
%   - phaseX is loaded from the authoritative phase intermediates produced by
%     run_phase_band_data.
%   - r(t) is recomputed downstream from phaseX using hs.phase.kuramoto_r.
%   - beta(t) is interpreted as radians per 1 sd of v2 via StandardizeX=true.

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v) iscell(v) || isstring(v));
p.addParameter('Overwrite', false, @(b) islogical(b) && isscalar(b));
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();

if ~exist(cfg.paths.intermediate, 'dir')
    mkdir(cfg.paths.intermediate);
end

% -------------------------------------------------------------------------
% Determine current data label/tag from the configured processed dataset
% -------------------------------------------------------------------------
Sproc = load(cfg.outputs.processedMat);
[~,~,dataLabel] = hs.data.select_hpi_matrix(Sproc, cfg);
dataTag = hs.util.data_tag(dataLabel);
dataLabelStr = char(string(dataLabel));

bandKeys = string(opt.WhichBands(:)).';
for bk = bandKeys
    assert(isfield(cfg.bands, bk), 'Unknown band key: %s', bk);

    bcfg = cfg.bands.(bk);
    lowF = bcfg.lowF;
    upF  = bcfg.upF;

    %bandTag = band_tag_(lowF, upF);
    bandTag = hs.util.band_tag(lowF, upF);

    inMat = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_%s_band_%s.mat', dataTag, bandTag));

    outMat = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_gradient_%s_band_%s.mat', dataTag, bandTag));

    if exist(outMat, 'file') == 2 && ~opt.Overwrite
        fprintf('Exists (set Overwrite=true): %s\n', outMat);
        continue;
    end

    assert(exist(inMat, 'file') == 2, ...
        'Missing %s (run run_phase_band_data first).', inMat);

    tmp = load(inMat);
    assert(isfield(tmp, 'out'), 'Expected variable `out` in %s.', inMat);
    out = tmp.out;

    assert(isfield(out, 'dates') && isfield(out, 'phaseX'), ...
        'Phase intermediate missing out.dates/out.phaseX: %s', inMat);

    dates  = out.dates(:);
    phaseX = out.phaseX;
    if isfield(out, 'ampX')
        ampX = out.ampX;
    else
        ampX = [];
    end


    % ---------------------------------------------------------------------
    % Load geo from authoritative geoMat
    % ---------------------------------------------------------------------
    assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);
    G = load(cfg.outputs.geoMat);
    assert(isfield(G,'geo'), 'geoMat does not contain variable "geo".');
    geo = G.geo;

    assert(isfield(geo,'V') && ~isempty(geo.V), ...
        'geo.V missing or empty. Re-run run_precompute_geo with eigenmodes saved.');

    assert(size(geo.V,2) >= 2, ...
        'geo.V must contain at least two modes (including constant mode).');

    v2 = geo.V(:,2);   % authoritative Fiedler mode (raw)

   
    N  = numel(v2);
    [T, Ntheta] = size(phaseX);
    assert(Ntheta == N, ...
        'phaseX has %d columns but geo.v2 has length %d.', Ntheta, N);

    mu = mean(v2, 'omitnan');
    sd = std(v2, 0, 'omitnan');
    assert(isfinite(sd) && sd > 0, 'geo.v2 has zero or invalid standard deviation.');

    v2z = (v2 - mu) ./ sd;                    % standardised v2 for reporting
    dz_90_10 = prctile(v2z, 90) - prctile(v2z, 10);

    % ---------------------------------------------------------------------
    % Global synchrony from authoritative phaseX
    % ---------------------------------------------------------------------
    [r, phi] = hs.phase.kuramoto_r(phaseX);
    r   = r(:);
    phi = phi(:);

    % ---------------------------------------------------------------------
    % Mean-field-free fit of phase gradient onto v2
    % beta(t) is radians per 1 sd of v2 because StandardizeX=true
    % ---------------------------------------------------------------------
    fit = hs.spatial.fit_phase_gradient(phaseX, v2, ...
        'StandardizeX', true, ...
        'BetaRange', cfg.fig.betaRange, ...
        'BetaGridN', cfg.fig.betaGridN, ...
        'Refine', true);

    assert(isfield(fit, 'A') && isfield(fit, 'beta'), ...
        'fit_phase_gradient output missing A/beta.');

    A    = fit.A(:);
    beta = fit.beta(:);

    assert(numel(A) == T && numel(beta) == T, ...
        'fit outputs have wrong length relative to dates/phaseX.');

    % ---------------------------------------------------------------------
    % Interpret beta as implied lead-lag scale
    % Use geometric-mean period of the band
    % ---------------------------------------------------------------------
    pEffYears   = sqrt(lowF * upF);
    monthsPerRad = (12 * pEffYears) / (2*pi);

    dt_1sigma = monthsPerRad * beta;          % months per 1 sd of v2
    dt_90_10  = dz_90_10 * dt_1sigma;         % months across robust 90-10 spread

    bandMeanY = 0.5 * (lowF + upF);
    useYears  = (bandMeanY >= 11);

    % ---------------------------------------------------------------------
    % Optional concise console summary
    % ---------------------------------------------------------------------
    medAbsDt1sigma = median(abs(dt_1sigma), 'omitnan');
    maxAbsDt1sigma = max(abs(dt_1sigma), [], 'omitnan');
    medAbsDt9010   = median(abs(dt_90_10), 'omitnan');
    maxAbsDt9010   = max(abs(dt_90_10), [], 'omitnan');

    fprintf('\nBand %s (%g-%gy), %s:\n', bandTag, lowF, upF, dataLabelStr);
    fprintf('  v2 spread (90-10): %.2f sd\n', dz_90_10);
    fprintf('  median |Δt_1σ|:    %s\n', fmt_duration_(medAbsDt1sigma, useYears));
    fprintf('  max |Δt_1σ|:       %s\n', fmt_duration_(maxAbsDt1sigma, useYears));
    fprintf('  median |Δt_90-10|: %s\n', fmt_duration_(medAbsDt9010, useYears));
    fprintf('  max |Δt_90-10|:    %s\n', fmt_duration_(maxAbsDt9010, useYears));

    % ---------------------------------------------------------------------
    % Save result
    % ---------------------------------------------------------------------
    res = struct();

    res.dates   = dates;
    res.phaseX  = phaseX;
    res.ampX    = ampX;

    res.r       = r;
    res.phi     = phi;

    res.v2      = v2;
    res.v2z     = v2z;
    res.dz_90_10 = dz_90_10;

    res.A       = A;
    res.beta    = beta;
    res.fit     = fit;

    res.monthsPerRad = monthsPerRad;
    res.dt_1sigma    = dt_1sigma;
    res.dt_90_10     = dt_90_10;
    res.useYears     = useYears;

    res.N        = N;
    res.T        = T;
    res.band     = [lowF, upF];
    res.bandTag  = bandTag;

    res.dataLabel = dataLabelStr;
    res.dataTag   = dataTag;

    res.geo      = geo;

    % Preserve upstream meta if present, and add lightweight provenance
    if isfield(out, 'meta')
        res.meta = out.meta;
    else
        res.meta = struct();
    end
    res.meta.sourcePhaseFile = inMat;
    res.meta.runner          = mfilename;
    res.meta.bandKey         = char(bk);
    res.meta.lowF            = lowF;
    res.meta.upF             = upF;
    res.meta.pEffYears       = pEffYears;

    save(outMat, 'res', '-v7.3');
    fprintf('Saved: %s\n', outMat);
end

end


% =========================================================================
function s = fmt_duration_(months, useYears)
%FMT_DURATION_  Pretty duration string from months.
if ~isfinite(months)
    s = 'NaN';
    return;
end

if useYears
    s = sprintf('%.2f years (%.2f months)', months/12, months);
else
    s = sprintf('%.2f months', months);
end
end