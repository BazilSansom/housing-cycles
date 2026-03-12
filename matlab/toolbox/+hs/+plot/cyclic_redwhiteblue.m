function cmap = cyclic_redwhiteblue(n)
%HS.PLOT.CYCLIC_REDWHITEBLUE Cyclic map: blue->white->red->white->blue
if nargin < 1, n = 256; end
pos = [0 0.25 0.50 0.75 1.0];
rgb = [0 0 1;
       1 1 1;
       1 0 0;
       1 1 1;
       0 0 1];
xi = linspace(0,1,n);
cmap = interp1(pos, rgb, xi, 'linear');
cmap = max(0,min(1,cmap));
end
