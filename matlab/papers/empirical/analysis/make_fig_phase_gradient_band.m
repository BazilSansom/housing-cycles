function make_fig_phase_gradient_band(varargin)
%MAKE_FIG_PHASE_GRADIENT_BAND  Paper figure: spatial mode-lock and Fiedler gradient.
%
% Reads:
%   outputs/intermediate/phase_gradient_<dataTag>_band_<bandTag>.mat
%
% Writes:
%   outputs/figures/Fig_phase_gradient_<bandTag>_<dataTag>.pdf/.png
%
% Panels:
%   A: Spatial mode-lock A(t) and global synchrony r(t)
%   B: Fiedler-gradient coefficient beta(t), with implied lead-lag scale on
%      the right axis
%
% Notes:
%   - Uses phase_gradient_*.mat as the single source of truth.
%   - Optional smoothing is for presentation only.

p = inputParser;
p.addParameter('WhichBands', {'main','long'}, @(v) iscell(v) || isstring(v));
p.addParameter('SmoothMonths', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('Overwrite', false, @(b) islogical(b) && isscalar(b));
p.addParameter('YearTickStep', 5, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();
if ~exist(cfg.paths.figures, 'dir')
    mkdir(cfg.paths.figures);
end

% -------------------------------------------------------------------------
% Data tag for filenames
% -------------------------------------------------------------------------
assert(exist(cfg.outputs.processedMat,'file')==2, 'Missing %s', cfg.outputs.processedMat);
Sproc = load(cfg.outputs.processedMat);
[~,~,dataLabel] = hs.data.select_hpi_matrix(Sproc, cfg);
dataTag = hs.util.data_tag(dataLabel);

bandKeys = string(opt.WhichBands(:)).';
for bk = bandKeys
    assert(isfield(cfg.bands, bk), 'Unknown band key: %s', bk);

    bcfg = cfg.bands.(bk);
    lowF = bcfg.lowF;
    upF  = bcfg.upF;

    bandTag = hs.util.band_tag(lowF, upF);
    bandTagPretty = sprintf('%.0f--%.0fy', lowF, upF);

    inMat = fullfile(cfg.paths.intermediate, ...
        sprintf('phase_gradient_%s_band_%s.mat', dataTag, bandTag));
    assert(exist(inMat,'file')==2, ...
        'Missing %s (run run_phase_gradient_band_data first).', inMat);

    tmp = load(inMat);
    assert(isfield(tmp,'res'), 'Expected variable `res` in %s.', inMat);
    res = tmp.res;

    % ---------------------------------------------------------------------
    % Required fields
    % ---------------------------------------------------------------------
    req = {'dates','A','r','beta','monthsPerRad','dz_90_10','useYears'};
    for i = 1:numel(req)
        assert(isfield(res, req{i}), 'res missing field `%s` in %s.', req{i}, inMat);
    end

    dates        = res.dates(:);
    A            = res.A(:);
    r            = res.r(:);
    beta         = res.beta(:);
    monthsPerRad = res.monthsPerRad;
    dz_90_10     = res.dz_90_10;
    useYears     = logical(res.useYears);

    if isfield(res, 'dataLabel') && ~isempty(res.dataLabel)
        dataLabelStr = char(string(res.dataLabel));
    else
        dataLabelStr = char(string(dataLabel));
    end

    % ---------------------------------------------------------------------
    % Optional smoothing for presentation
    % ---------------------------------------------------------------------
    if opt.SmoothMonths > 1
        wlen  = opt.SmoothMonths;
        Aplot = movmean(A,    wlen, 'omitnan');
        rplot = movmean(r,    wlen, 'omitnan');
        bplot = movmean(beta, wlen, 'omitnan');
    else
        Aplot = A;
        rplot = r;
        bplot = beta;
    end

    % Implied lead-lag scale from plotted beta
    dt1sigma_mo = monthsPerRad * bplot;   % months per 1 sd of v2

    % ---------------------------------------------------------------------
    % Figure
    % ---------------------------------------------------------------------
    fig = figure('Color','w','Position',[100 100 980 720]);
    tl = tiledlayout(fig, 2, 1, 'Padding','compact', 'TileSpacing','compact');

    % =======================
    % Panel A
    % =======================
    ax1 = nexttile(tl, 1);
    hold(ax1, 'on');
    plot(ax1, dates, Aplot, 'LineWidth', 1.4, 'DisplayName', 'Mode-lock A(t)');
    plot(ax1, dates, rplot, 'LineWidth', 1.4, 'DisplayName', 'Kuramoto r(t)');
    hold(ax1, 'off');

    grid(ax1, 'on');
    ax1.Box = 'on';
    ax1.Layer = 'top';
    ylim(ax1, [0 1]);
    ylabel(ax1, 'alignment / coherence');
    title(ax1, sprintf('A. Spatial mode-lock and global synchrony (%s, %s)', ...
        bandTagPretty, dataLabelStr));
    legend(ax1, 'Location', 'best');
    set_year_ticks_(ax1, dates, opt.YearTickStep);

    % =======================
    % Panel B
    % =======================
    ax2 = nexttile(tl, 2);

    yyaxis(ax2, 'left');
    plot(ax2, dates, bplot, 'LineWidth', 1.4);
    hold(ax2, 'on');
    yline(ax2, 0, '--', 'LineWidth', 1.0);
    hold(ax2, 'off');

    grid(ax2, 'on');
    ax2.Box = 'on';
    ax2.Layer = 'top';
    ylabel(ax2, '\beta(t) (rad per 1 sd of v_2)', 'Interpreter', 'tex');

    % Capture left-axis limits to map onto implied lead-lag axis
    ylBeta = ylim(ax2);

    yyaxis(ax2, 'right');
    if useYears
        ylabel(ax2, '\Deltat_{1\sigma}(t) (years)', 'Interpreter', 'tex');
        ylim(ax2, (ylBeta * monthsPerRad) / 12);
    else
        ylabel(ax2, '\Deltat_{1\sigma}(t) (months)', 'Interpreter', 'tex');
        ylim(ax2, ylBeta * monthsPerRad);
    end

    yyaxis(ax2, 'left');
    title(ax2, 'B. Spatial phase gradient and implied lead-lag scale', ...
        'Interpreter', 'tex');
    xlabel(ax2, 'Date');

    txt = sprintf('v_2 spread (90-10) = %.2f sd  =>  \\Deltat_{90-10}(t) \\approx %.2f \\times \\Deltat_{1\\sigma}(t)', ...
        dz_90_10, dz_90_10);
    text(ax2, 0.99, 0.96, txt, ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', ...
        'Margin', 2, ...
        'FontSize', 9, ...
        'Interpreter', 'tex');

    set_year_ticks_(ax2, dates, opt.YearTickStep);

    sgtitle(fig, sprintf('Housing-cycle spatial gradient diagnostics (%s band; %s)', ...
        bandTagPretty, dataLabelStr));

    % ---------------------------------------------------------------------
    % Export
    % ---------------------------------------------------------------------
    outPdf = fullfile(cfg.paths.figures, ...
        sprintf('Fig_phase_gradient_%s_%s.pdf', bandTag, dataTag));
    outPng = fullfile(cfg.paths.figures, ...
        sprintf('Fig_phase_gradient_%s_%s.png', bandTag, dataTag));

    if exist(outPdf,'file')==2 && ~opt.Overwrite
        fprintf('Exists (set Overwrite=true): %s\n', outPdf);
        close(fig);
        continue;
    end

    exportgraphics(fig, outPdf, 'ContentType','vector');
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
ax.XTick = datetime(yt,1,1);
ax.XAxis.TickLabelFormat = 'yyyy';
end