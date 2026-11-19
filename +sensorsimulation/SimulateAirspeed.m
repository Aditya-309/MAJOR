function AirData = SimulateAirspeed(NoisyAirData, CorruptionSeverity)
%SIMULATEAIRSPEED Apply deterministic Block 8 airspeed corruption.
%
%   AirData = sensorsimulation.SimulateAirspeed( ...
%       NoisyAirData, CorruptionSeverity)
%
%   Applies the Block 8 deterministic airspeed corruption envelope to
%   post-Block-5 airspeed telemetry.
%
%   Block 5 stochastic airspeed noise is assumed to have already been
%   applied. This function does not generate or reapply stochastic noise.
%
%   Corruption severity:
%       0   -> no additional corruption
%       100 -> full deterministic fault envelope
%
%   Severity scaling:
%       alpha = (CorruptionSeverity / 100)^2
%
%   Full Block 8 airspeed fault envelope:
%       True Airspeed: +10 m/s
%
%   Dynamic pressure is updated consistently using:
%       q_corrupt = q_ideal * (V_corrupt / V_ideal)^2
%
%   for non-zero input true airspeed.
%
%   If the input true airspeed is zero, dynamic pressure is preserved.
%
%   Availability is preserved independently of corruption severity.
%
%   Input:
%       NoisyAirData
%           Frozen Block 5-compatible AirData structure containing:
%               Time_s
%               SampleRate_Hz
%               SampleCount
%               TrueAirspeed_mps
%               DynamicPressure_Pa
%               Available
%
%       CorruptionSeverity
%           Finite real scalar in the range [0,100].
%
%   Output:
%       AirData
%           Same structure and metadata as NoisyAirData with deterministic
%           Block 8 corruption applied.
%
%   Notes:
%       - No random numbers are generated.
%       - Input telemetry is not modified.
%       - Units remain SI.
%       - Negative post-Block-5 noisy true-air-speed values are accepted.
%       - This function does not implement outages, dropouts, or trust.

arguments
    NoisyAirData (1,1) struct
    CorruptionSeverity (1,1) double
end

%% Validate corruption severity

if ~isfinite(CorruptionSeverity)
    error( ...
        "sensorsimulation:InvalidCorruptionSeverity", ...
        "CorruptionSeverity must be finite.");
end

if CorruptionSeverity < 0 || CorruptionSeverity > 100
    error( ...
        "sensorsimulation:InvalidCorruptionSeverity", ...
        "CorruptionSeverity must be between 0 and 100.");
end

%% Validate required frozen Block 5 AirData fields

RequiredFields = { ...
    'Time_s', ...
    'SampleRate_Hz', ...
    'SampleCount', ...
    'TrueAirspeed_mps', ...
    'DynamicPressure_Pa', ...
    'Available'};

for k = 1:numel(RequiredFields)
    if ~isfield(NoisyAirData, RequiredFields{k})
        error( ...
            "sensorsimulation:MissingField", ...
            "NoisyAirData is missing required field '%s'.", ...
            RequiredFields{k});
    end
end

%% Validate scalar metadata

if ~isnumeric(NoisyAirData.SampleRate_Hz) || ...
        ~isscalar(NoisyAirData.SampleRate_Hz) || ...
        ~isfinite(NoisyAirData.SampleRate_Hz) || ...
        NoisyAirData.SampleRate_Hz <= 0

    error( ...
        "sensorsimulation:InvalidSampleRate", ...
        "SampleRate_Hz must be a finite positive scalar.");
end

if ~isnumeric(NoisyAirData.SampleCount) || ...
        ~isscalar(NoisyAirData.SampleCount) || ...
        ~isfinite(NoisyAirData.SampleCount) || ...
        NoisyAirData.SampleCount < 1 || ...
        NoisyAirData.SampleCount ~= floor(NoisyAirData.SampleCount)

    error( ...
        "sensorsimulation:InvalidSampleCount", ...
        "SampleCount must be a positive integer scalar.");
end

N = NoisyAirData.SampleCount;

%% Validate time vector

if ~isnumeric(NoisyAirData.Time_s) || ...
        ~isvector(NoisyAirData.Time_s) || ...
        numel(NoisyAirData.Time_s) ~= N || ...
        any(~isfinite(NoisyAirData.Time_s))

    error( ...
        "sensorsimulation:InvalidTime", ...
        "Time_s must contain exactly SampleCount finite samples.");
end

Time_s = NoisyAirData.Time_s(:);

if any(diff(Time_s) <= 0)
    error( ...
        "sensorsimulation:NonMonotonicTime", ...
        "Time_s must be strictly increasing.");
end

%% Validate true airspeed

if ~isnumeric(NoisyAirData.TrueAirspeed_mps) || ...
        ~isvector(NoisyAirData.TrueAirspeed_mps) || ...
        numel(NoisyAirData.TrueAirspeed_mps) ~= N || ...
        any(~isfinite(NoisyAirData.TrueAirspeed_mps))

    error( ...
        "sensorsimulation:InvalidTrueAirspeed", ...
        "TrueAirspeed_mps must contain exactly SampleCount finite values.");
end

TrueAirspeed_mps = NoisyAirData.TrueAirspeed_mps(:);

%% Validate dynamic pressure

if ~isnumeric(NoisyAirData.DynamicPressure_Pa) || ...
        ~isvector(NoisyAirData.DynamicPressure_Pa) || ...
        numel(NoisyAirData.DynamicPressure_Pa) ~= N || ...
        any(~isfinite(NoisyAirData.DynamicPressure_Pa))

    error( ...
        "sensorsimulation:InvalidDynamicPressure", ...
        "DynamicPressure_Pa must contain exactly SampleCount finite values.");
end

DynamicPressure_Pa = NoisyAirData.DynamicPressure_Pa(:);

if any(DynamicPressure_Pa < 0)
    error( ...
        "sensorsimulation:InvalidDynamicPressure", ...
        "DynamicPressure_Pa must be non-negative.");
end

%% Validate availability

if ~islogical(NoisyAirData.Available) || ...
        ~isvector(NoisyAirData.Available) || ...
        numel(NoisyAirData.Available) ~= N

    error( ...
        "sensorsimulation:InvalidAvailability", ...
        "Available must be an N-by-1 or 1-by-N logical vector.");
end

%% Copy input to preserve immutability

AirData = NoisyAirData;

%% Zero-corruption exact pass-through

if CorruptionSeverity == 0
    return;
end

%% Quadratic corruption severity

Alpha = (CorruptionSeverity / 100)^2;

%% Apply deterministic true-air-speed fault

TrueAirspeedCorrupt_mps = ...
    TrueAirspeed_mps + Alpha * 10;

%% Update dynamic pressure consistently

DynamicPressureCorrupt_Pa = DynamicPressure_Pa;

NonZeroSpeed = TrueAirspeed_mps ~= 0;

DynamicPressureCorrupt_Pa(NonZeroSpeed) = ...
    DynamicPressure_Pa(NonZeroSpeed) .* ...
    (TrueAirspeedCorrupt_mps(NonZeroSpeed) ./ ...
     TrueAirspeed_mps(NonZeroSpeed)).^2;

%% Preserve dynamic pressure when input TAS is zero

DynamicPressureCorrupt_Pa(~NonZeroSpeed) = ...
    DynamicPressure_Pa(~NonZeroSpeed);

%% Write corrupted measurements

AirData.TrueAirspeed_mps = TrueAirspeedCorrupt_mps;
AirData.DynamicPressure_Pa = DynamicPressureCorrupt_Pa;

%% Preserve availability exactly

AirData.Available = NoisyAirData.Available;

end