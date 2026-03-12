function run_graph_fourier_topm_band_data(varargin)
%RUN_GRAPH_FOURIER_TOPM_BAND_DATA
% Compute/save top-M modal concentration diagnostics from graph-Fourier outputs.
%
% Reads:
%   outputs/intermediate/graph_fourier_<dataTag>_<bandTag>_K<Kuse>.mat
%
% Writes:
%   outputs/intermediate/graph_fourier_topm_<dataTag>_<bandTag>_K<Kuse>.mat
%
% For each date t and each M in Mlist, computes:
%   qLowM(t) = sum of shares in the first M non-constant modes
%            = sum_{k=2}^{M+1} s_k(t)
%
%   qTopM(t) = sum of the largest M modal shares across all non-constant modes
%
% Interpretation:
%   - qLowM ~ qTopM and both high  => smooth / low-mode structure
%   - qTopM >> qLowM               => low-dimensional but not smooth
%   - both low                     => more diffuse / higher-dimensional
%
% Also saves:
%   - dominant mode index kStar(t)
%   - dominant mode share sStar(t)
%   - sorted top-mode indices/shares
%   - summary table across chosen M values

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v) iscell(v) || isstring(v));
p.addParameter('Mlist', [1 2 3 5], @(v) isnumeric(v) && isvector(v) && ...
    all(v >= 1) && all(abs(v - round(v)) < 1e-12));
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
% Determine Kuse used in graph_fourier filename
% -------------------------------------------------------------------------
assert(exist(cfg.outputs.geoMat,'file')==2, 'Missing geoMat: %s', cfg.outputs.geoMat);
G = load(cfg.outputs.geoMat);
assert(isfield(G,'geo'), 'geoMat does not contain variable "geo".');
geo = G.geo;

assert(isfield(geo,'V') && ~isempty(geo.V), ...
    'geo.V missing or empty. Re-run run_precompute_geo with eigenmodes saved.');

Kmax = size(geo.V, 2);
if isinf(cfg.graphFourier.Kuse)
    Kfile = Kmax;
else
    Kfile = min(cfg.graphFourier.Kuse, Kmax);
end

