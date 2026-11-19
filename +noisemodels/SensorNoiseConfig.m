function Config = SensorNoiseConfig(varargin)
%SENSORNOISECONFIG Create the Block 5 sensor-error configuration.
%
%   Config = sensormodels.SensorNoiseConfig()
%   creates the default deterministic sensor-error configuration.
%
%   Config = sensormodels.SensorNoiseConfig(Name,Value,...)
%   allows approved configuration items to be overridden.
%
%   Block 5 models:
%
%       GNSS
%           Gaussian white measurement noise
%           Slowly varying stochastic bias
%
%       IMU
%           Constant per-flight turn-on bias
%           First-order Gauss-Markov in-run bias
%           Gaussian white measurement noise
%           Constant per-flight scale factor
%
%       AirData
%           Gaussian measurement-error model
%
%       Magnetometer
%           Gaussian measurement-error model
%
%   This function ONLY defines model parameters.
%   It does not generate random numbers and does not modify telemetry.

    %% Default configuration

    Config = struct();

    Config.RandomSeed = 20260801;

    Config.Corruption = struct();

    Config.Corruption.GNSS = 0;
    Config.Corruption.IMU = 0;
    Config.Corruption.Airspeed = 0;
    Config.Corruption.Magnetometer = 0;

    %% GNSS

    Config.GNSS = struct();

    % Horizontal position noise.
    Config.GNSS.HorizontalNoiseSigma_m = 0.85;

    % Vertical position noise.
    %
    % Engineering-derived from the selected horizontal basis and the
    % manufacturer guidance that GNSS height is generally poorer than
    % horizontal position.
    Config.GNSS.VerticalNoiseSigma_m = 1.80;

    % Velocity noise.
    Config.GNSS.VelocityNoiseSigma_mps = 0.03;

    % Slowly varying bias.
    Config.GNSS.BiasSigmaHorizontal_m = 0.30;
    Config.GNSS.BiasSigmaVertical_m = 0.45;
    Config.GNSS.BiasCorrelationTime_s = 60;

    %% IMU

    Config.IMU = struct();

    % Gyroscope turn-on bias.
    Config.IMU.GyroTurnOnBiasSigma_radps = ...
        deg2rad(20) / 3600;

    % Gyroscope in-run Gauss-Markov bias.
    Config.IMU.GyroInRunBiasSigma_radps = ...
        deg2rad(0.45) / 3600;

    Config.IMU.GyroInRunBiasCorrelationTime_s = 100;

    % Gyroscope angle random walk.
    Config.IMU.GyroARW_radpsSqrtHz = ...
        deg2rad(0.06) / 60;

    % Gyroscope scale-factor repeatability.
    Config.IMU.GyroScaleFactorSigma = 300e-6;

    % Accelerometer turn-on bias.
    Config.IMU.AccelTurnOnBiasSigma_mps2 = ...
        3.0e-3 * 9.80665;

    % Accelerometer in-run Gauss-Markov bias.
    Config.IMU.AccelInRunBiasSigma_mps2 = ...
        0.075e-3 * 9.80665;

    Config.IMU.AccelInRunBiasCorrelationTime_s = 100;

    % Velocity random walk.
    Config.IMU.AccelVRW_mps2SqrtHz = ...
        0.06 / sqrt(3600);

    % Accelerometer scale-factor repeatability.
    Config.IMU.AccelScaleFactorSigma = 120e-6;

    %% Air Data

    Config.Airspeed = struct();

    % Engineering stochastic interpretation of the published Atlas
    % airspeed-error envelope.
    Config.Airspeed.NoiseSigma_mps = 1.0;

    %% Magnetometer

    Config.Magnetometer = struct();

    % Engineering stochastic interpretation derived from the published
    % HMR2300 accuracy specification.
    Config.Magnetometer.NoiseSigma_uT = 0.12;

    %% Apply optional overrides

    if mod(nargin, 2) ~= 0

        error( ...
            'ASRTE:SensorNoiseConfig:InvalidNameValueArguments', ...
            'Name-value arguments must be supplied in pairs.');

    end

    for k = 1:2:nargin

        Name = varargin{k};
        Value = varargin{k + 1};

        if ~(ischar(Name) || ...
                (isstring(Name) && isscalar(Name)))

            error( ...
                'ASRTE:SensorNoiseConfig:InvalidParameterName', ...
                'Parameter names must be character vectors or scalar strings.');

        end

        Name = char(Name);

        switch lower(Name)

            case 'randomseed'

                Config.RandomSeed = Value;

            case 'gnsscorruption'

                Config.Corruption.GNSS = Value;

            case 'imucorruption'

                Config.Corruption.IMU = Value;

            case 'airspeedcorruption'

                Config.Corruption.Airspeed = Value;

            case 'magnetometercorruption'

                Config.Corruption.Magnetometer = Value;

            otherwise

                error( ...
                    'ASRTE:SensorNoiseConfig:UnknownParameter', ...
                    'Unknown configuration parameter "%s".', ...
                    Name);

        end

    end

    %% Validate scalar configuration items

    if ~isnumeric(Config.RandomSeed) || ...
            ~isreal(Config.RandomSeed) || ...
            ~isscalar(Config.RandomSeed) || ...
            ~isfinite(Config.RandomSeed) || ...
            Config.RandomSeed ~= floor(Config.RandomSeed) || ...
            Config.RandomSeed < 0

        error( ...
            'ASRTE:SensorNoiseConfig:InvalidRandomSeed', ...
            'RandomSeed must be a nonnegative integer scalar.');

    end

    CorruptionNames = ...
        {'GNSS', 'IMU', 'Airspeed', 'Magnetometer'};

    for k = 1:numel(CorruptionNames)

        SensorName = CorruptionNames{k};

        CorruptionValue = ...
            Config.Corruption.(SensorName);

        if ~isnumeric(CorruptionValue) || ...
                ~isreal(CorruptionValue) || ...
                ~isscalar(CorruptionValue) || ...
                ~isfinite(CorruptionValue) || ...
                CorruptionValue < 0 || ...
                CorruptionValue > 100

            error( ...
                'ASRTE:SensorNoiseConfig:InvalidCorruptionSeverity', ...
                ['%s corruption severity must be a finite ', ...
                 'real scalar in the range 0 to 100 percent.'], ...
                SensorName);

        end

    end

end