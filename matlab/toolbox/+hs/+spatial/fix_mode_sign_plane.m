function [v2, info] = fix_mode_sign_plane(v, xy)
%FIX_MODE_SIGN_PLANE  Deterministic sign-fix for a spatial mode via plane fit.
%
% v  : (N x 1) mode values
% xy : (N x 2) centroids [x y] (e.g. lon-like, lat-like)
%
% Returns:
%   v2   : sign-fixed v
%   info : struct with plane coeffs, direction label, etc.

x = xy(:,1);
y = xy(:,2);

% Standardise coords so a,b are comparable
xz = (x - mean(x,'omitnan')) ./ std(x,0,'omitnan');
yz = (y - mean(y,'omitnan')) ./ std(y,0,'omitnan');

% Fit plane v ≈ a*xz + b*yz + c
X = [xz(:), yz(:), ones(numel(v),1)];
bhat = X \ v(:);
g = bhat(1:2);

ng = norm(g);
info = struct();
info.a = bhat(1);
info.b = bhat(2);
info.c = bhat(3);

if ~(isfinite(ng) && ng > 0)
    % Fallback: deterministic sign by first element
    v2 = v(:);
    if v2(1) < 0, v2 = -v2; end
    info.rule = "fallback_first_positive";
    info.dir_label = "NA";
    info.angle_deg = NaN;
    info.dot = NaN;
    return;
end

ghat = g ./ ng;                 % unit gradient direction
info.angle_deg = atan2d(ghat(2), ghat(1));

% Canonical directions (unit)
U = [ 1  0;
      0  1;
      1  1;
      1 -1 ];
U = U ./ vecnorm(U,2,2);

labels = ["E-W","N-S","NE-SW","NW-SE"];

dots = U * ghat;                % alignment with each direction
[~, k] = max(abs(dots));        % choose closest axis/diagonal (up to sign)
info.dir_label = labels(k);
info.dot = dots(k);
info.rule = "plane_4dirs";

% Flip so alignment is positive
v2 = v(:);
if dots(k) < 0
    v2 = -v2;
    info.dot = -info.dot;
    info.a = -info.a; info.b = -info.b; info.c = -info.c;
    info.angle_deg = mod(info.angle_deg + 180, 360) - 180;
end
end
