function Noise = GenerateSensorNoise(SensorTimeline, Config)
%GENERATESENSORNOISE Generate complete Block 5 sensor noise/error realization.
%
%   Noise = noisemodels.GenerateSensorNoise(SensorTimeline, Config)
%
%   Generates the complete stochastic sensor-error realization required
%   by Block 5 by invoking the independently validated sensor models:
%
%       GNSS:
%           - Gaussian measurement noise
%           - Slowly varying Gauss-Markov bias
%
%       IMU:
%           - Turn-on bias
%           - In-run Gauss-Markov bias
%           - Gaussian measurement noise
%           - Constant per-flight scale factor
%
%       Airspeed:
%           - Gaussian measurement noise
%
%       Magnetometer:
%           - Gaussian measurement noise
%
%   This function is an orchestration layer only. It does not implement
%   any stochastic model equations itself.
%
%   IMPORTANT:
%       SensorTimeline is expected to contain the already-established
%       sensor-specific time vectors. This function does not resample,
%       interpolate, or modify those timelines.
%
%   Expected SensorTimeline fields:
%
%       SensorTimeline.GNSS.Time_s
%       SensorTimeline.IMU.Time_s
%       SensorTimeline.AirData.Time_s
%       SensorTimeline.Magnetometer.Time_s
%
%   Output:
%
%       Noise.GNSS
%       Noise.IMU
%       Noise.Airspeed
%       Noise.Magnetometer
%
%   Each output branch is the direct result of the corresponding
%   Block 5 model.
%
%   This function does NOT:
%       - modify ideal sensor telemetry
%       - apply noise to measurements
%       - apply corruption severity
%       - implement outages/dropouts
%       - implement saturation
%       - implement estimator trust
%       - implement state estimation
%
%   Inputs:
%       SensorTimeline : structure containing sensor time vectors
%       Config         : Block 5 sensor-noise configuration
%
%   Example:
%       Config = noisemodels.SensorNoiseConfig();
%       Noise = noisemodels.GenerateSensorNoise(SensorTimeline, Config);

    if nargin ~= 2
        error( ...
            'ASRTE:GenerateSensorNoise:InvalidInputCount', ...
            'GenerateSensorNoise requires SensorTimeline and Config.');
    end

    if ~isstruct(SensorTimeline)
        error( ...
            'ASRTE:GenerateSensorNoise:InvalidSensorTimeline', ...
            'SensorTimeline must be a structure.');
    end

    if ~isstruct(Config)
        error( ...
            'ASRTE:GenerateSensorNoise:InvalidConfig', ...
            'Config must be a structure.');
    end

    RequiredSensorFields = { ...
        'GNSS', ...
        'IMU', ...
        'AirData', ...
        'Magnetometer'};

    for k = 1:numel(RequiredSensorFields)

        FieldName = RequiredSensorFields{k};

        if ~isfield(SensorTimeline, FieldName)
            error( ...
                'ASRTE:GenerateSensorNoise:MissingSensorTimeline', ...
                'SensorTimeline is missing required field "%s".', ...
                FieldName);
        end

        if ~isstruct(SensorTimeline.(FieldName))
            error( ...
                'ASRTE:GenerateSensorNoise:InvalidSensorTimelineBranch', ...
                'SensorTimeline.%s must be a structure.', ...
                FieldName);
        end

        if ~isfield(SensorTimeline.(FieldName), 'Time_s')
            error( ...
                'ASRTE:GenerateSensorNoise:MissingTimeField', ...
                'SensorTimeline.%s is missing Time_s.', ...
                FieldName);
        end
    end

    GNSS_Time = SensorTimeline.GNSS.Time_s;
    IMU_Time = SensorTimeline.IMU.Time_s;
    AirData_Time = SensorTimeline.AirData.Time_s;
    Magnetometer_Time = SensorTimeline.Magnetometer.Time_s;

    Noise = struct();

    Noise.GNSS = struct();

    GNSSNoise = noisemodels.GNSSNoiseModel( ...
        GNSS_Time, Config);

    GNSSBias = noisemodels.GNSSBiasModel( ...
        GNSS_Time, Config);

    Noise.GNSS.MeasurementNoise = GNSSNoise;
    Noise.GNSS.Bias = GNSSBias;

    Noise.IMU = struct();

    IMUNoise = noisemodels.IMUNoiseModel( ...
        IMU_Time, Config);

    IMUBias = noisemodels.IMUBiasModel( ...
        IMU_Time, Config);

    IMUScaleFactor = noisemodels.IMUScaleFactorModel( ...
        IMU_Time, Config);

    Noise.IMU.MeasurementNoise = IMUNoise;
    Noise.IMU.Bias = IMUBias;
    Noise.IMU.ScaleFactor = IMUScaleFactor;

    Noise.Airspeed = ...
        noisemodels.AirspeedNoiseModel( ...
            AirData_Time, Config);

    Noise.Magnetometer = ...
        noisemodels.MagnetometerNoiseModel( ...
            Magnetometer_Time, Config);
end