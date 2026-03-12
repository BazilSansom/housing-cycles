function tag = band_tag(lowF, upF)
%HS.UTIL.BAND_TAG  Canonical filename-safe tag for a year band.
%
% Examples:
%   band_tag(8,10)    -> '8_10y'
%   band_tag(12,14)   -> '12_14y'
%
% Convention matches phase intermediate filenames:
%   phase_<dataTag>_band_<bandTag>.mat

tag = sprintf('%.0f_%.0fy', lowF, upF);
tag = regexprep(tag, '[^a-zA-Z0-9_]+', '_');
tag = regexprep(tag, '^_+|_+$', '');
end