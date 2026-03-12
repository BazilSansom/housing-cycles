function cfg = config_empirical()
%CONFIG_EMPIRICAL  Central configuration for empirical pipeline.

here = fileparts(mfilename('fullpath'));           % .../empirical/config
root = fileparts(here);                           % .../empirical

cfg = struct();


% ---------------- Paths ----------------
cfg.paths.root          = root;
cfg.paths.dataRaw       = fullfile(root, 'data', 'raw');
cfg.paths.dataProcessed = fullfile(root, 'data', 'processed');
cfg.paths.outputs       = fullfile(root, 'outputs');
cfg.paths.figures       = fullfile(cfg.paths.outputs, 'figures');
cfg.paths.intermediate  = fullfile(cfg.paths.outputs, 'intermediate');

cfg.inputs.rawCsv       = fullfile(cfg.paths.dataRaw, 'fmhpi_master_file.csv');
cfg.outputs.processedMat = fullfile(cfg.paths.dataProcessed, 'fmhpi_state_hpi.mat');

cfg.outputs.geoMat      = fullfile(cfg.paths.intermediate, 'geo_contiguity_fiedler.mat');
cfg.outputs.powerMat    = fullfile(cfg.paths.intermediate, 'wavelet_power_summary.mat');
%cfg.outputs.phaseMat    = fullfile(cfg.paths.intermediate, 'phase_band_10_12y.mat');
%cfg.outputs.modeLockMat = fullfile(cfg.paths.intermediate, 'mode_lock_dynamics.mat');

% ---------------- Data choice ----------------
cfg.inputs.rawCsvUrl = "https://www.freddiemac.com/fmac-resources/research/docs/fmhpi_master_file.csv";
cfg.data.autoDownload = true;
cfg.data.forceDownload = false;
cfg.data.series = "NSA";   % "SA" or "NSA"
% Optional: simple seasonal removal on NSA without full SA:
cfg.data.nsa_deseason = "yoy_diff"; % "none" | "month_demean" | "yoy_diff"


% ---------------- Geography ----------------
cfg.geo.excludeNames = {'Alaska','Hawaii','District of Columbia'};
cfg.geo.excludeUSPS = ["AK","HI","DC"];


% ---------------- Graph Fourier diagnostics ----------------
cfg.graphFourier = struct();

% Use all available modes (up to N) for diagnostics.
% (Inf means “use all modes available in geo.V”, capped at N.)
cfg.graphFourier.Kuse = Inf;

% Low-frequency cutoff for summaries: modes k=2..Klow
cfg.graphFourier.Klow = 8;

% Small denominator guard
cfg.graphFourier.DenomEps = 1e-8;

% Optional: save cumulative q(k) curves
cfg.graphFourier.SaveQCumulative = false;

% Default which modal shares to show in figures (plotting function uses this)
cfg.graphFourier.ShowShares = 2:5;

% ---------------- Laplacian eigenmodes ----------------
cfg.geo.nModesToSave = 100;   % capped at N by run_precompute_geo


% ---------------- Laplacian eigenmodes ----------------
%cfg.geo.nModesToSave = 48;      % save v1..v_{K} including constant (v1)
%cfg.geo.nModesToSave = max(cfg.geo.nModesToSave, cfg.graphFourier.Kuse);
%cfg.geo.nModesToPlot = 5;      % plot v2..v_{K}

% ---------------- Wavelets (ASToolbox) ----------------
cfg.wave.dt         = 1/12;
cfg.wave.dj         = 1/30;
cfg.wave.low_period = 1;    % minimum wavelet period in years
cfg.wave.up_period  = 25;
cfg.wave.pad        = 0;
cfg.wave.mother     = 'Morlet';
cfg.wave.beta       = 6.0;
cfg.wave.gamma      = 0;
cfg.wave.sig_type   = 'AR0';

% ---------------- Bands (years) ----------------
cfg.bands = struct();

% Primary “housing cycle” band (data-supported)
cfg.bands.main.lowF = 8;
cfg.bands.main.upF  = 10;

% Secondary slower component (COI sensitive)
cfg.bands.long.lowF = 11;
cfg.bands.long.upF  = 14;

% Backward-compatible alias (use MAIN as default)
%cfg.band.lowF = cfg.bands.main.lowF;
%cfg.band.upF  = cfg.bands.main.upF;

% Phase-origin calibration (global rotation only)
cfg.phaseCal.testPeriodYears = 11;
cfg.phaseCal.makePlot = false;

% ---------------- Snapshot ----------------
% Requested snapshot date; scripts snap to nearest observation in the data.
cfg.snapshot.tstar_req = datetime(1995,1,1);

%cfg.snapshot.long.tstar_req = datetime(1994,1,1);
cfg.snapshot.titleFmt = 'mmm yyyy';

% Title date format (used in figure titles)
%cfg.snapshot.titleFmt = "mmm yyyy";


% ---------------- Example sate ----------------

cfg.exampleState.code = "WA";
cfg.exampleState.name = "Washington";


% ---------------- Figure defaults ----------------
cfg.fig.dpi = 300;

% fit_phase_gradient grid-search settings
cfg.fig.betaRange = [-8 8];    % radians per 1 sd of v2
cfg.fig.betaGridN = 801;       % odd is nice; >= 201

end
