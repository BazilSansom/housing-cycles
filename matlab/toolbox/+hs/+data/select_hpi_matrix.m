function [X, dates, label] = select_hpi_matrix(S, cfg)
%HS.DATA.SELECT_HPI_MATRIX  Select which processed HPI matrix to use (SA/NSA variants).
%
% Config:
%   cfg.data.series       = "SA" | "NSA"   (case-insensitive ok)
%   cfg.data.nsa_deseason = "none" | "month_demean" | "yoy_diff" (only if series="NSA")
%
% Returns:
%   X     : T x N matrix
%   dates : T x 1 datetime aligned with X
%   label : string label for provenance/filenames:
%           "sa", "nsa", "nsa-monthdemean", "nsa-yoy"

assert(isstruct(cfg) && isfield(cfg,'data') && isstruct(cfg.data), 'cfg.data missing.');
assert(isfield(cfg.data,'series'), 'cfg.data.series missing.');

series = upper(strtrim(string(cfg.data.series)));

switch series
    case "SA"
        assert(isfield(S,'dlog_sa_states') && isfield(S,'dates_dlog'), ...
            'Processed MAT missing SA fields (dlog_sa_states, dates_dlog).');
        X = S.dlog_sa_states;
        dates = S.dates_dlog;
        label = "sa";

    case "NSA"
        ds = "none";
        if isfield(cfg.data,'nsa_deseason') && strlength(string(cfg.data.nsa_deseason))>0
            ds = lower(strtrim(string(cfg.data.nsa_deseason)));
        end

        switch ds
            case "none"
                assert(isfield(S,'dlog_nsa_states') && isfield(S,'dates_dlog'), ...
                    'Processed MAT missing NSA fields (dlog_nsa_states, dates_dlog).');
                X = S.dlog_nsa_states;
                dates = S.dates_dlog;
                label = "nsa";

            case "month_demean"
                assert(isfield(S,'dlog_nsa_monthdemean_states') && isfield(S,'dates_dlog'), ...
                    'Processed MAT missing NSA month-demean fields.');
                X = S.dlog_nsa_monthdemean_states;
                dates = S.dates_dlog;
                label = "nsa-monthdemean";

            case "yoy_diff"
                assert(isfield(S,'dlog12_nsa_states') && isfield(S,'dates_dlog12'), ...
                    'Processed MAT missing NSA YoY fields (dlog12_nsa_states, dates_dlog12).');
                X = S.dlog12_nsa_states;
                dates = S.dates_dlog12;
                label = "nsa-yoy";

            otherwise
                error('Unknown cfg.data.nsa_deseason="%s". Use "none"|"month_demean"|"yoy_diff".', ds);
        end

    otherwise
        error('Unknown cfg.data.series="%s". Use "SA" or "NSA".', string(cfg.data.series));
end

% ---- sanity ----
label = string(label);
assert(isscalar(label) && strlength(label)>0, 'label must be a nonempty string.');

assert(isnumeric(X) && ismatrix(X), 'X must be a numeric matrix.');
assert(isdatetime(dates) && isvector(dates), 'dates must be a datetime vector.');
dates = dates(:);
assert(size(X,1) == numel(dates), 'X/dates length mismatch: %d vs %d.', size(X,1), numel(dates));

end