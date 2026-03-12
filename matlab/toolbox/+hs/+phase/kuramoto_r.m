function [r, phi, m] = kuramoto_r(theta, varargin)
%HS.PHASE.KURAMOTO_R  Kuramoto order parameter r(t) from phase field theta(t,i).
%
%   [r, phi, m] = hs.phase.kuramoto_r(theta)
%   [r, phi, m] = hs.phase.kuramoto_r(theta, 'Weights', w, 'OmitNaN', true)
%
% Inputs
%   theta : T x N (or N x T) real phase angles (radians)
%
% Name-value options
%   'Weights' : [] (default) or N x 1 nonnegative weights
%               If provided, uses weighted mean:
%                 m(t) = sum_i w_i * exp(1i*theta_i(t)) / sum_i w_i
%   'OmitNaN' : true (default). If true, drops NaNs per time t (and renormalizes weights).
%               If false, any NaN in a row makes m(t)=NaN.
%
% Outputs
%   r   : T x 1, r(t) in [0,1]
%   phi : T x 1, mean phase angle arg(m(t))
%   m   : T x 1 complex order parameter
%
% Notes
%   - r(t) = abs(m(t))
%   - phi(t) = angle(m(t))
%
% Baz: keep this as a shared primitive so all plots/diagnostics are consistent.

p = inputParser;
p.addParameter('Weights', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
p.addParameter('OmitNaN', true, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results;

theta = double(theta);

% Accept N x T by flipping if needed (heuristic: more columns than rows is typical T x N)
if size(theta,1) < size(theta,2) && size(theta,1) <= 60 && size(theta,2) > 60
    % probably N x T, but be conservative: only flip if N looks "small"
    theta = theta.'; % now T x N
end

[T,N] = size(theta);

w = opt.Weights;
if isempty(w)
    w = ones(N,1);
else
    w = w(:);
    assert(numel(w)==N, 'Weights must have length N=%d.', N);
    assert(all(isfinite(w)) && all(w>=0), 'Weights must be finite and nonnegative.');
end

m   = complex(nan(T,1), nan(T,1));
r   = nan(T,1);
phi = nan(T,1);

if ~opt.OmitNaN
    U = exp(1i*theta);                    % T x N
    denom = sum(w);
    if denom==0
        return;
    end
    m = (U * w) ./ denom;
    r = abs(m);
    phi = angle(m);
    return;
end

% Omit NaNs per row, renormalize weights
for t = 1:T
    th = theta(t,:);
    ok = isfinite(th);
    if ~any(ok)
        continue;
    end
    ww = w(ok);
    denom = sum(ww);
    if denom<=0
        continue;
    end
    mt = sum( ww.' .* exp(1i*th(ok)) ) ./ denom;
    m(t) = mt;
end

r = abs(m);
phi = angle(m);
end