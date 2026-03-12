function [RPA, r, phi] = relative_phase_weighted(phaseX, w)
%RELATIVE_PHASE_WEIGHTED  Weighted Kuramoto order parameter and relative phases.
%
% Inputs:
%   phaseX : T x N phases (rad)
%   w      : T x N nonnegative weights (e.g., band amplitude proxy)
%
% Outputs:
%   r      : T x 1 weighted order parameter
%   phi    : T x 1 weighted mean phase
%   RPA    : T x N relative phase angles in [-pi, pi]

assert(ismatrix(phaseX) && isnumeric(phaseX), 'phaseX must be numeric T x N');
assert(isequal(size(phaseX), size(w)), 'w must have same size as phaseX');
w = max(w, 0);

Z = exp(1i*phaseX);

num = sum(w .* Z, 2);
den = sum(w, 2);

phi = angle(num);
r = abs(num ./ den);
r(den < eps) = NaN;             % avoid 0/0 if all weights are zero

RPA = angle(exp(1i*(phaseX - phi)));  % wrap to [-pi, pi]
end
