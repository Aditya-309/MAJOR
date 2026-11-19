function Config = SensorConfig()
%SENSORCONFIG Define the frozen Block 4 sensor configuration.
%
%   Config = SENSORCONFIG() returns the deterministic configuration for the
%   project's frozen sensor suite:
%
%       1. GNSS
%       2. IMU
%          - Accelerometer
%          - Gyroscope
%       3. Air Data
%       4. Magnetometer
%
%   Block 4 uses this configuration only to define ideal sensor behavior,
%   native sample rates, and deterministic physical model parameters.
%
%   Error, noise, bias, random-walk, dropout, outage, fault, and
%   quantization behavior are not generated in this function.
%
%   Specification parameters required by future blocks may be preserved as
%   configuration data, but no downstream stochastic behavior is implemented
%   here.

    %% Configuration Metadata

    Config = struct();

    Config.Name = ...
        "Block4SensorConfiguration";

    Config.Version = ...
        "1.0";

    %% GNSS Configuration
    %
    % Native update rate is representative of a standard GNSS receiver.
    %
    % Position and velocity measurements generated in Block 4 remain ideal.
    % Accuracy-related specifications are preserved only for downstream
    % sensor-error modelling and are not applied here.

    Config.GNSS = struct();

    Config.GNSS.SampleRate_Hz = 10.0;

    Config.GNSS.PositionAccuracyHorizontal_m = 2.5;

    Config.GNSS.PositionAccuracyVertical_m = 4.0;

    Config.GNSS.VelocityAccuracy_mps = 0.1;

    %% IMU Configuration

    Config.IMU = struct();

    Config.IMU.SampleRate_Hz = 100.0;

    %% Accelerometer Configuration
    %
    % Block 4 generates ideal specific force only.
    %
    % Measurement range is retained as a physical sensor specification.
    % Noise density and bias-related specifications are retained for
    % downstream modelling but are not applied in Block 4.

    Config.IMU.Accelerometer = struct();

    Config.IMU.Accelerometer.FullScale_mps2 = ...
        16.0 * 9.80665;

    Config.IMU.Accelerometer.NoiseDensity_mps2_per_sqrtHz = ...
        0.001;

    Config.IMU.Accelerometer.BiasInstability_mps2 = ...
        0.001;

    %% Gyroscope Configuration
    %
    % Block 4 generates ideal body angular rate only.
    %
    % Measurement range is retained as a physical sensor specification.
    % Noise density and bias-related specifications are retained for
    % downstream modelling but are not applied in Block 4.

    Config.IMU.Gyroscope = struct();

    Config.IMU.Gyroscope.FullScale_radps = ...
        deg2rad(2000.0);

    Config.IMU.Gyroscope.NoiseDensity_radps_per_sqrtHz = ...
        deg2rad(0.005);

    Config.IMU.Gyroscope.BiasInstability_radps = ...
        deg2rad(0.1);

    %% Air Data Configuration
    %
    % Block 4 generates ideal true airspeed and dynamic pressure.
    %
    % Native update rate represents a typical electronic air-data sensing
    % subsystem. Pressure range is retained as a physical specification.

    Config.AirData = struct();

    Config.AirData.SampleRate_Hz = 50.0;

    Config.AirData.DynamicPressureRange_Pa = ...
        [0.0, 20000.0];

    %% Magnetometer Configuration
    %
    % Block 4 generates the deterministic Earth magnetic field transformed
    % into the aircraft body frame.
    %
    % Native update rate represents a typical three-axis magnetometer.
    % Measurement range is retained as a physical sensor specification.

    Config.Magnetometer = struct();

    Config.Magnetometer.SampleRate_Hz = 50.0;

    Config.Magnetometer.FullScale_uT = 4900.0;

    %% Deterministic Availability Configuration
    %
    % Block 4 ideal sensors are always available. This field defines the
    % deterministic availability policy only; no outage or dropout behaviour
    % is generated here.

    Config.Availability = struct();

    Config.Availability.GNSS = true;

    Config.Availability.IMU = true;

    Config.Availability.AirData = true;

    Config.Availability.Magnetometer = true;

end