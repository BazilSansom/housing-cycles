function manifest = build_dataset_fmhpi(varargin)
%BUILD_DATASET_FMHPI  Build state-level HPI dataset from Freddie Mac master file (FMHPI).
%
% Reads:
%   cfg.inputs.rawCsv   (default)  OR downloads cfg.inputs.rawCsvUrl if missing/forced
% Writes:
%   cfg.outputs.processedMat
%
% Options:
%   'OverwriteProcessed' : false (default)  -> if processed MAT exists, skip rebuild
%   'AutoDownload'       : [] (default)     -> if empty, uses cfg.data.autoDownload if present, else true
%   'ForceDownload'      : [] (default)     -> if empty, uses cfg.data.forceDownload if present, else false
%
% Output:
%   manifest struct (also saved inside processed MAT)

p = inputParser;
p.addParameter('OverwriteProcessed', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('AutoDownload', [], @(b)isempty(b) || (islogical(b)&&isscalar(b)));
p.addParameter('ForceDownload', [], @(b)isempty(b) || (islogical(b)&&isscalar(b)));
p.parse(varargin{:});
opt = p.Results;

cfg = config_empirical();

rawCsv = cfg.inputs.rawCsv;
outMat = cfg.outputs.processedMat;

% Default download behaviour from cfg if present
autoDl = true;
forceDl = false;
if isfield(cfg,'data') && isfield(cfg.data,'autoDownload')
    autoDl = logical(cfg.data.autoDownload);
end
if isfield(cfg,'data') && isfield(cfg.data,'forceDownload')
    forceDl = logical(cfg.data.forceDownload);
end
if ~isempty(opt.AutoDownload);  autoDl = opt.AutoDownload; end
if ~isempty(opt.ForceDownload); forceDl = opt.ForceDownload; end

% Ensure directories
if ~exist(fileparts(rawCsv),'dir'); mkdir(fileparts(rawCsv)); end
if ~exist(fileparts(outMat),'dir'); mkdir(fileparts(outMat)); end

% If processed exists and not overwriting, skip (idempotent)
if exist(outMat,'file')==2 && ~opt.OverwriteProcessed && ~forceDl
    fprintf('Processed MAT exists (set OverwriteProcessed=true to rebuild): %s\n', outMat);
    S = load(outMat, 'manifest');
    if isfield(S,'manifest'); manifest = S.manifest; else; manifest = struct(); end
    return;
end

% Auto-download raw CSV if missing or forced
if (forceDl || ~exist(rawCsv,'file')) && autoDl
    assert(isfield(cfg,'inputs') && isfield(cfg.inputs,'rawCsvUrl') && strlength(string(cfg.inputs.rawCsvUrl))>0, ...
        'cfg.inputs.rawCsvUrl missing/empty; cannot auto-download.');
    fprintf('Downloading FMHPI master CSV...\n  URL: %s\n  To:  %s\n', string(cfg.inputs.rawCsvUrl), rawCsv);
    hs.data.download_url_to_file(string(cfg.inputs.rawCsvUrl), rawCsv, 'Overwrite', true);

    % Lightweight sanity check on header
    fid = fopen(rawCsv,'r');
    assert(fid>0, 'Could not open downloaded CSV: %s', rawCsv);
    firstLine = fgetl(fid);
    fclose(fid);
    assert(contains(firstLine,"GEO_Type") && contains(firstLine,"Year") && contains(firstLine,"Month"), ...
        'Downloaded file does not look like FMHPI master CSV. First line: %s', firstLine);
end

assert(exist(rawCsv,'file')==2, 'Raw CSV not found: %s', rawCsv);

% ---------------- Read table ----------------
T = readtable(rawCsv, 'TextType','string');

% Required columns
reqCols = ["GEO_Type","GEO_Name","Year","Month","Index_SA","Index_NSA"];
assert(all(ismember(reqCols, string(T.Properties.VariableNames))), ...
    'FMHPI CSV missing required columns: %s', strjoin(reqCols(~ismember(reqCols,string(T.Properties.VariableNames))), ", "));

% --- State panel ---
Ts = T(T.GEO_Type=="State", :);
Ts.date = datetime(Ts.Year, Ts.Month, 1);

dates = unique(Ts.date);
dates = sort(dates);

stateCodes = unique(Ts.GEO_Name, 'stable');   % USPS codes (CSV order, usually stable)

% --- Add state names aligned with stateCodes (USPS) ---
xwPath = which('hs.spatial.us_state_crosswalk');
if ~isempty(xwPath)
    XW = hs.spatial.us_state_crosswalk();
elseif ~isempty(which('us_state_crosswalk'))
    XW = us_state_crosswalk();
else
    error('No state crosswalk found on MATLAB path.');
end

req = ["StateCode","State"];
assert(all(ismember(req, string(XW.Properties.VariableNames))), ...
    'Crosswalk table must contain columns: %s', strjoin(req, ", "));

stateCodesU = upper(strtrim(string(stateCodes)));
xwCodes = upper(strtrim(string(XW.StateCode)));
[tf, loc] = ismember(stateCodesU, xwCodes);

stateNames = strings(size(stateCodesU));
stateNames(tf) = string(XW.State(loc(tf)));

if any(~tf)
    missingCodes = stateCodesU(~tf);
    warning('No crosswalk name for these codes: %s', strjoin(cellstr(missingCodes), ", "));
    stateNames(~tf) = stateCodesU(~tf);
end

% --- Build state-level matrices (levels) ---
[~, col]  = ismember(Ts.GEO_Name, stateCodes);
[~, tidx] = ismember(Ts.date, dates);

X_sa  = accumarray([tidx, col], Ts.Index_SA,  [numel(dates), numel(stateCodes)], @mean, NaN);
X_nsa = accumarray([tidx, col], Ts.Index_NSA, [numel(dates), numel(stateCodes)], @mean, NaN);

% --- US aggregate ---
Tu = T(T.GEO_Type=="US", :);
Tu.date = datetime(Tu.Year, Tu.Month, 1);
[tfU, posU] = ismember(Tu.date, dates);
US_sa  = NaN(numel(dates),1);  US_sa(posU(tfU))  = Tu.Index_SA(tfU);
US_nsa = NaN(numel(dates),1);  US_nsa(posU(tfU)) = Tu.Index_NSA(tfU);

% --- Log diffs (monthly) ---
dlog_sa_states  = diff(log(X_sa));
dlog_sa_US      = diff(log(US_sa));

dlog_nsa_states = diff(log(X_nsa));
dlog_nsa_US     = diff(log(US_nsa));

dates_dlog      = dates(2:end);

% --- Optional deterministic deseasoning on NSA log diffs ---
% (A) Month-of-year demeaning (growth-rate seasonal pattern)
dlog_nsa_monthdemean_states = dlog_nsa_states;
dlog_nsa_monthdemean_US     = dlog_nsa_US;

mo = month(dates_dlog);
for m = 1:12
    idx = (mo == m);
    if any(idx)
        dlog_nsa_monthdemean_states(idx,:) = dlog_nsa_monthdemean_states(idx,:) - mean(dlog_nsa_monthdemean_states(idx,:), 1, 'omitnan');
        dlog_nsa_monthdemean_US(idx,:)     = dlog_nsa_monthdemean_US(idx,:)     - mean(dlog_nsa_monthdemean_US(idx,:), 1, 'omitnan');
    end
end

% (B) Year-on-year log diff (removes seasonality; changes sampling)
dlog12_nsa_states = log(X_nsa(13:end,:)) - log(X_nsa(1:end-12,:));
dlog12_nsa_US     = log(US_nsa(13:end))  - log(US_nsa(1:end-12));
dates_dlog12      = dates(13:end);

% ---------------- Manifest ----------------
manifest = struct();
manifest.createdUTC = datetime('now','TimeZone','UTC');
manifest.matlabVersion = version();

manifest.rawCsv = rawCsv;
manifest.rawUrl = "";
if isfield(cfg,'inputs') && isfield(cfg.inputs,'rawCsvUrl')
    manifest.rawUrl = string(cfg.inputs.rawCsvUrl);
end

d = dir(rawCsv);
manifest.rawBytes = d.bytes;
manifest.rawModified = datetime(d.datenum,'ConvertFrom','datenum');

% Hash for exact-vintage reproducibility (requires helper; if missing, leave blank)
manifest.rawSha256 = "";
try
    manifest.rawSha256 = string(hs.data.sha256_file(rawCsv));
catch ME
    warning('Could not compute SHA-256 (hs.data.sha256_file): %s', ME.message);
    manifest.rawSha256 = "";
end

manifest.outMat = outMat;

% ---------------- Save ----------------
save(outMat, ...
    'dates','dates_dlog','dates_dlog12', ...
    'stateCodes','stateNames', ...
    'X_sa','X_nsa', ...
    'US_sa','US_nsa', ...
    'dlog_sa_states','dlog_sa_US', ...
    'dlog_nsa_states','dlog_nsa_US', ...
    'dlog_nsa_monthdemean_states','dlog_nsa_monthdemean_US', ...
    'dlog12_nsa_states','dlog12_nsa_US', ...
    'manifest');

fprintf('Saved: %s\n', outMat);
fprintf('States: %d\n', numel(stateCodes));
fprintf('Range:  %s to %s (%d months)\n', string(dates(1)), string(dates(end)), numel(dates));
end