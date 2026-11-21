function ModelMismatch = DetectModelMismatch(ForwardEKF, ForwardUKF, RunLogEKF, Config)
%DETECTMODELMISMATCH Persistent residual patterns and filter disagreement.
%
%   ModelMismatch = DETECTMODELMISMATCH(ForwardEKF, ForwardUKF,
%   RunLogEKF, RunLogUKF, Config) identifies:
%
%       1. Persistent residual patterns: per measurement stream, the
%          standardized innovation (innovation divided by the innovation
%          standard deviation from S) is averaged over the documented
%          trailing window (Config.Diagnostics.MismatchWindow_s). A
%          window is flagged when the magnitude of the window mean
%          exceeds 3 standard errors of that mean (3/sqrt(n) for
%          standardized innovations), a statistically documented bound.
%
%       2. EKF/UKF disagreement: per forward step the state difference
%          is normalized by the combined forward standard deviations;
%          steps whose maximum normalized difference exceeds
%          Config.Diagnostics.DisagreementSigmaGate (default 3) are
%          flagged and grouped into intervals.
%
%   Records include the affected time intervals, the involved source
%   rows and the measured statistics. The diagnostics deliberately make
%   NO physical attribution: a mismatch is reported as an observed
%   evidence pattern, not as a diagnosed cause (task document 12.4).
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: BuildInvestigationEvents, CalculateIntegrityIndex.

    Definition = estimation.StateDefinition();
    NavSpan = [Definition.Span.Position, Definition.Span.Velocity, ...
        Definition.Span.Attitude];

    Window_s = Config.Diagnostics.MismatchWindow_s;
    SigmaGate = Config.Diagnostics.DisagreementSigmaGate;

    %% 1. Persistent standardized-residual patterns

    StreamNames = {'GNSS', 'Magnetometer'};
    ResidualPatterns = struct();

    for Index = 1:numel(StreamNames)

        StreamName = StreamNames{Index};
        Pattern = struct('Stream', StreamName, ...
            'Windows', struct('Start_s', {}, 'End_s', {}, ...
                'MeanStdInnovation', {}, 'SampleCount', {}, ...
                'SourceRows', {}), ...
            'StdInnovationDefinition', [ ...
                'innovation ./ sqrt(diag(S)) per channel, averaged ', ...
                'over channels and window samples']);

        Rows = find(strcmp(RunLogEKF.Updates.Stream, StreamName) & ...
            strcmp(RunLogEKF.Updates.Outcome, 'Applied'));

        if isempty(Rows)

            ResidualPatterns.(StreamName) = Pattern;
            continue

        end

        Times = RunLogEKF.Updates.Time_s(Rows);
        StdInnov = RunLogEKF.Updates.Innovation(Rows, :) ./ ...
            sqrt(max(RunLogEKF.Updates.SDiag(Rows, :), realmin));
        MeanStd = mean(StdInnov, 2);

        WindowStart = min(Times);
        MaxTime = max(Times);

        while WindowStart <= MaxTime

            InWindow = Times >= WindowStart & Times < WindowStart + Window_s;
            SampleCount = sum(InWindow);

            if SampleCount >= 3

                Mu = mean(MeanStd(InWindow));
                Bound = 3 / sqrt(SampleCount);

                if abs(Mu) > Bound

                    WindowRows = Rows(InWindow);
                    Pattern.Windows(end + 1) = struct( ...
                        'Start_s', WindowStart, ...
                        'End_s', WindowStart + Window_s, ...
                        'MeanStdInnovation', Mu, ...
                        'SampleCount', SampleCount, ...
                        'SourceRows', ...
                            RunLogEKF.Updates.SourceRowIdx(WindowRows));

                end

            end

            WindowStart = WindowStart + Window_s;

        end

        ResidualPatterns.(StreamName) = Pattern;

    end

    %% 2. EKF/UKF disagreement on common steps

    Disagreement = struct();
    Disagreement.Gate = SigmaGate;
    Disagreement.GateSource = [ ...
        'Config.Diagnostics.DisagreementSigmaGate: state difference ', ...
        'normalized by the combined forward standard deviations.'];
    Disagreement.Intervals = struct('Start_s', {}, 'End_s', {}, ...
        'MaxNormalizedDifference', {}, 'StateIndex', {});
    Disagreement.MaxNormalizedDifferenceOverall = 0;

    [CommonTime, Ia, Ib] = intersect( ...
        ForwardEKF.Time_s, ForwardUKF.Time_s);

    if ~isempty(CommonTime)

        SigmaCombined = sqrt( ...
            ForwardEKF.CovDiag(Ia, NavSpan) + ...
            ForwardUKF.CovDiag(Ib, NavSpan));
        Delta = ForwardEKF.State(Ia, NavSpan) - ...
            ForwardUKF.State(Ib, NavSpan);
        Normalized = abs(Delta) ./ max(SigmaCombined, realmin);
        [MaxPerStep, StateIndex] = max(Normalized, [], 2);

        Disagreement.MaxNormalizedDifferenceOverall = ...
            max(MaxPerStep);

        Flagged = MaxPerStep > SigmaGate;
        Disagreement.FlaggedSteps = Flagged;
        Disagreement.Time_s = CommonTime;
        Disagreement.MaxPerStep = MaxPerStep;

        Indices = find(Flagged);
        StartIdx = [];

        for k = 1:numel(Indices)

            if isempty(StartIdx)
                StartIdx = Indices(k);
            elseif Indices(k) ~= Indices(k - 1) + 1
                Block = StartIdx:Indices(k - 1);
                Disagreement.Intervals(end + 1) = struct( ...
                    'Start_s', CommonTime(Block(1)), ...
                    'End_s', CommonTime(Block(end)), ...
                    'MaxNormalizedDifference', max(MaxPerStep(Block)), ...
                    'StateIndex', ...
                        Definition.Names{NavSpan(StateIndex(Block(1)))});
                StartIdx = Indices(k);
            end

        end

        if ~isempty(StartIdx)

            Block = StartIdx:Indices(end);
            Disagreement.Intervals(end + 1) = struct( ...
                'Start_s', CommonTime(Block(1)), ...
                'End_s', CommonTime(Block(end)), ...
                'MaxNormalizedDifference', max(MaxPerStep(Block)), ...
                'StateIndex', ...
                    Definition.Names{NavSpan(StateIndex(Block(1)))});

        end

    end

    ModelMismatch = struct();
    ModelMismatch.ResidualPatterns = ResidualPatterns;
    ModelMismatch.Disagreement = Disagreement;
    ModelMismatch.Window_s = Window_s;
    ModelMismatch.Notes = [ ...
        'Observed evidence patterns only. No physical cause is ', ...
        'attributed to any mismatch; the affected intervals, source ', ...
        'rows and measured statistics are recorded for investigation.'];

end
