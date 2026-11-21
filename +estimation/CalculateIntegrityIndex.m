function Integrity = CalculateIntegrityIndex(Forward, RunLog, Config)
%CALCULATEINTEGRITYINDEX Transparent composite reconstruction integrity indicator.
%
%   Integrity = CALCULATEINTEGRITYINDEX(Forward, RunLog, Config) computes
%   a transparent engineering indicator of the reconstruction's internal
%   health per forward step, together with ALL component measures and the
%   validity status of every component. Nothing is hidden inside a
%   single number.
%
%   The indicator is NOT a probability, NOT a certified safety measure
%   and NOT an aviation assurance metric. It is a documented composite of
%   four observable component measures, each mapped to [0, 1]:
%
%       1. Consistency - the fraction of applied updates in the trailing
%          window whose NIS is at or below the documented chi-square
%          consistency bound (0.95 quantile, 3 DoF).
%       2. CovarianceValidity - 1 when the recorded covariance diagonal
%          is finite, nonnegative and below the configured
%          PoorlyConstrained floor logic of CalculateConfidence; 0 when
%          any violation occurs at the step.
%       3. SensorSupport - the fraction of eligible update events in the
%          trailing window that were actually applied (evidence that
%          sensor support reached the estimate).
%       4. InnovationHealth - 1 minus the fraction of update events in
%          the trailing window that were gated (gate hits indicate
%          inconsistency).
%
%   Weights: Config.Integrity.Weights (default 0.25 each). Rationale
%   (recorded): with no validated basis for unequal weighting in this
%   project, equal declared weights are used; the composite exposes its
%   components so any weighting can be re-evaluated from the evidence.
%
%   Window: Config.Diagnostics.MismatchWindow_s (default 10 s), trailing.
%   Windows are labelled 'Valid' only when at least one update falls
%   inside; windows without updates are marked Invalid and carry no
%   claim.
%
%   Output fields:
%       .Time_s, .Score (Sx1), .Components (Sx4 struct-of-arrays),
%       .Validity (Sx1 cellstr), .Weights, .Window_s,
%       .ComponentDefinitions, .Disclaimer
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: CalculateConfidence, DetectModelMismatch, BuildDiagnostics.

    Steps = numel(Forward.Time_s);
    Window_s = Config.Diagnostics.MismatchWindow_s;
    Weights = Config.Integrity.Weights;

    ConsistencyBound = estimation.ChiSquareQuantile(0.95, 3);

    Updates = RunLog.Updates;
    UpdateTimes = Updates.Time_s;
    AppliedMask = strcmp(Updates.Outcome, 'Applied');
    GatedMask = strcmp(Updates.Outcome, 'Gated');
    EligibleMask = AppliedMask | GatedMask | ...
        strcmp(Updates.Outcome, 'DiagnosticOnly');

    Score = nan(Steps, 1);
    Consistency = nan(Steps, 1);
    CovarianceValidity = nan(Steps, 1);
    SensorSupport = nan(Steps, 1);
    InnovationHealth = nan(Steps, 1);
    Validity = cell(Steps, 1);

    for k = 1:Steps

        t = Forward.Time_s(k);
        InWindow = UpdateTimes >= t - Window_s & UpdateTimes <= t;
        WindowRows = find(InWindow);

        % Component 2 is defined for every step.
        DiagP = Forward.CovDiag(k, :);
        CovarianceValidity(k) = double( ...
            all(isfinite(DiagP)) && all(DiagP >= 0));

        if isempty(WindowRows)

            Validity{k} = 'Invalid:NoUpdatesInWindow';
            Score(k) = NaN;
            Consistency(k) = NaN;
            SensorSupport(k) = NaN;
            InnovationHealth(k) = NaN;
            continue

        end

        AppliedRows = WindowRows(AppliedMask(WindowRows));
        GatedRows = WindowRows(GatedMask(WindowRows));
        EligibleRows = WindowRows(EligibleMask(WindowRows));

        % Component 1: consistency of applied updates.
        if ~isempty(AppliedRows)

            NIS = Updates.NIS(AppliedRows);
            NIS = NIS(isfinite(NIS));
            Consistency(k) = mean(NIS <= ConsistencyBound);

        else

            Consistency(k) = NaN;

        end

        % Component 3: sensor support.
        SensorSupport(k) = ...
            numel(AppliedRows) / max(1, numel(EligibleRows));

        % Component 4: innovation health.
        InnovationHealth(k) = ...
            1 - numel(GatedRows) / max(1, numel(EligibleRows));

        Components = [ ...
            orOne(Consistency(k)), ...
            CovarianceValidity(k), ...
            SensorSupport(k), ...
            InnovationHealth(k)];

        WeightVector = [Weights.Consistency, ...
            Weights.CovarianceValidity, ...
            Weights.SensorSupport, ...
            Weights.InnovationHealth];

        Score(k) = sum(Components .* WeightVector);

        if any(isnan(Components))

            Validity{k} = 'Partial:ComponentUnavailable';

        else

            Validity{k} = 'Valid';

        end

    end

    Integrity = struct();
    Integrity.Time_s = Forward.Time_s;
    Integrity.Score = Score;
    Integrity.Components = struct( ...
        'Consistency', Consistency, ...
        'CovarianceValidity', CovarianceValidity, ...
        'SensorSupport', SensorSupport, ...
        'InnovationHealth', InnovationHealth);
    Integrity.Validity = Validity;
    Integrity.Weights = Weights;
    Integrity.WeightRationale = Config.Integrity.WeightRationale;
    Integrity.Window_s = Window_s;
    Integrity.ConsistencyBound = ConsistencyBound;
    Integrity.ComponentDefinitions = { ...
        'Consistency: fraction of applied updates in the trailing window with NIS <= chi2(0.95, 3).'; ...
        'CovarianceValidity: 1 when the recorded covariance diagonal is finite and nonnegative at the step.'; ...
        'SensorSupport: applied updates over eligible update events in the trailing window.'; ...
        'InnovationHealth: 1 minus the gated fraction of update events in the trailing window.'};
    Integrity.Disclaimer = [ ...
        'Engineering indicator only: not a probability, not a ', ...
        'certified safety measure, not an aviation assurance metric. ', ...
        'All component measures and the validity status are exposed ', ...
        'alongside the composite score.'];

end

function Value = orOne(NaNValue)
    % A missing consistency statistic does not contribute a claim: the
    % composite is then marked Partial instead of silently treating the
    % missing component as healthy or unhealthy.
    if isnan(NaNValue)
        Value = NaN;
    else
        Value = NaNValue;
    end
end
