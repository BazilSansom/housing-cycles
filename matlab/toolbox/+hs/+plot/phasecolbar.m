function axWheel = phasecolbar(axParent, varargin)
%HS.PLOT.PHASECOLBAR  Add a circular phase legend (wheel) as an inset.
%
% axWheel = hs.plot.phasecolbar(axParent, 'Name',Value,...)
%
% Options:
%   'Location'      'se'|'sw'|'ne'|'nw' (default 'se')
%   'Size'          fraction of plotbox width/height (default 0.20)
%   'InnerFrac'     inner radius fraction of outer radius (default 0.62)
%   'Resolution'    grid resolution (default 300)
%   'Labels'        {'trough','peak'} (default {'trough','peak'})
%   'LabelAngles'   angles (rad) for labels (default [0 pi])
%   'UsePlotbox'    use plotboxpos for placement (default true)
%   'EdgeColor'     circle outline color (default = axParent XColor)
%
% Behaviour:
% - Inherits colormap and clim from axParent.
% - Does not change current axes (restores it).
% - Tags wheel axes with 'hs_phasebar' so you can find/delete later.

if nargin < 1 || isempty(axParent)
    axParent = gca;
end
assert(ishghandle(axParent,'axes'), 'axParent must be an axes handle.');

p = inputParser;
p.addParameter('Location','se', @(s)ischar(s)||isstring(s));
p.addParameter('Size',0.20, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<1);
p.addParameter('InnerFrac',0.62, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<1);
p.addParameter('Resolution',300, @(n)isnumeric(n)&&isscalar(n)&&n>=100);
p.addParameter('Labels',{'trough','peak'}, @(c)iscell(c)&&numel(c)==2);
p.addParameter('LabelAngles',[0 pi], @(v)isnumeric(v)&&numel(v)==2);
p.addParameter('UsePlotbox',true, @(b)islogical(b)&&isscalar(b));
p.addParameter('EdgeColor',[], @(c)isempty(c)||(isnumeric(c)&&numel(c)==3));
p.addParameter('ShowDirection', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('Direction', 'ccw', @(s)ischar(s)||isstring(s));
p.addParameter('ArrowAngle', -pi/4, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('ArrowSpan', pi/3, @(x)isnumeric(x)&&isscalar(x)&&x>0&&x<2*pi);
p.parse(varargin{:});

loc   = lower(string(p.Results.Location));
sz    = p.Results.Size;
innerFrac = p.Results.InnerFrac;
N     = p.Results.Resolution;
lab   = p.Results.Labels;
labAng= p.Results.LabelAngles;
usePB = p.Results.UsePlotbox;

% Determine placement box (prefer plotbox)
if usePB
    pb = hs.plot.plotboxpos(axParent);
else
    pb = get(axParent,'Position');
end

% Compute inset axes position within pb
switch loc
    case {"se","southeast"}
        pos = [pb(1)+(1-sz)*pb(3), pb(2),              sz*pb(3), sz*pb(4)];
    case {"ne","northeast"}
        pos = [pb(1)+(1-sz)*pb(3), pb(2)+(1-sz)*pb(4), sz*pb(3), sz*pb(4)];
    case {"sw","southwest"}
        pos = [pb(1),              pb(2),              sz*pb(3), sz*pb(4)];
    case {"nw","northwest"}
        pos = [pb(1),              pb(2)+(1-sz)*pb(4), sz*pb(3), sz*pb(4)];
    otherwise
        error('Unrecognized Location: %s', loc);
end

% Edge color defaults to parent XColor
if isempty(p.Results.EdgeColor)
    edgeCol = get(axParent,'XColor');
else
    edgeCol = p.Results.EdgeColor;
end

% Inherit colormap and clim from parent
cm = colormap(axParent);
cl = clim(axParent);

% Build wheel data: angle field on an annulus
outerR = 1;
innerR = innerFrac*outerR;

[x,y] = meshgrid(linspace(-outerR, outerR, N));
theta = atan2(y,x);  % in [-pi,pi]
rho = hypot(x,y);

mask = (rho >= innerR) & (rho <= outerR);
theta(~mask) = NaN;

% Create inset axes on same figure
fig = ancestor(axParent,'figure');
axOld = gca;

axWheel = axes('Parent',fig, 'Position',pos, 'Units',get(axParent,'Units'));
set(axWheel,'Tag','hs_phasebar');

% Draw wheel as an image (fast)
hImg = imagesc(axWheel, x(1,:), y(:,1), theta);
set(hImg,'AlphaData',~isnan(theta));
set(axWheel,'YDir','normal');

axis(axWheel,'image');
axis(axWheel,'off');
colormap(axWheel, cm);
clim(axWheel, cl);

hold(axWheel,'on');
t = linspace(-pi, pi, 400);
plot(axWheel, innerR*cos(t), innerR*sin(t), '-', 'Color',edgeCol, 'LineWidth',0.5);
plot(axWheel, outerR*cos(t), outerR*sin(t), '-', 'Color',edgeCol, 'LineWidth',0.5);

% Labels (default at angle 0 and pi)
for k = 1:2
    ang = labAng(k);
    rr  = 1.18*outerR;
    tx = rr*cos(ang);
    ty = rr*sin(ang);
    ht = text(axWheel, tx, ty, string(lab{k}), ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
        'Color', edgeCol, 'FontSize', 9);
    % rotate labels roughly tangential if you want; simple option:
    set(ht,'Rotation', rad2deg(ang)+90);
end

% Direction indicator (curved arrow)
if p.Results.ShowDirection
    dir = lower(string(p.Results.Direction));
    a0  = p.Results.ArrowAngle;
    span = p.Results.ArrowSpan;

    if dir == "ccw"
        ang = linspace(a0, a0+span, 80);
    else
        ang = linspace(a0, a0-span, 80);
    end

    rr = 0.90*outerR;  % radius of arrow arc (inside ring)
    xa = rr*cos(ang);
    ya = rr*sin(ang);

    plot(axWheel, xa, ya, 'Color', edgeCol, 'LineWidth', 1.0);

    % Arrowhead at end of arc
    xe = xa(end); ye = ya(end);
    % Tangent direction at end
    tx = -sin(ang(end));
    ty =  cos(ang(end));
    if dir ~= "ccw"
        tx = -tx; ty = -ty;
    end

    % Build two short segments for arrowhead
    ah = 0.12*outerR;           % arrowhead size
    phi = deg2rad(25);          % opening angle
    R1 = [cos(phi) -sin(phi); sin(phi) cos(phi)];
    R2 = [cos(-phi) -sin(-phi); sin(-phi) cos(-phi)];

    v  = [tx; ty] / norm([tx ty]);  % unit tangent
    v1 = R1*v;
    v2 = R2*v;

    plot(axWheel, [xe, xe - ah*v1(1)], [ye, ye - ah*v1(2)], 'Color', edgeCol, 'LineWidth', 1.0);
    plot(axWheel, [xe, xe - ah*v2(1)], [ye, ye - ah*v2(2)], 'Color', edgeCol, 'LineWidth', 1.0);

    % Optional tiny label
    %text(axWheel, 0, -1.25*outerR, '\rightarrow phase', ...
    %    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    %    'Color', edgeCol, 'FontSize', 8);
end


hold(axWheel,'off');

% Restore previous current axes and bring wheel to top
axes(axOld);
uistack(axWheel,'top');
end
