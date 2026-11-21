function Metrics = CalculateEstimationMetrics(Estimate, Truth, Config, Label)
%CALCULATEESTIMATIONMETRICS Error metrics of one estimate against truth.
%
%   Metrics = CALCULATEESTIMATIONMETRICS(Estimate, Truth, Config, Label)
%   computes the documented comparison metrics for one estimate series
%   against ground truth. This function is part of the POST-ESTIMATION
%   evaluation stage: it is only ever called after the forward and
%   smoothed reconstructions have completed (task document 13).
%
%   Inputs:
%       Estimate - struct with fields Time_s (Sx1), State (Sx15),
%                  CovDiag (Sx15)
%       Truth    - struct with fields Time_s (Sx1), PositionNED_m (Sx3),
%                  VelocityNED_mps (Sx3), Euler_rad (Sx3 [roll pitch
%                  yaw]), Quaternion (Sx4 [w x y z])
%       Label    - text label for the metric set (e.g. 'ForwardEKF')
%
%   Metrics computed:
%       - NED position error per axis and RMSE, 3D error statistics
%       - NED velocity error per axis and RMSE
%       - attitude angular error via quaternion geometry
%         (angle of q_est * conj(q_true); never naive Euler
%         subtraction across wrap boundaries)
%       - NEES of the 9 navigation states (position, velocity, attitude)
%         where the state-to-truth mapping is direct and the covariance
%         block is valid; bias states are excluded because ground truth
%         carries no bias channels
%       - confidence coverage: fraction of truth inside k*sigma for the
%         configured CoverageSigmas, per block
%       - execution timing fields are passed through when present in
%       Estimate (set by the orchestrator)
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: EvaluateAgainstGroundTruth, CompareEstimators.

    Definition = estimation.StateDefinition();
    Idx = Definition.Index;

    Steps = numel(Estimate.Time_s);

    PosErr = Estimate.State(:, Idx.pN:Idx.pD) - Truth.PositionNED_m;
    VelErr = Estimate.State(:, Idx.vN:Idx.vD) - Truth.VelocityNED_mps;

    % Explicit validity accounting: rows whose truth alignment produced
    % non-finite entries are excluded from the aggregated scalars and
    % COUNTED, never silently dropped. Full per-row series are still
    % recorded below for traceability.
    ValidRow = all(isfinite(PosErr), 2) & all(isfinite(VelErr), 2);
    InvalidEstimateRows = 0;

    % Reviewer finding F5: the ESTIMATOR validity mask also excludes rows
    % (hard stop, IMU hold-invalid, pitch singularity) - never silently.
    if isfield(Estimate, 'Valid') && ~isempty(Estimate.Valid)
        EstimateValid = logical(Estimate.Valid(:));
        InvalidEstimateRows = sum(~EstimateValid);
        ValidRow = ValidRow & EstimateValid;
    end

    % Unfiltered copies for per-row diagnostics (NEES) that must stay
    % aligned with the estimate rows.
    PosErrFull = PosErr;
    VelErrFull = VelErr;
    PosErrV = PosErr(ValidRow, :);
    VelErrV = VelErr(ValidRow, :);

    Metrics = struct();
    Metrics.Label = Label;
    Metrics.StepCount = Steps;
    Metrics.EvaluatedRows = sum(ValidRow);
    Metrics.ExcludedRows = sum(~ValidRow);
    Metrics.InvalidEstimateRows = InvalidEstimateRows;
    Metrics.TimeRange_s = [Estimate.Time_s(1), Estimate.Time_s(end)];

    Metrics.PositionError_m = PosErr;
    Metrics.PositionRMSE_m = sqrt(mean(PosErrV .^ 2, 1));
    Metrics.PositionMaxAbs_m = max(abs(PosErrV), [], 1);
    Pos3D = sqrt(sum(PosErrV .^ 2, 2));
    Metrics.Position3DRMSE_m = sqrt(mean(Pos3D .^ 2));
    Metrics.Position3DMax_m = max(Pos3D);

    Metrics.VelocityError_mps = VelErr;
    Metrics.VelocityRMSE_mps = sqrt(mean(VelErrV .^ 2, 1));
    Metrics.VelocityMaxAbs_mps = max(abs(VelErrV), [], 1);

    % Attitude angular error via quaternion geometry.
    AngErr = zeros(Steps, 1);

    for k = 1:Steps

        qEst = coordinates.Euler2Quaternion( ...
            Estimate.State(k, Idx.roll), ...
            Estimate.State(k, Idx.pitch), ...
            Estimate.State(k, Idx.yaw));
        qTrue = Truth.Quaternion(k, :);

        qErr = quatMultiply(qEst, quatConjugate(qTrue));
        qErr = qErr / max(norm(qErr), realmin);
        AngErr(k) = 2 * acos(min(1, abs(qErr(1))));

    end

    Metrics.AttitudeAngularError_rad = AngErr;
    AngErrV = AngErr(ValidRow & isfinite(AngErr));
    Metrics.AttitudeAngularRMSE_rad = sqrt(mean(AngErrV .^ 2));
    Metrics.AttitudeAngularMax_rad = max(AngErrV);

    % NEES of the 9 navigation states (reviewer finding F4).
    % Method: FULL 9x9 covariance block when the estimate carries CovFull
    % (the intended metric). The diagonal-only form is kept as an
    % explicitly labelled SECONDARY series (NEESDiag) because it is only
    % an approximation. Numerical safeguards: the block is symmetrized;
    % rows whose block is not positive definite (chol failure) are
    % excluded from the full NEES and COUNTED in NEESPsdRejectedRows.
    NavSpan = [Idx.pN:Idx.pD, Idx.vN:Idx.vD, Idx.roll:Idx.yaw];
    NEES = nan(Steps, 1);
    NEESDiag = nan(Steps, 1);
    PsdRejected = 0;
    HasFullCov = isfield(Estimate, 'CovFull') && ...
        ~isempty(Estimate.CovFull);

    for k = 1:Steps

        ErrorNav = [PosErrFull(k, :), VelErrFull(k, :), ...
            navAttitudeError(Estimate.State(k, Idx.roll:Idx.yaw), ...
            Truth.Euler_rad(k, :))]';

        if all(isfinite(ErrorNav))

            Pdiag = diag(Estimate.CovDiag(k, NavSpan));

            if all(diag(Pdiag) > 0)
                NEESDiag(k) = ErrorNav' * (Pdiag \ ErrorNav);
            end

            if HasFullCov
                Pfull = reshape(Estimate.CovFull(k, :), ...
                    Definition.Count, Definition.Count);
                Pnav = Pfull(NavSpan, NavSpan);
                Pnav = (Pnav + Pnav') / 2;
                [~, CholFlag] = chol(Pnav);

                if CholFlag == 0
                    NEES(k) = ErrorNav' * (Pnav \ ErrorNav);
                else
                    PsdRejected = PsdRejected + 1;
                end

            end

        end

    end

    if HasFullCov
        Metrics.NEESMethod = 'FullCovariance9DoF';
    else
        Metrics.NEESMethod = 'DiagonalApproximationOnly';
    end

    Metrics.NEES = NEES;
    Metrics.NEESMean = mean(NEES, 'omitnan');
    Metrics.NEESDiag = NEESDiag;
    Metrics.NEESDiagMean = mean(NEESDiag, 'omitnan');
    Metrics.NEESPsdRejectedRows = PsdRejected;
    Metrics.NEESDoF = 9;
    Metrics.NEESExpectedMean = 9;

    % Confidence coverage per block.
    Coverage = struct();
    Sigmas = Config.Evaluation.CoverageSigmas;

    Blocks = {'Position', 'Velocity', 'Attitude'};
    BlockSpans = {Idx.pN:Idx.pD, Idx.vN:Idx.vD, Idx.roll:Idx.yaw};

    for b = 1:numel(Blocks)

        BlockName = Blocks{b};
        Span = BlockSpans{b};
        SigmaBlock = sqrt(Estimate.CovDiag(:, Span));

        switch BlockName
            case 'Position'
                ErrBlock = PosErr;
            case 'Velocity'
                ErrBlock = VelErr;
            otherwise
                ErrBlock = [ ...
                    wrapToPiLocal(Estimate.State(:, Idx.roll) - ...
                        Truth.Euler_rad(:, 1)), ...
                    Estimate.State(:, Idx.pitch) - Truth.Euler_rad(:, 2), ...
                    wrapToPiLocal(Estimate.State(:, Idx.yaw) - ...
                        Truth.Euler_rad(:, 3))];
        end

        Fractions = zeros(1, numel(Sigmas));

        for s = 1:numel(Sigmas)

            Inside = abs(ErrBlock) <= Sigmas(s) * SigmaBlock;
            Fractions(s) = mean(Inside(:));

        end

        Coverage.(BlockName) = struct( ...
            'Sigmas', Sigmas, ...
            'CoveredFraction', Fractions);

    end

    Metrics.Coverage = Coverage;

    if isfield(Estimate, 'ExecutionTime_s')
        Metrics.ExecutionTime_s = Estimate.ExecutionTime_s;
    end

    if isfield(Estimate, 'MemoryUsed_MB')
        Metrics.MemoryUsed_MB = Estimate.MemoryUsed_MB;
    end

end

function q = quatMultiply(a, b)
    q = [ ...
        a(1) * b(1) - a(2) * b(2) - a(3) * b(3) - a(4) * b(4), ...
        a(1) * b(2) + a(2) * b(1) + a(3) * b(4) - a(4) * b(3), ...
        a(1) * b(3) - a(2) * b(4) + a(3) * b(1) + a(4) * b(2), ...
        a(1) * b(4) + a(2) * b(3) - a(3) * b(2) + a(4) * b(1)];
end

function q = quatConjugate(a)
    q = [a(1), -a(2), -a(3), -a(4)];
end

function Ang = wrapToPiLocal(Ang)
    Ang = mod(Ang + pi, 2 * pi) - pi;
end

function Err = navAttitudeError(EtaEst, EtaTrue)
    Err = [ ...
        wrapToPiLocal(EtaEst(1) - EtaTrue(1)), ...
        EtaEst(2) - EtaTrue(2), ...
        wrapToPiLocal(EtaEst(3) - EtaTrue(3))];
end
