function [keep, codesIncluded, meta] = select_states(codesAll, cfg, varargin)
%HS.SPATIAL.SELECT_STATES  Select subset of states by include/exclude rules.
%
% [keep, codesIncluded, meta] = hs.spatial.select_states(codesAll, cfg, ...)
%
% Inputs
%   codesAll : (N x 1) string/cellstr of dataset state codes (e.g. USPS: "CA")
%   cfg      : config struct (expects cfg.geo.excludeUSPS if defaults used)
%
% Options
%   'IncludeUSPS'          : string/cellstr of codes to include (default: empty)
%   'ExcludeUSPS'          : string/cellstr of codes to exclude (default: empty)
%   'UseDefaultExclusions' : true/false (default: true)
%   'Strict'               : if true, error on unknown IncludeUSPS codes (default: true)
%   'CaseInsensitive'      : true/false (default: true)
%
% Precedence
%   1) If IncludeUSPS provided (non-empty): include exactly those (minus any ExcludeUSPS)
%   2) Else: include all, then remove ExcludeUSPS, and (if enabled) cfg.geo.excludeUSPS
%
% Outputs
%   keep         : (N x 1) logical mask on codesAll
%   codesIncluded: selected codes in the same order as codesAll
%   meta         : struct with details for reproducibility

p = inputParser;
p.addRequired('codesAll');
p.addRequired('cfg');
p.addParameter('IncludeUSPS', string.empty(0,1));
p.addParameter('ExcludeUSPS', string.empty(0,1));
p.addParameter('UseDefaultExclusions', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('Strict', true, @(b)islogical(b)&&isscalar(b));
p.addParameter('CaseInsensitive', true, @(b)islogical(b)&&isscalar(b));
p.parse(codesAll, cfg, varargin{:});
opt = p.Results;

codesAll = string(codesAll(:));
if opt.CaseInsensitive
    codesAllCmp = upper(codesAll);
else
    codesAllCmp = codesAll;
end

include = string(opt.IncludeUSPS(:));
exclude = string(opt.ExcludeUSPS(:));

if opt.CaseInsensitive
    includeCmp = upper(include);
    excludeCmp = upper(exclude);
else
    includeCmp = include;
    excludeCmp = exclude;
end

% Default exclusions from config
defaultExclude = string.empty(0,1);
if opt.UseDefaultExclusions
    if isfield(cfg,'geo') && isfield(cfg.geo,'excludeUSPS') && ~isempty(cfg.geo.excludeUSPS)
        defaultExclude = string(cfg.geo.excludeUSPS(:));
    else
        error('UseDefaultExclusions=true but cfg.geo.excludeUSPS is missing/empty.');
    end
end
if opt.CaseInsensitive
    defaultExcludeCmp = upper(defaultExclude);
else
    defaultExcludeCmp = defaultExclude;
end

% Start mask
keep = true(size(codesAllCmp));

% Include logic (highest precedence)
usedInclude = ~isempty(includeCmp);
unknownInclude = string.empty(0,1);

if usedInclude
    % Determine which requested include codes exist
    [tf, loc] = ismember(includeCmp, codesAllCmp);
    unknownInclude = include(~tf);
    if opt.Strict && any(~tf)
        example = unknownInclude(1);
        error('IncludeUSPS contains codes not present in dataset. Example: %s', example);
    end
    % Keep exactly those found
    keep = false(size(keep));
    keep(loc(tf)) = true;
end

% Apply exclusions (explicit + defaults)
excludeAllCmp = unique([excludeCmp; defaultExcludeCmp], 'stable');
if ~isempty(excludeAllCmp)
    keep = keep & ~ismember(codesAllCmp, excludeAllCmp);
end

% Outputs
codesIncluded = codesAll(keep);

meta = struct();
meta.codesAll = codesAll;
meta.codesIncluded = codesIncluded;
meta.includeUSPS = include;
meta.excludeUSPS = exclude;
meta.defaultExcludeUSPS = defaultExclude;
meta.useDefaultExclusions = opt.UseDefaultExclusions;
meta.usedInclude = usedInclude;
meta.strict = opt.Strict;
meta.caseInsensitive = opt.CaseInsensitive;
meta.unknownInclude = unknownInclude;

if usedInclude
    meta.reason = "IncludeUSPS";
else
    meta.reason = "ExcludeUSPS/defaults";
end

if ~any(keep)
    error('State selection produced empty set. Check Include/Exclude/default exclusions.');
end
end
