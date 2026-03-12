function download_url_to_file(url, outFile, varargin)
%HS.DATA.DOWNLOAD_URL_TO_FILE  Download URL to outFile (websave with curl fallback).
p = inputParser;
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results;

url = char(string(url));
outFile = char(string(outFile));

if exist(outFile,'file')==2 && ~opt.Overwrite
    return;
end

outDir = fileparts(outFile);
if ~isempty(outDir) && ~exist(outDir,'dir'); mkdir(outDir); end

tmp = [outFile '.download'];
if exist(tmp,'file')==2; delete(tmp); end

try
    opts = weboptions('Timeout', 120, 'UserAgent', 'Mozilla/5.0');
    websave(tmp, url, opts);
catch
    cmd = sprintf('curl -L --fail --silent --show-error -o "%s" "%s"', tmp, url);
    [status, msg] = system(cmd);
    assert(status==0, 'curl download failed: %s', msg);
end

movefile(tmp, outFile, 'f');
end