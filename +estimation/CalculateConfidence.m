function Confidence = CalculateConfidence(Forward, Smoothing, Config)
%CALCULATECONFIDENCE Confidence and uncertainty assessment from covariance.
%
%   Confidence = CALCULATECONFIDENCE(Forward, Smoothing, Config,
%   NoiseModels) derives per-step uncertainty outputs from the filter
%   covariance (forward and, when available, smoothed) and classifies
%   where the estimate is well constrained, relaxing, tightening or
%   poorly constrained.
%
%   Confidence outputs are uncertainty statements about the estimator,
%   not guarantees of actual error (a covariance is only as good as the
%   model behind it); the ground-truth evaluation in
%   EvaluateAgainstGroundTruth measures the actual errors separately.
%
%   Fields:
%       .Time_s              - forward step times
%       .SigmaPosition_m     - Sx3 forward 1-sigma NED position
%       .SigmaVelocity_mps   - Sx3 forward 1-sigma NED velocity
%       .SigmaAttitude_rad   - Sx3 forward 1-sigma roll/pitch/yaw
%       .SigmaSmoothed*      - the same from the smoothed covariance
%       .Constrained         - Sx1 logical (see rule below)
%       .Trend               - Sx1 cellstr: 'Tightening', 'Stable',
%                              'Relaxing'
%       .Summary             - max/mean sigmas, constrained fraction,
%                              poorly constrained intervals
%
%   Constrained rule (thresholds derived from the configured sensor
%   noise, not invented): a step is 'Constrained' when the filter
%   position uncertainty is at or below the configured GNSS position
%   measurement noise on every axis, i.e. the fused estimate is at least
%   as precise as a raw position measurement; otherwise it is flagged
%   'PoorlyConstrained' and reported with its interval.
%
%   Trend rule: the relative change per second of the navigation-state
%   variance trace over a 1 s span is compared against a documented 5%
%   engineering threshold (hysteresis against numerical jitter in an
%   otherwise steady covariance); the threshold is recorded in the
%   output.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: CalculateIntegrityIndex, BuildDiagnostics,
%   EvaluateAgainstGroundTruth.

    Definition = estimation.StateDefinition();
    Idx = Definition.Index;

    Steps = numel(Forward.Time_s);
    SigmaP = sqrt(Forward.CovDiag(:, Idx.pN:Idx.pD));
    SigmaV = sqrt(Forward.CovDiag(:, Idx.vN:Idx.vD));
    SigmaA = sqrt(Forward.CovDiag(:, Idx.roll:Idx.yaw));

    % Constrained rule: position sigma at or below raw GNSS noise.
    NoiseGNSS = Config.Noise.GNSS;
    FloorH = NoiseGNSS.HorizontalSigma_m;
    FloorV = NoiseGNSS.VerticalSigma_m;
    Constrained = SigmaP(:, 1) <= FloorH & ...
        SigmaP(:, 2) <= FloorH & SigmaP(:, 3) <= FloorV;

    % Trend of the navigation variance trace (1 s span).
    NavSpan = [Idx.pN:Idx.pD, Idx.vN:Idx.vD, Idx.roll:Idx.yaw];
    TraceNav = sum(Forward.CovDiag(:, NavSpan), 2);
    TrendThreshold = 0.05;
    Trend = cell(Steps, 1);

    for k = 1:Steps

        t = Forward.Time_s(k);
        Span = Forward.Time_s >= t - 1 & Forward.Time_s <= t;
        Indices = find(Span);

        if numel(Indices) < 2

            Trend{k} = 'Stable';

        else

            % Reviewer finding F10: the threshold is PER SECOND, so the
            % relative change is normalized by the ACTUAL elapsed time of
            % the span. At startup and under irregular sampling the span
            % is shorter than 1 s; comparing its raw change against a
            % per-second threshold would misclassify the rate.
            Elapsed_s = Forward.Time_s(Indices(end)) - ...
                Forward.Time_s(Indices(1));

            if Elapsed_s <= 0

                Trend{k} = 'Stable';

            else

                RelativeChangePerSecond = ...
                    ((TraceNav(Indices(end)) - TraceNav(Indices(1))) / ...
                    max(TraceNav(Indices(1)), eps)) / Elapsed_s;

                if RelativeChangePerSecond > TrendThreshold
                    Trend{k} = 'Relaxing';
                elseif RelativeChangePerSecond < -TrendThreshold
                    Trend{k} = 'Tightening';
                else
                    Trend{k} = 'Stable';
                end

            end

        end

    end

    % Poorly constrained intervals (contiguous runs).
    Intervals = contiguousIntervals(~Constrained, Forward.Time_s);

    Confidence = struct();
    Confidence.Time_s = Forward.Time_s;
    Confidence.SigmaPosition_m = SigmaP;
    Confidence.SigmaVelocity_mps = SigmaV;
    Confidence.SigmaAttitude_rad = SigmaA;
    Confidence.Constrained = Constrained;
    Confidence.Trend = Trend;
    Confidence.Thresholds = struct( ...
        'PositionFloor_m', [FloorH, FloorH, FloorV], ...
        'PositionFloorSource', [ ...
            'Configured GNSS measurement noise sigmas ', ...
            '(Block 5 SensorNoiseConfig): a step is Constrained when ', ...
            'the fused position uncertainty is at or below the raw ', ...
            'measurement noise on every axis.'], ...
        'TrendThresholdPerSecond', TrendThreshold, ...
        'TrendThresholdSource', [ ...
            '5% relative change per second of the navigation variance ', ...
            'trace; documented engineering hysteresis against ', ...
            'numerical jitter in steady covariances.']);

    if strcmp(Smoothing.Status, 'Smoothed')

        Confidence.SigmaPositionSmoothed_m = ...
            sqrt(Smoothing.CovDiag(:, Idx.pN:Idx.pD));
        Confidence.SigmaVelocitySmoothed_mps = ...
            sqrt(Smoothing.CovDiag(:, Idx.vN:Idx.vD));
        Confidence.SigmaAttitudeSmoothed_rad = ...
            sqrt(Smoothing.CovDiag(:, Idx.roll:Idx.yaw));

    else

        Confidence.SigmaPositionSmoothed_m = nan(Steps, 3);
        Confidence.SigmaVelocitySmoothed_mps = nan(Steps, 3);
        Confidence.SigmaAttitudeSmoothed_rad = nan(Steps, 3);

    end

    Summary = struct();
    Summary.MaxSigmaPosition_m = max(SigmaP, [], 1);
    Summary.MeanSigmaPosition_m = mean(SigmaP, 1);
    Summary.MaxSigmaVelocity_mps = max(SigmaV, [], 1);
    Summary.MaxSigmaAttitude_rad = max(SigmaA, [], 1);
    Summary.ConstrainedFraction = mean(Constrained);
    Summary.PoorlyConstrainedIntervals = Intervals;
    Summary.StepCount = Steps;

    Confidence.Summary = Summary;

end

function Intervals = contiguousIntervals(Mask, Time_s)
    Intervals = struct('Start_s', {}, 'End_s', {});
    Indices = find(Mask);
    StartIdx = [];

    for k = 1:numel(Indices)

        if isempty(StartIdx)
            StartIdx = Indices(k);
        elseif Indices(k) ~= Indices(k - 1) + 1
            Intervals(end + 1) = struct( ...
                'Start_s', Time_s(StartIdx), ...
                'End_s', Time_s(Indices(k - 1))); %#ok<AGROW>
            StartIdx = Indices(k);
        end

    end

    if ~isempty(StartIdx)
        Intervals(end + 1) = struct( ...
            'Start_s', Time_s(StartIdx), ...
            'End_s', Time_s(Indices(end)));
    end

end
