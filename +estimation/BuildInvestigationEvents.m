function Events = BuildInvestigationEvents(Timeline, RunLogEKF, RunLogUKF, ForwardEKF, SmoothingEKF, ConfidenceEKF, IntegrityEKF, ModelMismatch, InitInfo, Config)
%BUILDINVESTIGATIONEVENTS Evidence-linked investigation events.
%
%   Events = BUILDINVESTIGATIONEVENTS(...) generates investigation events
%   for the relevant conditions of the reconstruction. Every event links
%   to the relevant timestamps, source rows, measurement updates,
%   estimates and diagnostics where available, so any observation can be
%   traced back to the measurement evidence that produced it.
%
%   Event types (task document 12.5):
%       - GNSS outage start/end (Block 9 availability outages)
%       - invalid or unavailable measurements (timeline exclusions,
%         grouped into intervals)
%       - significant residual excursions (NIS above the documented
%         chi-square 0.99 quantile of the update dimension)
%       - persistent model mismatch (intervals from DetectModelMismatch)
%       - EKF/UKF disagreement (intervals from DetectModelMismatch)
%       - integrity indicator changes (component half-scale crossings and
%         composite changes of at least one equal weight)
%       - significant retrospective smoothing revisions (revision beyond
%         Config.Diagnostics.SmoothingRevisionSigma combined forward
%         standard deviations of the navigation states)
%       - estimator initialization or termination issues (init warnings,
%         propagation-unavailable events, pitch warning/hard stop)
%
%   Each event carries: Type, Severity ('Info'|'Warning'|'Significant'),
%   StartTime_s, EndTime_s, Message, and Evidence (struct with available
%   source rows, update indices, step indices and statistics).
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: DetectModelMismatch, CalculateIntegrityIndex,
%   BuildDiagnostics.

    Events = struct('Type', {}, 'Severity', {}, 'StartTime_s', {}, ...
        'EndTime_s', {}, 'Message', {}, 'Evidence', {});

    %% GNSS outage start/end (Block 9 outages)

    if isfield(Timeline.Outages, 'GNSS')

        Outages = Timeline.Outages.GNSS;

        for k = 1:numel(Outages)

            Events(end + 1) = makeEvent('GNSSOutage', 'Warning', ...
                Outages(k).StartTime_s, Outages(k).EndTime_s, ...
                sprintf('GNSS availability outage recorded by Block 9 (%.3f s to %.3f s).', ...
                Outages(k).StartTime_s, Outages(k).EndTime_s), ...
                struct('Source', 'Block9 Outages span')); %#ok<AGROW>

        end

    end

    %% Invalid or unavailable measurements (timeline exclusions)

    % All excluded measurements are reported (including those before
    % t_init, flagged as pre-initialization in the evidence).
    Excluded = find(~Timeline.Events.Eligible);

    if ~isempty(Excluded)

        Reasons = unique(Timeline.Events.ExclusionReason(Excluded));

        for k = 1:numel(Reasons)

            Rows = Excluded(strcmp( ...
                Timeline.Events.ExclusionReason(Excluded), Reasons{k}));

            Events(end + 1) = makeEvent('InvalidOrUnavailableMeasurement', ...
                'Info', min(Timeline.Events.Time_s(Rows)), ...
                max(Timeline.Events.Time_s(Rows)), ...
                sprintf('%d measurement(s) excluded: %s.', ...
                numel(Rows), Reasons{k}), ...
                struct('SourceRows', Timeline.Events.SourceRowIdx(Rows), ...
                'Streams', {unique(Timeline.Events.Stream(Rows))}, ...
                'Reason', Reasons{k}, ...
                'PreInitialization', ...
                    all(Timeline.Events.Time_s(Rows) < ...
                    InitInfo.t_init_s)));

        end

    end

    %% Significant residual excursions (NIS above chi2 0.99)

    ExcursionBound = estimation.ChiSquareQuantile(0.99, 3);
    Updates = RunLogEKF.Updates;

    for k = 1:numel(Updates.Time_s)

        if isfinite(Updates.NIS(k)) && ...
                strcmp(Updates.Outcome{k}, 'Applied') && ...
                Updates.NIS(k) > ExcursionBound

            Events(end + 1) = makeEvent('SignificantResidualExcursion', ...
                'Warning', Updates.Time_s(k), Updates.Time_s(k), ...
                sprintf('%s update NIS %.3g exceeds the chi-square 0.99 bound %.3g.', ...
                Updates.Stream{k}, Updates.NIS(k), ExcursionBound), ...
                struct('SourceRowIdx', Updates.SourceRowIdx(k), ...
                'Stream', Updates.Stream{k}, ...
                'Innovation', Updates.Innovation(k, :), ...
                'NIS', Updates.NIS(k), ...
                'Bound', ExcursionBound)); %#ok<AGROW>

        end

    end

    %% Persistent model mismatch intervals

    StreamNames = fieldnames(ModelMismatch.ResidualPatterns);

    for k = 1:numel(StreamNames)

        Pattern = ModelMismatch.ResidualPatterns.(StreamNames{k});

        for w = 1:numel(Pattern.Windows)

            W = Pattern.Windows(w);
            Events(end + 1) = makeEvent('PersistentModelMismatch', ...
                'Warning', W.Start_s, W.End_s, ...
                sprintf(['Persistent standardized-residual pattern in ', ...
                '%s: window mean %.3g over %d samples (bound %.3g).'], ...
                StreamNames{k}, W.MeanStdInnovation, W.SampleCount, ...
                3 / sqrt(W.SampleCount)), ...
                struct('SourceRows', W.SourceRows, ...
                'Stream', StreamNames{k}, ...
                'MeanStdInnovation', W.MeanStdInnovation)); %#ok<AGROW>

        end

    end

    %% EKF/UKF disagreement intervals

    for k = 1:numel(ModelMismatch.Disagreement.Intervals)

        D = ModelMismatch.Disagreement.Intervals(k);
        Events(end + 1) = makeEvent('EstimatorDisagreement', 'Warning', ...
            D.Start_s, D.End_s, ...
            sprintf(['EKF/UKF state difference reached %.3g combined ', ...
            'standard deviations (gate %.3g) on %s.'], ...
            D.MaxNormalizedDifference, ...
            ModelMismatch.Disagreement.Gate, D.StateIndex), ...
            struct('MaxNormalizedDifference', ...
            D.MaxNormalizedDifference, 'State', D.StateIndex)); %#ok<AGROW>

    end

    %% Integrity indicator changes

    WeightNames = fieldnames(IntegrityEKF.Weights);
    EqualWeight = mean(struct2array(IntegrityEKF.Weights));
    Scores = IntegrityEKF.Score;
    Components = IntegrityEKF.Components;

    for k = 2:numel(Scores)

        if isfinite(Scores(k)) && isfinite(Scores(k - 1)) && ...
                abs(Scores(k) - Scores(k - 1)) >= EqualWeight

            Events(end + 1) = makeEvent('IntegrityChange', 'Warning', ...
                IntegrityEKF.Time_s(k), IntegrityEKF.Time_s(k), ...
                sprintf('Integrity composite changed by %.3g (>= one equal weight %.3g).', ...
                Scores(k) - Scores(k - 1), EqualWeight), ...
                struct('ScoreBefore', Scores(k - 1), ...
                'ScoreAfter', Scores(k))); %#ok<AGROW>

        end

        for w = 1:numel(WeightNames)

            C = Components.(WeightNames{w});

            if isfinite(C(k)) && isfinite(C(k - 1)) && ...
                    ((C(k - 1) < 0.5 && C(k) >= 0.5) || ...
                    (C(k - 1) >= 0.5 && C(k) < 0.5))

                Events(end + 1) = makeEvent('IntegrityChange', 'Info', ...
                    IntegrityEKF.Time_s(k), IntegrityEKF.Time_s(k), ...
                    sprintf('Integrity component %s crossed the half scale (%.3g -> %.3g).', ...
                    WeightNames{w}, C(k - 1), C(k)), ...
                    struct('Component', WeightNames{w}, ...
                    'ValueBefore', C(k - 1), 'ValueAfter', C(k))); %#ok<AGROW>

            end

        end

    end

    %% Significant retrospective smoothing revisions

    if strcmp(SmoothingEKF.Status, 'Smoothed')

        SigmaCombined = sqrt(sum( ...
            ConfidenceEKF.SigmaPosition_m .^ 2 + ...
            ConfidenceEKF.SigmaVelocity_mps .^ 2, 2));
        Threshold = Config.Diagnostics.SmoothingRevisionSigma * ...
            max(SigmaCombined, realmin);
        Significant = SmoothingEKF.RevisionNorm > Threshold;

        Indices = find(Significant);

        for k = 1:numel(Indices)

            Events(end + 1) = makeEvent('SmoothingRevision', 'Info', ...
                SmoothingEKF.Time_s(Indices(k)), ...
                SmoothingEKF.Time_s(Indices(k)), ...
                sprintf(['Smoothed estimate revised the forward ', ...
                'navigation state by %.3g m-equivalent (> %.3g sigma ', ...
                'scale).'], SmoothingEKF.RevisionNorm(Indices(k)), ...
                Config.Diagnostics.SmoothingRevisionSigma), ...
                struct('StepIndex', Indices(k), ...
                'RevisionNorm', SmoothingEKF.RevisionNorm(Indices(k)), ...
                'Threshold', Threshold(Indices(k)))); %#ok<AGROW>

        end

    end

    %% Invalid forward estimates (e.g. pitch hard stop)

    InvalidSteps = find(~ForwardEKF.Valid);

    if ~isempty(InvalidSteps)

        Events(end + 1) = makeEvent('InvalidEstimates', 'Significant', ...
            ForwardEKF.Time_s(InvalidSteps(1)), ...
            ForwardEKF.Time_s(InvalidSteps(end)), ...
            sprintf('%d forward estimate(s) are marked invalid.', ...
            numel(InvalidSteps)), ...
            struct('StepIndices', InvalidSteps(:)'));

    end

    %% Initialization and termination issues

    for k = 1:numel(InitInfo.Warnings)

        Events(end + 1) = makeEvent('InitializationIssue', 'Warning', ...
            InitInfo.t_init_s, InitInfo.t_init_s, ...
            InitInfo.Warnings{k}, struct('Source', 'InitializeState'));

    end

    AllRunEvents = [RunLogEKF.Events(:); RunLogUKF.Events(:)];

    for k = 1:numel(AllRunEvents)

        E = AllRunEvents(k);
        Events(end + 1) = makeEvent(['Estimator_' E.Kind], 'Warning', ...
            E.Time_s, E.Time_s, E.Message, ...
            struct('SourceRowIdx', E.SourceRowIdx));

    end

    %% Chronological order

    if ~isempty(Events)

        [~, Order] = sortrows([[Events.StartTime_s]', ...
            [Events.EndTime_s]']);
        Events = Events(Order);

    end

end

function Event = makeEvent(Type, Severity, StartTime_s, EndTime_s, ...
    Message, Evidence)

    Event = struct( ...
        'Type', Type, ...
        'Severity', Severity, ...
        'StartTime_s', StartTime_s, ...
        'EndTime_s', EndTime_s, ...
        'Message', Message, ...
        'Evidence', Evidence);

end
