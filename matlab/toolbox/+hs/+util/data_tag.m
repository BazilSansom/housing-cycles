function tag = data_tag(label)
%HS.UTIL.DATA_TAG  Safe filename tag from a human-readable label.
label = lower(char(string(label)));
tag = regexprep(label, '[^a-z0-9]+', '_');
tag = regexprep(tag, '^_+|_+$', '');
if isempty(tag)
    tag = 'data';
end
end