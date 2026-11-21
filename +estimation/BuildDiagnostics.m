function Diagnostics = BuildDiagnostics(ForwardEKF, ForwardUKF, SmoothingEKF, SmoothingUKF, RunLogEKF, RunLogUKF, Timeline, InitInfo, Config)
%BUILDDIAGNOSTICS Assemble the full Block 10 diagnostics package.
%
%   Diagnostics = BUILDDIAGNOSTICS(...) runs the research-oriented
%   diagnostic calculators over the recorded estimator evidence and
%   returns the EstimationResults.Diagnostics hierarchy:
%
%       .Innovations        - per-update innovation records (both filters)
%       .SensorContribution - per-stream contribution evidence
%       .Confidence         - uncertainty assessment (forward/smoothed)
%       .Integrity          - composite integrity indicator + components
%       .ModelMismatch      - residual patterns and EKF/UKF disagreement
%       .Investigation      - evidence-linked events
%
%   All quantities are computed from estimator evidence only; ground
%   truth is never read here.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: CalculateConfidence, CalculateSensorContribution,
%   CalculateIntegrityIndex, DetectModelMismatch,
%   BuildInvestigationEvents.

    Confidence = struct();
    Confidence.EKF = estimation.CalculateConfidence( ...
        ForwardEKF, SmoothingEKF, Config);
    Confidence.UKF = estimation.CalculateConfidence( ...
        ForwardUKF, SmoothingUKF, Config);

    SensorContribution = struct();
    SensorContribution.EKF = ...
        estimation.CalculateSensorContribution(RunLogEKF);
    SensorContribution.UKF = ...
        estimation.CalculateSensorContribution(RunLogUKF);

    Integrity = struct();
    Integrity.EKF = estimation.CalculateIntegrityIndex( ...
        ForwardEKF, RunLogEKF, Config);
    Integrity.UKF = estimation.CalculateIntegrityIndex( ...
        ForwardUKF, RunLogUKF, Config);

    ModelMismatch = estimation.DetectModelMismatch( ...
        ForwardEKF, ForwardUKF, RunLogEKF, Config);

    Events = estimation.BuildInvestigationEvents( ...
        Timeline, RunLogEKF, RunLogUKF, ForwardEKF, SmoothingEKF, ...
        Confidence.EKF, Integrity.EKF, ModelMismatch, InitInfo, Config);

    Diagnostics = struct();
    Diagnostics.Innovations = struct('EKF', RunLogEKF.Updates, ...
        'UKF', RunLogUKF.Updates);
    Diagnostics.SensorContribution = SensorContribution;
    Diagnostics.Confidence = Confidence;
    Diagnostics.Integrity = Integrity;
    Diagnostics.ModelMismatch = ModelMismatch;
    Diagnostics.Investigation = struct('Events', Events, ...
        'EventCount', numel(Events));
    Diagnostics.AirData = struct('EKF', RunLogEKF.AirData, ...
        'UKF', RunLogUKF.AirData);

end
