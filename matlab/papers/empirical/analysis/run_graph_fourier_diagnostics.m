function outAll = run_graph_fourier_diagnostics(varargin)
%RUN_GRAPH_FOURIER_DIAGNOSTICS  Graph-Fourier diagnostics of the demeaned phase field.
%
% Pipeline:
%   - Reads phase intermediates produced by run_phase_band_data:
%       cfg.paths.intermediate/phase_<dataTag>_band_<low>_<up>y.mat
%   - Reads Laplacian eigenmodes produced by run_precompute_geo:
%       cfg.outputs.geoMat (expects geo.V, orthonormal eigenmodes)
%
% For each band, with theta_i(t) phases:
%   U_i(t)   = exp(i*theta_i(t))
%   mU(t)    = mean_i U_i(t)
%   r(t)     = |mU(t)|,  phi(t)=arg(mU(t))
%   Urel_i   = U_i * exp(-i*phi(t))    (remove global rotation)
%
% Graph Fourier using Laplacian eigenmodes v_k:
%   a_k(t) = sum_i Urel_i(t) v_k(i)
%   p_k(t) = |a_k(t)|^2
%
% TOTAL dispersion energy (non-uniform energy) is exact from r(t):
%   Etot(t) = N * (1 - r(t)^2)
%
% Diagnostics (relative to TOTAL dispersion Etot unless stated):
%   Sk(t,k)   = p_k(t) / Etot(t)             for k>=2  (share of TOTAL dispersion)
%   qK(t)     = sum_{k=2..Klow} p_k / Etot   (low-mode share of TOTAL)
%   qKuse(t)  = sum_{k=2..Kuse} p_k / Etot   (coverage; ~1 if Kuse spans all modes)
%   deff(t)   = (sum p)^2 / sum p^2 over k=2..Kuse  (effective dimension within used modes)
%
% Config (single source of truth):
%   cfg.graphFourier.Kuse (Inf => use all modes up to N)
%   cfg.graphFourier.Klow
%   cfg.graphFourier.DenomEps
%   cfg.graphFourier.SaveQCumulative
%
% Optional overrides:
%   'WhichBands'        : {'main','long'}
%   'Overwrite'         : false
%   'Kuse'              : [] | int | Inf        (override cfg.graphFourier.Kuse)
%   'Klow'              : [] | int              (override cfg.graphFourier.Klow)
%   'DenomEps'          : [] | scalar           (override cfg.graphFourier.DenomEps)
%   'SaveQCumulative'   : [] | logical          (override cfg.graphFourier.SaveQCumulative)
%
% Saves (one per band):
%   cfg.paths.intermediate/graph_fourier_<dataTag>_<bandTag>_K<Kuse>.mat
%
% Output:
%   outAll.(bandKey) = res struct (also written to disk)

% ---------------- Options ----------------
p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v)iscell(v)||isstring(v));
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));

% Optional overrides (default [] => take from cfg.graphFourier.*)
p.addParameter('Kuse', [], @(x) isempty(x) || (isnumeric(x)&&isscalar(x)&&(x>=3 || isinf(x))));
p.addParameter('Klow', [], @(x) isempty(x) || (isnumeric(x)&&isscalar(x)&&x>=2));
p.addParameter('DenomEps', [], @(x) isempty(x) || (isnumeric(x)&&isscalar(x)&&x>0));
p.addParameter('SaveQCumulative', [], @(b) isempty(b) || (islogical(b)&&isscalar(b)));
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();

% ---------------- Config defaults (single source of truth) ----------------
assert(isfield(cfg,'graphFourier') && isstruct(cfg.graphFourier), ...
    'Missing cfg.graphFourier in config.');

Kuse_req = cfg.graphFourier.Kuse;
Klow_req = cfg.graphFourier.Klow;
DenomEps = cfg.graphFourier.DenomEps;

SaveQCum = false;
if isfield(cfg.graphFourier,'SaveQCumulative')
    SaveQCum = cfg.graphFourier.SaveQCumulative;
end

