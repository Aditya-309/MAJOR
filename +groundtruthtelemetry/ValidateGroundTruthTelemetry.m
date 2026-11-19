function ValidateGroundTruthTelemetry(GroundTruth)
%VALIDATEGROUNDTRUTHTELEMETRY Validate canonical Block 7 ground-truth telemetry.
%
%   ValidateGroundTruthTelemetry(GroundTruth)
%
%   Validates the canonical ground-truth telemetry structure produced by
%   ConvertGroundTruthState. This function performs structural, dimensional,
%   numerical, and temporal consistency checks before the telemetry is used
%   by downstream Block 7 processing.

    %% Input Validation

    if nargin ~= 1

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidInputCount', ...
            ['ValidateGroundTruthTelemetry requires exactly one input: ' ...
             'GroundTruth.']);

    end

    if ~isstruct(GroundTruth) || ...
            ~isscalar(GroundTruth)

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidGroundTruth', ...
            'GroundTruth must be a scalar structure.');

    end

    %% Required Top-Level Fields

    RequiredFields = { ...
        'SampleCount'
        'SampleTime_s'
        'Time_s'
        'Position'
        'VelocityBody_mps'
        'AngularRateBody_radps'
        'Euler_rad'
        'AirDensity_kgpm3'
        };

    for FieldIndex = 1:numel(RequiredFields)

        FieldName = RequiredFields{FieldIndex};

        if ~isfield(GroundTruth, FieldName) || ...
                isempty(GroundTruth.(FieldName))

            error( ...
                'Block7:ValidateGroundTruthTelemetry:MissingField', ...
                'GroundTruth.%s is required.', ...
                FieldName);

        end

    end

    %% Validate Sample Count

    SampleCount = GroundTruth.SampleCount;

    if ~isnumeric(SampleCount) || ...
            ~isscalar(SampleCount) || ...
            ~isfinite(SampleCount) || ...
            SampleCount < 2 || ...
            SampleCount ~= floor(SampleCount)

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidSampleCount', ...
            ['GroundTruth.SampleCount must be a finite integer ' ...
             'greater than or equal to 2.']);

    end

    %% Validate Sample Time

    SampleTime_s = GroundTruth.SampleTime_s;

    if ~isnumeric(SampleTime_s) || ...
            ~isscalar(SampleTime_s) || ...
            ~isfinite(SampleTime_s) || ...
            SampleTime_s <= 0

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidSampleTime', ...
            ['GroundTruth.SampleTime_s must be a positive finite ' ...
             'scalar.']);

    end

    %% Validate Time History

    Time_s = GroundTruth.Time_s;

    if ~isnumeric(Time_s) || ...
            ~isvector(Time_s) || ...
            numel(Time_s) ~= SampleCount

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidTimeHistory', ...
            ['GroundTruth.Time_s must be a numeric vector with ' ...
             'SampleCount elements.']);

    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidTimeHistory', ...
            'GroundTruth.Time_s must contain only finite values.');

    end

    TimeDifference_s = diff(Time_s);

    if any(TimeDifference_s <= 0)

        error( ...
            'Block7:ValidateGroundTruthTelemetry:NonMonotonicTime', ...
            'GroundTruth.Time_s must be strictly increasing.');

    end

    %% Validate Position Structure

    if ~isstruct(GroundTruth.Position) || ...
            ~isscalar(GroundTruth.Position)

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidPosition', ...
            'GroundTruth.Position must be a scalar structure.');

    end

    RequiredPositionFields = { ...
        'Latitude_rad'
        'Longitude_rad'
        'Altitude_m'
        };

    for FieldIndex = 1:numel(RequiredPositionFields)

        FieldName = RequiredPositionFields{FieldIndex};

        if ~isfield(GroundTruth.Position, FieldName) || ...
                isempty(GroundTruth.Position.(FieldName))

            error( ...
                'Block7:ValidateGroundTruthTelemetry:MissingPositionField', ...
                'GroundTruth.Position.%s is required.', ...
                FieldName);

        end

    end

    Latitude_rad = ...
        GroundTruth.Position.Latitude_rad;

    Longitude_rad = ...
        GroundTruth.Position.Longitude_rad;

    Altitude_m = ...
        GroundTruth.Position.Altitude_m;

    PositionVectors = { ...
        Latitude_rad
        Longitude_rad
        Altitude_m
        };

    PositionNames = { ...
        'Latitude_rad'
        'Longitude_rad'
        'Altitude_m'
        };

    for PositionIndex = 1:numel(PositionVectors)

        PositionVector = ...
            PositionVectors{PositionIndex};

        if ~isnumeric(PositionVector) || ...
                ~isvector(PositionVector) || ...
                numel(PositionVector) ~= SampleCount

            error( ...
                'Block7:ValidateGroundTruthTelemetry:InvalidPosition', ...
                ['GroundTruth.Position.%s must be a numeric vector ' ...
                 'with SampleCount elements.'], ...
                PositionNames{PositionIndex});

        end

        if any(~isfinite(PositionVector(:)))

            error( ...
                'Block7:ValidateGroundTruthTelemetry:InvalidPosition', ...
                ['GroundTruth.Position.%s must contain only finite ' ...
                 'values.'], ...
                PositionNames{PositionIndex});

        end

    end

    if any(abs(Latitude_rad(:)) > pi / 2)

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidLatitude', ...
            'Latitude values must lie within [-pi/2, pi/2].');

    end

    if any(abs(Longitude_rad(:)) > pi)

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidLongitude', ...
            'Longitude values must lie within [-pi, pi].');

    end

    %% Validate Body Velocity

    VelocityBody_mps = ...
        GroundTruth.VelocityBody_mps;

    if ~isnumeric(VelocityBody_mps) || ...
            ~isequal(size(VelocityBody_mps), ...
                [SampleCount, 3])

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidVelocity', ...
            ['GroundTruth.VelocityBody_mps must have dimensions ' ...
             'SampleCount-by-3.']);

    end

    if any(~isfinite(VelocityBody_mps(:)))

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidVelocity', ...
            'GroundTruth.VelocityBody_mps must contain only finite values.');

    end

    %% Validate Body Angular Rate

    AngularRateBody_radps = ...
        GroundTruth.AngularRateBody_radps;

    if ~isnumeric(AngularRateBody_radps) || ...
            ~isequal(size(AngularRateBody_radps), ...
                [SampleCount, 3])

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidAngularRate', ...
            ['GroundTruth.AngularRateBody_radps must have dimensions ' ...
             'SampleCount-by-3.']);

    end

    if any(~isfinite(AngularRateBody_radps(:)))

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidAngularRate', ...
            ['GroundTruth.AngularRateBody_radps must contain only ' ...
             'finite values.']);

    end

    %% Validate Euler Attitude

    Euler_rad = ...
        GroundTruth.Euler_rad;

    if ~isnumeric(Euler_rad) || ...
            ~isequal(size(Euler_rad), ...
                [SampleCount, 3])

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidEuler', ...
            ['GroundTruth.Euler_rad must have dimensions ' ...
             'SampleCount-by-3.']);

    end

    if any(~isfinite(Euler_rad(:)))

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidEuler', ...
            'GroundTruth.Euler_rad must contain only finite values.');

    end

    %% Validate Air Density

    AirDensity_kgpm3 = ...
        GroundTruth.AirDensity_kgpm3;

    if ~isnumeric(AirDensity_kgpm3) || ...
            ~isvector(AirDensity_kgpm3) || ...
            numel(AirDensity_kgpm3) ~= SampleCount

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidAirDensity', ...
            ['GroundTruth.AirDensity_kgpm3 must be a numeric vector ' ...
             'with SampleCount elements.']);

    end

    AirDensity_kgpm3 = ...
        AirDensity_kgpm3(:);

    if any(~isfinite(AirDensity_kgpm3)) || ...
            any(AirDensity_kgpm3 <= 0)

        error( ...
            'Block7:ValidateGroundTruthTelemetry:InvalidAirDensity', ...
            ['GroundTruth.AirDensity_kgpm3 must contain only positive ' ...
             'finite values.']);

    end

end