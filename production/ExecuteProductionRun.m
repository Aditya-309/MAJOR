function RunResult = ExecuteProductionRun( ...
    ProductionConfig, ...
    RunContext)
%EXECUTEPRODUCTIONRUN Execute one ASRTE production computational run.
%
%   RunResult = ExecuteProductionRun(ProductionConfig, RunContext)
%
%   Executes the frozen Block 6 -> Block 7 -> Block 4 -> Block 5 ->
%   Block 8 computational chain inside an existing production working
%   run created by CreateProductionRun.
%
%   Frozen Blocks 1-8 are not modified.
%
%   Block 7 retains ownership of its own generated JSBSim artifacts.
%   Production captures those generated artifacts into the production
%   working-run directory after successful Block 7 execution.

    %% ============================================================
    % INPUT VALIDATION
    % ============================================================

    if nargin ~= 2

        error( ...
            'Production:ExecuteProductionRun:InvalidInputCount', ...
            ['ExecuteProductionRun requires exactly two inputs: ' ...
             'ProductionConfig and RunContext.']);

    end

    if ~isstruct(ProductionConfig) || ...
            ~isscalar(ProductionConfig)

        error( ...
            'Production:ExecuteProductionRun:InvalidProductionConfig', ...
            'ProductionConfig must be a scalar structure.');

    end

    if ~isstruct(RunContext) || ...
            ~isscalar(RunContext)

        error( ...
            'Production:ExecuteProductionRun:InvalidRunContext', ...
            'RunContext must be a scalar structure.');

    end

    %% ============================================================
    % REQUIRED PRODUCTION CONFIGURATION
    % =============================================================

    RequiredConfigFields = { ...
        'ScenarioSelector'
        'ScenarioID'
        'ScenarioName'
        };

    for Index = 1:numel(RequiredConfigFields)

        FieldName = RequiredConfigFields{Index};

        if ~isfield(ProductionConfig, FieldName)

            error( ...
                'Production:ExecuteProductionRun:MissingConfigField', ...
                'ProductionConfig.%s is required.', ...
                FieldName);

        end

    end

    %% ============================================================
    % REQUIRED RUN CONTEXT
    % =============================================================

    RequiredRunFields = { ...
        'RunID'
        'Status'
        'WorkingRunDirectory'
        'Block7Directory'
        'GroundTruthDirectory'
        'IdealSensorDirectory'
        'RealisticSensorDirectory'
        };

    for Index = 1:numel(RequiredRunFields)

        FieldName = RequiredRunFields{Index};

        if ~isfield(RunContext, FieldName) || ...
                isempty(RunContext.(FieldName))

            error( ...
                'Production:ExecuteProductionRun:MissingRunContextField', ...
                'RunContext.%s is required.', ...
                FieldName);

        end

    end

    if ~strcmp(RunContext.Status, 'WORKING')

        error( ...
            'Production:ExecuteProductionRun:InvalidRunStatus', ...
            ['RunContext must have status WORKING before execution. ' ...
             'Current status: %s'], ...
            RunContext.Status);

    end

    WorkingRunDirectory = ...
        char(RunContext.WorkingRunDirectory);

    if ~isfolder(WorkingRunDirectory)

        error( ...
            'Production:ExecuteProductionRun:WorkingDirectoryMissing', ...
            'Production working run directory does not exist: %s', ...
            WorkingRunDirectory);

    end

    %% ============================================================
    % BLOCK 6 — SCENARIO
    % ============================================================

    Scenario = ...
        flightscenario.ScenarioConfig( ...
            ProductionConfig.ScenarioSelector);

    %% ============================================================
    % VERIFY PRODUCTION SCENARIO IDENTITY
    % ============================================================

    if ~isequaln( ...
            Scenario.ID, ...
            ProductionConfig.ScenarioID)

        error( ...
            'Production:ExecuteProductionRun:ScenarioIDMismatch', ...
            ['Block 6 Scenario.ID does not match ProductionConfig.' ...
             'ScenarioID.']);

    end

    if ~isequaln( ...
            Scenario.Name, ...
            ProductionConfig.ScenarioName)

        error( ...
            'Production:ExecuteProductionRun:ScenarioNameMismatch', ...
            ['Block 6 Scenario.Name does not match ProductionConfig.' ...
             'ScenarioName.']);

    end

    %% ============================================================
    % BLOCK 6 — TIMELINE
    % ============================================================

    Timeline = ...
        flightscenario.BuildScenarioTimeline( ...
            Scenario);

    %% ============================================================
    % BLOCK 7 — GROUND TRUTH
    % ============================================================

    GroundTruth = ...
        groundtruthtelemetry.BuildGroundTruthTelemetry( ...
            Scenario, ...
            Timeline);

    %% ============================================================
    % VERIFY GROUND TRUTH
    % ============================================================

    if ~isstruct(GroundTruth) || ...
            ~isscalar(GroundTruth)

        error( ...
            'Production:ExecuteProductionRun:InvalidGroundTruth', ...
            'Frozen Block 7 did not return a scalar GroundTruth structure.');

    end

    if ~isfield(GroundTruth, 'SourceFile') || ...
            isempty(GroundTruth.SourceFile)

        error( ...
            'Production:ExecuteProductionRun:MissingGroundTruthSource', ...
            ['GroundTruth.SourceFile is required for production ' ...
             'Block 7 artifact capture.']);

    end

    Block7TelemetrySource = ...
        char(GroundTruth.SourceFile);

    if ~isfile(Block7TelemetrySource)

        error( ...
            'Production:ExecuteProductionRun:GroundTruthSourceMissing', ...
            ['GroundTruth.SourceFile does not exist:\n%s'], ...
            Block7TelemetrySource);

    end

    %% ============================================================
    % BLOCK 7 — RESOLVE ACTUAL GENERATED ARTIFACT DIRECTORY
    %
    % GroundTruth.SourceFile is the actual Telemetry.csv produced
    % by the frozen Block 7 execution.
    % =============================================================

    Block7SourceDirectory = ...
        fileparts(Block7TelemetrySource);

    Block7SourceArtifacts = { ...
        fullfile(Block7SourceDirectory, 'Init.xml')
        fullfile(Block7SourceDirectory, 'Script.xml')
        fullfile(Block7SourceDirectory, 'Output.xml')
        Block7TelemetrySource
        };

    Block7ArtifactNames = { ...
        'Init.xml'
        'Script.xml'
        'Output.xml'
        'Telemetry.csv'
        };

    %% ============================================================
    % VERIFY ALL FOUR BLOCK 7 ARTIFACTS
    % =============================================================

    for Index = 1:numel(Block7SourceArtifacts)

        if ~isfile(Block7SourceArtifacts{Index})

            error( ...
                'Production:ExecuteProductionRun:MissingBlock7Artifact', ...
                ['Frozen Block 7 artifact %s was not found at:\n%s'], ...
                Block7ArtifactNames{Index}, ...
                Block7SourceArtifacts{Index});

        end

    end

    %% ============================================================
    % CAPTURE BLOCK 7 ARTIFACTS
    % =============================================================

    Block7DestinationArtifacts = { ...
        fullfile(RunContext.Block7Directory, 'Init.xml')
        fullfile(RunContext.Block7Directory, 'Script.xml')
        fullfile(RunContext.Block7Directory, 'Output.xml')
        fullfile(RunContext.Block7Directory, 'Telemetry.csv')
        };

    for Index = 1:numel(Block7SourceArtifacts)

        [CopyStatus, CopyMessage] = ...
            copyfile( ...
                Block7SourceArtifacts{Index}, ...
                Block7DestinationArtifacts{Index}, ...
                'f');

        if ~CopyStatus

            error( ...
                'Production:ExecuteProductionRun:Block7ArtifactCopyFailed', ...
                ['Failed to capture Block 7 artifact %s.\n\n' ...
                 'Source: %s\n' ...
                 'Destination: %s\n' ...
                 'Reason: %s'], ...
                Block7ArtifactNames{Index}, ...
                Block7SourceArtifacts{Index}, ...
                Block7DestinationArtifacts{Index}, ...
                CopyMessage);

        end

    end

    %% ============================================================
    % BLOCK 4 — SENSOR CONFIGURATION
    % ============================================================

    SensorConfig = ...
        sensormodels.SensorConfig();

    %% ============================================================
    % BLOCK 4 — IDEAL SENSOR TELEMETRY
    % ============================================================

    IdealSensorTelemetry = ...
        sensormodels.BuildIdealSensorTelemetry( ...
            GroundTruth, ...
            SensorConfig, ...
            Scenario);

    %% ============================================================
    % BLOCK 5 — SENSOR TIMELINE
    % ============================================================

    SensorTimeline = struct();

    SensorTimeline.GNSS.Time_s = ...
        IdealSensorTelemetry.GNSS.Time_s;

    SensorTimeline.IMU.Time_s = ...
        IdealSensorTelemetry.IMU.Time_s;

    SensorTimeline.AirData.Time_s = ...
        IdealSensorTelemetry.AirData.Time_s;

    SensorTimeline.Magnetometer.Time_s = ...
        IdealSensorTelemetry.Magnetometer.Time_s;

    %% ============================================================
    % BLOCK 5 — GENERATE STOCHASTIC NOISE
    % ============================================================

    NoiseConfig = ...
        noisemodels.SensorNoiseConfig();

    Noise = ...
        noisemodels.GenerateSensorNoise( ...
            SensorTimeline, ...
            NoiseConfig);

    %% ============================================================
    % BLOCK 5 — APPLY STOCHASTIC NOISE
    % ============================================================

    NoisySensorTelemetry = ...
        noisemodels.ApplySensorNoise( ...
            IdealSensorTelemetry, ...
            Noise);

    %% ============================================================
    % BLOCK 8 — SENSOR SIMULATION
    % ============================================================

    SimulationConfig = ...
        sensorsimulation.SensorSimulationConfig();

    RealisticSensorTelemetry = ...
        sensorsimulation.BuildSensorSimulation( ...
            NoisySensorTelemetry, ...
            SimulationConfig);

    %% ============================================================
    % BLOCK 8 — WRITE REALISTIC SENSOR TELEMETRY
    % ============================================================

    OutputPaths = ...
        sensorsimulation.WriteSensorTelemetry( ...
            RealisticSensorTelemetry, ...
            RunContext.RealisticSensorDirectory);

    %% ============================================================
    % RETURN PRODUCTION EXECUTION RESULT
    % ============================================================

    RunResult = struct();

    RunResult.RunID = ...
        RunContext.RunID;

    RunResult.Status = ...
        'EXECUTED';

    RunResult.RunContext = ...
        RunContext;

    RunResult.Scenario = ...
        Scenario;

    RunResult.Timeline = ...
        Timeline;

    RunResult.GroundTruth = ...
        GroundTruth;

    RunResult.SensorConfig = ...
        SensorConfig;

    RunResult.IdealSensorTelemetry = ...
        IdealSensorTelemetry;

    RunResult.SensorTimeline = ...
        SensorTimeline;

    RunResult.NoiseConfig = ...
        NoiseConfig;

    RunResult.Noise = ...
        Noise;

    RunResult.NoisySensorTelemetry = ...
        NoisySensorTelemetry;

    RunResult.SimulationConfig = ...
        SimulationConfig;

    RunResult.RealisticSensorTelemetry = ...
        RealisticSensorTelemetry;

    RunResult.OutputPaths = ...
        OutputPaths;

    RunResult.Block7SourceDirectory = ...
        Block7SourceDirectory;

    RunResult.Block7TelemetrySource = ...
        Block7TelemetrySource;

    RunResult.Block7CapturedDirectory = ...
        char(RunContext.Block7Directory);

end