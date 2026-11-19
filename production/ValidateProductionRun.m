function ValidationResult = ValidateProductionRun( ...
    ProductionConfig, ...
    RunResult)
%VALIDATEPRODUCTIONRUN Validate one completed ASRTE production run.
%
%   ValidationResult = ValidateProductionRun(ProductionConfig, RunResult)
%
%   Performs production-level validation of the already executed
%   Block 6 -> Block 7 -> Block 4 -> Block 5 -> Block 8 pipeline.
%
%   This function does not execute the frozen scientific blocks,
%   modify telemetry, write final run artifacts, or change run status.

    %% ============================================================
    % INPUT VALIDATION
    % ============================================================

    if nargin ~= 2
        error( ...
            'Production:ValidateProductionRun:InvalidInputCount', ...
            ['ValidateProductionRun requires exactly two inputs: ' ...
             'ProductionConfig and RunResult.']);
    end

    if ~isstruct(ProductionConfig) || ~isscalar(ProductionConfig)
        error( ...
            'Production:ValidateProductionRun:InvalidProductionConfig', ...
            'ProductionConfig must be a scalar structure.');
    end

    if ~isstruct(RunResult) || ~isscalar(RunResult)
        error( ...
            'Production:ValidateProductionRun:InvalidRunResult', ...
            'RunResult must be a scalar structure.');
    end

    %% ============================================================
    % REQUIRED TOP-LEVEL FIELDS
    % ============================================================

    RequiredResultFields = { ...
        'RunID'
        'Status'
        'RunContext'
        'Scenario'
        'Timeline'
        'GroundTruth'
        'IdealSensorTelemetry'
        'SensorTimeline'
        'NoiseConfig'
        'Noise'
        'NoisySensorTelemetry'
        'SimulationConfig'
        'RealisticSensorTelemetry'
        'OutputPaths'
        'Block7SourceDirectory'
        'Block7TelemetrySource'
        'Block7CapturedDirectory'
        };

    for Index = 1:numel(RequiredResultFields)

        FieldName = RequiredResultFields{Index};

        if ~isfield(RunResult, FieldName)
            error( ...
                'Production:ValidateProductionRun:MissingResultField', ...
                'RunResult.%s is required.', ...
                FieldName);
        end

    end

    %% ============================================================
    % RUN ID / STATUS
    % ============================================================

    if ~isequaln( ...
            RunResult.RunID, ...
            RunResult.RunContext.RunID)

        error( ...
            'Production:ValidateProductionRun:RunIDMismatch', ...
            'RunResult.RunID does not match RunContext.RunID.');
    end

    if ~strcmp(RunResult.Status, 'EXECUTED')

        error( ...
            'Production:ValidateProductionRun:InvalidExecutionStatus', ...
            ['RunResult.Status must be EXECUTED before production ' ...
             'validation. Current status: %s'], ...
            RunResult.Status);
    end

    %% ============================================================
    % SCENARIO VALIDATION
    % ============================================================

    Scenario = RunResult.Scenario;

    if ~isstruct(Scenario) || ~isscalar(Scenario)
        error( ...
            'Production:ValidateProductionRun:InvalidScenario', ...
            'RunResult.Scenario must be a scalar structure.');
    end

    if ~isfield(Scenario, 'ID') || ...
            ~isfield(Scenario, 'Name')

        error( ...
            'Production:ValidateProductionRun:IncompleteScenario', ...
            'Scenario.ID and Scenario.Name are required.');
    end

    if ~isequaln( ...
            Scenario.ID, ...
            ProductionConfig.ScenarioID)

        error( ...
            'Production:ValidateProductionRun:ScenarioIDMismatch', ...
            'Scenario.ID does not match ProductionConfig.ScenarioID.');
    end

    if ~isequaln( ...
            Scenario.Name, ...
            ProductionConfig.ScenarioName)

        error( ...
            'Production:ValidateProductionRun:ScenarioNameMismatch', ...
            'Scenario.Name does not match ProductionConfig.ScenarioName.');
    end

    %% ============================================================
    % TIMELINE VALIDATION
    % ============================================================

    Timeline = RunResult.Timeline;

    RequiredTimelineFields = { ...
        'Time_s'
        'NumberOfSamples'
        'SampleRate_Hz'
        'SampleTime_s'
        'Duration_s'
        'Controls'
        'Wind'
        'Events'
        };

    for Index = 1:numel(RequiredTimelineFields)

        FieldName = RequiredTimelineFields{Index};

        if ~isfield(Timeline, FieldName)
            error( ...
                'Production:ValidateProductionRun:MissingTimelineField', ...
                'Timeline.%s is required.', ...
                FieldName);
        end

    end

    Time_s = Timeline.Time_s(:);

    if isempty(Time_s) || any(~isfinite(Time_s))
        error( ...
            'Production:ValidateProductionRun:InvalidTimelineTime', ...
            'Timeline.Time_s must contain finite values.');
    end

    if any(diff(Time_s) <= 0)
        error( ...
            'Production:ValidateProductionRun:NonMonotonicTimeline', ...
            'Timeline.Time_s must be strictly increasing.');
    end

    if Timeline.NumberOfSamples ~= numel(Time_s)
        error( ...
            'Production:ValidateProductionRun:TimelineCountMismatch', ...
            'Timeline.NumberOfSamples does not match Time_s.');
    end

    if ~isscalar(Timeline.SampleRate_Hz) || ...
            ~isfinite(Timeline.SampleRate_Hz) || ...
            Timeline.SampleRate_Hz <= 0

        error( ...
            'Production:ValidateProductionRun:InvalidSampleRate', ...
            'Timeline.SampleRate_Hz must be positive and finite.');
    end

    if ~isscalar(Timeline.SampleTime_s) || ...
            ~isfinite(Timeline.SampleTime_s) || ...
            Timeline.SampleTime_s <= 0

        error( ...
            'Production:ValidateProductionRun:InvalidSampleTime', ...
            'Timeline.SampleTime_s must be positive and finite.');
    end

    %% ============================================================
    % GROUND TRUTH VALIDATION
    % ============================================================

    GroundTruth = RunResult.GroundTruth;

    RequiredGroundTruthFields = { ...
        'SampleCount'
        'SampleTime_s'
        'Time_s'
        'Position'
        'VelocityBody_mps'
        'AngularRateBody_radps'
        'Euler_rad'
        'AirDensity_kgpm3'
        'SourceFile'
        };

    for Index = 1:numel(RequiredGroundTruthFields)

        FieldName = RequiredGroundTruthFields{Index};

        if ~isfield(GroundTruth, FieldName)
            error( ...
                'Production:ValidateProductionRun:MissingGroundTruthField', ...
                'GroundTruth.%s is required.', ...
                FieldName);
        end

    end

    GroundTruthTime = GroundTruth.Time_s(:);

    if isempty(GroundTruthTime) || ...
            any(~isfinite(GroundTruthTime))

        error( ...
            'Production:ValidateProductionRun:InvalidGroundTruthTime', ...
            'GroundTruth.Time_s contains invalid values.');
    end

    if any(diff(GroundTruthTime) <= 0)
        error( ...
            'Production:ValidateProductionRun:GroundTruthTimeOrder', ...
            'GroundTruth.Time_s must be strictly increasing.');
    end

    if GroundTruth.SampleCount ~= numel(GroundTruthTime)
        error( ...
            'Production:ValidateProductionRun:GroundTruthCountMismatch', ...
            'GroundTruth.SampleCount does not match Time_s.');
    end

    if ~isfile(char(GroundTruth.SourceFile))
        error( ...
            'Production:ValidateProductionRun:GroundTruthSourceMissing', ...
            'GroundTruth.SourceFile does not exist.');
    end

    %% ============================================================
    % BLOCK 7 CAPTURE VALIDATION
    % ============================================================

    Block7Files = { ...
        fullfile(RunResult.Block7CapturedDirectory, 'Init.xml')
        fullfile(RunResult.Block7CapturedDirectory, 'Script.xml')
        fullfile(RunResult.Block7CapturedDirectory, 'Output.xml')
        fullfile(RunResult.Block7CapturedDirectory, 'Telemetry.csv')
        };

    Block7Names = { ...
        'Init.xml'
        'Script.xml'
        'Output.xml'
        'Telemetry.csv'
        };

    for Index = 1:numel(Block7Files)

        if ~isfile(Block7Files{Index})
            error( ...
                'Production:ValidateProductionRun:MissingCapturedArtifact', ...
                'Captured Block 7 artifact missing: %s', ...
                Block7Names{Index});
        end

        FileInfo = dir(Block7Files{Index});

        if isempty(FileInfo) || FileInfo.bytes <= 0
            error( ...
                'Production:ValidateProductionRun:EmptyCapturedArtifact', ...
                'Captured Block 7 artifact is empty: %s', ...
                Block7Names{Index});
        end

    end

    %% ============================================================
    % IDEAL SENSOR TELEMETRY VALIDATION
    % ============================================================

    Ideal = RunResult.IdealSensorTelemetry;

    SensorNames = { ...
        'GNSS'
        'IMU'
        'AirData'
        'Magnetometer'
        };

    for Index = 1:numel(SensorNames)

        SensorName = SensorNames{Index};

        if ~isfield(Ideal, SensorName)
            error( ...
                'Production:ValidateProductionRun:MissingIdealSensor', ...
                'IdealSensorTelemetry.%s is missing.', ...
                SensorName);
        end

        Sensor = Ideal.(SensorName);

        if ~isfield(Sensor, 'Time_s') || ...
                ~isfield(Sensor, 'SampleCount')

            error( ...
                'Production:ValidateProductionRun:IncompleteIdealSensor', ...
                ['IdealSensorTelemetry.%s must contain Time_s and ' ...
                 'SampleCount.'], ...
                SensorName);
        end

        if Sensor.SampleCount ~= numel(Sensor.Time_s)
            error( ...
                'Production:ValidateProductionRun:IdealCountMismatch', ...
                '%s ideal SampleCount does not match Time_s.', ...
                SensorName);
        end

    end

    %% ============================================================
    % REALISTIC SENSOR TELEMETRY VALIDATION
    % ============================================================

    Realistic = RunResult.RealisticSensorTelemetry;

    for Index = 1:numel(SensorNames)

        SensorName = SensorNames{Index};

        if ~isfield(Realistic, SensorName)
            error( ...
                'Production:ValidateProductionRun:MissingRealisticSensor', ...
                'RealisticSensorTelemetry.%s is missing.', ...
                SensorName);
        end

        Sensor = Realistic.(SensorName);

        if ~isfield(Sensor, 'Time_s') || ...
                ~isfield(Sensor, 'SampleCount')

            error( ...
                'Production:ValidateProductionRun:IncompleteRealisticSensor', ...
                ['RealisticSensorTelemetry.%s must contain Time_s ' ...
                 'and SampleCount.'], ...
                SensorName);
        end

        if Sensor.SampleCount ~= numel(Sensor.Time_s)
            error( ...
                'Production:ValidateProductionRun:RealisticCountMismatch', ...
                '%s realistic SampleCount does not match Time_s.', ...
                SensorName);
        end

    end

    %% ============================================================
    % SENSOR TIMELINE CONSISTENCY
    % ============================================================

    SensorTimeline = RunResult.SensorTimeline;

    for Index = 1:numel(SensorNames)

        SensorName = SensorNames{Index};

        if ~isfield(SensorTimeline, SensorName)
            error( ...
                'Production:ValidateProductionRun:MissingSensorTimeline', ...
                'SensorTimeline.%s is missing.', ...
                SensorName);
        end

        if ~isfield( ...
                SensorTimeline.(SensorName), ...
                'Time_s')

            error( ...
                'Production:ValidateProductionRun:IncompleteSensorTimeline', ...
                'SensorTimeline.%s.Time_s is missing.', ...
                SensorName);
        end

        if ~isequal( ...
                SensorTimeline.(SensorName).Time_s(:), ...
                Ideal.(SensorName).Time_s(:))

            error( ...
                'Production:ValidateProductionRun:SensorTimelineMismatch', ...
                ['SensorTimeline.%s does not match the corresponding ' ...
                 'ideal sensor timeline.'], ...
                SensorName);
        end

    end

    %% ============================================================
    % PRODUCTION DIRECTORY VALIDATION
    % ============================================================

    RunContext = RunResult.RunContext;

    RequiredDirectories = { ...
        RunContext.WorkingRunDirectory
        RunContext.Block7Directory
        RunContext.GroundTruthDirectory
        RunContext.IdealSensorDirectory
        RunContext.RealisticSensorDirectory
        };

    for Index = 1:numel(RequiredDirectories)

        if ~isfolder(RequiredDirectories{Index})

            error( ...
                'Production:ValidateProductionRun:MissingRunDirectory', ...
                'Required production directory is missing: %s', ...
                RequiredDirectories{Index});

        end

    end

    %% ============================================================
    % VALIDATION RESULT
    % ============================================================

    ValidationResult = struct();

    ValidationResult.Status = 'PASSED';

    ValidationResult.RunID = RunResult.RunID;

    ValidationResult.ScenarioID = Scenario.ID;

    ValidationResult.ScenarioName = Scenario.Name;

    ValidationResult.TimelineSampleCount = ...
        numel(Timeline.Time_s);

    ValidationResult.GroundTruthSampleCount = ...
        GroundTruth.SampleCount;

    ValidationResult.GNSSSampleCount = ...
        Ideal.GNSS.SampleCount;

    ValidationResult.IMUSampleCount = ...
        Ideal.IMU.SampleCount;

    ValidationResult.AirDataSampleCount = ...
        Ideal.AirData.SampleCount;

    ValidationResult.MagnetometerSampleCount = ...
        Ideal.Magnetometer.SampleCount;

    ValidationResult.Block7ArtifactCount = ...
        numel(Block7Files);

    ValidationResult.ValidatedAt = ...
        datetime('now', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS');

end