function [Directions, Floors] = DefineNullSpaceDirections(P0, Definition)
%DEFINEDIRECTIONSOFNULLSPACE No-information directions of the bias pairs.
%
%   [Directions, Floors] = DefineNullSpaceDirections(P0, Definition)
%   derives the unobservable split directions of each turn-on-bias pair
%   from the INITIAL joint covariance exactly (S8a, 2026-11-24):
%
%       z = x + b (or leveling: delta_theta = J_level * b_a) leaves the
%       SPLIT of the error between x and b unobservable. The split
%       direction is recovered from the honest S1/A1 joint prior via
%       u = (P0(x,b) / P0(b,b) * e_k, e_k) - no tuning, no extra
%       parameters: the floors are the no-information prior variances
%       u' * P0 * u.
%
%   Sequential updates numerically chip away at these null directions
%   (measured: 3-11x variance loss in 30 s on exact-model data), which
%   makes the filter report confidence the data never delivered.
%   ProtectNullSpaceCovariance restores the floor.
%
%   INTERNAL function.

    Idx = Definition.Index;
    Count = Definition.Count;
    Directions = zeros(Count, 0);
    Floors = zeros(1, 0);

    Pairs = { ...
        Idx.roll:Idx.yaw,    Idx.bgx:Idx.bgz; ...   % gyro-bias / attitude
        Idx.roll:Idx.pitch,  Idx.bax:Idx.baz};      % accel-bias / tilt

    % GNSS-bias states exist only in the 18-state model (field guard —
    % the 15-state Index has no bgn/bge/bgd).
    if isfield(Idx, 'bgn')
        Pairs(end + 1, :) = {Idx.pN:Idx.pD, Idx.bgn:Idx.bgd};
    end

    for p = 1:size(Pairs, 1)
        Xs = Pairs{p, 1};
        Bs = Pairs{p, 2};

        if max(Bs) > Count
            continue
        end

        Pbb = P0(Bs, Bs);
        Pxb = P0(Xs, Bs);

        if rcond(Pbb) < 1e-12
            continue
        end

        J = Pxb / Pbb;

        for kk = 1:numel(Bs)
            u = zeros(Count, 1);
            u(Xs) = J(:, kk);
            u(Bs(kk)) = 1;
            u = u / max(norm(u), realmin);
            Directions(:, end + 1) = u; %#ok<AGROW>
            Floors(end + 1) = u' * P0 * u; %#ok<AGROW>
        end

        % Consider-parameter completion: the turn-on bias itself is not
        % credited with being learned below its declared prior within a
        % single flight. The split manifold ROTATES with the dynamics, so
        % the initial-manifold floors alone leak along the rotated
        % directions (measured: pos block 9.3 with only split floors).
        % Flooring the pure bias directions at the prior closes the leak
        % and is the honest reading of the Block 5 turn-on-bias semantics.
        for kk = 1:numel(Bs)
            u = zeros(Count, 1);
            u(Bs(kk)) = 1;
            Directions(:, end + 1) = u; %#ok<AGROW>
            Floors(end + 1) = P0(Bs(kk), Bs(kk)); %#ok<AGROW>
        end

    end

end
