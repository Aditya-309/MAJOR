function xNext = StateTransitionModel(x, dt, Accel_mps2, Gyro_radps, ...
        TauGNSSBias_s)
%STATETRANSITIONMODEL Approved 15-state strapdown inertial propagation.
%
%   xNext = STATETRANSITIONMODEL(x, dt, Accel_mps2, Gyro_radps)
%   propagates the approved 15-state ZYX Euler state over one interval
%   dt (s) using the measured specific force (m/s^2) and measured angular
%   rate (rad/s), both expressed in body axes [X Y Z] (X forward, Y
%   right, Z down).
%
%   Process model (approved strapdown model, task document 7):
%       p_dot = v
%       v_dot = Cbn(eta) * (f_m - b_a) + g_n
%       eta_dot = T(eta) * (omega_m - b_g)
%       b_a_dot = w_ba   (accelerometer bias random walk)
%       b_g_dot = w_bg   (gyroscope bias random walk)
%
%   Documented conventions (verified against the frozen project):
%       - Specific force: f = a - g, i.e. the accelerometer measures the
%         non-gravitational acceleration minus gravity; at rest in level
%         attitude f_body = [0; 0; -9.80665] (frozen Block 4 generator
%         +sensormodels/GenerateIdealIMU.m uses f_b = dv_b/dt +
%         omega_b x v_b - g_b).
%       - Body-to-navigation rotation: Cbn is the body-to-NED DCM in ZYX
%         (yaw-pitch-roll) order, identical to coordinates.Euler2DCM.
%       - Gravity: g_n = [0; 0; +g], g = 9.80665 m/s^2 (frozen
%         +dynamics/GravityModel("NED")); the NED Down axis is positive.
%       - Local NED / flat-Earth assumption: the navigation frame is a
%         local NED frame anchored at the run navigation origin; Earth
%         rotation (Coriolis) and transport-rate terms are neglected.
%         Justification: flights are short (<= 300 s) and low-velocity
%         (< 10 m/s) in this corpus, so those terms are orders of
%         magnitude below the configured sensor noise. The assumption and
%         its limits are recorded in the estimation report; the model
%         must not be used for long-duration or high-latitude navigation
%         without revisiting this term.
%       - Integration: first-order Euler with piecewise-constant (ZOH)
%         IMU input over each interval dt; dt is always the ACTUAL
%         interval between consecutive timeline events (never a fixed
%         step). The discretization error is O(dt^2) per step and is
%         characterized in the numerical test suite against a high-order
%         reference integration on the same ZOH input.
%       - Roll and yaw are carried continuous/unwrapped: this function
%         never wraps angles. The Euler-rate transformation T(eta) is
%         undefined at |pitch| = 90 deg; the estimator enforces the
%         configured singularity thresholds before propagation.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: StateTransitionJacobian, StateDefinition, MeasurementModel.

    Definition = estimation.StateDefinition(numel(x) > 15);

    if ~(isnumeric(x) && isreal(x) && ...
            isequal(size(x), [Definition.Count, 1]) && all(isfinite(x)))

        error( ...
            'Estimation:StateTransitionModel:InvalidState', ...
            'x must be a finite real %dx1 state vector.', ...
            Definition.Count);

    end

    if ~(isnumeric(dt) && isreal(dt) && isscalar(dt) && ...
            isfinite(dt) && dt > 0)

        error( ...
            'Estimation:StateTransitionModel:InvalidTimeStep', ...
            'dt must be a positive finite real scalar.');

    end

    if ~(isnumeric(Accel_mps2) && isreal(Accel_mps2) && ...
            isequal(size(Accel_mps2), [3, 1]) && all(isfinite(Accel_mps2)))

        error( ...
            'Estimation:StateTransitionModel:InvalidAccel', ...
            'Accel_mps2 must be a finite real 3x1 vector.');

    end

    if ~(isnumeric(Gyro_radps) && isreal(Gyro_radps) && ...
            isequal(size(Gyro_radps), [3, 1]) && all(isfinite(Gyro_radps)))

        error( ...
            'Estimation:StateTransitionModel:InvalidGyro', ...
            'Gyro_radps must be a finite real 3x1 vector.');

    end

    Idx = Definition.Index;

    p = x(Idx.pN:Idx.pD);
    v = x(Idx.vN:Idx.vD);
    eta = x(Idx.roll:Idx.yaw);
    b_a = x(Idx.bax:Idx.baz);
    b_g = x(Idx.bgx:Idx.bgz);

    roll = eta(1);
    pitch = eta(2);
    yaw = eta(3);

    % The ZYX formulas are valid for every pitch EXCEPT exactly the
    % gimbal-lock angles (cos(pitch) = 0). Near the true lock the angle
    % is nudged to the nearest representable value and the run continues
    % (flow guarantee: estimation never crashes on any state trajectory).
    if abs(cos(pitch)) < 1e-6
        if pitch >= 0
            pitch = pi / 2 - 1e-6;
        else
            pitch = -pi / 2 + 1e-6;
        end
    end

    Cbn = coordinates.Euler2DCM(roll, pitch, yaw);
    T = eulerRateTransformation(roll, pitch);
    g_n = dynamics.GravityModel("NED");

    f_bar = Accel_mps2 - b_a;
    w_bar = Gyro_radps - b_g;

    xNext = x;
    xNext(Idx.pN:Idx.pD) = p + v * dt;
    xNext(Idx.vN:Idx.vD) = v + (Cbn * f_bar + g_n) * dt;
    xNext(Idx.roll:Idx.yaw) = eta + (T * w_bar) * dt;

    % GNSS position-bias states (augmentation A1): exact Gauss-Markov
    % decay phi = exp(-dt/tau) driven by Block 5's BiasCorrelationTime_s.
    if Definition.EnableGNSSBiasStates

        if nargin < 5 || ~(isnumeric(TauGNSSBias_s) && isreal(TauGNSSBias_s) ...
                && isscalar(TauGNSSBias_s) && isfinite(TauGNSSBias_s) ...
                && TauGNSSBias_s > 0)

            error( ...
                'Estimation:StateTransitionModel:InvalidGNSSBiasTau', ...
                ['TauGNSSBias_s must be a positive finite scalar when ', ...
                'GNSS bias states are enabled.']);
        end

        Phi = exp(-dt / TauGNSSBias_s);
        xNext(Idx.bgn:Idx.bgd) = Phi * x(Idx.bgn:Idx.bgd);
    end

end

function T = eulerRateTransformation(roll, pitch)
%ZYX Euler-rate transformation T(roll, pitch): omega_body -> [roll;pitch;yaw]_dot.

    sinRoll = sin(roll);
    cosRoll = cos(roll);
    tanPitch = tan(pitch);
    cosPitch = cos(pitch);

    T = [ ...
        1, sinRoll * tanPitch, cosRoll * tanPitch; ...
        0, cosRoll, -sinRoll; ...
        0, sinRoll / cosPitch, cosRoll / cosPitch];

end
