function fit = mode_lock_static(theta, x, varargin)
%HS.SPATIAL.MODE_LOCK_STATIC  Fit phase gradient theta ~ alpha + beta*x on the circle.
%
% Model: maximize A(beta) = |(1/N) sum_i exp(i*(theta_i - beta*z_i))|
% where z is x (optionally standardized).
%
% Inputs:
%   theta : (N x 1) angles in radians (wrapToPi recommended but not required)
%   x     : (N x 1) linear coordinate (e.g., v2)
%
% Options:
%   'StandardizeX' (default true)  : use z = (x-mean)/std; beta in rad per 1 std of x
%   'BetaRange'    (default [-8 8])
%   'BetaGridN'    (default 801)
%   'Refine'       (default true)  : local refinement around best grid point
%
% Output struct fit:
%   .A       scalar best alignment in [0,1]
%   .beta    scalar best slope (rad per std(x) if StandardizeX)
%   .alpha   scalar intercept phase shift (rad), circular
%   .z       standardized x used internally
%   .betaGrid, .Agrid (optional diagnostics)

p = inputParser;
p.addRequired('theta', @(v)isnumeric(v) && isvector(v));
p.addRequired('x', @(v)isnumeric(v) && isvector(v));
p.addParameter('StandardizeX', true, @(b)islogical(b) && isscalar(b));
p.addParameter('BetaRange', [-8 8], @(v)isnumeric(v) && numel(v)==2);
p.addParameter('BetaGridN', 801, @(n)isnumeric(n) && isscalar(n) && n>=21);
p.addParameter('Refine', true, @(b)islogical(b) && isscalar(b));
p.parse(theta, x, varargin{:});

theta = theta(:);
x = x(:);
ok = isfinite(theta) & isfinite(x);
theta = theta(ok);
x = x(ok);

N = numel(theta);
assert(N>=3, 'Need at least 3 points.');

if p.Results.StandardizeX
    z = (x - mean(x)) ./ std(x);
else
    z = x;
end

betaGrid = linspace(p.Results.BetaRange(1), p.Results.BetaRange(2), p.Results.BetaGridN).';
E = exp(1i*theta).';                      % 1xN
Shifts = exp(-1i*(betaGrid * z.'));       % KxN
S = Shifts * E.';                         % Kx1 (complex sums)
Agrid = abs(S) / N;

[Abest, k0] = max(Agrid);
betahat = betaGrid(k0);

% Optional local refine (1D)
if p.Results.Refine
    obj = @(b) -abs(mean(exp(1i*(theta - b*z))));
    % bracket around best grid point
    kL = max(1, k0-2);
    kR = min(numel(betaGrid), k0+2);
    bL = betaGrid(kL);
    bR = betaGrid(kR);
    betahat = fminbnd(obj, bL, bR);
    Abest = abs(mean(exp(1i*(theta - betahat*z))));
end

% alpha: best phase offset after removing gradient
alphaHat = angle(mean(exp(1i*(theta - betahat*z))));

fit = struct();
fit.A = Abest;
fit.beta = betahat;
fit.alpha = alphaHat;
fit.z = z;
fit.betaGrid = betaGrid;
fit.Agrid = Agrid;
fit.N = N;
end
