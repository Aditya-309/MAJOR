function GroundTruth = GenerateGroundTruth(Scenario, Timeline)
%GENERATEGROUNDTRUTH Generate validated 200 Hz flight ground truth.
%
%   GroundTruth = GenerateGroundTruth(Scenario, Timeline)
%
%   Public entry point for Block 7.
%
%   Inputs
%   ------
%   Scenario
%       Frozen Block 6 scenario definition.
%
%   Timeline
%       Frozen Block 6 flight timeline.
%
%   Output
%   ------
%   GroundTruth
%       Validated immutable ground-truth structure in the project's
%       standard SI, NED, Body, WGS-84, ZYX Euler, and scalar-first
%       quaternion conventions.
%
%   Pipeline
%   --------
%   Scenario + Timeline
%       -> BuildJSBSimRun
%       -> BuildJSBSimInitialization
%       -> BuildJSBSimScript
%       -> BuildJSBSimOutput
%       -> RunJSBSim
%       -> ParseJSBSimTelemetry
%       -> ConvertGroundTruthState
%       -> ValidateGroundTruth
%       -> GroundTruth

    %% Input Validation

    if nargin ~= 2
        error( ...
            'Block7:GenerateGroundTruth:InvalidInputCount', ...
            'GenerateGroundTruth requires exactly two inputs: Scenario and Timeline.');
    end

    if ~isstruct(Scenario) || ~isscalar(Scenario)
        error( ...
            'Block7:GenerateGroundTruth:InvalidScenario', ...
            'Scenario must be a scalar structure.');
    end

    if ~isstruct(Timeline) || ~isscalar(Timeline)
        error( ...
            'Block7:GenerateGroundTruth:InvalidTimeline', ...
            'Timeline must be a scalar structure.');
    end

    %% Build Deterministic Run Configuration

    RunConfig = BuildJSBSimRun( ...
        Scenario, ...
        Timeline);

    %% Generate JSBSim Run Artifacts

    InitFile = BuildJSBSimInitialization( ...
        RunConfig, ...
        Scenario);

    ScriptFile = BuildJSBSimScript( ...
        RunConfig, ...
        Scenario, ...
        Timeline);

    OutputFile = BuildJSBSimOutput( ...
        RunConfig);

    %% Store Generated Artifact Paths

    RunConfig.InitFile = InitFile;
    RunConfig.ScriptFile = ScriptFile;
    RunConfig.OutputFile = OutputFile;

    %% Execute JSBSim

    TelemetryFile = RunJSBSim( ...
        RunConfig, ...
        ScriptFile);

    %% Parse Raw Telemetry

    RawTelemetry = ParseJSBSimTelemetry( ...
        TelemetryFile);

    %% Convert to Project Ground-Truth Conventions

    GroundTruth = ConvertGroundTruthState( ...
        RawTelemetry, ...
        RunConfig, ...
        Scenario);

    %% Validate Final Ground Truth

    Validation = ValidateGroundTruth( ...
        GroundTruth, ...
        Scenario, ...
        Timeline);

    GroundTruth.Validation = Validation;

end