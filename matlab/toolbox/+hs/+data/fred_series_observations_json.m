function tt = fred_series_observations_json(series_id, api_key, varargin)
%FRED_SERIES_OBSERVATIONS_JSON Download a FRED series (optionally "as-of" vintage date).
%
% tt = fred_series_observations_json("MIUR", api_key, ...
%     'ObservationStart',"1976-01-01", 'ObservationEnd',"2025-12-01", ...
%     'VintageDate',"2026-03-05");
%
% Notes:
% - Uses FRED API: /fred/series/observations with file_type=json
% - If VintageDate is set, we map it to realtime_start=realtime_end=VintageDate
%   (i.e., values known as-of that date).
%
% Docs: https://fred.stlouisfed.org/docs/api/fred/series_observations.html

p = inputParser;
p.addParameter('ObservationStart',"", @(x)isstring(x)||ischar(x)||isdatetime(x));
p.addParameter('ObservationEnd',"",   @(x)isstring(x)||ischar(x)||isdatetime(x));
p.addParameter('VintageDate',"",      @(x)isstring(x)||ischar(x)||isdatetime(x));
p.addParameter('Units',"",            @(x)isstring(x)||ischar(x));      % optional
p.addParameter('Frequency',"",        @(x)isstring(x)||ischar(x));      % optional
p.addParameter('AggregationMethod',"",@(x)isstring(x)||ischar(x));      % optional
p.addParameter('OutputType',1,        @(x)isnumeric(x)&&isscalar(x));   % default = 1
p.addParameter('Timeout',30,          @(x)isnumeric(x)&&isscalar(x)&&x>0);
p.parse(varargin{:});
opt = p.Results;

baseUrl = "https://api.stlouisfed.org/fred/series/observations";

% Build query parameters
q = struct();
q.series_id  = char(string(series_id));
q.api_key    = char(string(api_key));
q.file_type  = 'json';
q.output_type = opt.OutputType;

obsStart = toYMD(opt.ObservationStart);
obsEnd   = toYMD(opt.ObservationEnd);
if ~isempty(obsStart), q.observation_start = obsStart; end
if ~isempty(obsEnd),   q.observation_end   = obsEnd;   end

% Vintage snapshot: map to realtime_start/end
vint = toYMD(opt.VintageDate);
if ~isempty(vint)
    q.realtime_start = vint;
    q.realtime_end   = vint;
end

% Optional transforms (leave blank if not needed)
if strlength(string(opt.Units))>0,             q.units = char(string(opt.Units)); end
if strlength(string(opt.Frequency))>0,         q.frequency = char(string(opt.Frequency)); end
if strlength(string(opt.AggregationMethod))>0, q.aggregation_method = char(string(opt.AggregationMethod)); end

w = weboptions("Timeout", opt.Timeout, "ContentType","json");
S = webread(baseUrl, q, w);

% Parse to timetable
obs = S.observations;
d = datetime(string({obs.date})', "InputFormat","yyyy-MM-dd");
v = str2double(string({obs.value})');  % '.' -> NaN

tt = timetable(d, v, 'VariableNames', matlab.lang.makeValidName(cellstr(string(series_id))));
tt = sortrows(tt);

end

function s = toYMD(x)
if isdatetime(x)
    s = char(datetime(x,'Format','yyyy-MM-dd'));
else
    x = string(x);
    if strlength(x)==0
        s = '';
    else
        s = char(x);
    end
end
end