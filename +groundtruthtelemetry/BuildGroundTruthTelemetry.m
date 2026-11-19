function GroundTruth = BuildGroundTruthTelemetry( ...
    Scenario, ...
    Timeline)
%BUILDGROUNDTRUTHTELEMETRY Generate validated Block 7 ground-truth telemetry.
%
%   GroundTruth = BuildGroundTruthTelemetry(Scenario, Timeline)
%
%   Executes the complete Block 7 ground-truth telemetry generation
%   pipeline:
%
%       Scenario + Timeline
%           ->
%       BuildJSBSimRun
%           ->
%       BuildJSBSimInitialization
%           ->
%       BuildJSBSimScript
%           ->
%       BuildJSBSimOutput
%           ->
%       RunJSBSim
%           ->
%       ConvertGroundTruthState
%           ->
%       ValidateGroundTruthTelemetry
%           ->
%       GroundTruth
%
%   The returned GroundTruth structure is the canonical validated Block 7
%   ground-truth telemetry representation.

    %% Input Validation

    if nargin ~= 2

        error( ...
            'Block7:BuildGroundTruthTelemetry:InvalidInputCount', ...
            ['BuildGroundTruthTelemetry requires exactly two inputs: ' ...
             'Scenario and Timeline.']);

    end

    if ~isstruct(Scenario) || ...
            ~isscalar(Scenario)

        error( ...
            'Block7:BuildGroundTruthTelemetry:InvalidScenario', ...
            'Scenario must be a scalar structure.');

    end

    if ~isstruct(Timeline) || ...
            ~isscalar(Timeline)

        error( ...
            'Block7:BuildGroundTruthTelemetry:InvalidTimeline', ...
            'Timeline must be a scalar structure.');

    end

    %% Build JSBSim Run Configuration

    RunConfig = ...
        groundtruthtelemetry.BuildJSBSimRun( ...
            Scenario, ...
            Timeline);

    %% Build JSBSim Initialization

    InitFile = ...
        groundtruthtelemetry.BuildJSBSimInitialization( ...
            RunConfig, ...
            Scenario);

    RunConfig.InitFile = InitFile;

    %% Build JSBSim Execution Script

    ScriptFile = ...
        groundtruthtelemetry.BuildJSBSimScript( ...
            RunConfig, ...
            Scenario, ...
            Timeline);

    RunConfig.ScriptFile = ScriptFile;

    %% Build JSBSim Output Definition

    OutputFile = ...
        groundtruthtelemetry.BuildJSBSimOutput( ...
            RunConfig);

    RunConfig.OutputFile = OutputFile;

    %% Execute JSBSim

    TelemetryFile = ...
        groundtruthtelemetry.RunJSBSim( ...
            RunConfig, ...
            ScriptFile);

    %% Convert Raw JSBSim Telemetry

    GroundTruth = ...
        groundtruthtelemetry.ConvertGroundTruthState( ...
            TelemetryFile);

    %% Validate Canonical Ground Truth

    groundtruthtelemetry.ValidateGroundTruthTelemetry( ...
        GroundTruth);

end