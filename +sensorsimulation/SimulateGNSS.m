
function GNSS = SimulateGNSS(NoisyGNSS, CorruptionSeverity)
%SIMULATEGNSS Apply deterministic Block 8 GNSS corruption.
%
%   GNSS = sensorsimulation.SimulateGNSS( ...
%       NoisyGNSS, CorruptionSeverity)
%
%   applies the deterministic GNSS fault envelope defined by Block 8.
%
%   Corruption severity:
%
%       0%   -> no additional corruption
%       100% -> maximum defined GNSS fault
%
%   Nonlinear severity mapping:
%
%       Alpha = (CorruptionSeverity / 100)^2
%
%   Maximum GNSS fault envelope at 100%:
%
%       Position NED:
%           North = +50 m
%           East  = +50 m
%           Down  = -75 m
%
%       Velocity NED:
%           North = +5.0 m/s
%           East  = +5.0 m/s
%           Down  = +2.5 m/s
%
%   Position corruption is applied through the frozen Block 2
%   NED2ECEF and ECEF2LLA coordinate transformations.
%
%   Block 8 does NOT:
%       - generate stochastic noise
%       - call GenerateSensorNoise
%       - call ApplySensorNoise
%       - modify Available
%       - modify GroundTruth
%       - perform state estimation
%       - perform sensor fusion
%       - perform trust evaluation
%
%   Input:
%       NoisyGNSS
%           GNSS telemetry produced by the frozen Block 5 application
%           stage.
%
%       CorruptionSeverity
%           Scalar GNSS corruption severity in [0,100] percent.
%
%   Output:
%       GNSS
%           Same GNSS telemetry structure with deterministic Block 8
%           corruption applied to position and velocity.

    %% Validate input structure

    if ~isstruct(NoisyGNSS) || ~isscalar(NoisyGNSS)

        error( ...
            'ASRTE:SimulateGNSS:InvalidInput', ...
            'NoisyGNSS must be a scalar structure.');

    end

    RequiredFields = { ...
        'Time_s', ...
        'SampleRate_Hz', ...
        'SampleCount', ...
        'Latitude_rad', ...
        'Longitude_rad', ...
        'Altitude_m', ...
        'Velocity_NED_mps', ...
        'Available'};

    for k = 1:numel(RequiredFields)

        FieldName = RequiredFields{k};

        if ~isfield(NoisyGNSS, FieldName)

            error( ...
                'ASRTE:SimulateGNSS:MissingField', ...
                'NoisyGNSS is missing required field "%s".', ...
                FieldName);

        end

    end

    %% Validate corruption severity

    if ~isnumeric(CorruptionSeverity) || ...
            ~isreal(CorruptionSeverity) || ...
            ~isscalar(CorruptionSeverity) || ...
            ~isfinite(CorruptionSeverity) || ...
            CorruptionSeverity < 0 || ...
            CorruptionSeverity > 100

        error( ...
            'ASRTE:SimulateGNSS:InvalidCorruptionSeverity', ...
            ['GNSS corruption severity must be a finite ', ...
             'real scalar in the range 0 to 100 percent.']);

    end

    %% Validate sample count

    SampleCount = NoisyGNSS.SampleCount;

    if ~isnumeric(SampleCount) || ...
            ~isreal(SampleCount) || ...
            ~isscalar(SampleCount) || ...
            ~isfinite(SampleCount) || ...
            SampleCount < 1 || ...
            SampleCount ~= floor(SampleCount)

        error( ...
            'ASRTE:SimulateGNSS:InvalidSampleCount', ...
            'NoisyGNSS.SampleCount must be a positive integer scalar.');

    end

    %% Validate timeline

    Time_s = NoisyGNSS.Time_s;

    if ~isnumeric(Time_s) || ...
            ~isreal(Time_s) || ...
            ~isvector(Time_s) || ...
            numel(Time_s) ~= SampleCount || ...
            any(~isfinite(Time_s))

        error( ...
            'ASRTE:SimulateGNSS:InvalidTime', ...
            ['NoisyGNSS.Time_s must be a finite real vector ', ...
             'containing SampleCount elements.']);

    end

    Time_s = Time_s(:);

    if any(diff(Time_s) <= 0)

        error( ...
            'ASRTE:SimulateGNSS:NonMonotonicTime', ...
            'NoisyGNSS.Time_s must be strictly increasing.');

    end

    %% Validate sample rate

    SampleRate_Hz = NoisyGNSS.SampleRate_Hz;

    if ~isnumeric(SampleRate_Hz) || ...
            ~isreal(SampleRate_Hz) || ...
            ~isscalar(SampleRate_Hz) || ...
            ~isfinite(SampleRate_Hz) || ...
            SampleRate_Hz <= 0

        error( ...
            'ASRTE:SimulateGNSS:InvalidSampleRate', ...
            'NoisyGNSS.SampleRate_Hz must be a positive finite scalar.');

    end

    %% Validate position measurements

    PositionFields = { ...
        'Latitude_rad', ...
        'Longitude_rad', ...
        'Altitude_m'};

    for k = 1:numel(PositionFields)

        FieldName = PositionFields{k};
        Value = NoisyGNSS.(FieldName);

        if ~isnumeric(Value) || ...
                ~isreal(Value) || ...
                ~isvector(Value) || ...
                numel(Value) ~= SampleCount || ...
                any(~isfinite(Value(:)))

            error( ...
                'ASRTE:SimulateGNSS:InvalidMeasurement', ...
                ['NoisyGNSS.%s must be a finite real vector ', ...
                 'containing SampleCount elements.'], ...
                FieldName);

        end

    end

    %% Validate velocity

    Velocity_NED_mps = NoisyGNSS.Velocity_NED_mps;

    if ~isnumeric(Velocity_NED_mps) || ...
            ~isreal(Velocity_NED_mps) || ...
            ~isequal(size(Velocity_NED_mps), [SampleCount, 3]) || ...
            any(~isfinite(Velocity_NED_mps), 'all')

        error( ...
            'ASRTE:SimulateGNSS:InvalidVelocity', ...
            ['NoisyGNSS.Velocity_NED_mps must be a finite real ', ...
             'SampleCount-by-3 matrix.']);

    end

    %% Validate availability

    Available = NoisyGNSS.Available;

    if ~islogical(Available)

        error( ...
            'ASRTE:SimulateGNSS:InvalidAvailability', ...
            'NoisyGNSS.Available must be logical.');

    end

    if ~(isscalar(Available) || ...
            (isvector(Available) && numel(Available) == SampleCount))

        error( ...
            'ASRTE:SimulateGNSS:InvalidAvailability', ...
            ['NoisyGNSS.Available must be either a logical scalar ', ...
             'or a logical vector containing SampleCount elements.']);

    end

    %% Copy input to preserve immutability

    GNSS = NoisyGNSS;

    %% Convert severity to nonlinear fault fraction

    Alpha = (CorruptionSeverity / 100)^2;

    %% Zero-corruption fast path

    if Alpha == 0

        return;

    end

    %% Define maximum GNSS fault envelope

    MaximumPositionFault_NED_m = ...
        [50, 50, -75];

    MaximumVelocityFault_NED_mps = ...
        [5, 5, 2.5];

    %% Apply deterministic GNSS position corruption

    Latitude_rad = NoisyGNSS.Latitude_rad(:);
    Longitude_rad = NoisyGNSS.Longitude_rad(:);
    Altitude_m = NoisyGNSS.Altitude_m(:);

    PositionFault_NED_m = ...
        Alpha .* MaximumPositionFault_NED_m;

    NorthFault_m = PositionFault_NED_m(1);
    EastFault_m = PositionFault_NED_m(2);
    DownFault_m = PositionFault_NED_m(3);

    CorruptedLatitude_rad = zeros(SampleCount,1);
    CorruptedLongitude_rad = zeros(SampleCount,1);
    CorruptedAltitude_m = zeros(SampleCount,1);

    for k = 1:SampleCount

        [X, Y, Z] = coordinates.NED2ECEF( ...
            NorthFault_m, ...
            EastFault_m, ...
            DownFault_m, ...
            Latitude_rad(k), ...
            Longitude_rad(k), ...
            Altitude_m(k));

        [CorruptedLatitude_rad(k), ...
         CorruptedLongitude_rad(k), ...
         CorruptedAltitude_m(k)] = ...
            coordinates.ECEF2LLA(X, Y, Z);

    end

    GNSS.Latitude_rad = CorruptedLatitude_rad;
    GNSS.Longitude_rad = CorruptedLongitude_rad;
    GNSS.Altitude_m = CorruptedAltitude_m;

    %% Apply deterministic GNSS velocity corruption

    GNSS.Velocity_NED_mps = ...
        NoisyGNSS.Velocity_NED_mps + ...
        Alpha .* MaximumVelocityFault_NED_mps;

end

