function cmap = cyclic_red_blue_red(n)
%HS.PLOT.CYCLIC_RED_BLUE_RED  Cyclic phase colormap:
%   phase = 0   (peak)  -> blue
%   phase = ±pi (trough)-> red
%
% With CLim = [-pi pi], -pi -> red, 0 -> blue, +pi -> red.
%
% Interpretation (with ccw increasing phase):
%   -pi -> 0 : expansion (red -> blue)
%    0 -> pi : downswing (blue -> red)

if nargin < 1, n = 256; end
n2 = floor(n/2);

red  = [0.85 0.15 0.15];
blue = [0.15 0.25 0.90];

x1 = linspace(0,1,n2).';
x2 = linspace(0,1,n-n2).';

c1 = red  + (blue-red).*x1;     % red -> blue
c2 = blue + (red-blue).*x2;     % blue -> red

cmap = [c1; c2];
end