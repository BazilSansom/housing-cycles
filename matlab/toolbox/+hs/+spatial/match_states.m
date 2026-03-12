function out = match_states(shpIds, dataIds, varargin)
%HS.SPATIAL.MATCH_STATES  Match/align state identifiers between two systems via a crosswalk.
%
% out fields:
%   .colIdx      indices into dataIds corresponding to shpIds order
%   .usps_shp    USPS codes for shpIds (after crosswalk)
%   .usps_data   USPS codes for dataIds (after crosswalk)
%   .missing_shp states in shpIds not found in crosswalk
%   .missing_data ids in dataIds not mapped to USPS under DataIdType
%   .missing_in_dataset USPS codes implied by shpIds but not found in dataset
%
% Defaults:
%   ShapefileIdType = 'name'   (because shapefile uses full state names)
%   DataIdType      = 'usps'   (FMHPI uses USPS codes)
%   MissingPolicy   = 'error'  ('nan' returns NaN indices for missing_in_dataset)
%
% Supported ID types (for shpIds and/or dataIds):
%   'name'    full state name (e.g., "Massachusetts")
%   'usps'    2-letter code   (e.g., "MA")
%   'fred'    St Louis Fed ID (e.g., "MAURN") if present in crosswalk
%   'numeric' NumericID       (your internal IDs) if present in crosswalk

p = inputParser;
p.addRequired('shpIds');
p.addRequired('dataIds');
p.addParameter('Crosswalk', [], @(x)istable(x) || isempty(x));
p.addParameter('ShapefileIdType', 'name', @(s)ischar(s) || isstring(s));
p.addParameter('DataIdType', 'usps', @(s)ischar(s) || isstring(s));
p.addParameter('MissingPolicy', 'error', @(s)ischar(s) || isstring(s));
p.parse(shpIds, dataIds, varargin{:});

C = p.Results.Crosswalk;
if isempty(C)
    C = hs.spatial.us_state_crosswalk();
end

shpIds  = string(shpIds(:));
dataIds = string(dataIds(:));

% --- Convert both sides to USPS ---
[usps_shp, missing_shp]   = local_to_usps(shpIds,  lower(string(p.Results.ShapefileIdType)), C);
[usps_data, missing_data] = local_to_usps(dataIds, lower(string(p.Results.DataIdType)),      C);

if ~isempty(missing_shp)
    error('match_states:ShapefileIdsNotInCrosswalk', ...
        'Some shapefile IDs not found in crosswalk (type=%s). Example: %s', ...
        p.Results.ShapefileIdType, missing_shp(1));
end
if ~isempty(missing_data)
    error('match_states:DataIdsNotInCrosswalk', ...
        'Some dataset IDs not found in crosswalk (type=%s). Example: %s', ...
        p.Results.DataIdType, missing_data(1));
end

% --- Match USPS codes ---
[tf, colIdx] = ismember(usps_shp, usps_data);
missing_in_dataset = usps_shp(~tf);

if ~all(tf)
    switch lower(string(p.Results.MissingPolicy))
        case "error"
            error('match_states:StatesMissingFromDataset', ...
                'Some states implied by shapefile are missing from dataset. Example USPS: %s', ...
                missing_in_dataset(1));
        case "nan"
            colIdx(~tf) = NaN;
        otherwise
            error('Unsupported MissingPolicy: %s', p.Results.MissingPolicy);
    end
end

out = struct();
out.colIdx = colIdx(:);
out.usps_shp = usps_shp(:);
out.usps_data = usps_data(:);
out.missing_shp = missing_shp(:);
out.missing_data = missing_data(:);
out.missing_in_dataset = missing_in_dataset(:);
end

function [usps, missing] = local_to_usps(ids, idType, C)
ids = strtrim(ids);
missing = strings(0,1);

switch idType
    case "usps"
        usps = upper(ids);

    case "name"
        [tf, loc] = ismember(ids, strtrim(string(C.State)));
        if ~all(tf)
            missing = ids(~tf);
            usps = strings(size(ids));
            usps(tf) = upper(strtrim(string(C.StateCode(loc(tf)))));
        else
            usps = upper(strtrim(string(C.StateCode(loc))));
        end

    case "fred"
        if ~ismember("StLouisFedID", string(C.Properties.VariableNames))
            error('Crosswalk missing StLouisFedID column.');
        end
        key = upper(strtrim(string(C.StLouisFedID)));
        [tf, loc] = ismember(upper(ids), key);
        if ~all(tf)
            missing = ids(~tf);
            usps = strings(size(ids));
            usps(tf) = upper(strtrim(string(C.StateCode(loc(tf)))));
        else
            usps = upper(strtrim(string(C.StateCode(loc))));
        end

    case "numeric"
        if ~ismember("NumericID", string(C.Properties.VariableNames))
            error('Crosswalk missing NumericID column.');
        end
        num = double(ids);
        [tf, loc] = ismember(num, C.NumericID);
        if ~all(tf)
            missing = ids(~tf);
            usps = strings(size(ids));
            usps(tf) = upper(strtrim(string(C.StateCode(loc(tf)))));
        else
            usps = upper(strtrim(string(C.StateCode(loc))));
        end

    otherwise
        error('Unsupported idType: %s', idType);
end
end
