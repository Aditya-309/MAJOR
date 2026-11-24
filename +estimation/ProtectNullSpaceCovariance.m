function P = ProtectNullSpaceCovariance(P, P0, Definition)
%PROTECTNULLSPACECOVARIANCE No-information variance floors (S8a, dynamic).
%
%   P = ProtectNullSpaceCovariance(P, P0, Definition) restores the
%   variance of the confounded turn-on-bias directions to their
%   no-information level. The confounded subspace ROTATES with the
%   dynamics (measured: fixed initial-manifold floors left vel/att blocks
%   3-5x above expectation on maneuvering data), so the directions are
%   recomputed from the CURRENT covariance at every call:
%
%       J = P(x,b) / P(b,b),  u = (J*e_k, e_k),  floor = u' * P0 * u
%
%   where (x,b) are the attitude/gyro-bias, position/GNSS-bias and
%   tilt/accel-bias pairs. The floors are exact no-information levels of
%   the current direction (its P0 variance) - derived, never tuned. The
%   pure turn-on-bias directions are additionally floored at their prior
%   (consider-parameter semantics: single-flight data is not credited
%   with learning a turn-on bias below its declared prior).
%
%   The projection only ADDS variance (PSD rank-one), preserves symmetry,
%   and leaves all other directions untouched.
%
%   INTERNAL function.

    if nargin < 3
        return
    end

    Idx = Definition.Index;
    Count = Definition.Count;
    P = (P + P') / 2;

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

        for kk = 1:numel(Bs)
            u = zeros(Count, 1);
            u(Xs) = J(:, kk);
            u(Bs(kk)) = 1;
            u = u / max(norm(u), realmin);
            Floor = u' * P0 * u;
            v = u' * P * u;
            if isfinite(Floor) && Floor > 0 && v < Floor
                P = P + (Floor - v) * (u * u');
            end
        end

        % Consider-parameter floor on the pure bias direction.
        for kk = 1:numel(Bs)
            u = zeros(Count, 1);
            u(Bs(kk)) = 1;
            Floor = P0(Bs(kk), Bs(kk));
            v = u' * P * u;
            if isfinite(Floor) && Floor > 0 && v < Floor
                P = P + (Floor - v) * (u * u');
            end
        end

    end

    P = (P + P') / 2;
end
