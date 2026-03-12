function [colIdx, uspsShp, uspsData] = match_shapefile_to_usps(shpNames, dataIds, varargin)
%HS.SPATIAL.MATCH_SHAPEFILE_TO_USPS
% Map shapefile state names (full names) to dataset column indices via USPS codes.
%
% Inputs:
%   shpNames       (n x 1) cellstr/string full state names (from shapefile: states.Name)
%   dataIds        (m x 1) cellstr/string data IDs (e.g. from FMHPI GEO_Name)
%   crosswalk      table from hs.spatial.us_state_crosswalk (optional)
%
% Outputs:
%   colIdx    (n x 1) indices such that dataset(:, colIdx) aligns with shpNames order
%   uspsShp   (n x 1) USPS codes corresponding to shpNames
%   uspsData  (m x 1) USPS codes corresponding to dataIds
%
% Example:
%   out = hs.spatial.build_us_contiguity([], 'excludeNames', {'Alaska','Hawaii','District of Columbia'});
%   S = load('fmhpi_state_hpi.mat'); % contains stateCodes
%   colIdx = hs.spatial.match_shapefile_to_usps(out.names, S.stateCodes);

% Options:
%   'Crosswalk'     table (default hs.spatial.us_state_crosswalk())
%   'DataIdType'    'usps' | 'name' | 'fred' | 'numeric'  (default 'usps')
%   'MissingPolicy' 'error' | 'nan'  (default 'error')

p = inputParser;
p.addRequired('shpNames');
p.addRequired('dataIds');
p.addParameter('Crosswalk', [], @(x)istable(x) || isempty(x));
p.addParameter('DataIdType', 'usps', @(s)ischar(s) || isstring(s));
p.addParameter('MissingPolicy', 'error', @(s)ischar(s) || isstring(s));
p.parse(shpNames, dataIds, varargin{:});

C = p.Results.Crosswalk;
if isempty(C), C = hs.spatial.us_state_crosswalk(); end

shpNames = string(shpNames(:));
dataIds  = string(dataIds(:));

% --- 1) Shapefile Name -> USPS
[tfS, locS] = ismember(strtrim(shpNames), strtrim(C.State));
if ~all(tfS)
    missing = shpNames(~tfS);
    error('Shapefile names not in crosswalk: %s', strjoin(cellstr(missing(1:min(10,end))), ', '));
end
uspsShp = upper(strtrim(C.StateCode(locS)));

% --- 2) Data IDs -> USPS depending on DataIdType
switch lower(string(p.Results.DataIdType))
    case "usps"
        uspsData = upper(strtrim(dataIds));
    case "name"
        [tfD, locD] = ismember(strtrim(dataIds), strtrim(C.State));
        if ~all(tfD)
            missing = dataIds(~tfD);
            error('Data state names not in crosswalk: %s', strjoin(cellstr(missing(1:min(10,end))), ', '));
        end
        uspsData = upper(strtrim(C.StateCode(locD)));
    case "fred"
        if ~ismember("StLouisFedID", string(C.Properties.VariableNames))
            error('Crosswalk has no StLouisFedID column.');
        end
        [tfD, locD] = ismember(upper(strtrim(dataIds)), upper(strtrim(C.StLouisFedID)));
        if ~all(tfD)
            missing = dataIds(~tfD);
            error('Data FRED IDs not in crosswalk: %s', strjoin(cellstr(missing(1:min(10,end))), ', '));
        end
        uspsData = upper(strtrim(C.StateCode(locD)));
    case "numeric"
        if ~ismember("NumericID", string(C.Properties.VariableNames))
            error('Crosswalk has no NumericID column.');
        end
        num = double(dataIds);
        [tfD, locD] = ismember(num, C.NumericID);
        if ~all(tfD)
            missing = dataIds(~tfD);
            error('Data NumericIDs not in crosswalk.');
        end
        uspsData = upper(strtrim(C.StateCode(locD)));
    otherwise
        error('Unsupported DataIdType: %s', p.Results.DataIdType);
end

% --- 3) USPS -> dataset column indices
[tf, colIdx] = ismember(uspsShp, uspsData);
if ~all(tf)
    switch lower(string(p.Results.MissingPolicy))
        case "error"
            missing = uspsShp(~tf);
            error('States in shapefile missing from dataset: %s', strjoin(cellstr(missing(1:min(10,end))), ', '));
        case "nan"
            colIdx(~tf) = NaN;
        otherwise
            error('Unsupported MissingPolicy: %s', p.Results.MissingPolicy);
    end
end

colIdx = colIdx(:);
end