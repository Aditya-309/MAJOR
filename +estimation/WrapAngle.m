function Angle = WrapAngle(Angle)
%WRAPANGLE Wrap angular quantities to the interval (-pi, pi].
%
%   Angle = WRAPANGLE(Angle) wraps radians to (-pi, pi]. Works on arrays
%   of any size and preserves NaN and Inf (returned unchanged).
%
%   Used for presentation and for angular measurement residuals. Roll and
%   yaw state components remain continuous/unwrapped internally and are
%   never passed through this function during propagation.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: StateDefinition, MeasurementModel.

    Angle = mod(Angle + pi, 2 * pi) - pi;

    % mod() maps exact -pi to -pi; the declared interval is (-pi, pi].
    Angle(Angle == -pi & isfinite(Angle)) = pi;

end
