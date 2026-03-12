function run_all_empirical(varargin)
%RUN_ALL_EMPIRICAL  One-command deterministic rebuild of empirical pipeline.
%
% Supported stages:
%   0. setup
%   1. data build
%   2. geography / Fiedler precompute
%   3. example state figure
%   4. power summary + mean WPS figure
%   5. phase-band data + global synchrony figure
%   6. neighbor coherence figure
%   7. graph Fourier diagnostics + main figure
%   8. graph Fourier top-M figure
%   9. phase gradient data + figure
%   10. snapshot figures
%  11. appendix figures
%  12. supplementary material
%  13. paper macros
%
% StopAfter values:
%   "setup" | "data" | "geo" | "example" | "power" | "synch" | "neighbor" |
%   "fourier" | "topm" | "gradient" | "snapshots" | "appendix" |
%   "supplement" | "macros" | "none"

p = inputParser;
p.addParameter('Overwrite', false, @(b)islogical(b)&&isscalar(b));
p.addParameter('StopAfter', "none", @(s)isstring(s)||ischar(s));
p.parse(varargin{:});
opt = p.Results;

stopAfter = lower(string(opt.StopAfter));

% ---------------- 0) Setup ----------------
rng(1);

here = fileparts(mfilename('fullpath'));   % .../empirical
analysisDir = fullfile(here, 'analysis');
configDir   = fullfile(here, 'config');
addpath(analysisDir);
addpath(configDir);

% Ensure toolbox root is on path (so +hs is visible)
matlabRoot = fileparts(fileparts(here));   % .../matlab
toolboxDir = fullfile(matlabRoot, 'toolbox');
if exist(toolboxDir,'dir')
    addpath(toolboxDir);
end

% Project startup (ASToolbox etc.)
if exist('startup_project','file') == 2
    startup_project;
end
rehash;

assert(exist('config_empirical','file') == 2, ...
    'config_empirical not found on path.');
cfg = config_empirical();

% Create dirs
mk = @(d) (exist(d,'dir') || mkdir(d));
mk(cfg.paths.outputs);
mk(cfg.paths.figures);
mk(cfg.paths.intermediate);
mk(cfg.paths.dataProcessed);
mk(cfg.paths.dataRaw);

fprintf('\n=== Empirical pipeline ===\n');
fprintf('  Overwrite: %d\n', opt.Overwrite);
fprintf('  Data series: %s\n', string(cfg.data.series));
if isfield(cfg.data,'nsa_deseason')
    fprintf('  NSA deseason: %s\n', string(cfg.data.nsa_deseason));
end
fprintf('  Config: %s\n', which('config_empirical'));

if stopAfter == "setup"; return; end


% ---------------- 1) Build dataset ----------------
fprintf('\n[1/11] build_dataset_fmhpi\n');
build_dataset_fmhpi('OverwriteProcessed', opt.Overwrite);

assert(exist(cfg.outputs.processedMat,'file') == 2, ...
    'Missing processed MAT: %s', cfg.outputs.processedMat);

S = load(cfg.outputs.processedMat);
need = {'dates','dates_dlog','stateCodes','stateNames', ...
        'dlog_sa_states','dlog_nsa_states','manifest'};
for k = 1:numel(need)
    assert(isfield(S, need{k}), 'Processed MAT missing field: %s', need{k});
end

fprintf('  OK: %d states, %s -> %s (dlog)\n', numel(S.stateCodes), ...
    datestr(S.dates_dlog(1)), datestr(S.dates_dlog(end)));
fprintf('  Raw SHA-256: %s\n', string(S.manifest.rawSha256));

if stopAfter == "data"; return; end


% ---------------- 2) Geography + Fiedler ----------------
fprintf('\n[2/11] run_precompute_geo\n');
run_precompute_geo();

assert(exist(cfg.outputs.geoMat,'file') == 2, ...
    'Missing geoMat: %s', cfg.outputs.geoMat);

G = load(cfg.outputs.geoMat);
geo = G.geo;

needGeo = {'A','L','names','poly','centroidXY','V','Z','evals', ...
           'colIdx','codes','v2','z','modeInfo'};
for k = 1:numel(needGeo)
    assert(isfield(geo, needGeo{k}), 'geo missing field: %s', needGeo{k});
end

