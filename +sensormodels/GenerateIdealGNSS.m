function GNSS = GenerateIdealGNSS(GroundTruth, Timeline)
%GENERATEIDEALGNSS Generate ideal GNSS position and NED velocity.
%
%   GNSS = sensormodels.GenerateIdealGNSS(GroundTruth, Timeline)
%
%   Generates deterministic ideal GNSS telemetry on the native GNSS
%   timeline from Block 7 GroundTruth.
%
%   Outputs:
%       GNSS.Time_s
%       GNSS.SampleRate_Hz
%       GNSS.SampleCount
%       GNSS.Latitude_rad
%       GNSS.Longitude_rad
%       GNSS.Altitude_m
%       GNSS.Velocity_NED_mps
%       GNSS.Available
%
%   Position is interpolated directly from Block 7.
%   Body velocity is transformed to NED using the frozen Block 2
%   Body-to-NED attitude convention before interpolation.

    %% Validate GroundTruth

    RequiredGroundTruthFields = { ...
        'Time_s', ...
        'Position', ...
        'VelocityBody_mps', ...
        'Euler_rad'};

    for FieldIndex = 1:numel(RequiredGroundTruthFields)

        FieldName = RequiredGroundTruthFields{FieldIndex};

        if ~isfield(GroundTruth, FieldName)

            error( ...
                'sensormodels:GenerateIdealGNSS:MissingGroundTruthField', ...
                'GroundTruth.%s is required.', ...
                FieldName);

        end
    end

    RequiredPositionFields = { ...
        'Latitude_rad', ...
        'Longitude_rad', ...
        'Altitude_m'};

    for FieldIndex = 1:numel(RequiredPositionFields)

        FieldName = RequiredPositionFields{FieldIndex};

        if ~isfield(GroundTruth.Position, FieldName)

            error( ...
                'sensormodels:GenerateIdealGNSS:MissingPositionField', ...
                'GroundTruth.Position.%s is required.', ...
                FieldName);

        end
    end

    %% Validate Timeline

    RequiredTimelineFields = { ...
        'Time_s', ...
        'SampleRate_Hz', ...
        'SampleCount'};

    for FieldIndex = 1:numel(RequiredTimelineFields)

        FieldName = RequiredTimelineFields{FieldIndex};

        if ~isfield(Timeline, FieldName)

            error( ...
                'sensormodels:GenerateIdealGNSS:MissingTimelineField', ...
                'Timeline.%s is required.', ...
                FieldName);

        end
    end

    GroundTruthTime_s = GroundTruth.Time_s(:);
    SensorTime_s = Timeline.Time_s(:);

    GroundTruthSampleCount = numel(GroundTruthTime_s);
    SensorSampleCount = Timeline.SampleCount;

    if GroundTruthSampleCount < 2 || ...
            any(~isfinite(GroundTruthTime_s)) || ...
            any(diff(GroundTruthTime_s) <= 0)

        error( ...
            'sensormodels:GenerateIdealGNSS:InvalidGroundTruthTime', ...
            'GroundTruth.Time_s must be finite and strictly increasing.');

    end

    if SensorSampleCount ~= numel(SensorTime_s)

        error( ...
            'sensormodels:GenerateIdealGNSS:TimelineSizeMismatch', ...
            'Timeline.SampleCount must match Timeline.Time_s.');

    end

    if any(~isfinite(SensorTime_s)) || ...
            any(diff(SensorTime_s) <= 0)

        error( ...
            'sensormodels:GenerateIdealGNSS:InvalidTimeline', ...
            'Timeline.Time_s must be finite and strictly increasing.');

    end

    %% Extract position

    Latitude_rad = ...
        GroundTruth.Position.Latitude_rad(:);

    Longitude_rad = ...
        GroundTruth.Position.Longitude_rad(:);

    Altitude_m = ...
        GroundTruth.Position.Altitude_m(:);

    if numel(Latitude_rad) ~= GroundTruthSampleCount || ...
            numel(Longitude_rad) ~= GroundTruthSampleCount || ...
            numel(Altitude_m) ~= GroundTruthSampleCount

        error( ...
            'sensormodels:GenerateIdealGNSS:PositionSizeMismatch', ...
            'GroundTruth position fields must match GroundTruth.Time_s.');

    end

    if any(~isfinite(Latitude_rad)) || ...
            any(~isfinite(Longitude_rad)) || ...
            any(~isfinite(Altitude_m))

        error( ...
            'sensormodels:GenerateIdealGNSS:InvalidPosition', ...
            'GroundTruth position contains non-finite values.');

    end

    %% Extract body velocity and attitude

    VelocityBody_mps = GroundTruth.VelocityBody_mps;
    Euler_rad = GroundTruth.Euler_rad;

    if ~isequal(size(VelocityBody_mps), ...
            [GroundTruthSampleCount, 3])

        error( ...
            'sensormodels:GenerateIdealGNSS:InvalidVelocitySize', ...
            'GroundTruth.VelocityBody_mps must be SampleCount-by-3.');

    end

    if ~isequal(size(Euler_rad), ...
            [GroundTruthSampleCount, 3])

        error( ...
            'sensormodels:GenerateIdealGNSS:InvalidEulerSize', ...
            'GroundTruth.Euler_rad must be SampleCount-by-3.');

    end

    if any(~isfinite(VelocityBody_mps), 'all') || ...
            any(~isfinite(Euler_rad), 'all')

        error( ...
            'sensormodels:GenerateIdealGNSS:InvalidKinematics', ...
            'GroundTruth velocity and attitude must be finite.');

    end

    %% Convert body velocity to NED velocity

    VelocityNED_mps = zeros(GroundTruthSampleCount, 3);

    for SampleIndex = 1:GroundTruthSampleCount

        Roll_rad = Euler_rad(SampleIndex, 1);
        Pitch_rad = Euler_rad(SampleIndex, 2);
        Yaw_rad = Euler_rad(SampleIndex, 3);

        Quaternion = coordinates.Euler2Quaternion( ...
            Roll_rad, ...
            Pitch_rad, ...
            Yaw_rad);

        Cbn = coordinates.Quaternion2DCM(Quaternion);

        VelocityNED_mps(SampleIndex, :) = ...
            (Cbn * VelocityBody_mps(SampleIndex, :).').';

    end

    %% Interpolate onto GNSS timeline

    GNSSLatitude_rad = interp1( ...
        GroundTruthTime_s, ...
        Latitude_rad, ...
        SensorTime_s, ...
        'linear');

    GNSSLongitude_rad = interp1( ...
        GroundTruthTime_s, ...
        Longitude_rad, ...
        SensorTime_s, ...
        'linear');

    GNSSAltitude_m = interp1( ...
        GroundTruthTime_s, ...
        Altitude_m, ...
        SensorTime_s, ...
        'linear');

    GNSSVelocityNED_mps = interp1( ...
        GroundTruthTime_s, ...
        VelocityNED_mps, ...
        SensorTime_s, ...
        'linear');

    %% Final numerical validation

    if any(~isfinite(GNSSLatitude_rad)) || ...
            any(~isfinite(GNSSLongitude_rad)) || ...
            any(~isfinite(GNSSAltitude_m)) || ...
            any(~isfinite(GNSSVelocityNED_mps), 'all')

        error( ...
            'sensormodels:GenerateIdealGNSS:InvalidOutput', ...
            'Generated GNSS telemetry contains non-finite values.');

    end

    %% Build output

    GNSS = struct();

    GNSS.Time_s = SensorTime_s;
    GNSS.SampleRate_Hz = Timeline.SampleRate_Hz;
    GNSS.SampleCount = SensorSampleCount;

    GNSS.Latitude_rad = GNSSLatitude_rad;
    GNSS.Longitude_rad = GNSSLongitude_rad;
    GNSS.Altitude_m = GNSSAltitude_m;

    GNSS.Velocity_NED_mps = GNSSVelocityNED_mps;

    GNSS.Available = true(SensorSampleCount, 1);

end