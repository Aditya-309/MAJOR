function F = StateTransitionJacobian(x, dt, Accel_mps2, Gyro_radps, ...
        TauGNSSBias_s)
%STATETRANSITIONJACOBIAN Analytical Jacobian of the strapdown propagation.
%
%   F = STATETRANSITIONJACOBIAN(x, dt, Accel_mps2, Gyro_radps) returns
%   the 15x15 state-transition Jacobian of the first-order Euler
%   discretization used by StateTransitionModel:
%
%       F = I + dt * A(x, u)
%
%   where A is the continuous-time Jacobian of the approved strapdown
%   process model with respect to the state:
%
%       A = [ 0       I        0        0        0     ]
%           [ 0       0    dCbn/deta*f  -Cbn     0     ]
%           [ 0       0    dT/deta*w     0       -T    ]
%           [ 0       0        0        0        0     ]
%           [ 0       0        0        0        0     ]
%
%   with f = f_m - b_a, w = omega_m - b_g and
%
%       dCbn/deta*f = [dCbn/droll*f, dCbn/dpitch*f, dCbn/dyaw*f]
%       dT/deta*w   = [dT/droll*w,   dT/dpitch*w,   0]
%
%   The Cbn derivatives follow from Cbn = Rz(yaw)*Ry(pitch)*Rx(roll):
%       dCbn/droll  = Rz*Ry*dRx/droll
%       dCbn/dpitch = Rz*dRy/dpitch*Rx
%       dCbn/dyaw   = dRz/dyaw*Ry*Rx
%
%   The analytical Jacobian is verified numerically against central
%   finite differences of StateTransitionModel in the numerical test
%   suite over valid operating regions.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: StateTransitionModel, MeasurementJacobian.

    Definition = estimation.StateDefinition(numel(x) > 15);

    if ~(isnumeric(x) && isreal(x) && ...
            isequal(size(x), [Definition.Count, 1]) && all(isfinite(x)))

        error( ...
            'Estimation:StateTransitionJacobian:InvalidState', ...
            'x must be a finite real %dx1 state vector.', ...
            Definition.Count);

    end

    if ~(isnumeric(dt) && isreal(dt) && isscalar(dt) && ...
            isfinite(dt) && dt > 0)

        error( ...
            'Estimation:StateTransitionJacobian:InvalidTimeStep', ...
            'dt must be a positive finite real scalar.');

    end

    if ~(isnumeric(Accel_mps2) && isreal(Accel_mps2) && ...
            isequal(size(Accel_mps2), [3, 1]) && all(isfinite(Accel_mps2)))

        error( ...
            'Estimation:StateTransitionJacobian:InvalidAccel', ...
            'Accel_mps2 must be a finite real 3x1 vector.');

    end

    if ~(isnumeric(Gyro_radps) && isreal(Gyro_radps) && ...
            isequal(size(Gyro_radps), [3, 1]) && all(isfinite(Gyro_radps)))

        error( ...
            'Estimation:StateTransitionJacobian:InvalidGyro', ...
            'Gyro_radps must be a finite real 3x1 vector.');

    end

    Idx = Definition.Index;

    eta = x(Idx.roll:Idx.yaw);
    b_a = x(Idx.bax:Idx.baz);
    b_g = x(Idx.bgx:Idx.bgz);

    roll = eta(1);
    pitch = eta(2);
    yaw = eta(3);

    if abs(pitch) >= pi / 2

        error( ...
            'Estimation:StateTransitionJacobian:PitchSingularity', ...
            ['The ZYX Euler-rate transformation is undefined at ', ...
             '|pitch| >= 90 deg (pitch = %.4f deg).'], ...
            rad2deg(pitch));

    end

    f_bar = Accel_mps2 - b_a;
    w_bar = Gyro_radps - b_g;

    % Shared attitude matrices and analytical partials (single source).
    K = estimation.AttitudeKinematics(roll, pitch, yaw);
    Cbn = K.Cbn;
    dCbn_droll = K.dCbn_droll;
    dCbn_dpitch = K.dCbn_dpitch;
    dCbn_dyaw = K.dCbn_dyaw;
    T = K.T;
    dT_droll = K.dT_droll;
    dT_dpitch = K.dT_dpitch;

    % Continuous Jacobian blocks
    A = zeros(Definition.Count);

    A(Idx.pN:Idx.pD, Idx.vN:Idx.vD) = eye(3);
    A(Idx.vN:Idx.vD, Idx.roll:Idx.yaw) = [ ...
        dCbn_droll * f_bar, ...
        dCbn_dpitch * f_bar, ...
        dCbn_dyaw * f_bar];
    A(Idx.vN:Idx.vD, Idx.bax:Idx.baz) = -Cbn;
    A(Idx.roll:Idx.yaw, Idx.roll:Idx.yaw) = [ ...
        dT_droll * w_bar, ...
        dT_dpitch * w_bar, ...
        zeros(3, 1)];
    A(Idx.roll:Idx.yaw, Idx.bgx:Idx.bgz) = -T;

    F = eye(Definition.Count) + A * dt;

    % GNSS position-bias states: exact Gauss-Markov derivative.
    if Definition.EnableGNSSBiasStates

        if nargin < 5 || ~(isnumeric(TauGNSSBias_s) && isscalar(TauGNSSBias_s) ...
                && isfinite(TauGNSSBias_s) && TauGNSSBias_s > 0)

            error( ...
                'Estimation:StateTransitionJacobian:InvalidGNSSBiasTau', ...
                'TauGNSSBias_s must be a positive finite scalar.');
        end

        F(Idx.bgn:Idx.bgd, Idx.bgn:Idx.bgd) = ...
            exp(-dt / TauGNSSBias_s) * eye(3);
    end

end
