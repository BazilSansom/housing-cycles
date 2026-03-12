function ticksDt = year_ticks(t, stepYears, year0)
%HS.PLOT.YEAR_TICKS  Round-year tick locations as datetime.
%
% ticksDt = hs.plot.year_ticks(t, stepYears)
%   returns datetime ticks at Jan-01 every stepYears between min(t) and max(t),
%   aligned to the next multiple of stepYears.
%
% year0 (optional): force starting year.

t = t(:);
assert(isdatetime(t), 't must be datetime');

if nargin < 2 || isempty(stepYears)
    stepYears = 5;
end
if nargin < 3
    year0 = [];
end

tmin = min(t);
tmax = max(t);

if isempty(year0)
    y0 = year(tmin);
    y0 = stepYears * ceil(y0/stepYears);   % next multiple
else
    y0 = year0;
end

y1 = year(tmax);
tickYears = y0:stepYears:y1;
ticksDt = datetime(tickYears,1,1);
end
