function Evaluation = EvaluateAgainstGroundTruth(RunID, InputInfo, InitInfo, ForwardEKF, ForwardUKF, SmoothingEKF, SmoothingUKF, Config, Paths)
%EVALUATEAGAINSTGROUNDTRUTH Post-estimation ground-truth evaluation.
%
%   Evaluation = EVALUATEAGAINSTGROUNDTRUTH(...) is the ONLY Block 10
%   function that reads ground truth. It is called strictly AFTER the
%   forward and smoothed reconstruction of both estimators has completed
%   (task document 13): ground truth is never an estimator input, an
%   initialization source, a tuning input or a measurement update.
%   The ground-truth separation test verifies this property.
%
%   The ground-truth file is resolved from the run directory
%   production/Runs/<RunID>/GroundTruth/GroundTruthTelemetry.mat and
%   loaded by variable inspection. The truth channels are:
%       GroundTruth.Time_s, .Position.Latitude_rad/.Longitude_rad/
%       .Altitude_m, .VelocityBody_mps (body axes!), .Euler_rad
%       ([roll pitch yaw]).
%
%   Truth preparation (evaluation only):
%       - position: converted to the SAME local NED frame as the
%         estimates (ConvertLLA2NED about InitInfo.Anchor);
%       - velocity: body velocity rotated to NED with the truth Euler
%         angles (coordinates.Euler2DCM);
%       - attitude: truth quaternion from coordinates.Euler2Quaternion;
%       - alignment: truth is interpolated at the estimate timestamps
%         (linear, after unwrap of roll and yaw for interpolation only).
%
%   Metrics per estimate series (ForwardEKF, SmoothedEKF, ForwardUKF,
%   SmoothedUKF) come from CalculateEstimationMetrics. Forward-versus-
%   smoothed error comparison and outage behaviour summaries are added;
%   where the corpus has no outages the field is reported
%   'NotApplicable' rather than glossed over.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: CalculateEstimationMetrics, CompareEstimators.

    %% Resolve and load ground truth (post-estimation stage)

    GroundTruthFile = fullfile(Paths.RunsRoot, RunID, 'GroundTruth', ...
        'GroundTruthTelemetry.mat');

    if ~isfile(GroundTruthFile)

        error( ...
            'Estimation:EvaluateAgainstGroundTruth:GroundTruthMissing', ...
            'Ground truth file not found: "%s".', GroundTruthFile);

    end

    Contents = whos('-file', GroundTruthFile);
    VariableName = '';

    for Index = 1:numel(Contents)

        if strcmp(Contents(Index).name, 'GroundTruth') && ...
                strcmp(Contents(Index).class, 'struct')

            VariableName = 'GroundTruth';
            break

        end

    end

    if isempty(VariableName)

        for Index = 1:numel(Contents)

            if strcmp(Contents(Index).class, 'struct') && ...
                    isscalar(Contents(Index).size)

                Candidate = load(GroundTruthFile, Contents(Index).name);
                Value = Candidate.(Contents(Index).name);

                if isstruct(Value) && isfield(Value, 'Time_s') && ...
                        isfield(Value, 'Position')

                    VariableName = Contents(Index).name;
                    break

                end

            end

        end

    end

    if isempty(VariableName)

        error( ...
            'Estimation:EvaluateAgainstGroundTruth:GroundTruthVariable', ...
            'No ground-truth structure found in "%s".', ...
            GroundTruthFile);

    end

    Loaded = load(GroundTruthFile, VariableName);
    GT = Loaded.(VariableName);

    %% Build truth series in the estimation NED frame

    Truth = struct();
    Truth.Time_s = GT.Time_s(:);

    [North, East, Down] = estimation.ConvertLLA2NED( ...
        GT.Position.Latitude_rad(:), GT.Position.Longitude_rad(:), ...
        GT.Position.Altitude_m(:), InitInfo.Anchor);
    Truth.PositionNED_m = [North, East, Down];

    Steps = numel(Truth.Time_s);
    Truth.VelocityNED_mps = zeros(Steps, 3);
    Truth.Quaternion = zeros(Steps, 4);

    for k = 1:Steps

        Euler = GT.Euler_rad(k, :);
        Cbn = coordinates.Euler2DCM(Euler(1), Euler(2), Euler(3));
        Truth.VelocityNED_mps(k, :) = ...
            (Cbn * GT.VelocityBody_mps(k, :)')';
        Truth.Quaternion(k, :) = coordinates.Euler2Quaternion( ...
            Euler(1), Euler(2), Euler(3));

    end

    Truth.Euler_rad = GT.Euler_rad;

    %% Interpolate truth at estimate times (evaluation only)

    QueryTimes = {ForwardEKF.Time_s, SmoothingEKF.Time_s, ...
        ForwardUKF.Time_s, SmoothingUKF.Time_s};
    QueryNames = {'ForwardEKF', 'SmoothedEKF', 'ForwardUKF', ...
        'SmoothedUKF'};
    QueryEstimates = {ForwardEKF, SmoothingEKF, ForwardUKF, SmoothingUKF};

    RollUnwrapped = unwrap(Truth.Euler_rad(:, 1));
    YawUnwrapped = unwrap(Truth.Euler_rad(:, 3));

    Evaluation = struct();
    Evaluation.Status = 'Completed';
    Evaluation.RunID = RunID;
    Evaluation.PreprocessID = InputInfo.PreprocessID;
    Evaluation.GroundTruthFile = GroundTruthFile;
    Evaluation.GroundTruthVariable = VariableName;
    Evaluation.Stage = 'PostEstimation';
    Evaluation.SeparationNote = [ ...
        'Ground truth was loaded only after the forward and smoothed ', ...
        'reconstructions completed; it was never an estimator input.'];

    for Index = 1:numel(QueryNames)

        T = QueryTimes{Index};
        Estimate = QueryEstimates{Index};

        if strcmp(QueryNames{Index}, 'SmoothedEKF') && ...
                ~strcmp(SmoothingEKF.Status, 'Smoothed')
            Evaluation.(QueryNames{Index}) = struct( ...
                'Status', SmoothingEKF.Status, ...
                'Limitation', SmoothingEKF.Limitation);
            continue
        end

        if strcmp(QueryNames{Index}, 'SmoothedUKF') && ...
                ~strcmp(SmoothingUKF.Status, 'Smoothed')
            Evaluation.(QueryNames{Index}) = struct( ...
                'Status', SmoothingUKF.Status, ...
                'Limitation', SmoothingUKF.Limitation);
            continue
        end

        TruthAt = struct();
        TruthAt.Time_s = T;
        % Numerical time-representation guard: measurement stream times and
        % the ground-truth grid can differ by double round-off (measured
        % 3.126e-13 s at the final sample, from separate CSV and MAT import
        % paths). Queries within 1e-9 s of the truth range boundary are snapped
        % to that boundary; queries further outside remain NaN (no silent
        % extrapolation) and are excluded from metrics with an explicit count
        % (CalculateEstimationMetrics records EvaluatedRows/ExcludedRows).
        % This is a floating-point representation tolerance, not a data-quality
        % or acceptance threshold.
        Tolerance_s = 1e-9;
        MaxTruthTime_s = max(Truth.Time_s);
        MinTruthTime_s = min(Truth.Time_s);
        TQ = T;
        EdgeHigh = TQ > MaxTruthTime_s & (TQ - MaxTruthTime_s) <= Tolerance_s;
        EdgeLow = TQ < MinTruthTime_s & (MinTruthTime_s - TQ) <= Tolerance_s;
        TQ(EdgeHigh) = MaxTruthTime_s;
        TQ(EdgeLow) = MinTruthTime_s;

        TruthAt.PositionNED_m = interp1(Truth.Time_s, ...
            Truth.PositionNED_m, TQ, 'linear');
        TruthAt.VelocityNED_mps = interp1(Truth.Time_s, ...
            Truth.VelocityNED_mps, TQ, 'linear');
        TruthAt.Euler_rad = [ ...
            interp1(Truth.Time_s, RollUnwrapped, TQ, 'linear'), ...
            interp1(Truth.Time_s, Truth.Euler_rad(:, 2), TQ, 'linear'), ...
            interp1(Truth.Time_s, YawUnwrapped, TQ, 'linear')];
        % Reviewer finding F11: quaternion interpolation with
        % hemisphere alignment and SLERP. Component-wise lerp is not an
        % appropriate interpolation on S^3 and fails outright across sign
        % flips (q and -q are the same rotation; raw series flip at Euler
        % wrap boundaries).
        TruthAt.Quaternion = estimation.SlerpQuaternions( ...
            Truth.Time_s, Truth.Quaternion, TQ);

        Metrics = estimation.CalculateEstimationMetrics( ...
            Estimate, TruthAt, Config, QueryNames{Index});
        Metrics.Status = 'Evaluated';
        Evaluation.(QueryNames{Index}) = Metrics;

    end

    %% Forward-versus-smoothed error comparison

    if strcmp(SmoothingEKF.Status, 'Smoothed')

        Evaluation.ForwardVersusSmoothed = struct( ...
            'EKFPosition3DRMSE_m', [ ...
                Evaluation.ForwardEKF.Position3DRMSE_m, ...
                Evaluation.SmoothedEKF.Position3DRMSE_m], ...
            'EKFAttitudeRMSE_rad', [ ...
                Evaluation.ForwardEKF.AttitudeAngularRMSE_rad, ...
                Evaluation.SmoothedEKF.AttitudeAngularRMSE_rad], ...
            'UKFPosition3DRMSE_m', [ ...
                Evaluation.ForwardUKF.Position3DRMSE_m, ...
                Evaluation.SmoothedUKF.Position3DRMSE_m], ...
            'UKFAttitudeRMSE_rad', [ ...
                Evaluation.ForwardUKF.AttitudeAngularRMSE_rad, ...
                Evaluation.SmoothedUKF.AttitudeAngularRMSE_rad], ...
            'Order', {'[forward, smoothed]'});

    else

        Evaluation.ForwardVersusSmoothed = struct( ...
            'Status', 'NotAvailable', ...
            'Limitation', SmoothingEKF.Limitation);

    end

    %% Outage-related error behaviour

    Evaluation.OutageErrorBehaviour = 'NotApplicable: no GNSS outage exists in this run.';

end

