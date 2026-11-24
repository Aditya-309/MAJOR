function P = ProtectNullSpaceCovariance(P, Directions, Floors)
%PROTECTNULLSPACECOVARIANCE Restore no-information variance floors.
%
%   P = ProtectNullSpaceCovariance(P, Directions, Floors) adds the
%   smallest PSD rank-one corrections that bring every protected
%   direction's variance back to its no-information floor (S8a). The
%   projection only ever ADDS variance in the named directions, keeps
%   symmetry, and leaves all other directions untouched.
%
%   INTERNAL function.

    if isempty(Directions)
        return
    end

    P = (P + P') / 2;

    for j = 1:size(Directions, 2)
        u = Directions(:, j);
        v = u' * P * u;

        if isfinite(Floors(j)) && Floors(j) > 0 && v < Floors(j)
            P = P + (Floors(j) - v) * (u * u');
        end

    end

    P = (P + P') / 2;
end
