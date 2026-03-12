function out = fit_phase_gradient(theta, x, varargin)
%HS.SPATIAL.FIT_PHASE_GRADIENT  Circular fit: theta_i ~ alpha + beta*x_i (per time t)
%
% Inputs
%   theta : (T x N) phases in radians (e.g. from wavelet band)
%   x     : (N x 1) spatial coordinate (e.g. Fiedler vector v2)
%
% Name-value options
%   'BetaRange'     [min max] (default [-8 8])
%   'BetaGridN'     integer   (default 801)
%   'StandardizeX'  true/false (default true)
%   'Refine'        true/false (default true) refine beta with fminbnd
%
% Outputs (struct out)
%   .beta   (T x 1)
%   .alpha  (T x 1)
%   .A      (T x 1) alignment in [0,1]
%   .x_used (N x 1) x after standardization (if enabled)
%
% Notes
% - Handles NaNs per time t (drops missing states at that t)
% - Uses A(beta)=|mean(exp(i*(theta - beta*x)))|; alpha is implied by the mean angle.

p = inputParser;
p.addParameter('BetaRange', [-8 8], @(v)isnumeric(v) && numel(v)==2);
p.addParameter('BetaGridN', 801, @(n)isnumeric(n) && isscalar(n) && n>=51);
p.addParameter('StandardizeX', true, @(b)islogical(b) && isscalar(b));
p.addParameter('Refine', true, @(b)islogical(b) && isscalar(b));
p.parse(varargin{:});

betaRange = p.Results.BetaRange;
betaGridN = p.Results.BetaGridN;
doStdX    = p.Results.StandardizeX;
doRefine  = p.Results.Refine;

theta = double(theta);
x = double(x(:));

[T,N] = size(theta);
assert(numel(x)==N, 'x must have length N matching theta columns.');

% Standardize x (recommended: makes beta scale stable)
x_used = x;
if doStdX
    x_used = x_used - mean(x_used, 'omitnan');
    sx = std(x_used, 'omitnan');
    if sx > 0
        x_used = x_used ./ sx;
    end
end

betaGrid = linspace(betaRange(1), betaRange(2), betaGridN);

betaHat  = NaN(T,1);
alphaHat = NaN(T,1);
AHat     = NaN(T,1);

for t = 1:T
    th = theta(t,:).';
    ok = isfinite(th) & isfinite(x_used);
    if nnz(ok) < 10
        continue;
    end
    th = th(ok);
    xx = x_used(ok);

    % Grid search
    Agrid = zeros(betaGridN,1);
    for k = 1:betaGridN
        b = betaGrid(k);
        z = exp(1i*(th - b*xx));
        Agrid(k) = abs(mean(z));
    end
    [A0, k0] = max(Agrid);
    b0 = betaGrid(k0);

    % Optional refine (local continuous optimization)
    if doRefine
        left  = betaGrid(max(k0-1,1));
        right = betaGrid(min(k0+1,betaGridN));
        if left < right
            obj = @(b) -abs(mean(exp(1i*(th - b*xx))));
            b0 = fminbnd(obj, left, right);
            A0 = abs(mean(exp(1i*(th - b0*xx))));
        end
    end

    % Alpha implied by circular mean after removing gradient
    z0 = exp(1i*(th - b0*xx));
    a0 = angle(mean(z0));

    betaHat(t)  = b0;
    alphaHat(t) = a0;
    AHat(t)     = A0;
end

out = struct();
out.beta = betaHat;
out.alpha = alphaHat;
out.A = AHat;
out.x_used = x_used;
out.options = p.Results;
end
