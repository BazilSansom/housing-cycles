function make_fig_graph_fourier_band(varargin)
%MAKE_FIG_GRAPH_FOURIER_BAND  Paper figure: Graph-Fourier spatial diagnostics.
%
% Reads:
%   outputs/intermediate/graph_fourier_<dataTag>_<bandTag>_K<Kuse>.mat
%
% Writes:
%   outputs/figures/Fig_graph_fourier_<bandTag>_<dataTag>.pdf/.png
%
% Conventions:
%   - Paper-facing convention is "share of TOTAL dispersion".
%   - Diagnostics file is assumed to have been produced using the configured
%     full-spectrum choice of Kuse (typically all available modes).
%   - Panel B therefore shows selected modal shares s_k(t) = P_k / E_tot,
%     plus "other modes" = 1 - sum(selected shares).
%
% Panels:
%   A: Total phase dispersion e_tot = 1-r^2, low-mode dispersion e_low,
%      and residual dispersion e_hi
%   B: Selected graph-Fourier mode shares of TOTAL dispersion + other modes
%   C: q_K(t), optional q_Kall(t) diagnostic, and d_eff(t)

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v) iscell(v) || isstring(v));
p.addParameter('ShowShares', [], @(v) isempty(v) || (isnumeric(v) && isvector(v)));
p.addParameter('ShowQKall', true, @(b) islogical(b) && isscalar(b));
p.addParameter('Overwrite', false, @(b) islogical(b) && isscalar(b));
p.addParameter('YearTickStep', 5, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();
if ~exist(cfg.paths.figures, 'dir')
    mkdir(cfg.paths.figures);
end

if isempty(opt.ShowShares)
    opt.ShowShares = cfg.graphFourier.ShowShares;
end

% -------------------------------------------------------------------------
% Data label / safe tag for filenames
% -------------------------------------------------------------------------
Sproc = load(cfg.outputs.processedMat);
[~,~,dataLabel] = hs.data.select_hpi_matrix(Sproc, cfg);
dataTag = hs.util.data_tag(dataLabel);          % safe filename tag, e.g. nsa_yoy
dataLabelStr = char(string(dataLabel));         % human-readable label for titles

% -------------------------------------------------------------------------
% Determine the Kuse used in the diagnostics filename
% (paper convention: use configured/full-spectrum diagnostics)
% -------------------------------------------------------------------------
G = load(cfg.outputs.geoMat);
Kmax = size(G.geo.V, 2);

if isinf(cfg.graphFourier.Kuse)
    Kfile = Kmax;
else
    Kfile = min(cfg.graphFourier.Kuse, Kmax);
end

bandKeys = string(opt.WhichBands(:)).';
for bk = bandKeys
    band = cfg.bands.(bk);
    lowF = band.lowF;
    upF  = band.upF;

    bandTagPretty = sprintf('%.0f--%.0fy', lowF, upF);
    %bandTagFile   = regexprep(sprintf('%.0f-%.0fy', lowF, upF), '[^A-Za-z0-9_-]+', '_');
    bandTag = hs.util.band_tag(lowF, upF);

    inMat = fullfile(cfg.paths.intermediate, ...
        sprintf('graph_fourier_%s_%s_K%d.mat', dataTag, bandTag, Kfile));
    assert(exist(inMat, 'file') == 2, ...
        'Missing %s (run run_graph_fourier_diagnostics first).', inMat);

    tmp = load(inMat);
    res = tmp.res;

    % ---------------------------------------------------------------------
    % Required fields
    % ---------------------------------------------------------------------
    assert(isfield(res,'dates') && isfield(res,'r') && ...
           isfield(res,'qK')    && isfield(res,'Sk') && ...
           isfield(res,'deff')  && isfield(res,'Klow') && isfield(res,'Kuse'), ...
        ['res missing one or more required fields: dates/r/qK/Sk/deff/' ...
         'Klow/Kuse. Re-run run_graph_fourier_diagnostics.']);

    dates = res.dates;
    r     = res.r(:);
    qK    = res.qK(:);
    Sk    = res.Sk;
    deff  = res.deff(:);
    Klow  = res.Klow;
    Kuse  = res.Kuse;

    % Total per-node dispersion
    if isfield(res, 'etot')
        etot = res.etot(:);   % should equal 1-r.^2
    else
        etot = 1 - r.^2;
    end

    % Low-mode / residual decomposition (all as shares of total dispersion)
    eLow = qK .* etot;
    eHi  = max(etot - eLow, 0);

    % ---------------------------------------------------------------------
    % qKall diagnostic: should be ~1 if all non-uniform modes are included
    % Prefer renamed field qKall if present; otherwise accept legacy qKuse.
    % Fallback: reconstruct from Sk.
    % ---------------------------------------------------------------------
    if isfield(res, 'qKall')
        qKall = res.qKall(:);
    elseif isfield(res, 'qKuse')
        qKall = res.qKuse(:);   % legacy name
    else
        % Sk is assumed to be share of TOTAL dispersion
        if size(Sk,2) >= 2
            qKall = sum(Sk(:,2:end), 2, 'omitnan');
        else
            qKall = zeros(size(qK));
        end
    end

    qKallErr = max(abs(qKall - 1), [], 'omitnan');
    fprintf('Graph Fourier QC [%s, %s]: max|qKall - 1| = %.3g\n', ...
        bandTag, dataTag, qKallErr);

    % ---------------------------------------------------------------------
    % Modal shares to display
    % ---------------------------------------------------------------------
    showK = opt.ShowShares(:).';
    showK = showK(showK >= 2 & showK <= Kuse);

    if isempty(showK)
        showK = 2:min(5, Kuse);
        warning('No valid ShowShares remained after clipping; using %s.', mat2str(showK));
    end

    others = 1 - sum(Sk(:, showK), 2, 'omitnan');
    others = max(min(others, 1), 0);   % numerical guard

    % ---------------------------------------------------------------------
    % Figure
    % ---------------------------------------------------------------------
    fig = figure('Color', 'w', 'Position', [100 100 1100 860]);
    tl = tiledlayout(fig, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

    % =======================
    % Panel A
    % =======================
    ax1 = nexttile(tl, 1);
    hold(ax1, 'on');
    plot(ax1, dates, etot, 'LineWidth', 1.3, ...
        'DisplayName', 'Total dispersion $1-r(t)^2$');
    plot(ax1, dates, eLow, 'LineWidth', 1.3, ...
        'DisplayName', sprintf('Low-mode dispersion (modes 2..%d)', Klow));
    plot(ax1, dates, eHi, '--', 'LineWidth', 1.1, ...
        'DisplayName', 'Residual dispersion');
    hold(ax1, 'off');

    grid(ax1, 'on');
    ax1.Box = 'on';
    ax1.Layer = 'top';
    ylim(ax1, [0 1]);
    ylabel(ax1, 'per-node energy');
    title(ax1, sprintf('A. Phase dispersion: total vs low-mode spatial component (%s, %s)', ...
        bandTagPretty, dataLabelStr));
    legend(ax1, 'Interpreter', 'latex', 'Location', 'best');
    set_year_ticks_(ax1, dates, opt.YearTickStep);

    % =======================
    % Panel B
    % =======================
    ax2 = nexttile(tl, 2);
    hold(ax2, 'on');
    for k = showK
        plot(ax2, dates, Sk(:,k), 'LineWidth', 1.2, ...
            'DisplayName', sprintf('$s_{%d}(t)$', k));
    end
    plot(ax2, dates, others, 'k--', 'LineWidth', 1.1, ...
        'DisplayName', 'other modes');
    hold(ax2, 'off');

    grid(ax2, 'on');
    ax2.Box = 'on';
    ax2.Layer = 'top';
    ylim(ax2, [0 1]);
    ylabel(ax2, 'share of total dispersion');
    title(ax2, 'B. Selected graph-Fourier mode shares of total dispersion');
    legend(ax2, 'Interpreter', 'latex', 'Location', 'best');
    set_year_ticks_(ax2, dates, opt.YearTickStep);

    % =======================
    % Panel C
    % =======================
    ax3 = nexttile(tl, 3);

    yyaxis(ax3, 'left');
    hQK = plot(ax3, dates, qK, 'LineWidth', 1.3, ...
        'DisplayName', sprintf('$q_{%d}(t)$', Klow));
    ylim(ax3, [0 1.05]);
    ylabel(ax3, sprintf('$q_{%d}(t)$', Klow), 'Interpreter', 'latex');

    hold(ax3, 'on');
    if opt.ShowQKall
        hQKall = plot(ax3, dates, qKall, '--', 'LineWidth', 1.0, ...
            'DisplayName', '$q_{K,\mathrm{all}}(t)$');
    else
        hQKall = gobjects(0);
    end

    yyaxis(ax3, 'right');
    hDeff = plot(ax3, dates, deff, 'LineWidth', 1.3, ...
        'DisplayName', '$d_{\mathrm{eff}}(t)$');
    ylabel(ax3, '$d_{\mathrm{eff}}(t)$', 'Interpreter', 'latex');

    grid(ax3, 'on');
    ax3.Box = 'on';
    ax3.Layer = 'top';
    xlabel(ax3, 'Date');

    if opt.ShowQKall
        title(ax3, sprintf('\\bf C. Smooth-dispersion share q_{%d}(t), q_{all}(t), and effective dimension', Klow), ...
            'Interpreter', 'tex');
        legend(ax3, [hQK, hQKall, hDeff], ...
            {'$q_{K}(t)$', '$q_{K,\mathrm{all}}(t)$', '$d_{\mathrm{eff}}(t)$'}, ...
            'Interpreter', 'latex', 'Location', 'best');
    else
        title(ax3, sprintf('\\bf C. Smooth-dispersion share q_{%d}(t) and effective dimension', Klow), ...
            'Interpreter', 'tex');
        legend(ax3, [hQK, hDeff], ...
            {sprintf('$q_{%d}(t)$', Klow), '$d_{\mathrm{eff}}(t)$'}, ...
            'Interpreter', 'latex', 'Location', 'best');
    end
    hold(ax3, 'off');

    set_year_ticks_(ax3, dates, opt.YearTickStep);

    sgtitle(fig, sprintf('Graph-Fourier diagnostics of demeaned phase field (%s band; %s)', ...
        bandTagPretty, dataLabelStr));

    % ---------------------------------------------------------------------
    % Export
    % ---------------------------------------------------------------------

    outPdf = fullfile(cfg.paths.figures, ...
        sprintf('Fig_graph_fourier_%s_%s.pdf', bandTag, dataTag));
    outPng = fullfile(cfg.paths.figures, ...
        sprintf('Fig_graph_fourier_%s_%s.png', bandTag, dataTag));

    if exist(outPdf, 'file') == 2 && ~opt.Overwrite
        fprintf('Exists (set Overwrite=true): %s\n', outPdf);
        close(fig);
        continue;
    end

    exportgraphics(fig, outPdf, 'ContentType', 'vector');
    exportgraphics(fig, outPng, 'Resolution', cfg.fig.dpi);
    close(fig);

    fprintf('Saved:\n  %s\n  %s\n', outPdf, outPng);
end
end

% -------------------------------------------------------------------------
function set_year_ticks_(ax, dates, stepYears)
ax.XLim = [dates(1) dates(end)];
y0 = year(dateshift(dates(1), 'start', 'year'));
y1 = year(dateshift(dates(end), 'start', 'year'));
yt = y0:stepYears:y1;
ax.XTick = datetime(yt, 1, 1);
ax.XAxis.TickLabelFormat = 'yyyy';
end