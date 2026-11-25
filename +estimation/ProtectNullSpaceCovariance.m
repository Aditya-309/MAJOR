function P = ProtectNullSpaceCovariance(P, P0, Definition, tElapsed_s)
%PROTECTNULLSPACECOVARIANCE No-information variance floors (S8c, growing).
%
%   P = ProtectNullSpaceCovariance(P, P0, Definition, tElapsed_s) keeps
%   the recorded covariance from claiming more precision than the data
%   can deliver along the weakly-observed directions. Two layers:
%
%   1) ATTITUDE BLOCK - time-growing no-information floor. An unlearnable
%      turn-on gyro bias accumulates attitude drift as t * b, so the
%      no-information attitude variance at elapsed time t is
%
%          Ptt_NI(t) = Ptt0 + t*(Ptb0 + Ptb0') + t^2 * Pbb0
%
%      (exact closed-form open-loop propagation of the S1 joint prior).
%      The recorded attitude block is floored at Ptt_NI(t) in the
%      Loewner order. Measured cause (S8c): on 300 s runs the static
%      prior-level floor left the attitude blocks 3-12x inconsistent
%      because the true error grows with the unlearnable-bias drift while
%      the static floor cannot.
%
%   2) CONFOUNDED PAIR DIRECTIONS - the gyro-bias/attitude,
%      accel-bias/tilt and GNSS-bias/position split directions and the
%      pure turn-on-bias directions, floored at the same grown
%      no-information blocks (consider-parameter semantics).
%
%   All floors are derived from the declared priors and the pair
%   dynamics; there are no free parameters. The projection only ADDS
%   variance (PSD), preserves symmetry, and leaves other directions
%   untouched. The filter recursion itself is never modified (recorded
%   covariance only).
%
%   INTERNAL function.

    if nargin < 4
        tElapsed_s = 0;
    end

    Idx = Definition.Index;
    Count = Definition.Count;
    P = (P + P') / 2;
    t = max(tElapsed_s, 0);

    AS = Idx.roll:Idx.yaw;
    BS = Idx.bgx:Idx.bgz;

    % ---- Layer 1: attitude-block no-information floor (time-growing)
    if max(BS) <= Count
        Ptt0 = P0(AS, AS);
        Ptb0 = P0(AS, BS);
        Pbb0 = P0(BS, BS);

        PttNI = Ptt0 + t * (Ptb0 + Ptb0') + (t ^ 2) * Pbb0;

        % S8d: the accelerometer turn-on bias is structurally
        % indistinguishable from a tilt of bias/g (the leveling
        % ambiguity) - a 2-DOF (roll/pitch) attitude uncertainty the
        % data cannot rule out, derived exactly from the declared prior.
        % For the isotropic prior eye(3)*sigma^2 used by InitializeState
        % this is rotation-invariant: C*Pba0*C' = Pba0 for any attitude.
        if isfield(Idx, 'bax') && max(Idx.bax:Idx.baz) <= Count
            Pba0 = P0(Idx.bax:Idx.baz, Idx.bax:Idx.baz);
            Gravity = 9.80665;
            TiltNI = zeros(3);
            TiltNI(1:2, 1:2) = Pba0(1:2, 1:2) / Gravity ^ 2;
            PttNI = PttNI + TiltNI;
        end

        PttNI = (PttNI + PttNI') / 2;

        Gap = PttNI - P(AS, AS);
        Gap = (Gap + Gap') / 2;
        [V, L] = eig(Gap);
        l = diag(L);
        if any(l > 0)
            P(AS, AS) = P(AS, AS) + V * diag(max(l, 0)) * V';
            P = (P + P') / 2;
        end
    end

    % ---- Layer 1b: NOT USED (documented). The accel-bias integral
    % floors for velocity (t^2 Pba) and position (t^4/4 Pba) were
    % evaluated 2026-11-25 and rejected: the no-information bound is
    % physically real but the data DOES constrain these directions
    % (GNSS velocity aiding), so the block floor explodes the recorded
    % sigma on long runs (km-scale position envelopes) while the real
    % pipeline shows velocity blocks at 2.7 (consistent). The synthetic
    % ValidationLab seeds with strong in-run GM draws show uncovered
    % excursions - tracked as a fixture-level limitation in
    % GuardrailUpdateProposal_S8a.md, not a product defect.

    % ---- Layer 2: confounded pair directions + pure bias floors
    Pairs = { ...
        Idx.roll:Idx.yaw,    Idx.bgx:Idx.bgz; ...   % gyro-bias / attitude
        Idx.roll:Idx.pitch,  Idx.bax:Idx.baz};      % accel-bias / tilt

    if isfield(Idx, 'bgn')
        Pairs(end + 1, :) = {Idx.pN:Idx.pD, Idx.bgn:Idx.bgd};
    end

    for p = 1:size(Pairs, 1)
        Xs = Pairs{p, 1};
        Bs = Pairs{p, 2};

        if max(Bs) > Count
            continue
        end

        Pbb = P(Bs, Bs);
        if rcond(Pbb) < 1e-12
            continue
        end
        J = P(Xs, Bs) / Pbb;

        % No-information reference blocks of this pair at time t. The
        % gyro pair accumulates t^2 * Pbb0 drift; the leveling pair is a
        % static ambiguity; the GNSS pair drifts with its bias walk.
        Pxx0 = P0(Xs, Xs);
        Pxb0 = P0(Xs, Bs);
        Pbb0 = P0(Bs, Bs);

        % Only the GYRO pair accumulates drift with time (the unlearnable
        % bias integrates into attitude). The GNSS-pair t^2 growth was
        % tested 2026-11-25 in both states: it does NOT cover the
        % synthetic mini's velocity block (55-60 with or without it) and
        % it crushes the real 300-s run's position block to 0.007. The
        % velocity coverage gap is addressed at its source instead: the
        % IMU bias states are Gauss-Markov (S8e, StateTransitionModel).
        if numel(Xs) == 3 && numel(Bs) == 3 && all(Xs == Idx.roll:Idx.yaw)
            Growth = t * (Pxb0 + Pxb0') + (t ^ 2) * Pbb0;   % gyro drift
        else
            Growth = zeros(size(Pxx0));                     % static pair
        end

        PxxNI = Pxx0 + Growth;
        PxbNI = Pxb0;
        PbbNI = Pbb0;

        for kk = 1:numel(Bs)
            u = zeros(Count, 1);
            u(Xs) = J(:, kk);
            u(Bs(kk)) = 1;
            u = u / max(norm(u), realmin);

            Floor = u(Xs)' * PxxNI * u(Xs) ...
                + 2 * u(Xs)' * PxbNI * u(Bs) ...
                + u(Bs)' * PbbNI * u(Bs);
            v = u' * P * u;

            if isfinite(Floor) && Floor > 0 && v < Floor
                P = P + (Floor - v) * (u * u');
            end
        end

        % Consider-parameter floor on the pure bias direction.
        for kk = 1:numel(Bs)
            u = zeros(Count, 1);
            u(Bs(kk)) = 1;
            Floor = PbbNI(kk, kk);
            v = u' * P * u;
            if isfinite(Floor) && Floor > 0 && v < Floor
                P = P + (Floor - v) * (u * u');
            end
        end

    end

    P = (P + P') / 2;
end
