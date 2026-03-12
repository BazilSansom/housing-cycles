function run_neighbor_coherence_band_data(varargin)
%RUN_NEIGHBOR_COHERENCE_BAND_DATA
% Compute/save neighbor phase coherence relative to a permutation null.
%
% Reads:
%   outputs/intermediate/phase_<dataTag>_band_<bandTag>.mat
%   cfg.outputs.geoMat
%
% Writes:
%   outputs/intermediate/neighbor_coherence_<dataTag>_band_<bandTag>.mat
%
% For each date t:
%   edgeCoherence(t) = mean_{(i,j) in E} cos(theta_i(t)-theta_j(t))
%
% Null:
%   Randomly permute node labels of theta(t), keeping graph edges fixed.
%   This tests whether neighboring states are more phase-aligned than would
%   be expected under a random relabeling of the same phase field.
%
% Saved outputs include:
%   edgeCoherence, nullMean, nullStd, zEdge, pHigh, pLow, edgeCount

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v) iscell(v) || isstring(v));
p.addParameter('Nperm', 500, @(x) isnumeric(x) && isscalar(x) && x >= 10);
p.addParameter('RandomSeed', 1, @(x) isnumeric(x) && isscalar(x));
p.addParameter('Overwrite', false, @(b) islogical(b) && isscalar(b));
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();

if ~exist(cfg.paths.intermediate, 'dir')
    mkdir(cfg.paths.intermediate);
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

assert(isfield(geo,'A') && ~isempty(geo.A), ...
    'geo.A missing or empty. Re-run run_precompute_geo.');

A = geo.A;
assert(size(A,1) == size(A,2), 'geo.A must be square.');

% Use undirected edge list from upper triangle
A = double(A ~= 0);
A = triu(A, 1);
[ii, jj] = find(A);
nEdges = numel(ii);
assert(nEdges > 0, 'No edges found in geo.A.');

rng(opt.RandomSeed);

bandKeys = string(opt.WhichBands(:)).';
for bk = bandKeys
    assert(isfield(cfg.bands, bk), 'Unknown band key: %s', bk);

    bcfg = cfg.bands.(bk);
    lowF = bcfg.lowF;
    upF  = bcfg.upF;

    bandTag = hs.util.band_tag(lowF, upF);

    inMat = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_%s_band_%s.mat', dataTag, bandTag));

    outMat = fullfile(cfg.paths.intermediate, ...
        sprintf('neighbor_coherence_%s_band_%s.mat', dataTag, bandTag));

    if exist(outMat, 'file') == 2 && ~opt.Overwrite
        fprintf('Exists (set Overwrite=true): %s\n', outMat);
        continue;
    end

    assert(exist(inMat,'file')==2, ...
        'Missing %s (run run_phase_band_data first).', inMat);

    tmp = load(inMat);
    assert(isfield(tmp,'out'), 'Expected variable `out` in %s.', inMat);
    out = tmp.out;

    assert(isfield(out,'dates') && isfield(out,'phaseX'), ...
        'Phase intermediate missing out.dates/out.phaseX: %s', inMat);

    dates  = out.dates(:);
    phaseX = out.phaseX;
    [T, N] = size(phaseX);

    assert(N == size(geo.A,1), ...
        'phaseX has %d columns but geo.A is %d x %d.', N, size(geo.A,1), size(geo.A,2));

    edgeCoherence = nan(T,1);
    nullMean      = nan(T,1);
    nullStd       = nan(T,1);
    zEdge         = nan(T,1);
    pHigh         = nan(T,1);   % observed > null
    pLow          = nan(T,1);   % observed < null

    for t = 1:T
        th = phaseX(t,:).';

        % Observed edge coherence
        dObs = th(ii) - th(jj);
        cObs = mean(cos(dObs), 'omitnan');
        edgeCoherence(t) = cObs;

        % Permutation null
        cNull = nan(opt.Nperm,1);
        for b = 1:opt.Nperm
            perm = randperm(N);
            thp = th(perm);
            dPerm = thp(ii) - thp(jj);
            cNull(b) = mean(cos(dPerm), 'omitnan');
        end

        mu0 = mean(cNull, 'omitnan');
        sd0 = std(cNull, 0, 'omitnan');

        nullMean(t) = mu0;
        nullStd(t)  = sd0;

        if isfinite(sd0) && sd0 > 0
            zEdge(t) = (cObs - mu0) / sd0;
        end

        pHigh(t) = (1 + sum(cNull >= cObs)) / (opt.Nperm + 1);
        pLow(t)  = (1 + sum(cNull <= cObs)) / (opt.Nperm + 1);
    end

    % Convenience excess measures
    edgeExcess = edgeCoherence - nullMean;

    res = struct();
    res.dates = dates;
    res.dataLabel = dataLabelStr;
    res.dataTag = dataTag;
    res.band = [lowF, upF];
    res.bandTag = bandTag;

    res.edgeCount = nEdges;
    res.N = N;
    res.T = T;
    res.Nperm = opt.Nperm;
    res.randomSeed = opt.RandomSeed;

    res.edgeCoherence = edgeCoherence;
    res.nullMean = nullMean;
    res.nullStd = nullStd;
    res.edgeExcess = edgeExcess;
    res.zEdge = zEdge;
    res.pHigh = pHigh;
    res.pLow = pLow;

    res.meta = struct();
    res.meta.sourcePhaseFile = inMat;
    res.meta.runner = mfilename;
    res.meta.bandKey = char(bk);

    save(outMat, 'res', '-v7.3');

    fprintf('\nNeighbor coherence [%s, %s]:\n', bandTag, dataLabelStr);
    fprintf('  median edge coherence: %.3f\n', median(edgeCoherence, 'omitnan'));
    fprintf('  median null mean:      %.3f\n', median(nullMean, 'omitnan'));
    fprintf('  median excess:         %.3f\n', median(edgeExcess, 'omitnan'));
    fprintf('  median zEdge:          %.3f\n', median(zEdge, 'omitnan'));
    fprintf('  frac pHigh < 0.05:     %.3f\n', mean(pHigh < 0.05, 'omitnan'));
    fprintf('Saved: %s\n', outMat);
end
end