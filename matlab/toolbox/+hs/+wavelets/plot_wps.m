function ax = plot_wps(t, out, varargin)
%HS.WAVELETS.PLOT_WPS  Plot a wavelet power spectrum (WPS) with optional COI/ridges/significance.
%
% ax = hs.wavelets.plot_wps(t, out, ...)
%
% t   : (T x 1) datetime or numeric
% out : struct from hs.wavelets.wps_awt (periods, coi, WPS, pv_WPS)
%
% Options:
%   'Parent'        : axes handle (default [])
%   'Title'         : char/string (default "")
%   'PicEnh'        : exponent for power compression (default 0.4)
%   'Colormap'      : colormap matrix or name (default parula)
%   'YTicksYears'   : vector of period ticks in years (default [1 2 3 5 10 15 20])
%   'ShowCOI'       : true/false (default true)
%   'ShowRidges'    : true/false (default true if MatrixMax exists)
%   'RidgeArgs'     : {nhood, thresh} for MatrixMax (default {3,0.01})
%   'ShowSignif'    : true/false (default true)
%   'SignifLevel'   : e.g. 0.05 (default 0.05)
%   'YDirReverse'   : true/false (default true)

p = inputParser;
p.addParameter('Parent', [], @(h) isempty(h) || isgraphics(h,'axes'));
p.addParameter('Title', "", @(s) isstring(s) || ischar(s));
p.addParameter('PicEnh', 0.4, @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('Colormap', parula(256));
p.addParameter('YTicksYears', [1 2 3 5 10 15 20], @(v) isnumeric(v) && isvector(v));
p.addParameter('ShowCOI', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('ShowRidges', [], @(b) isempty(b) || (islogical(b)&&isscalar(b)));
p.addParameter('RidgeArgs', {3, 0.01}, @(c) iscell(c) && numel(c)==2);
p.addParameter('ShowSignif', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('SignifLevel', 0.05, @(x) isnumeric(x) && isscalar(x) && x>0 && x<1);
p.addParameter('YDirReverse', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('CLim', [], @(v) isempty(v) || (isnumeric(v) && numel(v)==2));
p.addParameter('CLimQuantile', 95, @(x) isnumeric(x) && isscalar(x) && x>0 && x<100);
p.addParameter('ShowColorbar', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('XTickStepYears', 5, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('XTickYearOrigin', [], @(x) isempty(x) || (isnumeric(x)&&isscalar(x)));
p.addParameter('XTickLabelFormat', 'yyyy', @(s)ischar(s)||isstring(s));
p.addParameter('SetRoundYearTicks', true, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});


t = t(:);

% Parent axes
if isempty(p.Results.Parent)
    figure('Color','w');
    ax = gca;
else
    ax = p.Results.Parent;
end
hold(ax,'on');


% ---- handle datetime for contour/imagesc (contour needs numeric x) ----
isDt = isdatetime(t);
if isDt
    tNum = datenum(t);   % numeric serial date for contour/imagesc
else
    tNum = t;
end

periods = out.periods(:);
logperiods = log2(periods);

W = out.WPS;
pic_enh = p.Results.PicEnh;

C = W.^pic_enh;                       % the actual plotted CData


% imagesc supports datetime in modern MATLAB; keep as-is
imagesc(ax, tNum, logperiods, C);


% Then set CLim (so nothing resets it)
if isempty(p.Results.CLim)
    Cvec = C(:);
    Cvec = Cvec(isfinite(Cvec));
    hi = prctile(Cvec, p.Results.CLimQuantile);
    clim(ax, [0 hi]);
else
    clim(ax, p.Results.CLim);
end
caxis(ax,'manual');


% Colormap
cm = p.Results.Colormap;
if ischar(cm) || isstring(cm)
    colormap(ax, feval(cm,256));
else
    colormap(ax, cm);
end

% Axis formatting
y_ticks_lab = p.Results.YTicksYears(:)';
y_ticks = log2(y_ticks_lab);

set(ax, 'YLim', [min(logperiods) max(logperiods)], ...
        'YTick', y_ticks, 'YTickLabel', y_ticks_lab, ...
        'FontSize', 9, 'FontName','arial');

if p.Results.YDirReverse
    set(ax,'YDir','reverse');
else
    set(ax,'YDir','normal');
end

grid(ax,'on');
ylabel(ax,'Period (years)');
title(ax, p.Results.Title);

if p.Results.ShowColorbar
    cb = colorbar(ax);
    cb.Label.String = sprintf('Power^{%.2f}', pic_enh);
end

% COI
if p.Results.ShowCOI && isfield(out,'coi') && ~isempty(out.coi)
    logcoi = log2(out.coi(:));
    plot(ax, tNum, logcoi, 'k', 'LineWidth', 1.5);
end

% Decide default for ridges: on if MatrixMax exists
showRidges = p.Results.ShowRidges;
if isempty(showRidges)
    showRidges = (exist('MatrixMax','file')==2);
end

% Ridges
if showRidges
    if exist('MatrixMax','file')==2
        args = p.Results.RidgeArgs;
        max_power = MatrixMax(out.WPS, args{1}, args{2});
        contour(ax, tNum, logperiods, double(max_power), [1 1], 'w-', 'LineWidth', 1.25);

    else
        warning('MatrixMax not found on path; skipping ridge overlay.');
    end
end

% Significance contour
if p.Results.ShowSignif && isfield(out,'pv_WPS') && ~isempty(out.pv_WPS)
    lev = p.Results.SignifLevel;
    [~, hh] = contour(ax, tNum, logperiods, out.pv_WPS, [lev lev], ...
        'Color','k','LineWidth',1.25);
    set(hh,'ShowText','off');
end

% ---- X-axis limits (numeric, because we plot using tNum) ----
xlim(ax, [tNum(1) tNum(end)]);

% ---- Nice "round-year" ticks if datetime input ----
if isDt && p.Results.SetRoundYearTicks
    ticksDt = local_year_ticks(t, p.Results.XTickStepYears, p.Results.XTickYearOrigin);
    if ~isempty(ticksDt)
        ax.XTick = datenum(ticksDt);
        ax.XTickLabel = cellstr(datestr(ticksDt, char(p.Results.XTickLabelFormat))); %#ok<DATST>
    end
end


hold(ax,'off');
end

%=== Local functions ====

function ticksDt = local_year_ticks(t, stepYears, yearOrigin)
t = t(:);
tmin = min(t); tmax = max(t);

if isempty(yearOrigin)
    y0 = year(tmin);
    y0 = stepYears * ceil(y0/stepYears);   % next multiple of stepYears
else
    y0 = yearOrigin;
end

y1 = year(tmax);
tickYears = y0:stepYears:y1;
ticksDt = datetime(tickYears,1,1);
end
%--- End of local functions ---