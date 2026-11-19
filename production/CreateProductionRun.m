function RunContext = CreateProductionRun(ProductionConfig)
%CREATEPRODUCTIONRUN Create a new production run workspace.
%
%   RunContext = CreateProductionRun(ProductionConfig)
%
%   Creates a unique production working-run directory and the artifact
%   directories required by the ASRTE production pipeline.
%
%   This function does not execute Blocks 1-8 and does not modify any
%   frozen scientific implementation.

    %% ============================================================
    % INPUT VALIDATION
    % =============================================================

    if nargin ~= 1

        error( ...
            'Production:CreateProductionRun:InvalidInputCount', ...
            'CreateProductionRun requires exactly one input: ProductionConfig.');

    end

    if ~isstruct(ProductionConfig) || ~isscalar(ProductionConfig)

        error( ...
            'Production:CreateProductionRun:InvalidProductionConfig', ...
            'ProductionConfig must be a scalar structure.');

    end

    RequiredFields = { ...
        'ProductionRoot'
        'RunsRoot'
        'WorkingRunsRoot'
        'FailedRunsRoot'
        'ScenarioSelector'
        'ScenarioID'
        'ScenarioName'
        };

    for Index = 1:numel(RequiredFields)

        FieldName = RequiredFields{Index};

        if ~isfield(ProductionConfig, FieldName) || ...
                isempty(ProductionConfig.(FieldName))

            error( ...
                'Production:CreateProductionRun:MissingConfigField', ...
                'ProductionConfig.%s is required.', ...
                FieldName);

        end

    end

    %% ============================================================
    % RESOLVE PRODUCTION ROOTS
    % =============================================================

    WorkingRunsRoot = char(ProductionConfig.WorkingRunsRoot);
    RunsRoot        = char(ProductionConfig.RunsRoot);
    FailedRunsRoot  = char(ProductionConfig.FailedRunsRoot);

    if ~isfolder(WorkingRunsRoot)
        mkdir(WorkingRunsRoot);
    end

    if ~isfolder(RunsRoot)
        mkdir(RunsRoot);
    end

    if ~isfolder(FailedRunsRoot)
        mkdir(FailedRunsRoot);
    end

    %% ============================================================
    % GENERATE UNIQUE PRODUCTION RUN ID
    %
    % Format:
    %
    %   Run_001_YYYYMMDD_HHMMSS
    %
    % If a directory with the same timestamp already exists, a
    % numeric suffix is appended to guarantee uniqueness.
    % =============================================================

    Timestamp = datetime( ...
        'now', ...
        'Format', 'yyyyMMdd_HHmmss');

    BaseRunID = sprintf( ...
        'Run_%03d_%s', ...
        1, ...
        char(Timestamp));

    RunID = BaseRunID;

    ExistingDirectories = dir(WorkingRunsRoot);

    ExistingNames = string({ExistingDirectories.name});

    Counter = 1;

    while any(ExistingNames == RunID)

        Counter = Counter + 1;

        RunID = sprintf( ...
            'Run_%03d_%s', ...
            Counter, ...
            char(Timestamp));

    end

    %% ============================================================
    % CREATE WORKING RUN DIRECTORY
    % =============================================================

    WorkingRunDirectory = ...
        fullfile(WorkingRunsRoot, RunID);

    if isfolder(WorkingRunDirectory)

        error( ...
            'Production:CreateProductionRun:RunDirectoryCollision', ...
            'Production working run directory already exists: %s', ...
            WorkingRunDirectory);

    end

    mkdir(WorkingRunDirectory);

    %% ============================================================
    % CREATE PRODUCTION ARTIFACT DIRECTORIES
    % =============================================================

    Block7Directory = ...
        fullfile(WorkingRunDirectory, 'Block7');

    GroundTruthDirectory = ...
        fullfile(WorkingRunDirectory, 'GroundTruth');

    IdealSensorDirectory = ...
        fullfile(WorkingRunDirectory, 'IdealSensorTelemetry');

    RealisticSensorDirectory = ...
        fullfile(WorkingRunDirectory, 'RealisticSensorTelemetry');

    DirectoryList = { ...
        Block7Directory
        GroundTruthDirectory
        IdealSensorDirectory
        RealisticSensorDirectory
        };

    for Index = 1:numel(DirectoryList)

        if ~isfolder(DirectoryList{Index})

            mkdir(DirectoryList{Index});

        end

    end

    %% ============================================================
    % BUILD RUN CONTEXT
    % =============================================================

    RunContext = struct();

    RunContext.RunID = RunID;

    RunContext.Status = 'WORKING';

    RunContext.CreatedAt = ...
        datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS');

    RunContext.ProductionRoot = ...
        char(ProductionConfig.ProductionRoot);

    RunContext.WorkingRunsRoot = ...
        WorkingRunsRoot;

    RunContext.RunsRoot = ...
        RunsRoot;

    RunContext.FailedRunsRoot = ...
        FailedRunsRoot;

    RunContext.WorkingRunDirectory = ...
        WorkingRunDirectory;

    RunContext.FinalRunDirectory = ...
        fullfile(RunsRoot, RunID);

    RunContext.FailedRunDirectory = ...
        fullfile(FailedRunsRoot, RunID);

    RunContext.Block7Directory = ...
        Block7Directory;

    RunContext.GroundTruthDirectory = ...
        GroundTruthDirectory;

    RunContext.IdealSensorDirectory = ...
        IdealSensorDirectory;

    RunContext.RealisticSensorDirectory = ...
        RealisticSensorDirectory;

    RunContext.ScenarioSelector = ...
        ProductionConfig.ScenarioSelector;

    RunContext.ScenarioID = ...
        ProductionConfig.ScenarioID;

    RunContext.ScenarioName = ...
        char(ProductionConfig.ScenarioName);

end