% Apply overrides
if ~isempty(opt.Kuse),            Kuse_req = opt.Kuse; end
if ~isempty(opt.Klow),            Klow_req = opt.Klow; end
if ~isempty(opt.DenomEps),        DenomEps = opt.DenomEps; end
if ~isempty(opt.SaveQCumulative), SaveQCum = opt.SaveQCumulative; end

% ---------------- Load geo eigenmodes ----------------
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);
G = load(cfg.outputs.geoMat);
assert(isfield(G,'geo'), 'geoMat does not contain variable "geo".');
geo = G.geo;

assert(isfield(geo,'V') && ~isempty(geo.V), ...
    'geo.V missing or empty. Re-run run_precompute_geo with eigenmodes saved.');

V = geo.V;
Ngeo = size(V,1);
Kavail = size(V,2);

% Determine final Kuse
if isinf(Kuse_req), Kuse_req = Ngeo; end
Kuse = min([Kuse_req, Kavail, Ngeo]);

% Determine final Klow
Klow = min(max(2, Klow_req), Kuse);

% If you want full decomposition shares to sum to ~1, you need Kuse==Ngeo.
if Kuse < Ngeo
    warning(['run_graph_fourier_diagnostics: using Kuse=%d < N=%d.\n' ...
             'Sk/qK are shares of TOTAL dispersion, but qKuse(t) will be <1.\n' ...
             'Increase cfg.geo.nModesToSave (>=N) and re-run run_precompute_geo to save all modes.'], ...
             Kuse, Ngeo);
end

% ---------------- Determine dataTag from cfg.data (consistent across pipeline) ----------------
assert(exist(cfg.outputs.processedMat,'file')==2, 'Missing processedMat: %s', cfg.outputs.processedMat);
Sproc = load(cfg.outputs.processedMat);
[~,~,dataLabel] = hs.data.select_hpi_matrix(Sproc, cfg);
dataLabel = string(dataLabel);
dataTag = hs.util.data_tag(dataLabel);

% ---------------- Run per band ----------------
outAll = struct();
bandKeys = string(opt.WhichBands(:)).';

