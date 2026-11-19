function SensorTelemetry = ApplySensorNoise(IdealTelemetry, Noise)
%APPLYSENSORNOISE Apply generated Block 5 errors to ideal sensor telemetry.
%
%   SensorTelemetry = noisemodels.ApplySensorNoise(IdealTelemetry, Noise)
%
%   Applies the already-generated stochastic error realizations from
%   noisemodels.GenerateSensorNoise to the frozen Block 4 ideal sensor
%   telemetry.
%
%   This function is deterministic for a given pair of inputs. It does
%   NOT generate random numbers.
%
%   Ideal telemetry branches:
%       GNSS
%       IMU
%       AirData
%       Magnetometer
%
%   Noise branches:
%       GNSS
%       IMU
%       Airspeed
%       Magnetometer
%
%   GNSS errors:
%       Position = Gaussian measurement noise + slowly varying bias
%       Velocity = Gaussian measurement noise
%
%   IMU errors:
%       Measurement = (ideal + total bias + white noise)
%                     .* (1 + scale factor)
%
%   Airspeed:
%       TrueAirspeed = ideal true airspeed + Gaussian noise
%
%       DynamicPressure is updated consistently with the corrupted
%       airspeed while preserving the ideal air-data relationship:
%
%           q_corrupt = q_ideal * (V_corrupt / V_ideal)^2
%
%       If ideal airspeed is exactly zero, dynamic pressure is retained
%       at its ideal value.
%
%   Magnetometer:
%       MagneticField = ideal magnetic field + Gaussian noise
%
%   This function does NOT:
%       - generate random numbers
%       - modify Ground Truth
%       - modify IdealTelemetry
%       - apply corruption severity
%       - implement outages/dropouts
%       - implement sensor faults
%       - implement estimator trust
%       - implement state estimation

    if nargin ~= 2
        error( ...
            'ASRTE:ApplySensorNoise:InvalidInputCount', ...
            'ApplySensorNoise requires IdealTelemetry and Noise.');
    end

    if ~isstruct(IdealTelemetry)
        error( ...
            'ASRTE:ApplySensorNoise:InvalidIdealTelemetry', ...
            'IdealTelemetry must be a structure.');
    end

    if ~isstruct(Noise)
        error( ...
            'ASRTE:ApplySensorNoise:InvalidNoise', ...
            'Noise must be a structure.');
    end

    % ================================================================
    % Validate ideal telemetry branches.
    % ================================================================

    RequiredIdealSensors = { ...
        'GNSS', ...
        'IMU', ...
        'AirData', ...
        'Magnetometer'};

    for k = 1:numel(RequiredIdealSensors)

        SensorName = RequiredIdealSensors{k};

        if ~isfield(IdealTelemetry, SensorName)
            error( ...
                'ASRTE:ApplySensorNoise:MissingIdealSensor', ...
                'IdealTelemetry is missing required field "%s".', ...
                SensorName);
        end

        if ~isstruct(IdealTelemetry.(SensorName))
            error( ...
                'ASRTE:ApplySensorNoise:InvalidIdealSensor', ...
                'IdealTelemetry.%s must be a structure.', ...
                SensorName);
        end
    end

    % ================================================================
    % Validate noise branches.
    %
    % Air-data telemetry is called AirData, but its stochastic model is
    % called Airspeed. These are intentionally different interfaces.
    % ================================================================

    RequiredNoiseSensors = { ...
        'GNSS', ...
        'IMU', ...
        'Airspeed', ...
        'Magnetometer'};

    for k = 1:numel(RequiredNoiseSensors)

        SensorName = RequiredNoiseSensors{k};

        if ~isfield(Noise, SensorName)
            error( ...
                'ASRTE:ApplySensorNoise:MissingNoiseSensor', ...
                'Noise is missing required field "%s".', ...
                SensorName);
        end

        if ~isstruct(Noise.(SensorName))
            error( ...
                'ASRTE:ApplySensorNoise:InvalidNoiseSensor', ...
                'Noise.%s must be a structure.', ...
                SensorName);
        end
    end

    % ================================================================
    % Validate ideal telemetry fields.
    % ================================================================

    RequiredIdealSubfields = { ...
        {'Time_s', 'Latitude_rad', 'Longitude_rad', ...
         'Altitude_m', 'Velocity_NED_mps'}, ...
        {'Time_s', 'Accelerometer_mps2', ...
         'Gyroscope_radps'}, ...
        {'Time_s', 'TrueAirspeed_mps', ...
         'DynamicPressure_Pa'}, ...
        {'Time_s', 'MagneticFieldBody_uT'}};

    for k = 1:numel(RequiredIdealSensors)

        SensorName = RequiredIdealSensors{k};
        Fields = RequiredIdealSubfields{k};

        for j = 1:numel(Fields)

            FieldName = Fields{j};

            if ~isfield(IdealTelemetry.(SensorName), FieldName)
                error( ...
                    'ASRTE:ApplySensorNoise:MissingIdealField', ...
                    'IdealTelemetry.%s is missing field "%s".', ...
                    SensorName, FieldName);
            end
        end
    end

    % ================================================================
    % Validate noise sub-branches.
    % ================================================================

    RequiredNoiseSubfields = { ...
        {'MeasurementNoise', 'Bias'}, ...
        {'MeasurementNoise', 'Bias', 'ScaleFactor'}, ...
        {'AirspeedNoise_mps'}, ...
        {'MagnetometerNoise_uT'}};

    for k = 1:numel(RequiredNoiseSensors)

        SensorName = RequiredNoiseSensors{k};
        Fields = RequiredNoiseSubfields{k};

        for j = 1:numel(Fields)

            FieldName = Fields{j};

            if ~isfield(Noise.(SensorName), FieldName)
                error( ...
                    'ASRTE:ApplySensorNoise:MissingNoiseField', ...
                    'Noise.%s is missing field "%s".', ...
                    SensorName, FieldName);
            end
        end
    end

    % ================================================================
    % Copy input first so IdealTelemetry is never modified.
    % ================================================================

    SensorTelemetry = IdealTelemetry;

    % ================================================================
    % GNSS
    % ================================================================

    GNSS = IdealTelemetry.GNSS;

    GNSSNoise = Noise.GNSS.MeasurementNoise;
    GNSSBias = Noise.GNSS.Bias;

    GNSSPositionError_m = ...
        GNSSNoise.PositionNoise_m + ...
        GNSSBias.PositionBias_m;

    GNSSVelocityError_mps = ...
        GNSSNoise.VelocityNoise_mps;

    N_GNSS = numel(GNSS.Time_s);

    if ~isequal(size(GNSSPositionError_m), [N_GNSS 3])
        error( ...
            'ASRTE:ApplySensorNoise:GNSSPositionDimensionMismatch', ...
            'GNSS position error must have N-by-3 dimensions.');
    end

    if ~isequal(size(GNSSVelocityError_mps), [N_GNSS 3])
        error( ...
            'ASRTE:ApplySensorNoise:GNSSVelocityDimensionMismatch', ...
            'GNSS velocity error must have N-by-3 dimensions.');
    end

    Latitude_rad = GNSS.Latitude_rad(:);
    Longitude_rad = GNSS.Longitude_rad(:);
    Altitude_m = GNSS.Altitude_m(:);

    if numel(Latitude_rad) ~= N_GNSS || ...
            numel(Longitude_rad) ~= N_GNSS || ...
            numel(Altitude_m) ~= N_GNSS
        error( ...
            'ASRTE:ApplySensorNoise:GNSSTelemetryDimensionMismatch', ...
            'GNSS position fields must contain N samples.');
    end

    % WGS84 constants.
    a = 6378137.0;
    f = 1 / 298.257223563;
    e2 = f * (2 - f);

    sinLat = sin(Latitude_rad);

    PrimeVerticalRadius_m = ...
        a ./ sqrt(1 - e2 .* sinLat.^2);

    MeridianRadius_m = ...
        a .* (1 - e2) ./ ...
        (1 - e2 .* sinLat.^2).^(3/2);

    NorthError_m = GNSSPositionError_m(:, 1);
    EastError_m = GNSSPositionError_m(:, 2);
    VerticalError_m = GNSSPositionError_m(:, 3);

    LatitudePerturbation_rad = ...
        NorthError_m ./ ...
        (MeridianRadius_m + Altitude_m);

    CosLatitude = cos(Latitude_rad);

    if any(abs(CosLatitude) < 1e-12)
        error( ...
            'ASRTE:ApplySensorNoise:GNSSPoleSingularity', ...
            'GNSS longitude perturbation is undefined at the poles.');
    end

    LongitudePerturbation_rad = ...
        EastError_m ./ ...
        ((PrimeVerticalRadius_m + Altitude_m) .* CosLatitude);

    SensorTelemetry.GNSS.Latitude_rad = ...
        Latitude_rad + LatitudePerturbation_rad;

    SensorTelemetry.GNSS.Longitude_rad = ...
        Longitude_rad + LongitudePerturbation_rad;

    SensorTelemetry.GNSS.Altitude_m = ...
        Altitude_m + VerticalError_m;

    SensorTelemetry.GNSS.Velocity_NED_mps = ...
        GNSS.Velocity_NED_mps + GNSSVelocityError_mps;

    % ================================================================
    % IMU
    % ================================================================

    IMUNoise = Noise.IMU.MeasurementNoise;
    IMUBias = Noise.IMU.Bias;
    IMUScaleFactor = Noise.IMU.ScaleFactor;

    N_IMU = numel(IdealTelemetry.IMU.Time_s);

    if ~isequal(size(IdealTelemetry.IMU.Accelerometer_mps2), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUAccelerometerDimensionMismatch', ...
            'Ideal IMU accelerometer data must have N-by-3 dimensions.');
    end

    if ~isequal(size(IdealTelemetry.IMU.Gyroscope_radps), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUGyroscopeDimensionMismatch', ...
            'Ideal IMU gyroscope data must have N-by-3 dimensions.');
    end

    if ~isequal(size(IMUNoise.AccelerometerNoise_mps2), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUAccelerometerNoiseDimensionMismatch', ...
            'IMU accelerometer noise must have N-by-3 dimensions.');
    end

    if ~isequal(size(IMUNoise.GyroscopeNoise_radps), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUGyroscopeNoiseDimensionMismatch', ...
            'IMU gyroscope noise must have N-by-3 dimensions.');
    end

    if ~isequal(size(IMUBias.AccelerometerTotalBias_mps2), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUAccelerometerBiasDimensionMismatch', ...
            'IMU accelerometer bias must have N-by-3 dimensions.');
    end

    if ~isequal(size(IMUBias.GyroscopeTotalBias_radps), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUGyroscopeBiasDimensionMismatch', ...
            'IMU gyroscope bias must have N-by-3 dimensions.');
    end

    if ~isequal(size(IMUScaleFactor.AccelerometerScaleFactor), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUAccelerometerScaleFactorDimensionMismatch', ...
            'IMU accelerometer scale factor must have N-by-3 dimensions.');
    end

    if ~isequal(size(IMUScaleFactor.GyroscopeScaleFactor), [N_IMU 3])
        error( ...
            'ASRTE:ApplySensorNoise:IMUGyroscopeScaleFactorDimensionMismatch', ...
            'IMU gyroscope scale factor must have N-by-3 dimensions.');
    end

    AccelerometerAdditiveError = ...
        IMUBias.AccelerometerTotalBias_mps2 + ...
        IMUNoise.AccelerometerNoise_mps2;

    GyroscopeAdditiveError = ...
        IMUBias.GyroscopeTotalBias_radps + ...
        IMUNoise.GyroscopeNoise_radps;

    SensorTelemetry.IMU.Accelerometer_mps2 = ...
        (IdealTelemetry.IMU.Accelerometer_mps2 + ...
         AccelerometerAdditiveError) .* ...
        (1 + IMUScaleFactor.AccelerometerScaleFactor);

    SensorTelemetry.IMU.Gyroscope_radps = ...
        (IdealTelemetry.IMU.Gyroscope_radps + ...
         GyroscopeAdditiveError) .* ...
        (1 + IMUScaleFactor.GyroscopeScaleFactor);

    % ================================================================
    % Air Data
    % ================================================================

    AirNoise = Noise.Airspeed;

    N_Air = numel(IdealTelemetry.AirData.Time_s);

    if ~isequal(size(IdealTelemetry.AirData.TrueAirspeed_mps), [N_Air 1])
        error( ...
            'ASRTE:ApplySensorNoise:AirspeedDimensionMismatch', ...
            'Ideal true airspeed must have N-by-1 dimensions.');
    end

    if ~isequal(size(IdealTelemetry.AirData.DynamicPressure_Pa), [N_Air 1])
        error( ...
            'ASRTE:ApplySensorNoise:DynamicPressureDimensionMismatch', ...
            'Ideal dynamic pressure must have N-by-1 dimensions.');
    end

    if ~isequal(size(AirNoise.AirspeedNoise_mps), [N_Air 1])
        error( ...
            'ASRTE:ApplySensorNoise:AirspeedNoiseDimensionMismatch', ...
            'Airspeed noise must have N-by-1 dimensions.');
    end

    IdealAirspeed_mps = ...
        IdealTelemetry.AirData.TrueAirspeed_mps;

    CorruptedAirspeed_mps = ...
        IdealAirspeed_mps + AirNoise.AirspeedNoise_mps;

    CorruptedDynamicPressure_Pa = ...
        IdealTelemetry.AirData.DynamicPressure_Pa;

    NonZeroAirspeed = abs(IdealAirspeed_mps) > 0;

    CorruptedDynamicPressure_Pa(NonZeroAirspeed) = ...
        IdealTelemetry.AirData.DynamicPressure_Pa(NonZeroAirspeed) .* ...
        (CorruptedAirspeed_mps(NonZeroAirspeed) ./ ...
         IdealAirspeed_mps(NonZeroAirspeed)).^2;

    SensorTelemetry.AirData.TrueAirspeed_mps = ...
        CorruptedAirspeed_mps;

    SensorTelemetry.AirData.DynamicPressure_Pa = ...
        CorruptedDynamicPressure_Pa;

    % ================================================================
    % Magnetometer
    % ================================================================

    MagNoise = Noise.Magnetometer;

    N_Mag = numel(IdealTelemetry.Magnetometer.Time_s);

    if ~isequal( ...
            size(IdealTelemetry.Magnetometer.MagneticFieldBody_uT), ...
            [N_Mag 3])
        error( ...
            'ASRTE:ApplySensorNoise:MagnetometerDimensionMismatch', ...
            'Ideal magnetic field must have N-by-3 dimensions.');
    end

    if ~isequal(size(MagNoise.MagnetometerNoise_uT), [N_Mag 3])
        error( ...
            'ASRTE:ApplySensorNoise:MagnetometerNoiseDimensionMismatch', ...
            'Magnetometer noise must have N-by-3 dimensions.');
    end

    SensorTelemetry.Magnetometer.MagneticFieldBody_uT = ...
        IdealTelemetry.Magnetometer.MagneticFieldBody_uT + ...
        MagNoise.MagnetometerNoise_uT;
end