function cmap = cyclic_quadrant(n)
if nargin<1, n=256; end
pos = [0 0.25 0.50 0.75 1.0];
rgb = [1 0 0;      % peak
       1 0 1;      % downturn
       0 0 1;      % trough
       0 1 1;      % recovery
       1 0 0];     % back to peak
xi = linspace(0,1,n);
cmap = interp1(pos, rgb, xi, 'linear');
cmap = max(0,min(1,cmap));
end
