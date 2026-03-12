function out = build_us_contiguity(shpFile, varargin)
%HS.SPATIAL.BUILD_US_CONTIGUITY  Build polygon map + contiguity for US states.
%
% out fields:
%   .states      shaperead struct (filtered)
%   .names       (n x 1) cellstr state names (order consistent everywhere)
%   .poly        (n x 1) polyshape polygons
%   .centroidXY  (n x 2) [x y] centroids for plotting
%   .A           (n x n) symmetric binary contiguity matrix
%   .G           graph(A, names)
%
% Notes:
% - Uses polybuffer trick to turn "touching boundary" into small overlap area.
% - Default excludes Alaska, Hawaii, and District of Columbia.

if nargin < 1 || isempty(shpFile)
    shpFile = which('usastatehi.shp');
    if isempty(shpFile)
        error(['Cannot find usastatehi.shp on the MATLAB path. ', ...
               'Do you have Mapping Toolbox installed, or the dataset available?']);
    end
end

% Parse inputs
p = inputParser;
p.addRequired('shpFile', @(s)(ischar(s) || isstring(s)) && strlength(string(s))>0);
p.addParameter('excludeNames', {'Alaska','Hawaii','District of Columbia'}, ...
    @(c)iscell(c) || isstring(c));
p.addParameter('buffer', 1e-4, @(x)isnumeric(x) && isscalar(x));
p.addParameter('areaTol', 1e-6, @(x)isnumeric(x) && isscalar(x));
p.parse(shpFile, varargin{:});

excludeNames = cellstr(p.Results.excludeNames);

% Load
states = shaperead(shpFile);

% Filter by name (robust)
keep = true(numel(states),1);
for i = 1:numel(states)
    if isfield(states,'Name') && any(strcmp(states(i).Name, excludeNames))
        keep(i) = false;
    end
end
states = states(keep);

names = {states.Name}';
n = numel(states);

% Build polyshapes robustly (handle NaN breaks)

ws = warning('off','MATLAB:polyshape:repairedBySimplify');

poly = repmat(polyshape(), n, 1);
for i = 1:n
    Xi = states(i).X(:);
    Yi = states(i).Y(:);
    % polyshape can handle NaNs; keep simplify on
    %poly(i) = polyshape(Xi, Yi, 'Simplify', true);
    poly(i) = polyshape(Xi, Yi, 'Simplify', true, 'KeepCollinearPoints', false);

end
warning(ws);

% Centroids for plotting graphs
[xc, yc] = centroid(poly);
centroidXY = [xc(:), yc(:)];

% Buffered polygons for adjacency detection
pfat = polybuffer(poly, p.Results.buffer);

% Build lower triangle adjacency then symmetrise
A = false(n,n);
for k = 1:n
    for j = (k+1):n
        % overlap area positive if buffered polygons overlap
        A(j,k) = area(intersect(pfat(j), pfat(k))) > p.Results.areaTol;
    end
end
A = A | A.';       % symmetric
A(1:n+1:end) = 0;  % zero diagonal

G = graph(sparse(A), names);

out = struct();
out.states = states;
out.names = names;
out.poly = poly;
out.centroidXY = centroidXY;
out.A = double(A);
out.G = G;
end
