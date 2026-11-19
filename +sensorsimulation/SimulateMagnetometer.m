function Magnetometer = SimulateMagnetometer( ...
    NoisyMagnetometer, CorruptionSeverity)
%SIMULATEMAGNETOMETER Apply deterministic Block 8 magnetometer corruption.
%
%   Magnetometer = sensorsimulation.SimulateMagnetometer( ...
%       NoisyMagnetometer, CorruptionSeverity)
%
%   Applies the Block 8 deterministic magnetometer corruption envelope
%   to post-Block-5 magnetometer telemetry.
%
%   Block 5 stochastic magnetometer noise is assumed to have already
%   been applied. This function does not generate or reapply noise.
%
%   Corruption severity:
%       0   -> no additional corruption
%       100 -> full deterministic fault envelope
%
%   Severity scaling:
%       alpha = (CorruptionSeverity / 100)^2
%
%   Full Block 8 fault envelope:
%       +20 uT on each body axis.
%
%   Availability is preserved independently of corruption severity.
%
%   Input:
%       NoisyMagnetometer
%           Frozen Block 5-compatible magnetometer telemetry containing:
%               Time_s
%               SampleRate_Hz
%               SampleCount
%               MagneticFieldBody_uT
%               Available
%
%       CorruptionSeverity
%           Finite real scalar in the range [0,100].
%
%   Output:
%       Magnetometer
%           Same structure and metadata as NoisyMagnetometer, with
%           deterministic Block 8 corruption applied.
%
%   Notes:
%       - No random numbers are generated.
%       - Input telemetry is not modified.
%       - Units remain uT.
%       - This function does not implement outages, dropouts, or trust.

arguments
    NoisyMagnetometer (1,1) struct
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

%% Validate required frozen Block 5 fields

RequiredFields = { ...
    'Time_s', ...
    'SampleRate_Hz', ...
    'SampleCount', ...
    'MagneticFieldBody_uT', ...
    'Available'};

for k = 1:numel(RequiredFields)
    if ~isfield(NoisyMagnetometer, RequiredFields{k})
        error( ...
            "sensorsimulation:MissingField", ...
            "NoisyMagnetometer is missing required field '%s'.", ...
            RequiredFields{k});
    end
end

%% Validate scalar metadata

if ~isnumeric(NoisyMagnetometer.SampleRate_Hz) || ...
        ~isscalar(NoisyMagnetometer.SampleRate_Hz) || ...
        ~isfinite(NoisyMagnetometer.SampleRate_Hz) || ...
        NoisyMagnetometer.SampleRate_Hz <= 0

    error( ...
        "sensorsimulation:InvalidSampleRate", ...
        "SampleRate_Hz must be a finite positive scalar.");
end

if ~isnumeric(NoisyMagnetometer.SampleCount) || ...
        ~isscalar(NoisyMagnetometer.SampleCount) || ...
        ~isfinite(NoisyMagnetometer.SampleCount) || ...
        NoisyMagnetometer.SampleCount < 1 || ...
        NoisyMagnetometer.SampleCount ~= ...
        floor(NoisyMagnetometer.SampleCount)

    error( ...
        "sensorsimulation:InvalidSampleCount", ...
        "SampleCount must be a positive integer scalar.");
end

N = NoisyMagnetometer.SampleCount;

%% Validate time vector

if ~isnumeric(NoisyMagnetometer.Time_s) || ...
        ~isvector(NoisyMagnetometer.Time_s) || ...
        numel(NoisyMagnetometer.Time_s) ~= N || ...
        any(~isfinite(NoisyMagnetometer.Time_s))

    error( ...
        "sensorsimulation:InvalidTime", ...
        "Time_s must contain exactly SampleCount finite samples.");
end

Time_s = NoisyMagnetometer.Time_s(:);

if any(diff(Time_s) <= 0)
    error( ...
        "sensorsimulation:NonMonotonicTime", ...
        "Time_s must be strictly increasing.");
end

%% Validate magnetic-field measurement

if ~isnumeric(NoisyMagnetometer.MagneticFieldBody_uT) || ...
        ~ismatrix(NoisyMagnetometer.MagneticFieldBody_uT) || ...
        size(NoisyMagnetometer.MagneticFieldBody_uT,1) ~= N || ...
        size(NoisyMagnetometer.MagneticFieldBody_uT,2) ~= 3 || ...
        any(~isfinite(NoisyMagnetometer.MagneticFieldBody_uT),'all')

    error( ...
        "sensorsimulation:InvalidMagneticField", ...
        "MagneticFieldBody_uT must be an N-by-3 finite numeric array.");
end

%% Validate availability

if ~islogical(NoisyMagnetometer.Available) || ...
        ~isvector(NoisyMagnetometer.Available) || ...
        numel(NoisyMagnetometer.Available) ~= N

    error( ...
        "sensorsimulation:InvalidAvailability", ...
        "Available must be an N-by-1 or 1-by-N logical vector.");
end

%% Copy input to preserve immutability

Magnetometer = NoisyMagnetometer;

%% Zero-corruption exact pass-through

if CorruptionSeverity == 0
    return;
end

%% Quadratic corruption severity

Alpha = (CorruptionSeverity / 100)^2;

%% Block 8 deterministic magnetometer fault envelope

MagneticFieldFault_uT = ...
    Alpha * repmat([20 20 20],N,1);

%% Apply deterministic corruption

Magnetometer.MagneticFieldBody_uT = ...
    NoisyMagnetometer.MagneticFieldBody_uT + ...
    MagneticFieldFault_uT;

%% Preserve availability exactly

Magnetometer.Available = NoisyMagnetometer.Available;

end