Mlist = unique(sort(round(opt.Mlist(:).')));
bandKeys = string(opt.WhichBands(:)).';

for bk = bandKeys
    assert(isfield(cfg.bands, bk), 'Unknown band key: %s', bk);

    bcfg = cfg.bands.(bk);
    lowF = bcfg.lowF;
    upF  = bcfg.upF;

    bandTag = hs.util.band_tag(lowF, upF);

    inMat = fullfile(cfg.paths.intermediate, ...
        sprintf('graph_fourier_%s_%s_K%d.mat', dataTag, bandTag, Kfile));

    outMat = fullfile(cfg.paths.intermediate, ...
        sprintf('graph_fourier_topm_%s_%s_K%d.mat', dataTag, bandTag, Kfile));

    if exist(outMat, 'file') == 2 && ~opt.Overwrite
        fprintf('Exists (set Overwrite=true): %s\n', outMat);
        continue;
    end

    assert(exist(inMat, 'file') == 2, ...
        'Missing %s (run run_graph_fourier_diagnostics first).', inMat);

    tmp = load(inMat);
    assert(isfield(tmp,'res'), 'Expected variable `res` in %s.', inMat);
    res = tmp.res;

    % ---------------------------------------------------------------------
    % Required fields
    % ---------------------------------------------------------------------
    req = {'dates','Sk','Kuse','Klow'};
    for i = 1:numel(req)
        assert(isfield(res, req{i}), 'res missing field `%s` in %s.', req{i}, inMat);
    end

    dates = res.dates(:);
    Sk    = res.Sk;
    Kuse  = res.Kuse;
    Klow  = res.Klow;

    assert(Kuse >= 2, 'Need at least one non-constant mode (Kuse >= 2).');
    assert(size(Sk,2) >= Kuse, 'res.Sk has fewer columns than res.Kuse.');

    T = numel(dates);
    nModes = Kuse - 1;   % non-constant modes are k = 2..Kuse
    maxM = max(Mlist);

    if maxM > nModes
        warning('Requested max(Mlist)=%d exceeds available non-constant modes=%d. Clipping.', ...
            maxM, nModes);
        Mlist = Mlist(Mlist <= nModes);
        maxM = max(Mlist);
    end

    % ---------------------------------------------------------------------
    % Modal shares of TOTAL dispersion over non-constant modes only
    % Columns correspond to graph modes k = 2..Kuse
    % ---------------------------------------------------------------------
    modalShares = Sk(:, 2:Kuse);
    modalShares = max(modalShares, 0);   % small numerical guard

    % qKall / closure
    if isfield(res, 'qKall')
        qKall = res.qKall(:);
    elseif isfield(res, 'qKuse')
        qKall = res.qKuse(:);    % legacy name
    else
        qKall = sum(modalShares, 2, 'omitnan');
    end

    % ---------------------------------------------------------------------
    % Low-M cumulative shares: first M non-constant modes
    % ---------------------------------------------------------------------
    qLowCum = cumsum(modalShares(:, 1:maxM), 2);

    % ---------------------------------------------------------------------
    % Top-M cumulative shares: best M modes regardless of order
    % ---------------------------------------------------------------------
    [topSharesSorted, topOrdRel] = sort(modalShares, 2, 'descend');
    topOrdAbs = topOrdRel + 1;   % convert back to actual graph mode index

    qTopCum = cumsum(topSharesSorted(:, 1:maxM), 2);

    % ---------------------------------------------------------------------
    % Extract requested M values
    % ---------------------------------------------------------------------
    nM = numel(Mlist);
    qLowM = nan(T, nM);
    qTopM = nan(T, nM);
    qGap  = nan(T, nM);    % qTopM - qLowM

    for j = 1:nM
        M = Mlist(j);
        qLowM(:,j) = qLowCum(:,M);
        qTopM(:,j) = qTopCum(:,M);
        qGap(:,j)  = qTopM(:,j) - qLowM(:,j);
    end

    % Dominant mode and its share
    kStar = topOrdAbs(:,1);
    sStar = topSharesSorted(:,1);

    % Fraction of dates where the single dominant mode lies among low modes
    fracDominantInLow = mean(kStar <= Klow, 'omitnan');

    % ---------------------------------------------------------------------
    % Summary table
    % ---------------------------------------------------------------------
    summary = table( ...
        Mlist(:), ...
        median(qLowM,  1, 'omitnan')', ...
        median(qTopM,  1, 'omitnan')', ...
        median(qGap,   1, 'omitnan')', ...
        mean(qLowM,    1, 'omitnan')', ...
        mean(qTopM,    1, 'omitnan')', ...
        mean(qGap,     1, 'omitnan')', ...
        'VariableNames', { ...
            'M', ...
            'median_qLowM', ...
            'median_qTopM', ...
            'median_gap_top_minus_low', ...
            'mean_qLowM', ...
            'mean_qTopM', ...
            'mean_gap_top_minus_low'});

    % ---------------------------------------------------------------------
    % Pack and save
    % ---------------------------------------------------------------------
    topm = struct();

    topm.dates   = dates;
    topm.dataLabel = dataLabelStr;
    topm.dataTag   = dataTag;

    topm.band    = [lowF, upF];
    topm.bandTag = bandTag;

    topm.Kuse    = Kuse;
    topm.Klow    = Klow;
    topm.nModes  = nModes;

    topm.Mlist   = Mlist;
    topm.qLowM   = qLowM;
    topm.qTopM   = qTopM;
    topm.qGap    = qGap;

    topm.qKall   = qKall;

    topm.kStar   = kStar;
    topm.sStar   = sStar;

    % Save top modes/shares up to maxM for later plotting / inspection
    topm.topModes  = topOrdAbs(:, 1:maxM);
    topm.topShares = topSharesSorted(:, 1:maxM);

    topm.fracDominantInLow = fracDominantInLow;
    topm.summary = summary;

    topm.meta = struct();
    topm.meta.sourceGraphFourierFile = inMat;
    topm.meta.runner = mfilename;
    topm.meta.bandKey = char(bk);

    save(outMat, 'topm', '-v7.3');

    % ---------------------------------------------------------------------
    % Console summary
    % ---------------------------------------------------------------------
    fprintf('\nTop-M modal concentration [%s, %s]:\n', bandTag, dataLabelStr);
    fprintf('  max |qKall - 1|: %.3g\n', max(abs(qKall - 1), [], 'omitnan'));
    fprintf('  frac dominant mode in low set (k <= %d): %.3f\n', Klow, fracDominantInLow);

    for j = 1:nM
        fprintf('  M=%d: median qLowM = %.3f, median qTopM = %.3f, median gap = %.3f\n', ...
            Mlist(j), ...
            summary.median_qLowM(j), ...
            summary.median_qTopM(j), ...
            summary.median_gap_top_minus_low(j));
    end

    fprintf('Saved: %s\n', outMat);
end
end