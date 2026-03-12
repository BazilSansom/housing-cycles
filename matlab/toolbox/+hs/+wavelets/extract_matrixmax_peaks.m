function peaks = extract_matrixmax_peaks(out, ridgeArgs, varargin)
% out: struct with fields WPS (nP×T), periods (nP×1), coi (nP×1 or T×1 depending on your wps_awt)
% ridgeArgs: {nb, factor}
% peaks: struct with indices and (optional) COI-masked subset

p = inputParser;
p.addParameter('MaskCOI', true, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results;

nb = ridgeArgs{1}; factor = ridgeArgs{2};

mask = MatrixMax(out.WPS, nb, factor) == 1;   % EXACTLY as plot_wps
[nP,T] = size(out.WPS);

% Optional: COI mask (recommended for “reliable” density)
mask_coi = mask;
if opt.MaskCOI && isfield(out,'coi') && ~isempty(out.coi)
    coi = out.coi(:);
    % In AWT, coi is often a vector over time in period units.
    % If your wps_awt stores coi as length-T, use this:
    if numel(coi) == T
        mask_coi = mask & (out.periods(:) <= coi(:)'); % nP×T
    end
end

% Coordinates
[p_idx, t_idx] = find(mask);
[p_idx_c, t_idx_c] = find(mask_coi);

peaks = struct();
peaks.mask = mask;                 % optional (can omit to save space)
peaks.p_idx = p_idx;
peaks.t_idx = t_idx;
peaks.period_years = out.periods(p_idx);
peaks.wps = out.WPS(sub2ind([nP,T], p_idx, t_idx));

peaks.p_idx_coi = p_idx_c;
peaks.t_idx_coi = t_idx_c;
peaks.period_years_coi = out.periods(p_idx_c);
peaks.wps_coi = out.WPS(sub2ind([nP,T], p_idx_c, t_idx_c));
end
