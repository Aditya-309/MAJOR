function NoiseModels = BuildNoiseModels(Config)
%BUILDNOISEMODELS Build the documented process and measurement noise models.
%
%   NoiseModels = BUILDNOISEMODELS(Config) derives the discrete process
%   noise handle and the measurement covariance matrices from the Block 5
%   sensor-error configuration carried in Config.Noise. Every parameter
%   keeps its documented origin in NoiseModels.Provenance. No value is
%   invented and neither Q nor R is ever zero.
%
%   Process noise (continuous-time, white):
%       q_a  = AccelVRW^2            [(m/s^2)^2 s]  accel white noise PSD
%       q_g  = GyroARW^2             [(rad/s)^2 s]  gyro white noise PSD
%       q_ba = (AccelInRunBiasSigma * sqrt(2/tau))^2  accel bias RW
%       q_bg = (GyroInRunBiasSigma * sqrt(2/tau))^2   gyro bias RW
%
%   The bias states are modelled as random walks (approved model). The
%   diffusion coefficients are derived from the Block 5 first-order
%   Gauss-Markov in-run bias model by matching the initial covariance
%       d/dt Var(b) at 0 = 2 * sigma_GM^2 / tau
%   of the Gauss-Markov process, which the random walk reproduces with
%   sigma_RW = sigma_GM * sqrt(2/tau).
%
%   Discrete Q for the first-order Euler step of StateTransitionModel:
%       Q(x, dt) = G(x) * Qc * G(x)' * dt
%   with G(x) the 15x12 input-coupling matrix
%       G(v-block, accel noise)     = Cbn(eta)
%       G(eta-block, gyro noise)    = T(eta)
%       G(b_a-block, bias noise)    = I3
%       G(b_g-block, bias noise)    = I3
%   and Qc = diag([q_a q_a q_a q_g q_g q_g q_ba q_ba q_ba q_bg q_bg q_bg]).
%   The linear-in-dt discretization is the standard first-order
%   approximation valid for dt well below the bias correlation time
%   (dt <= 0.01 s nominal vs tau = 100 s here); the discretization is
%   exercised in the numerical test suite. dt is always the ACTUAL
%   interval of the current propagation step, so no fixed Q ignoring the
%   sample interval is ever used.
%
%   Measurement covariances:
%       R.GNSSPosition = diag(sigma_h^2 + sigma_bh^2, ..., sigma_v^2 +
%                        sigma_bv^2)  (m^2)
%       R.GNSSVelocity = sigma_vel^2 * I3  (m/s)^2
%       R.MagneticField = sigma_B^2 * I3  (T)^2
%   GNSS bias inflation (Config.Noise.GNSS.IncludeBiasInR, default true):
%   the approved 15-state model carries no GNSS bias states, so the
%   Block 5 slowly varying GNSS bias (Gauss-Markov, tau 60 s) is folded
%   conservatively into R as its steady-state variance. This is
%   documented, configurable, and applied identically to both filters.
%
%   Output fields:
%       .QHandle     - @(x, dt) discrete 15x15 process noise at state x
%       .QcDiag      - the 12 continuous-time PSDs [q_a q_a q_a q_g ...
%                      q_g q_g q_ba q_ba q_ba q_bg q_bg q_bg]
%       .BiasRW      - .AccelSigma_mps2SqrtS, .GyroSigma_radpsSqrtS
%       .R           - .GNSSPosition, .GNSSVelocity, .MagneticField
%       .Provenance  - per-parameter sources and derivation notes
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: EstimationConfig, StateTransitionModel, RunFilter.

    NoiseIMU = Config.Noise.IMU;
    NoiseGNSS = Config.Noise.GNSS;
    NoiseMag = Config.Noise.Magnetometer;

    %% Continuous-time PSDs

    q_a = NoiseIMU.AccelVRW_mps2SqrtHz ^ 2;
    q_g = NoiseIMU.GyroARW_radpsSqrtHz ^ 2;

    Tau = NoiseIMU.InRunBiasCorrelationTime_s;
    SigmaRWAccel = NoiseIMU.AccelInRunBiasSigma_mps2 * sqrt(2 / Tau);
    SigmaRWGyro = NoiseIMU.GyroInRunBiasSigma_radps * sqrt(2 / Tau);

    q_ba = SigmaRWAccel ^ 2;
    q_bg = SigmaRWGyro ^ 2;

    QcDiag = [q_a, q_a, q_a, q_g, q_g, q_g, ...
        q_ba, q_ba, q_ba, q_bg, q_bg, q_bg];

    %% Measurement covariances

    if NoiseGNSS.IncludeBiasInR

        RPos = diag([ ...
            NoiseGNSS.HorizontalSigma_m ^ 2 + ...
                NoiseGNSS.BiasSigmaHorizontal_m ^ 2, ...
            NoiseGNSS.HorizontalSigma_m ^ 2 + ...
                NoiseGNSS.BiasSigmaHorizontal_m ^ 2, ...
            NoiseGNSS.VerticalSigma_m ^ 2 + ...
                NoiseGNSS.BiasSigmaVertical_m ^ 2]);

    else

        RPos = diag([ ...
            NoiseGNSS.HorizontalSigma_m ^ 2, ...
            NoiseGNSS.HorizontalSigma_m ^ 2, ...
            NoiseGNSS.VerticalSigma_m ^ 2]);

    end

    RVel = eye(3) * NoiseGNSS.VelocitySigma_mps ^ 2;
    RMag = eye(3) * NoiseMag.Sigma_T ^ 2;

    %% Provenance

    Provenance = struct();
    Provenance.Source = Config.NoiseProvenance.Source;
    Provenance.QParameters = struct( ...
        'q_a', ['SensorNoiseConfig.IMU.AccelVRW_mps2SqrtHz^2 ', ...
            '(m/s^2)^2 s'], ...
        'q_g', ['SensorNoiseConfig.IMU.GyroARW_radpsSqrtHz^2 ', ...
            '(rad/s)^2 s'], ...
        'q_ba', ['(SensorNoiseConfig.IMU.AccelInRunBiasSigma_mps2 * ', ...
            'sqrt(2/tau))^2, tau = ', ...
            'SensorNoiseConfig.IMU.InRunBiasCorrelationTime_s'], ...
        'q_bg', ['(SensorNoiseConfig.IMU.GyroInRunBiasSigma_radps * ', ...
            'sqrt(2/tau))^2, tau = ', ...
            'SensorNoiseConfig.IMU.InRunBiasCorrelationTime_s']);
    Provenance.BiasRWDerivation = [ ...
        'sigma_RW = sigma_GM * sqrt(2/tau) matches the initial ', ...
        'variance rate of the Block 5 first-order Gauss-Markov in-run ', ...
        'bias model to the approved bias random walk.'];
    Provenance.QDiscretization = [ ...
        'Q(x, dt) = G(x) * Qc * G(x)'' * dt, first order in dt, with ', ...
        'the actual per-step interval; G maps accel noise through ', ...
        'Cbn(eta) into velocity, gyro noise through T(eta) into ', ...
        'attitude, and bias noise into the bias states.'];
    Provenance.RParameters = struct( ...
        'GNSSPosition', [ ...
            'SensorNoiseConfig.GNSS.Horizontal/VerticalNoiseSigma_m ', ...
            'squared'], ...
        'GNSSPositionBiasInflation', sprintf( ...
            'IncludeBiasInR = %d; when enabled the Block 5 GNSS ', ...
            'BiasSigma values (Gauss-Markov, tau %.0f s) are added as ', ...
            'steady-state variance because the approved state has no ', ...
            'GNSS bias states.', ...
            NoiseGNSS.IncludeBiasInR, NoiseGNSS.BiasCorrelationTime_s), ...
        'GNSSVelocity', ...
            'SensorNoiseConfig.GNSS.VelocityNoiseSigma_mps squared', ...
        'MagneticField', [ ...
            'SensorNoiseConfig.Magnetometer.NoiseSigma_uT converted ', ...
            'uT -> T and squared (canonical Block 9 unit T)']);

    %% Assemble

    NoiseModels = struct();
    NoiseModels.QHandle = @(x, dt) buildQ(x, dt, QcDiag);
    NoiseModels.QcDiag = QcDiag;
    NoiseModels.BiasRW = struct( ...
        'AccelSigma_mps2SqrtS', SigmaRWAccel, ...
        'GyroSigma_radpsSqrtS', SigmaRWGyro);
    NoiseModels.R = struct( ...
        'GNSSPosition', RPos, ...
        'GNSSVelocity', RVel, ...
        'MagneticField', RMag);
    NoiseModels.Provenance = Provenance;

end

function Q = buildQ(x, dt, QcDiag)
    Definition = estimation.StateDefinition();
    Idx = Definition.Index;

    eta = x(Idx.roll:Idx.yaw);
    K = estimation.AttitudeKinematics(eta(1), eta(2), eta(3));

    G = zeros(15, 12);
    G(Idx.vN:Idx.vD, 1:3) = K.Cbn;
    G(Idx.roll:Idx.yaw, 4:6) = K.T;
    G(Idx.bax:Idx.baz, 7:9) = eye(3);
    G(Idx.bgx:Idx.bgz, 10:12) = eye(3);

    Q = G * diag(QcDiag) * G' * dt;

end
