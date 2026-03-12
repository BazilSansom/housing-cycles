function startup_project()
repoRoot = fileparts(fileparts(mfilename('fullpath')));  % .../housing-cycles

% Core toolbox
addpath(genpath(fullfile(repoRoot, 'matlab', 'toolbox')));

% Empirical paper pipeline
addpath(fullfile(repoRoot, 'matlab', 'papers', 'empirical'));
addpath(fullfile(repoRoot, 'matlab', 'papers', 'empirical', 'analysis'));
addpath(fullfile(repoRoot, 'matlab', 'papers', 'empirical', 'config'));
%addpath(fullfile(repoRoot, 'matlab', 'papers', 'empirical', 'data','raw'));


% Local (git-ignored) config
localDir = fullfile(repoRoot, 'matlab', 'local');
cfgFile  = fullfile(localDir, 'path_config.m');

if exist(cfgFile, 'file')
    addpath(localDir);
    cfg = path_config();

    if isfield(cfg,'astoolbox') && exist(cfg.astoolbox,'dir')
        addpath(genpath(cfg.astoolbox));
    end
end

rehash;
end