function K = AttitudeKinematics(roll, pitch, yaw)
%ATTITUDEKINEMATICS Shared ZYX attitude matrices and analytical partials.
%
%   K = ATTITUDEKINEMATICS(roll, pitch, yaw) returns the body-to-NED
%   direction cosine matrix and the analytical partial derivatives used
%   by the process and measurement Jacobians, so that both Jacobians and
%   the model functions share ONE implementation of the attitude math
%   (no duplicated rotation code that could drift apart):
%
%       K.Cbn          - body-to-NED DCM (ZYX), equals
%                        coordinates.Euler2DCM(roll, pitch, yaw)
%       K.dCbn_droll   - d Cbn / d roll
%       K.dCbn_dpitch  - d Cbn / d pitch
%       K.dCbn_dyaw    - d Cbn / d yaw
%       K.T            - ZYX Euler-rate transformation
%       K.dT_droll     - d T / d roll
%       K.dT_dpitch    - d T / d pitch
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: StateTransitionJacobian, MeasurementJacobian.

    if ~(isnumeric(roll) && isreal(roll) && isscalar(roll) && ...
            isfinite(roll) && isnumeric(pitch) && isreal(pitch) && ...
            isscalar(pitch) && isfinite(pitch) && ...
            isnumeric(yaw) && isreal(yaw) && isscalar(yaw) && ...
            isfinite(yaw))

        error( ...
            'Estimation:AttitudeKinematics:InvalidAngles', ...
            'roll, pitch and yaw must be finite real scalars.');

    end

    % The ZYX formulas are valid for every pitch EXCEPT exactly the
    % gimbal-lock angles |pitch| = 90 deg (cos(pitch) = 0), where the
    % Euler-rate map is genuinely unbounded. Outside that measure-zero
    % set - including |pitch| > 90 deg - the expressions are finite and
    % correct, so no guard may reject them (a hard error there crashed
    % the estimation flow on Run_001_20261124_220456 when the UKF state
    % reached 133 deg). Near the true lock the angle is nudged to the
    % nearest representable value and the run continues; the affected
    % interval is a documented degraded-estimate region.
    if abs(cos(pitch)) < 1e-6
        if pitch >= 0
            pitch = pi / 2 - 1e-6;
        else
            pitch = -pi / 2 + 1e-6;
        end
    end

    [sR, cR, sP, cP, sY, cY] = deal(sin(roll), cos(roll), ...
        sin(pitch), cos(pitch), sin(yaw), cos(yaw));
    tP = tan(pitch);

    Rx = [1, 0, 0; 0, cR, -sR; 0, sR, cR];
    Ry = [cP, 0, sP; 0, 1, 0; -sP, 0, cP];
    Rz = [cY, -sY, 0; sY, cY, 0; 0, 0, 1];

    dRx = [0, 0, 0; 0, -sR, -cR; 0, cR, -sR];
    dRy = [-sP, 0, cP; 0, 0, 0; -cP, 0, -sP];
    dRz = [-sY, -cY, 0; cY, -sY, 0; 0, 0, 0];

    K = struct();
    K.Cbn = Rz * Ry * Rx;
    K.dCbn_droll = Rz * Ry * dRx;
    K.dCbn_dpitch = Rz * dRy * Rx;
    K.dCbn_dyaw = dRz * Ry * Rx;

    K.T = [ ...
        1, sR * tP, cR * tP; ...
        0, cR, -sR; ...
        0, sR / cP, cR / cP];

    K.dT_droll = [ ...
        0, cR * tP, -sR * tP; ...
        0, -sR, -cR; ...
        0, cR / cP, -sR / cP];

    K.dT_dpitch = [ ...
        0, sR / (cP ^ 2), cR / (cP ^ 2); ...
        0, 0, 0; ...
        0, sR * sP / (cP ^ 2), cR * sP / (cP ^ 2)];

end
