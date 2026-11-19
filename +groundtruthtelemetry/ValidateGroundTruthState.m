function ValidateGroundTruthState(GroundTruth)
%VALIDATEGROUNDTRUTHSTATE Validate canonical Block 7 ground-truth state.
%
%   ValidateGroundTruthState(GroundTruth)
%
%   Performs structural, dimensional, numerical, temporal, and basic
%   physical validation of the canonical ground-truth state produced by
%   ConvertGroundTruthState.
%
%   This function does not modify GroundTruth.

    %% Input Validation

    if nargin ~= 1

        error( ...
            'Block7:ValidateGroundTruthState:InvalidInputCount', ...
            'ValidateGroundTruthState requires exactly one input: GroundTruth.');

    end

    if ~isstruct(GroundTruth) || ~isscalar(GroundTruth)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidGroundTruth', ...
            'GroundTruth must be a scalar structure.');

    end

    RequiredFields = { ...
        'Time_s'
        'Position'
        'VelocityBody_mps'
        'AngularRateBody_radps'
        'Euler_rad'
        'AirDensity_kgpm3'
        'SampleTime_s'
        'SampleCount'
        };

    for FieldIndex = 1:numel(RequiredFields)

        FieldName = ...
            RequiredFields{FieldIndex};

        if ~isfield(GroundTruth, FieldName) || ...
                isempty(GroundTruth.(FieldName))

            error( ...
                'Block7:ValidateGroundTruthState:MissingField', ...
                'GroundTruth.%s is required.', ...
                FieldName);

        end

    end

    %% Validate Position Structure

    if ~isstruct(GroundTruth.Position) || ...
            ~isscalar(GroundTruth.Position)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidPosition', ...
            'GroundTruth.Position must be a scalar structure.');

    end

    RequiredPositionFields = { ...
        'Latitude_rad'
        'Longitude_rad'
        'Altitude_m'
        };

    for FieldIndex = 1:numel(RequiredPositionFields)

        FieldName = ...
            RequiredPositionFields{FieldIndex};

        if ~isfield(GroundTruth.Position, FieldName) || ...
                isempty(GroundTruth.Position.(FieldName))

            error( ...
                'Block7:ValidateGroundTruthState:MissingPositionField', ...
                'GroundTruth.Position.%s is required.', ...
                FieldName);

        end

    end

    %% Validate Sample Count

    SampleCount = ...
        GroundTruth.SampleCount;

    if ~isnumeric(SampleCount) || ...
            ~isscalar(SampleCount) || ...
            ~isfinite(SampleCount) || ...
            SampleCount < 2 || ...
            SampleCount ~= floor(SampleCount)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidSampleCount', ...
            'GroundTruth.SampleCount must be an integer greater than or equal to 2.');

    end

    %% Validate Time

    Time_s = ...
        GroundTruth.Time_s;

    if ~isnumeric(Time_s) || ...
            ~isvector(Time_s)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidTime', ...
            'GroundTruth.Time_s must be a numeric vector.');

    end

    Time_s = ...
        Time_s(:);

    if numel(Time_s) ~= SampleCount

        error( ...
            'Block7:ValidateGroundTruthState:TimeSampleCountMismatch', ...
            'GroundTruth.Time_s length must equal GroundTruth.SampleCount.');

    end

    if any(~isfinite(Time_s))

        error( ...
            'Block7:ValidateGroundTruthState:NonFiniteTime', ...
            'GroundTruth.Time_s contains non-finite values.');

    end

    TimeDifference_s = ...
        diff(Time_s);

    if any(TimeDifference_s <= 0)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidTimeHistory', ...
            'GroundTruth.Time_s must be strictly increasing.');

    end

    %% Validate Sample Time

    SampleTime_s = ...
        GroundTruth.SampleTime_s;

    if ~isnumeric(SampleTime_s) || ...
            ~isscalar(SampleTime_s) || ...
            ~isfinite(SampleTime_s) || ...
            SampleTime_s <= 0

        error( ...
            'Block7:ValidateGroundTruthState:InvalidSampleTime', ...
            'GroundTruth.SampleTime_s must be a positive finite scalar.');

    end

    EstimatedSampleTime_s = ...
        median(TimeDifference_s);

    SampleTimeTolerance_s = ...
        max( ...
            1e-9, ...
            1e-6 * EstimatedSampleTime_s);

    if abs(SampleTime_s - EstimatedSampleTime_s) > ...
            SampleTimeTolerance_s

        error( ...
            'Block7:ValidateGroundTruthState:SampleTimeMismatch', ...
            ['GroundTruth.SampleTime_s is inconsistent with the ' ...
             'time history.']);

    end

    %% Validate Position Data

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

    for VectorIndex = 1:numel(PositionVectors)

        Values = ...
            PositionVectors{VectorIndex};

        if ~isnumeric(Values) || ...
                ~isvector(Values)

            error( ...
                'Block7:ValidateGroundTruthState:InvalidPositionData', ...
                'GroundTruth.Position.%s must be a numeric vector.', ...
                PositionNames{VectorIndex});

        end

        if numel(Values) ~= SampleCount

            error( ...
                'Block7:ValidateGroundTruthState:PositionSampleCountMismatch', ...
                ['GroundTruth.Position.%s length must equal ' ...
                 'GroundTruth.SampleCount.'], ...
                PositionNames{VectorIndex});

        end

        if any(~isfinite(Values))

            error( ...
                'Block7:ValidateGroundTruthState:NonFinitePosition', ...
                'GroundTruth.Position.%s contains non-finite values.', ...
                PositionNames{VectorIndex});

        end

    end

    if any(abs(Latitude_rad) > pi / 2)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidLatitude', ...
            'Latitude values must lie within [-pi/2, pi/2].');

    end

    if any(abs(Longitude_rad) > pi)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidLongitude', ...
            'Longitude values must lie within [-pi, pi].');

    end

    %% Validate Body Velocity

    VelocityBody_mps = ...
        GroundTruth.VelocityBody_mps;

    if ~isnumeric(VelocityBody_mps) || ...
            ~isequal(size(VelocityBody_mps), ...
                [SampleCount, 3])

        error( ...
            'Block7:ValidateGroundTruthState:InvalidVelocity', ...
            ['GroundTruth.VelocityBody_mps must have size ' ...
             '[SampleCount x 3].']);

    end

    if any(~isfinite(VelocityBody_mps), 'all')

        error( ...
            'Block7:ValidateGroundTruthState:NonFiniteVelocity', ...
            'GroundTruth.VelocityBody_mps contains non-finite values.');

    end

    %% Validate Angular Rate

    AngularRateBody_radps = ...
        GroundTruth.AngularRateBody_radps;

    if ~isnumeric(AngularRateBody_radps) || ...
            ~isequal(size(AngularRateBody_radps), ...
                [SampleCount, 3])

        error( ...
            'Block7:ValidateGroundTruthState:InvalidAngularRate', ...
            ['GroundTruth.AngularRateBody_radps must have size ' ...
             '[SampleCount x 3].']);

    end

    if any(~isfinite(AngularRateBody_radps), 'all')

        error( ...
            'Block7:ValidateGroundTruthState:NonFiniteAngularRate', ...
            ['GroundTruth.AngularRateBody_radps contains ' ...
             'non-finite values.']);

    end

    %% Validate Euler Attitude

    Euler_rad = ...
        GroundTruth.Euler_rad;

    if ~isnumeric(Euler_rad) || ...
            ~isequal(size(Euler_rad), ...
                [SampleCount, 3])

        error( ...
            'Block7:ValidateGroundTruthState:InvalidEuler', ...
            ['GroundTruth.Euler_rad must have size ' ...
             '[SampleCount x 3].']);

    end

    if any(~isfinite(Euler_rad), 'all')

        error( ...
            'Block7:ValidateGroundTruthState:NonFiniteEuler', ...
            'GroundTruth.Euler_rad contains non-finite values.');

    end

    %% Validate Air Density

    AirDensity_kgpm3 = ...
        GroundTruth.AirDensity_kgpm3;

    if ~isnumeric(AirDensity_kgpm3) || ...
            ~isvector(AirDensity_kgpm3)

        error( ...
            'Block7:ValidateGroundTruthState:InvalidAirDensity', ...
            'GroundTruth.AirDensity_kgpm3 must be a numeric vector.');

    end

    AirDensity_kgpm3 = ...
        AirDensity_kgpm3(:);

    if numel(AirDensity_kgpm3) ~= SampleCount

        error( ...
            'Block7:ValidateGroundTruthState:AirDensitySampleCountMismatch', ...
            ['GroundTruth.AirDensity_kgpm3 length must equal ' ...
             'GroundTruth.SampleCount.']);

    end

    if any(~isfinite(AirDensity_kgpm3))

        error( ...
            'Block7:ValidateGroundTruthState:NonFiniteAirDensity', ...
            'GroundTruth.AirDensity_kgpm3 contains non-finite values.');

    end

    if any(AirDensity_kgpm3 <= 0)

        error( ...
            'Block7:ValidateGroundTruthState:NonPositiveAirDensity', ...
            'GroundTruth.AirDensity_kgpm3 must be strictly positive.');

    end

end