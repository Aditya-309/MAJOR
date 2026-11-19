function Config = ProductionRunConfig(ScenarioSelector)
%PRODUCTIONRUNCONFIG Build production-run configuration.
%
%   Config = ProductionRunConfig(ScenarioSelector)
%
%   Establishes the production-layer filesystem and captures the
%   authoritative Block 6 scenario identity. No Block 1-8 computation
%   is executed here.

    %% Input validation

    if nargin ~= 1
        error( ...
            'Production:ProductionRunConfig:InvalidInputCount', ...
            ['ProductionRunConfig requires exactly one input: ' ...
             'ScenarioSelector.']);
    end

    if ~isnumeric(ScenarioSelector) || ...
            ~isscalar(ScenarioSelector) || ...
            ~isfinite(ScenarioSelector) || ...
            ScenarioSelector ~= floor(ScenarioSelector)

        error( ...
            'Production:ProductionRunConfig:InvalidScenarioSelector', ...
            'ScenarioSelector must be a finite integer scalar.');
    end

    if ScenarioSelector < 1 || ScenarioSelector > 6
        error( ...
            'Production:ProductionRunConfig:InvalidScenarioSelector', ...
            ['ScenarioSelector must be one of the six frozen Block 6 ' ...
             'scenario selectors (1 through 6).']);
    end


    %% Resolve production root and project root

    ProductionRoot = fileparts(mfilename('fullpath'));
    ProjectRoot = fileparts(ProductionRoot);

    if ~isfolder(ProjectRoot)
        error( ...
            'Production:ProductionRunConfig:InvalidProjectRoot', ...
            'Resolved project root does not exist.');
    end


    %% Ensure project root is available to MATLAB

    CurrentPathEntries = strsplit(path, pathsep);

    if ~any(strcmp(CurrentPathEntries, ProjectRoot))
        addpath(ProjectRoot);
    end


    %% Verify required frozen packages

    RequiredPackages = { ...
        '+config', ...
        '+flightscenario', ...
        '+groundtruthtelemetry', ...
        '+sensormodels', ...
        '+noisemodels', ...
        '+sensorsimulation'};

    for k = 1:numel(RequiredPackages)

        PackagePath = ...
            fullfile(ProjectRoot, RequiredPackages{k});

        if ~isfolder(PackagePath)

            error( ...
                'Production:ProductionRunConfig:MissingPackage', ...
                'Required frozen package directory is missing: %s', ...
                PackagePath);

        end
    end


    %% Verify frozen Block 6 entry point

    ScenarioConfigPath = ...
        which('flightscenario.ScenarioConfig');

    if isempty(ScenarioConfigPath)

        error( ...
            'Production:ProductionRunConfig:ScenarioConfigUnavailable', ...
            ['The frozen Block 6 entry point ' ...
             'flightscenario.ScenarioConfig could not be resolved.']);

    end


    %% Obtain authoritative Block 6 scenario

    Scenario = ...
        flightscenario.ScenarioConfig(ScenarioSelector);

    if ~isstruct(Scenario) || ~isscalar(Scenario)

        error( ...
            'Production:ProductionRunConfig:InvalidScenarioOutput', ...
            ['Frozen Block 6 ScenarioConfig did not return a ' ...
             'scalar structure.']);

    end


    %% Use the ACTUAL frozen Block 6 identity fields

    if ~isfield(Scenario,'ID')
        error( ...
            'Production:ProductionRunConfig:MissingScenarioID', ...
            'Frozen Block 6 scenario does not contain the required ID field.');
    end

    if ~isfield(Scenario,'Name')
        error( ...
            'Production:ProductionRunConfig:MissingScenarioName', ...
            'Frozen Block 6 scenario does not contain the required Name field.');
    end

    ScenarioID = Scenario.ID;
    ScenarioName = Scenario.Name;

    if ~isnumeric(ScenarioID) || ...
            ~isscalar(ScenarioID) || ...
            ~isfinite(ScenarioID)

        error( ...
            'Production:ProductionRunConfig:InvalidScenarioID', ...
            'Frozen Block 6 Scenario.ID is not a finite scalar.');
    end

    ScenarioName = char(string(ScenarioName));


    %% Production directories

    RunsRoot = ...
        fullfile(ProductionRoot,'Runs');

    WorkingRunsRoot = ...
        fullfile(ProductionRoot,'WorkingRuns');

    FailedRunsRoot = ...
        fullfile(ProductionRoot,'FailedRuns');

    RegistryFile = ...
        fullfile(ProductionRoot,'RunRegistry.json');


    %% Create production directories

    if ~isfolder(RunsRoot)
        mkdir(RunsRoot);
    end

    if ~isfolder(WorkingRunsRoot)
        mkdir(WorkingRunsRoot);
    end

    if ~isfolder(FailedRunsRoot)
        mkdir(FailedRunsRoot);
    end


    %% Assemble production configuration

    Config = struct();

    Config.ProjectRoot = ProjectRoot;
    Config.ProductionRoot = ProductionRoot;

    Config.RunsRoot = RunsRoot;
    Config.WorkingRunsRoot = WorkingRunsRoot;
    Config.FailedRunsRoot = FailedRunsRoot;

    Config.RegistryFile = RegistryFile;

    Config.ScenarioSelector = ScenarioSelector;
    Config.ScenarioID = ScenarioID;
    Config.ScenarioName = ScenarioName;

    Config.ScenarioConfigPath = ...
        char(string(ScenarioConfigPath));

end