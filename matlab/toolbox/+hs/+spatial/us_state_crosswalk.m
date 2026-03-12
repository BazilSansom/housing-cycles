function C = us_state_crosswalk(path)
%HS.SPATIAL.US_STATE_CROSSWALK  Load canonical US state crosswalk table.
%
% Default path:
%   matlab/toolbox/resources/us_state_crosswalk.csv
%
% Expected columns:
%   State, StateCode, StLouisFedID, NumericID (NumericID optional)

if nargin < 1 || isempty(path)
    % This file is: matlab/toolbox/+hs/+spatial/us_state_crosswalk.m
    here = fileparts(mfilename('fullpath'));
    path = fullfile(here, '..', '..', 'resources', 'us_state_crosswalk.csv');
end

if ~exist(path, 'file')
    error('Crosswalk CSV not found: %s', path);
end

C = readtable(path, 'TextType','string');

% Basic validation
req = ["State","StateCode"];
missing = req(~ismember(req, string(C.Properties.VariableNames)));
if ~isempty(missing)
    error('Crosswalk missing required columns: %s', strjoin(cellstr(missing), ', '));
end

% Normalize whitespace
C.State = strtrim(C.State);
C.StateCode = upper(strtrim(C.StateCode));

if ismember("StLouisFedID", string(C.Properties.VariableNames))
    C.StLouisFedID = upper(strtrim(C.StLouisFedID));
end

end
