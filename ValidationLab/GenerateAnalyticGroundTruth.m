function [GroundTruth, Scenario] = GenerateAnalyticGroundTruth( ...
        ScenarioName, Duration_s, AnchorLLA)
%GENERATEANALYTICGROUNDTRUTH Analytic maneuvering truth generator (change B1).
%
%   [GroundTruth, Scenario] = GENERATEANALYTICGROUNDTRUTH(ScenarioName,
%   Duration_s, AnchorLLA) produces a kinematic ground-truth trajectory in
%   exactly the schema consumed by the frozen Block 5/8 generators
%   (sensormodels.GenerateIdeal*), so sensor simulation, preprocessing and
%   estimation run UNCHANGED on the result.
%
%   Structure: a 10 s STATIC ALIGNMENT SEGMENT (required by the estimator's
%   low-dynamic initialization) followed by the maneuver, entered through a
%   3 s smooth time-warp so position/velocity/acceleration stay continuous.
%
%   Scenarios (chosen for specific-force-direction excitation, satisfying
%   the observability conditions from the Journal of Navigation analysis):
%       'StaticHold'    - stationary hold (baseline, low observability)
%       'BankedTurn'    - sustained 30 deg coordinated turn
%       'FigureEight'   - figure-eight (changing specific force direction)
%       'Slalom'        - sinusoidal heading changes
%       'PitchDoublet'  - straight flight with pitch oscillation
%
%   AnchorLLA = [lat_rad, lon_rad, alt_m] trajectory origin.
%
%   B1 is KINEMATIC truth by design (documented limitation: Block 3 6-DOF
%   dynamics is not the source; the frozen Block 8 sensor equations derive
%   IMU/GNSS/mag/airdata from any GT through the audited physical model).

    if nargin < 2 || isempty(Duration_s)
        Duration_s = 60;
    end

    if nargin < 3 || isempty(AnchorLLA)
        AnchorLLA = [deg2rad(28.6), deg2rad(77.2), 300];
    end

    g = 9.80665;
    dt = 0.01;
    t = (0:dt:Duration_s)';
    N = numel(t);
    V = 25;                      % nominal airspeed, m/s

    % Alignment segment then smooth maneuver onset via time warping.
    tAlign = 10;
    Tw = 3;
    te = zeros(N, 1);

    for k = 1:N
        tau = t(k) - tAlign;

        if tau <= 0
            te(k) = 0;
        elseif tau <= Tw
            % h(tau) = tau^2 - tau^3/3 : h'(0)=0, h'(1)=1, h''(1)=0 -
            % the warp rate ramps 0 -> 1 with continuous acceleration.
            u = tau / Tw;
            te(k) = Tw * (u ^ 2 - u ^ 3 / 3);
        else
            te(k) = Tw * (2 / 3) + (tau - Tw);
        end

    end

    switch ScenarioName
        case 'StaticHold'
            pN = zeros(N, 1);
            pE = zeros(N, 1);
            psi = deg2rad(29.75) * ones(N, 1);
            theta = deg2rad(3) * ones(N, 1);
            phi = deg2rad(5) * ones(N, 1);

        case 'BankedTurn'
            Phi = deg2rad(30);
            PsiDot = g * tan(Phi) / V;
            psi = PsiDot * te;
            pN = (V / PsiDot) * sin(PsiDot * te);
            pE = (V / PsiDot) * (1 - cos(PsiDot * te));
            theta = deg2rad(5) * ones(N, 1);
            phi = Phi * ones(N, 1);

        case 'FigureEight'
            w = 2 * pi / max(Duration_s, 10);
            A = 300;
            pN = A * sin(w * te);
            pE = A * sin(w * te) .* cos(w * te);
            psi = unwrap(atan2(cos(2 * w * te), cos(w * te)));
            theta = deg2rad(3) * ones(N, 1);
            phi = zeros(N, 1);     % set below from psiDot (coordinated)

        case 'Slalom'
            w = 2 * pi / max(Duration_s / 3, 5);
            A = 150;
            pN = V * te;
            pE = A * sin(w * te);
            psi = unwrap(atan2(A * w * cos(w * te), V * ones(N, 1)));
            theta = deg2rad(3) * ones(N, 1);
            phi = zeros(N, 1);     % set below from psiDot (coordinated)

        case 'PitchDoublet'
            pN = V * te;
            pE = zeros(N, 1);
            psi = zeros(N, 1);
            theta = deg2rad(5 + 8 * sin(2 * pi * te / max(Duration_s / 2, 5)));
            phi = zeros(N, 1);

        otherwise
            error('ValidationLab:GenerateAnalyticGroundTruth:UnknownScenario', ...
                'Unknown scenario "%s".', ScenarioName);
    end

    pD = zeros(N, 1);

    % Rates and velocities from derivatives w.r.t. REAL time t - the
    % gradient automatically applies the time-warp chain rule.
    psiDot = gradient(psi, t);
    thetaDot = gradient(theta, t);
    phiDot = gradient(phi, t);

    if strcmp(ScenarioName, 'FigureEight') || ...
            strcmp(ScenarioName, 'Slalom')
        phi = atan2(V * psiDot, g * ones(N, 1));
        phiDot = gradient(phi, t);
    end

    omega = [ ...
        phiDot - psiDot .* sin(theta), ...
        thetaDot .* cos(phi) + psiDot .* sin(phi) .* cos(theta), ...
        -thetaDot .* sin(phi) + psiDot .* cos(phi) .* cos(theta)];

    vN = gradient(pN, t);
    vE = gradient(pE, t);
    vD = gradient(pD, t);

    % Body velocity and geodetic position.
    VelocityBody = zeros(N, 3);
    Lat = zeros(N, 1);
    Lon = zeros(N, 1);
    Alt = zeros(N, 1);
    Anchor = struct('Latitude_rad', AnchorLLA(1), ...
        'Longitude_rad', AnchorLLA(2), 'Altitude_m', AnchorLLA(3));

    for k = 1:N
        Cbn = coordinates.Euler2DCM(phi(k), theta(k), psi(k));
        VelocityBody(k, :) = (Cbn' * [vN(k); vE(k); vD(k)])';
        [Lat(k), Lon(k), Alt(k)] = estimation.ConvertNED2LLA( ...
            pN(k), pE(k), pD(k), Anchor);
    end

    GroundTruth = struct();
    GroundTruth.Time_s = t;
    GroundTruth.SampleTime_s = t(2) - t(1);   % sample period (scalar)
    GroundTruth.SampleCount = N;
    GroundTruth.AirDensity_kgpm3 = 1.225 * ones(N, 1);   % ~300 m MSL
    GroundTruth.Position = struct( ...
        'Latitude_rad', Lat, 'Longitude_rad', Lon, 'Altitude_m', Alt);
    GroundTruth.VelocityBody_mps = VelocityBody;
    GroundTruth.AngularRateBody_radps = omega;
    GroundTruth.Euler_rad = [phi, theta, psi];
    GroundTruth.Validation = struct('Source', 'GenerateAnalyticGroundTruth', ...
        'Scenario', ScenarioName, 'KinematicTruth', true, ...
        'AlignmentSegment_s', tAlign);

    Scenario = struct('Name', ScenarioName, ...
        'Wind', struct('ConstantNED_mps', [0; 0; 0], ...
        'Gust', struct('Enabled', false, 'PeakNED_mps', [0; 0; 0])), ...
        'Events', struct('WindDisturbance', struct('Enabled', false, ...
        'StartTime_s', 0, 'EndTime_s', 0)));

end