for bk = bandKeys
    assert(isfield(cfg,'bands') && isfield(cfg.bands, bk), ...
        'Unknown band key "%s" (not found in cfg.bands).', bk);

    band = cfg.bands.(bk);
    assert(isfield(band,'lowF') && isfield(band,'upF'), ...
        'cfg.bands.%s must have fields lowF and upF.', bk);

    lowF = band.lowF; upF = band.upF;

    % Canonical band tag (matches run_phase_band_data)
    bandTag = hs.util.band_tag(lowF, upF);   % e.g. "8_10y", "11_14y"

    phaseMat = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_%s_band_%s.mat', dataTag, bandTag));

    assert(exist(phaseMat,'file')==2, ...
        'Missing %s (run run_phase_band_data first).', phaseMat);

    outMat = fullfile(cfg.paths.intermediate, ...
        sprintf('graph_fourier_%s_%s_K%d.mat', dataTag, bandTag, Kuse));

    %{
    % Phase intermediate naming convention must match run_phase_band_data
    bandTagPhase = sprintf('%g_%g', lowF, upF); % e.g. "8_10"
    phaseMat = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_%s_band_%sy.mat', dataTag, bandTagPhase));

    assert(exist(phaseMat,'file')==2, ...
        'Missing %s (run run_phase_band_data first).', phaseMat);

    % Output filename for diagnostics
    bandTagFile = regexprep(sprintf('%.0f-%.0fy', lowF, upF), '[^A-Za-z0-9_-]+', '_');
    outMat = fullfile(cfg.paths.intermediate, ...
        sprintf('graph_fourier_%s_%s_K%d.mat', dataTag, bandTagFile, Kuse));

    %}

    if exist(outMat,'file')==2 && ~opt.Overwrite
        fprintf('Exists (set Overwrite=true): %s\n', outMat);
        tmp = load(outMat);
        if isfield(tmp,'res')
            outAll.(bk) = tmp.res;
        else
            outAll.(bk) = tmp;
        end
        continue;
    end

    % Load phase data
    P = load(phaseMat);
    if isfield(P,'out'); out = P.out; else; out = P; end

    dates = out.dates(:);
    theta = out.phaseX;                 % T x N
    [T,N] = size(theta);

    assert(N == Ngeo, 'phaseX N=%d != geo.V N=%d', N, Ngeo);

    % Kuramoto order parameter from phaseX (single source of truth)
    [r, phi] = hs.phase.kuramoto_r(theta);

    % Demean by global rotation
    U    = exp(1i*theta);               % T x N
    Urel = U .* exp(-1i*phi);           % T x N

    % Graph-Fourier coefficients (T x Kuse)
    Acoef = Urel * V(:,1:Kuse);
    Pk    = abs(Acoef).^2;              % T x Kuse

    % TOTAL dispersion energy is exact from r(t)
    Etot = N * (1 - r.^2);              % T x 1
    etot = 1 - r.^2;                    % per-node (0..1)

    % Denominator guard
    denomTot = Etot;
    denomTot(denomTot < DenomEps) = NaN;

    % Shares of TOTAL dispersion by mode (k>=2)
    Sk = NaN(T, Kuse);
    Sk(:,2:Kuse) = Pk(:,2:Kuse) ./ denomTot;

    % Low-mode share of TOTAL dispersion (2..Klow)
    Elow = sum(Pk(:,2:Klow), 2);
    qK   = Elow ./ denomTot;

    % Coverage: share of TOTAL dispersion captured by modes 2..Kuse
    Esp  = sum(Pk(:,2:Kuse), 2);
    qKuse = Esp ./ denomTot;

    % Effective dimension within used spatial subspace (2..Kuse)
    Psp  = Pk(:,2:Kuse);
    deff = (sum(Psp,2)).^2 ./ sum(Psp.^2, 2);

    % Optional cumulative shares up to each mode (2..Kuse)
    if SaveQCum
        Pcum = cumsum(Pk(:,2:Kuse), 2);        % T x (Kuse-1)
        qCum = Pcum ./ denomTot;               % T x (Kuse-1)
        qCum_k = 2:Kuse;
    else
        qCum = [];
        qCum_k = [];
    end

    % Quality checks
    Eproj = sum(Pk(:,1:Kuse), 2); % with Kuse==N and V orthonormal, should be ~N always
    qc = struct();
    qc.Eproj_mean = mean(Eproj,'omitnan');
    qc.Eproj_maxabs_from_N = max(abs(Eproj - N), [], 'omitnan');
    qc.qKuse_mean = mean(qKuse,'omitnan');

    % When dispersion ~0, qK/qKuse/Sk are NaN already via denomTot; also guard deff
    small = Etot < DenomEps;
    deff(small) = NaN;

    % ---------------- Pack results ----------------
    res = struct();
    res.bandKey   = char(bk);
    res.band      = band;

    res.dataLabel = dataLabel;
    res.dataTag   = dataTag;

    res.dates     = dates;
    res.N         = N;
    res.Kuse      = Kuse;
    res.Klow      = Klow;

    % Global synchrony
    res.r   = r;
    res.phi = phi;

    % Graph Fourier
    res.Acoef = Acoef;
    res.Pk    = Pk;

    % Energies
    res.Etot = Etot;
    res.etot = etot;
    res.Esp  = Esp;
    res.Elow = Elow;

    % Shares of TOTAL dispersion
    res.Sk   = Sk;     % Sk(:,k) is share of TOTAL dispersion in mode k (k>=2)
    res.qK   = qK;     % share of TOTAL dispersion in modes 2..Klow
    res.qKuse = qKuse; % share of TOTAL dispersion captured by modes 2..Kuse

    % Dimensionality
    res.deff = deff;

    % Optional cumulative curves
    if SaveQCum
        res.qCum   = qCum;
        res.qCum_k = qCum_k;
    end

    res.qc = qc;

    res.meta = struct( ...
        'created', datetime('now'), ...
        'DenomEps', DenomEps, ...
        'Kuse_req', Kuse_req, ...
        'Klow_req', Klow_req, ...
        'Kavail', Kavail, ...
        'SaveQCumulative', SaveQCum, ...
        'phaseMat', phaseMat);

    % Save
    save(outMat, 'res', '-v7.3');
    fprintf('Saved: %s\n', outMat);

    outAll.(bk) = res;
end
end