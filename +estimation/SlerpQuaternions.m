function Qq = SlerpQuaternions(Ts, Qs, Tq)
%SLERPQUATERNIONS Hemispherically aligned SLERP along a quaternion series.
%
%   Qq = SLERPQUATERNIONS(Ts, Qs, Tq) interpolates the quaternion series
%   Qs (Nx4, scalar-first [w x y z], sample times Ts Nx1) at the query
%   times Tq (Mx1) using SLERP between bracketing samples.
%
%   Consecutive source quaternions are first aligned to a consistent
%   hemisphere (q and -q represent the same rotation; a raw series can
%   flip sign at Euler wrap boundaries - reviewer finding F11), then every
%   query is SLERPed between its bracketing samples. Near-parallel
%   segments use a normalized lerp (numerically safe equivalent). Queries
%   outside the source time range produce NaN rows (no extrapolation),
%   matching interp1 behaviour.
%
%   INTERNAL helper. Not part of the public Block 10 API.
%
%   See also: EvaluateAgainstGroundTruth, CalculateEstimationMetrics.

    N = size(Qs, 1);
    Qa = Qs;

    % Hemisphere alignment along the series.
    for k = 2:N

        if dot(Qa(k, :), Qa(k - 1, :)) < 0
            Qa(k, :) = -Qa(k, :);
        end

    end

    % Normalize the sources.
    for k = 1:N
        Qa(k, :) = Qa(k, :) / max(norm(Qa(k, :)), realmin);
    end

    % Bracketing source rows for each query ('previous' and 'next' both
    % return the exact row on a match).
    Lower = interp1(Ts, (1:N)', Tq, 'previous');
    Upper = interp1(Ts, (1:N)', Tq, 'next');

    Qq = nan(numel(Tq), 4);

    for i = 1:numel(Tq)

        lo = Lower(i);
        hi = Upper(i);

        if isnan(lo) || isnan(hi)
            continue
        end

        qa = Qa(lo, :);

        if lo == hi
            Qq(i, :) = qa;
            continue
        end

        qb = Qa(hi, :);
        frac = (Tq(i) - Ts(lo)) / (Ts(hi) - Ts(lo));
        d = dot(qa, qb);

        if d > 0.9995
            % Near-parallel: normalized lerp is numerically safe.
            q = qa + frac .* (qb - qa);
            q = q / max(norm(q), realmin);
        else
            theta = acos(min(1, max(-1, d)));
            q = (sin((1 - frac) * theta) .* qa + ...
                sin(frac * theta) .* qb) / sin(theta);
            q = q / max(norm(q), realmin);
        end

        Qq(i, :) = q;

    end

end