Ncc = numel(geo.colIdx);
assert(all(size(geo.A) == [Ncc Ncc]), 'geo.A size mismatch');
assert(all(size(geo.L) == [Ncc Ncc]), 'geo.L size mismatch');
assert(size(geo.V,1) == Ncc && size(geo.Z,1) == Ncc, 'geo.V/Z rows mismatch');
assert(numel(geo.evals) == size(geo.V,2), 'evals length mismatch');
assert(numel(geo.codes) == Ncc, 'geo.codes length mismatch');

fprintf('  OK: geoMat N=%d, K=%d modes saved\n', Ncc, size(geo.V,2));

if stopAfter == "geo"; return; end


% ---------------- 3) Example state figure ----------------

fprintf('\n[3/13] make_fig_single_state_example\n');
make_fig_single_state_example('Overwrite', opt.Overwrite);

fprintf('\n[4/13] run_power_summary\n');
outPS = run_power_summary('Overwrite', opt.Overwrite, 'SaveCanonical', true);

if stopAfter == "example"; return; end


% ---------------- 4) Power summary + mean WPS figure ----------------
fprintf('\n[3/11] run_power_summary\n');
outPS = run_power_summary('Overwrite', opt.Overwrite, 'SaveCanonical', true);

fprintf('  Power summary uses: %s\n', string(outPS.meta.dataLabel));
assert(exist(outPS.files.figPdf,'file') == 2, 'Missing %s', outPS.files.figPdf);
assert(exist(outPS.files.intermediate,'file') == 2, 'Missing %s', outPS.files.intermediate);

if stopAfter == "power"; return; end

% ---------------- 5) Phase-band data + global synchrony figure ----------------
fprintf('\n[4/11] run_phase_band_data + make_fig_global_synchrony_bands\n');
run_phase_band_data('Overwrite', opt.Overwrite);
make_fig_global_synchrony_bands('Overwrite', opt.Overwrite);

if stopAfter == "synch"; return; end

% ---------------- 6) Neighbor coherence figure ----------------
fprintf('\n[5/11] run_neighbor_coherence_band_data + make_fig_neighbor_coherence_band\n');
run_neighbor_coherence_band_data('Overwrite', opt.Overwrite);
make_fig_neighbor_coherence_band('Overwrite', opt.Overwrite);

if stopAfter == "neighbor"; return; end

% ---------------- 7) Graph Fourier diagnostics + main figure ----------------
fprintf('\n[6/11] run_graph_fourier_diagnostics + make_fig_graph_fourier_band\n');
run_graph_fourier_diagnostics('Overwrite', opt.Overwrite);
make_fig_graph_fourier_band('Overwrite', opt.Overwrite);

if stopAfter == "fourier"; return; end

% ---------------- 8) Graph Fourier top-M figure ----------------
fprintf('\n[7/11] make_fig_graph_fourier_topm_band\n');
run_graph_fourier_topm_band_data('Overwrite', opt.Overwrite);
make_fig_graph_fourier_topm_band('Overwrite', opt.Overwrite);

if stopAfter == "topm"; return; end

% ---------------- 9) Phase gradient data + figure ----------------
fprintf('\n[8/11] run_phase_gradient_band_data + make_fig_phase_gradient_band\n');
run_phase_gradient_band_data('Overwrite', opt.Overwrite);
make_fig_phase_gradient_band('Overwrite', opt.Overwrite);

if stopAfter == "gradient"; return; end

% ---------------- 10) Snapshot figures ----------------
fprintf('\n[9/11] make_fig_relative_phase_snapshot_band\n');
make_fig_relative_phase_snapshot_band('Overwrite', opt.Overwrite);

if stopAfter == "snapshots"; return; end

% ---------------- 11) Appendix figures ----------------
fprintf('\n[10/11] make_fig_fiedler_v2_map\n');
make_fig_fiedler_v2_map('Overwrite', opt.Overwrite);

if stopAfter == "appendix"; return; end

% ---------------- 12) Supplementary material ----------------
fprintf('\n[11/12] supplementary phase GIFs\n');

fprintf('\n[11/12] make_phase_gif_band (main)\n');
make_phase_gif_band('BandKey', 'main', 'Overwrite', opt.Overwrite);

fprintf('\n[11/12] make_phase_gif_band (long)\n');
make_phase_gif_band('BandKey', 'long', 'Overwrite', opt.Overwrite);

if stopAfter == "supplement"; return; end


% ---------------- 13) Paper macros ----------------
fprintf('\n[12/12] make_paper_macros_empirical\n');
make_paper_macros_empirical('Overwrite', opt.Overwrite);

if stopAfter == "macros" || stopAfter == "none"
    fprintf('\n=== Pipeline complete ===\n');
end


end