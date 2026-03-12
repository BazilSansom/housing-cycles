function startup_project()
repoRoot = fileparts(fileparts(mfilename('fullpath')));  % .../housing-cycles

% Your toolbox
addpath(genpath(fullfile(repoRoot, 'matlab', 'toolbox')));

% Local (git-ignored) config
localDir = fullfile(repoRoot, 'matlab', 'local');
cfgFile  = fullfile(localDir, 'path_config.m');

if exist(cfgFile, 'file')
    addpath(localDir);   % <-- this is the missing line
    cfg = path_config();

    if isfield(cfg,'astoolbox') && exist(cfg.astoolbox,'dir')
        addpath(genpath(cfg.astoolbox));
    end
end

rehash;
end
