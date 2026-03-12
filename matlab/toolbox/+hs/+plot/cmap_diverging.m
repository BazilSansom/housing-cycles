function cmap = cmap_diverging(m, cneg, czero, cpos, gamma)
%HS.PLOT.CMAP_DIVERGING  Diverging colormap interpolating between three colors.
%
% cmap = hs.plot.cmap_diverging(m, cneg, czero, cpos, gamma)
%
% Inputs:
%   m     number of colors (default 256)
%   cneg  1x3 RGB for negative end (default [0 0.2 0.8])
%   czero 1x3 RGB for midpoint (default [1 1 1])
%   cpos  1x3 RGB for positive end (default [0.8 0.2 0])
%   gamma contrast control around midpoint (default 1.0)
%
% gamma > 1 concentrates variation near the extremes;
% gamma < 1 concentrates near the midpoint.

if nargin < 1 || isempty(m),     m = 256; end
if nargin < 2 || isempty(cneg),  cneg  = [0 0.2 0.8]; end
if nargin < 3 || isempty(czero), czero = [1 1 1];     end
if nargin < 4 || isempty(cpos),  cpos  = [0.8 0.2 0]; end
if nargin < 5 || isempty(gamma), gamma = 1.0;         end

m = max(3, round(m));
t = linspace(0,1,m)'.^gamma;

% Two linear segments: [0,0.5] and [0.5,1]
t1 = t(t<=0.5);
t2 = t(t> 0.5);

% normalize each segment to [0,1]
u1 = (t1 - 0)   / 0.5;
u2 = (t2 - 0.5) / 0.5;

cmap1 = (1-u1).*cneg  + u1.*czero;
cmap2 = (1-u2).*czero + u2.*cpos;

cmap = [cmap1; cmap2];
cmap = max(0, min(1, cmap)); % clamp
end
