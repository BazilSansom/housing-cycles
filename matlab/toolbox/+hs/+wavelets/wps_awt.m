function out = wps_awt(y, cfg)
%HS.WAVELETS.WPS_AWT  Compute wavelet power spectrum via ASToolbox AWT.
%
% out = hs.wavelets.wps_awt(y, cfg)
%
% y   : (T x 1) numeric
% cfg : struct from config_empirical_rsue (needs cfg.wave.*)
%
% out fields:
%   WT, periods, coi, WPS, pv_WPS

arguments
    y (:,1) double
    cfg struct
end

[WT, periods, coi, WPS, pv_WPS] = AWT( ...
    y, ...
    cfg.wave.dt, cfg.wave.dj, cfg.wave.low_period, cfg.wave.up_period, ...
    cfg.wave.pad, cfg.wave.mother, cfg.wave.beta, cfg.wave.gamma, cfg.wave.sig_type);

out = struct();
out.WT      = WT;
out.periods = periods(:);
out.coi     = coi(:);       % should be length T
out.WPS     = WPS;          % (nPeriods x T) in ASToolbox
out.pv_WPS  = pv_WPS;       % (nPeriods x T)
end
