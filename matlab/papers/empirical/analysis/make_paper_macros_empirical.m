function make_paper_macros_empirical(varargin)

p = inputParser;
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.parse(varargin{:});
opt = p.Results; %#ok<NASGU>

cfg = config_empirical();

% -------------------------------------------------------------------------
% Build stats struct here from realised outputs
% -------------------------------------------------------------------------
stats = struct();

% Example sample metadata from processed data
S = load(cfg.outputs.processedMat);
stats.sampleStartLabel = datestr(S.dates(1), 'mmmm yyyy');
stats.sampleEndLabel   = datestr(S.dates(end), 'mmmm yyyy');
stats.sampleStartYear  = year(S.dates(1));
stats.sampleEndYear    = year(S.dates(end));

% Example contiguous-state count from geo
G = load(cfg.outputs.geoMat);
stats.nContigStates = numel(G.geo.names);

% Example requested snapshot used in paper
stats.snapshotUsedLabel = datestr(cfg.snapshot.tstar_req, 'mmm yyyy');

% Add your empirical band summaries here:
%   stats.v2spread_90_10 = ...
%   stats.bands = ...

outTexPath = fullfile(cfg.paths.root, 'paper_macros_empirical.tex');
write_paper_macros_empirical(cfg, stats, outTexPath);

fprintf('Wrote macros: %s\n', outTexPath);
end