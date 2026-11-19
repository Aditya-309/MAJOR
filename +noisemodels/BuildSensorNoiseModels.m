
function SensorNoiseModels = BuildSensorNoiseModels(Config)
% noisemodels.BuildSensorNoiseModels
%
% Build the Block 5 sensor-noise model configuration used by the
% stochastic sensor-noise generation pipeline.
%
% This function:
%   1. Validates the supplied sensor-noise configuration.
%   2. Returns a validated, immutable-by-convention model configuration
%      structure containing the exact configuration used by each frozen
%      Block 5 noise model.
%
% This function does NOT:
%   - generate random numbers
%   - generate sensor noise
%   - apply sensor noise
%   - modify Config
%   - implement outages or faults
%   - implement estimator/trust logic
%
% Usage:
%   SensorNoiseModels = noisemodels.BuildSensorNoiseModels(Config)
%
% The returned structure contains:
%   SensorNoiseModels.Config
%   SensorNoiseModels.GNSS
%   SensorNoiseModels.IMU
%   SensorNoiseModels.Airspeed
%   SensorNoiseModels.Magnetometer
%
% Each sensor entry identifies the frozen Block 5 model components and
% carries the corresponding validated configuration.

    %% Input handling

    if nargin < 1
        Config = noisemodels.SensorNoiseConfig();
    elseif nargin ~= 1
        error('noisemodels:BuildSensorNoiseModels:InvalidInputCount', ...
            'BuildSensorNoiseModels accepts zero or one input.');
    end

    %% Validate configuration

    noisemodels.ValidateSensorNoiseConfig(Config);

    %% Build model description

    SensorNoiseModels = struct();

    % Preserve the exact validated configuration.
    SensorNoiseModels.Config = Config;

    %% GNSS

    SensorNoiseModels.GNSS = struct( ...
        'NoiseModel', @noisemodels.GNSSNoiseModel, ...
        'BiasModel', @noisemodels.GNSSBiasModel);

    %% IMU

    SensorNoiseModels.IMU = struct( ...
        'NoiseModel', @noisemodels.IMUNoiseModel, ...
        'BiasModel', @noisemodels.IMUBiasModel, ...
        'ScaleFactorModel', @noisemodels.IMUScaleFactorModel);

    %% Airspeed

    SensorNoiseModels.Airspeed = struct( ...
        'NoiseModel', @noisemodels.AirspeedNoiseModel);

    %% Magnetometer

    SensorNoiseModels.Magnetometer = struct( ...
        'NoiseModel', @noisemodels.MagnetometerNoiseModel);

end
