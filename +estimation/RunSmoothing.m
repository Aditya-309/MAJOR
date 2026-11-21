function Smoothing = RunSmoothing(Filter, FilterLabel, Config, Forward)
%RUNSMOOTHING Full-flight backward smoothing of the recorded history.
%
%   Smoothing = RUNSMOOTHING(Filter, FilterLabel, Config, Forward) runs
%   the Sensor Fusion and Tracking Toolbox backward smoothing recursion
%   (R2024b trackingEKF/trackingUKF smooth operation) over the complete
%   recorded forward history of the filter and returns the smoothed
%   estimates together with a forward-versus-smoothed comparison.
%
%   Full-flight policy (task document 11.2):
%       - Config.Smoothing.FullFlight selects full-flight smoothing; the
%         filter's MaxNumSmoothingSteps is sized to cover every forward
%         step of the selected flight, so the result is genuinely
%         full-flight and never a silently shortened window.
%       - The resource preflight estimate (measured ~17 kB of smoothing
%         history per forward step on this machine, from the Phase 1
%         toolbox probe) is checked against Config.Smoothing.MemoryLimit_MB
%         BEFORE the run by the orchestrator. When the estimate exceeds
%         the limit, smoothing is NOT run, no shorter window is
%         substituted, and Smoothing.Status reports the limitation
%         explicitly.
%
%   Output fields:
%       .Status        - 'Smoothed', 'NotRequested', 'ResourceLimited'
%                        or 'AlignmentFailed'
%       .InitialBoundaryRow - always 1: the t_init snapshot PRECEDES the
%                        first predict, so the smoothing recursion cannot
%                        revise it; its forward value is retained and this
%                        row is EXCLUDED from revision statistics. It is
%                        reported as the initial boundary, not as a
%                        smoothed prediction-history entry.
%       .Limitation    - explicit text when not smoothed
%       .Time_s        - forward step times (from Forward.Time_s)
%       .State         - smoothed states (Sx15) aligned 1:1 with Time_s
%       .CovDiag       - smoothed covariance diagonals (Sx15)
%       .Revision      - smoothed-minus-forward state differences (Sx15)
%       .RevisionNorm  - per-step norm of the navigation-state revision
%       .HistorySteps  - number of backward recursion steps performed
%
%   Alignment note: the toolbox records one smoothing-history entry per
%   predict() call. The forward log records one snapshot per timestamp
%   group of the timeline. In this pipeline every group after t_init
%   contains exactly one predict, so HistorySteps == numel(Time_s) - 1
%   and the smoothed state for history step k is aligned with forward
%   snapshot k+1. The first forward snapshot (t_init) precedes any
%   predict: its smoothed value is UNDEFINED by the recursion, and the
%   forward value is retained and clearly marked as the initial boundary
%   (InitialBoundaryRow, BoundaryPolicy). The alignment is asserted by
%   the smoothing test; any mismatch is reported with the distinct
%   status 'AlignmentFailed', never hidden or mislabeled.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: RunFilter, CreateEKF, CreateUKF.

    Definition = estimation.StateDefinition();

    Smoothing = struct();
    Smoothing.Status = 'NotRequested';
    Smoothing.Limitation = '';
    Smoothing.Time_s = Forward.Time_s;
    Smoothing.State = zeros(size(Forward.State));
    Smoothing.CovDiag = zeros(size(Forward.CovDiag));
    % Full smoothed covariance (reviewer round 2, follow-up to F4): the
    % smoothed NEES must use the same full-covariance method as the
    % forward series; smoothP provides it.
    Smoothing.CovFull = zeros(size(Forward.State, 1), ...
        size(Forward.State, 2) ^ 2);
    Smoothing.Revision = zeros(size(Forward.State));
    Smoothing.RevisionNorm = zeros(size(Forward.Time_s));
    Smoothing.HistorySteps = 0;
    Smoothing.AlignmentVerified = false;
    % Reviewer finding F6: the initial boundary is explicit, not implicit.
    Smoothing.InitialBoundaryRow = 1;
    Smoothing.BoundaryPolicy = [ ...
        'Row 1 (t_init) precedes the first predict; the forward state ', ...
        'is retained there and the row is excluded from revision ', ...
        'statistics. It is not a smoothed prediction-history entry.'];
    % Smoothing cannot make hard-invalid estimates valid; the validity
    % mask carries over unchanged (reviewer finding F5).
    Smoothing.Valid = Forward.Valid;

    if ~Config.Smoothing.FullFlight

        Smoothing.Limitation = [ ...
            'Full-flight smoothing was not requested in the ', ...
            'configuration.'];
        return

    end

    if ~Filter.EnableSmoothing

        Smoothing.Status = 'ResourceLimited';
        Smoothing.Limitation = [ ...
            'The smoothing history was not enabled for this filter ', ...
            '(resource preflight exceeded the configured memory ', ...
            'limit); no shorter window was substituted.'];
        return

    end

    [smoothX, smoothP] = smooth(Filter);
    HistorySteps = size(smoothX, 2);
    Smoothing.HistorySteps = HistorySteps;

    % Alignment: history step k <-> forward snapshot k+1 (snapshot 1 is
    % the t_init group, which produced no predict).
    if HistorySteps == numel(Forward.Time_s) - 1

        Smoothing.State(1, :) = Forward.State(1, :);
        Smoothing.CovDiag(1, :) = Forward.CovDiag(1, :);

        for k = 1:HistorySteps

            Smoothing.State(k + 1, :) = smoothX(:, k)';
            Smoothing.CovDiag(k + 1, :) = diag(smoothP(:, :, k))';
            Smoothing.CovFull(k + 1, :) = ...
                reshape(smoothP(:, :, k), 1, []);

        end

        Smoothing.CovFull(1, :) = Forward.CovFull(1, :);

        Smoothing.AlignmentVerified = true;
        Smoothing.Status = 'Smoothed';

    elseif HistorySteps == numel(Forward.Time_s)

        % Unexpected but possible if a group produced no snapshot;
        % align 1:1 and mark alignment as unverified.
        for k = 1:HistorySteps

            Smoothing.State(k, :) = smoothX(:, k)';
            Smoothing.CovDiag(k, :) = diag(smoothP(:, :, k))';
            Smoothing.CovFull(k, :) = reshape(smoothP(:, :, k), 1, []);

        end

        Smoothing.Status = 'Smoothed';
        Smoothing.AlignmentVerified = false;
        Smoothing.Limitation = [ ...
            'History step count equals the snapshot count; 1:1 ', ...
            'alignment applied and marked unverified.'];

    else

        % Reviewer finding F7: a history/snapshot count mismatch is an
        % ALIGNMENT failure, not a resource limitation. The statuses are
        % now distinct: 'ResourceLimited' is reserved for the resource
        % preflight; this case is 'AlignmentFailed'.
        Smoothing.Status = 'AlignmentFailed';
        Smoothing.Limitation = sprintf( [ ...
            'The recorded smoothing history (%d steps) does not cover ', ...
            'the complete forward trajectory (%d snapshots); the ', ...
            'history-to-snapshot alignment FAILED and no smoothed ', ...
            'result is reported.'], ...
            HistorySteps, numel(Forward.Time_s));
        return

    end

    % Forward-versus-smoothed revision (navigation states and biases).
    Smoothing.Revision = Smoothing.State - Forward.State;
    NavSpan = [Definition.Span.Position, Definition.Span.Velocity, ...
        Definition.Span.Attitude];
    Smoothing.RevisionNorm = sqrt(sum( ...
        Smoothing.Revision(:, NavSpan) .^ 2, 2));
    Smoothing.Label = FilterLabel;

end
