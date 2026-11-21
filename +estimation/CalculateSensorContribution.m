function SensorContribution = CalculateSensorContribution(RunLog)
%CALCULATESENSORCONTRIBUTION Sensor trust and contribution evidence.
%
%   SensorContribution = CALCULATESENSORCONTRIBUTION(RunLog, Config)
%   aggregates the per-update evidence recorded by RunFilter into a
%   per-stream contribution record showing how each sensor's evidence
%   influenced the estimate:
%
%       - availability and eligibility counts (with exclusion reasons)
%       - applied / gated / diagnostic-only / skipped counts
%       - innovation and NIS distribution (mean, median, max, and the
%         fraction above the documented chi-square consistency bound)
%       - correction magnitudes and covariance trace reductions
%
%   Purpose and limits (task document 12.2): the record shows how sensor
%   evidence influenced the estimate. It does NOT label a sensor
%   unreliable on the basis of one large residual: the aggregates report
%   distribution statistics and context (model assumptions, uncertainty,
%   availability and repeated evidence) and the wording of the report is
%   evidentiary, not a verdict. NIS comparisons use the chi-square
%   quantile of the update dimension (3) at the documented 0.95
%   probability from ChiSquareQuantile.
%
%   Output fields:
%       .PerStream   - struct per stream with the aggregates above
%       .UpdateRef   - indices into RunLog.Updates by stream (traceable
%                      to source rows and timestamps)
%       .ConsistencyBound - the chi-square value used
%       .Notes       - interpretation limits
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: RunFilter, CalculateIntegrityIndex, BuildDiagnostics.

    Updates = RunLog.Updates;

    ConsistencyBound = estimation.ChiSquareQuantile(0.95, 3);

    StreamNames = {'GNSS', 'Magnetometer'};
    PerStream = struct();
    UpdateRef = struct();

    for Index = 1:numel(StreamNames)

        StreamName = StreamNames{Index};
        Rows = find(strcmp(Updates.Stream, StreamName));

        if isempty(Rows)
            PerStream.(StreamName) = struct('UpdateCount', 0);
            UpdateRef.(StreamName) = zeros(0, 1);
            continue
        end

        Applied = Rows(strcmp(Updates.Outcome(Rows), 'Applied'));
        Gated = Rows(strcmp(Updates.Outcome(Rows), 'Gated'));
        Diagnostic = Rows(strcmp(Updates.Outcome(Rows), 'DiagnosticOnly'));
        Skipped = setdiff(Rows, [Applied(:); Gated(:); Diagnostic(:)]);

        NIS = Updates.NIS(Rows);
        NISFinite = NIS(isfinite(NIS));

        Entry = struct();
        Entry.UpdateCount = numel(Rows);
        Entry.AppliedCount = numel(Applied);
        Entry.GatedCount = numel(Gated);
        Entry.DiagnosticOnlyCount = numel(Diagnostic);
        Entry.SkippedCount = numel(Skipped);
        Entry.SkippedOutcomes = unique(Updates.Outcome(Skipped));
        Entry.AvailabilityFraction = numel(Rows) / max(1, numel(Rows));

        if ~isempty(NISFinite)

            Entry.NISMean = mean(NISFinite);
            Entry.NISMedian = median(NISFinite);
            Entry.NISMax = max(NISFinite);
            Entry.NISExceedanceFraction = ...
                mean(NISFinite > ConsistencyBound);

        else

            Entry.NISMean = NaN;
            Entry.NISMedian = NaN;
            Entry.NISMax = NaN;
            Entry.NISExceedanceFraction = NaN;

        end

        AppliedCorr = Updates.CorrectionNorm(Applied);
        AppliedTrace = Updates.TraceChange(Applied);

        Entry.MeanCorrectionNorm = meanOrNaN(AppliedCorr);
        Entry.MaxCorrectionNorm = maxOrNaN(AppliedCorr);
        Entry.TotalTraceReduction = sum(AppliedTrace(~isnan(AppliedTrace)));

        Entry.SourceRows = Updates.SourceRowIdx(Rows);
        Entry.TimeRange_s = [min(Updates.Time_s(Rows)), ...
            max(Updates.Time_s(Rows))];

        PerStream.(StreamName) = Entry;
        UpdateRef.(StreamName) = Rows;

    end

    SensorContribution = struct();
    SensorContribution.PerStream = PerStream;
    SensorContribution.UpdateRef = UpdateRef;
    SensorContribution.ConsistencyBound = ConsistencyBound;
    SensorContribution.ConsistencyBoundSource = [ ...
        'Chi-square quantile at probability 0.95 with 3 degrees of ', ...
        'freedom (Wilson-Hilferty approximation, ChiSquareQuantile).'];
    SensorContribution.Notes = [ ...
        'Evidence record of how each sensor''s updates influenced the ', ...
        'estimate. A single large residual does not establish that a ', ...
        'sensor is unreliable; interpretation must consider the model ', ...
        'assumptions, uncertainty, availability and repeated evidence.'];

end

function Value = meanOrNaN(X)
    if isempty(X)
        Value = NaN;
    else
        Value = mean(X);
    end
end

function Value = maxOrNaN(X)
    if isempty(X)
        Value = NaN;
    else
        Value = max(X);
    end
end
