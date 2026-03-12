function calib = calibrate_phase_origin(dt, dj, low_period, up_period, mother, beta, gamma, sig_type, lowF, upF, varargin)
%HS.WAVELETS.CALIBRATE_PHASE_ORIGIN  Calibrate global phase origin for AWT+MeanPHASE.
%
% Goal: choose sign (+/-1) and offset delta so that for a synthetic cosine
% x(t)=cos(2*pi*t/T), extracted phase maps cosine PEAKS to phase 0.
%
% Outputs:
%   calib.sign        : +1 or -1 (chosen so phase increases with time)
%   calib.delta       : radians, so that wrapToPi(sign*theta - delta) has peaks near 0
%   calib.Rpeak       : mean resultant length at peaks (near 1 is good)
%   calib.Rtrough     : mean resultant length at troughs (near 1 is good)
%   calib.muPeak      : circular mean phase at peaks after calibration (should be ~0)
%   calib.muTrough    : circular mean phase at troughs after calibration (should be ~pi or ~-pi)
%   calib.apply       : @(th) wrapToPi(sign.*th - delta)
%   calib.periodYears : test period used
%
% Options:
%   'TestPeriodYears' (default mean([lowF upF]))
%   'TestYears'       (default 120)
%   'BurnYears'       (default 10)   % avoid edge effects
%   'MakePlot'        (default true)

p = inputParser;
p.addParameter('TestPeriodYears', mean([lowF upF]), @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('TestYears', 120, @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('BurnYears', 10, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
p.addParameter('MakePlot', true, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});

Tper = p.Results.TestPeriodYears;
Tyrs = p.Results.TestYears;
Burn = p.Results.BurnYears;
MakePlot = p.Results.MakePlot;

wrapToPi_local = @(a) mod(a + pi, 2*pi) - pi;

% --- Synthetic cosine ---
nObs = round(Tyrs/dt) + 1;
t = (0:nObs-1)' * dt;           % years
omega = 2*pi / Tper;
x = cos(omega * t);

% --- Extract phase with EXACT pipeline ---
[waveX, periods] = AWT(x, dt, dj, low_period, up_period, 0, mother, beta, gamma, sig_type);
theta = MeanPHASE(waveX, periods, lowF, upF);
theta = theta(:);
theta = wrapToPi_local(theta);

% Drop edges
burnN = round(Burn/dt);
idx = (1+burnN):(nObs-burnN);
t_i = t(idx);
th_i = theta(idx);

% --- Choose sign so phase increases with time (on average) ---
th_u = unwrap(th_i);                   % unwrapped phase
if corr(th_u, t_i, 'Rows','complete') < 0
    sgn = -1;
else
    sgn = +1;
end
th_i = wrapToPi_local(sgn .* th_i);

% --- Identify peak and trough times on the grid ---
% Peaks of cosine occur at t = k*Tper, troughs at t=(k+0.5)*Tper
kmax = floor(t_i(end)/Tper);
tPeaks  = (0:kmax)' * Tper;
tTrough = (0:kmax-1)' * Tper + 0.5*Tper;

% snap to nearest indices within interior sample
iPeaks  = zeros(numel(tPeaks),1);
for k = 1:numel(tPeaks)
    [~,ii] = min(abs(t_i - tPeaks(k)));
    iPeaks(k) = ii;
end
iTrough = zeros(numel(tTrough),1);
for k = 1:numel(tTrough)
    [~,ii] = min(abs(t_i - tTrough(k)));
    iTrough(k) = ii;
end

th_peaks  = th_i(iPeaks);
th_trough = th_i(iTrough);

% --- Delta so that peaks map to 0 ---
delta = angle(mean(exp(1i*th_peaks)));  % circular mean at peaks
th_cor = wrapToPi_local(th_i - delta);

% diagnostics: concentration at peaks/troughs after calibration
thp = th_cor(iPeaks);
tht = th_cor(iTrough);

Rpeak   = abs(mean(exp(1i*thp)));
Rtrough = abs(mean(exp(1i*tht)));
muPeak  = angle(mean(exp(1i*thp)));
muTrough= angle(mean(exp(1i*tht)));

calib = struct();
calib.sign = sgn;
calib.delta = delta;
calib.Rpeak = Rpeak;
calib.Rtrough = Rtrough;
calib.muPeak = muPeak;
calib.muTrough = muTrough;
calib.periodYears = Tper;

% IMPORTANT: define apply using local scalars (no captured struct)
calib.apply = @(th) wrapToPi_local(sgn .* th - delta);

fprintf('Phase origin calibration (peak-anchored), T=%.2f years:\n', Tper);
fprintf('  sign = %+d\n', calib.sign);
fprintf('  delta = %.4f rad (%.2f deg)\n', calib.delta, calib.delta*180/pi);
fprintf('  peaks:   R=%.4f, mean=%.4f rad\n', calib.Rpeak, calib.muPeak);
fprintf('  troughs: R=%.4f, mean=%.4f rad\n', calib.Rtrough, calib.muTrough);

if MakePlot
    % show a short excerpt
    K = min(600, numel(idx));
    ii = idx(1:K);
    th_raw = theta(ii);
    th_s   = wrapToPi_local(sgn .* th_raw);
    th_c   = wrapToPi_local(th_s - delta);

    figure('Color','w');
    plot(t(ii), x(ii), 'k'); grid on;
    title(sprintf('Synthetic cosine (T=%.2fy)', Tper));
    xlabel('Time (years)'); ylabel('x(t)');

    figure('Color','w');
    plot(t(ii), wrapToPi_local(th_s), 'Color',[0.5 0.5 0.5]); hold on;
    plot(t(ii), th_c, 'b', 'LineWidth', 1.2);
    yline(0,'--'); yline(pi,'--'); yline(-pi,'--');
    legend('AWT phase (signed)', 'Calibrated phase (peaks->0)', 'Location','best');
    title('Phase after peak-anchored calibration');
    xlabel('Time (years)'); ylabel('Phase (rad)');
    ylim([-pi pi]); grid on;

    figure('Color','w');
    histogram(thp, 30); hold on;
    histogram(tht, 30);
    legend('peaks','troughs');
    title('Calibrated phase at peaks vs troughs');
    xlabel('Phase (rad)'); grid on;
end
end
