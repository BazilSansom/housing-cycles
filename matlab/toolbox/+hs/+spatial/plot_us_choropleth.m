function ax = plot_us_choropleth(poly, values, varargin)
%HS.SPATIAL.PLOT_US_CHOROPLETH  Choropleth plot for US polyshape array.
%
% poly   : (n x 1) polyshape, one per state/region
% values : (n x 1) numeric values aligned with poly ordering
%
% Options:
%   'Parent'       target axes handle (default: gca)
%   'EdgeColor'    (default [0.6 0.6 0.6])
%   'LineWidth'    (default 0.5)
%   'ShowColorbar' (default true)
%   'ColorbarLabel' (default '')
%   'CLim'         (default symmetric maxabs)
%   'Colormap'     (default hs.plot.redblue(256))
%   'Title'        (default '')

p = inputParser;
p.addRequired('poly');
p.addRequired('values', @(v)isnumeric(v) && isvector(v));

p.addParameter('Parent', [], @(h) isempty(h) || ishghandle(h,'axes'));
p.addParameter('EdgeColor', [0.6 0.6 0.6]);
p.addParameter('LineWidth', 0.5);
p.addParameter('ShowColorbar', true);
p.addParameter('ColorbarLabel', '');
p.addParameter('CLim', []);
p.addParameter('Colormap', hs.plot.redblue(256));
p.addParameter('Title', '');
p.parse(poly, values, varargin{:});

values = values(:);

% Choose target axes
if isempty(p.Results.Parent)
    ax = gca;
else
    ax = p.Results.Parent;
end

% Do NOT create a new figure here. Caller controls figure/tiledlayout.
hold(ax,'on');

% Filled patches (handles multipart states robustly)
for i = 1:numel(poly)
    regs = regions(poly(i));
    for r = 1:numel(regs)
        reg = rmholes(regs(r));
        [xb, yb] = boundary(reg);
        if iscell(xb)
            for k = 1:numel(xb)
                %patch('XData', xb{k}, 'YData', yb{k}, ...
                 %     'CData', values(i), ...
                 %     'FaceColor','flat', 'EdgeColor','none', ...
                 %     'Parent', ax);
                patch('XData', xb{k}, 'YData', yb{k}, ...
                      'CData', values(i), ...
                      'FaceColor','flat', 'EdgeColor','none', ...
                      'Parent', ax, ...
                      'UserData', i);
            end
        else
            %patch('XData', xb, 'YData', yb, ...
            %      'CData', values(i), ...
            %      'FaceColor','flat', 'EdgeColor','none', ...
             %     'Parent', ax);
            patch('XData', xb, 'YData', yb, ...
                  'CData', values(i), ...
                  'FaceColor','flat', 'EdgeColor','none', ...
                  'Parent', ax, ...
                  'UserData', i);
        end
    end
end

% Outline on top
plot(ax, poly, 'FaceColor','none', ...
    'EdgeColor', p.Results.EdgeColor, ...
    'LineWidth', p.Results.LineWidth);

axis(ax, 'equal');
axis(ax, 'off');

% Color scaling
if isempty(p.Results.CLim)
    maxabs = max(abs(values(~isnan(values))));
    clim(ax, [-maxabs, maxabs]);
    %s = prctile(abs(values(~isnan(values))), 98);   % or 95/99 depending on how aggressive you want
    %clim(ax, [-s s]);
    %clim(ax, [min(values(~isnan(values))), max(values(~isnan(values)))]);

else
    clim(ax, p.Results.CLim);
end
colormap(ax, p.Results.Colormap);

% Colorbar (attached to this axes)
if p.Results.ShowColorbar
    cb = colorbar(ax);
    if ~isempty(p.Results.ColorbarLabel)
        cb.Label.String = p.Results.ColorbarLabel;
    end
end

title(ax, p.Results.Title);

hold(ax,'off');
end
