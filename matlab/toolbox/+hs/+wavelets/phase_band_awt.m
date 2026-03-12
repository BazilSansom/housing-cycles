function [phaseX, ampX, xband] = phase_band_awt( ...
    X, dt, dj, low_period, up_period, mother, beta, gamma, sig_type, lowF, upF)
%PHASE_BAND_AWT  Band-averaged wavelet phase (ASToolbox MeanPHASE) and band strength.
%
% phaseX: T x N band phase from MeanPHASE (unchanged definition)
% ampX:   T x N band amplitude proxy = RMS modulus across scales in band
% xband:  T x N band component proxy = ampX .* cos(phaseX)

[nObs, nSeries] = size(X);

phaseX = zeros(nObs, nSeries);

wantAmp   = (nargout >= 2);
wantXband = (nargout >= 3);

if wantAmp
    ampX = zeros(nObs, nSeries);
else
    ampX = [];
end

if wantXband
    xband = zeros(nObs, nSeries);
else
    xband = [];
end

% Optional: compute band index once (and validate periods stable)
periods0 = [];
indBand  = [];

for i = 1:nSeries
    [waveX, periods] = AWT(X(:,i), dt, dj, low_period, up_period, 0, mother, beta, gamma, sig_type);
    % waveX: nScales x T

    % Phase (toolbox definition)
    phaseX(:,i) = MeanPHASE(waveX, periods, lowF, upF);

    if wantAmp
        if isempty(periods0)
            periods0 = periods(:);
            indBand  = (periods0 >= lowF) & (periods0 <= upF);
            if ~any(indBand)
                error('phase_band_awt: no scales in band [%.3g, %.3g] years. Check periods grid.', lowF, upF);
            end
        else
            % fail-fast if periods grid changes across series
            if ~isequal(periods(:), periods0)
                error('phase_band_awt: periods grid differs across series (series %d).', i);
            end
        end

        Wb = waveX(indBand, :);                      % (nBandScales x T)
        amp_i = sqrt(mean(abs(Wb).^2, 1)).';         % (T x 1) RMS modulus
        ampX(:,i) = amp_i;

        if wantXband
            xband(:,i) = amp_i .* cos(phaseX(:,i));  % per-series band component proxy
        end
    end
end

% If prefered, compute xband here instead of inside the loop:
% if wantXband
%     xband = ampX .* cos(phaseX);
% end

end
