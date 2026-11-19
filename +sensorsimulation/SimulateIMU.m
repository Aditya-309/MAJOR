function IMU = SimulateIMU(NoisyIMU, CorruptionSeverity)
%SIMULATEIMU Apply deterministic Block 8 IMU corruption.
%
%   IMU = sensorsimulation.SimulateIMU(NoisyIMU, CorruptionSeverity)
%
%   Applies the Block 8 deterministic IMU corruption envelope to the
%   post-Block-5 IMU telemetry.
%
%   Block 5 stochastic effects are assumed to have already been applied.
%   This function therefore does NOT generate or reapply:
%       - measurement noise
%       - stochastic bias
%       - scale-factor error
%
%   Corruption severity:
%       0   -> no additional corruption
%       100 -> full deterministic fault envelope
%
%   Severity scaling:
%
%       alpha = (CorruptionSeverity / 100)^2
%
%   Full Block 8 fault envelopes:
%       Accelerometer: +[2 2 2] m/s^2
%       Gyroscope:     +5 deg/s per axis
%
%   Availability is preserved and is independent of corruption severity.
%
%   Input:
%       NoisyIMU
%           Frozen Block 5-compatible IMU telemetry structure containing:
%               Time_s
%               SampleRate_Hz
%               SampleCount
%               Accelerometer_mps2
%               Gyroscope_radps
%               Available
%
%       CorruptionSeverity
%           Finite real scalar in the range [0,100].
%
%   Output:
%       IMU
%           Same structure and metadata as NoisyIMU, with deterministic
%           Block 8 corruption applied to the IMU measurements.
%
%   Notes:
%       - No random numbers are generated.
%       - Input telemetry is not modified.
%       - Units remain m/s^2 and rad/s.
%       - This function does not implement outages, dropouts, or trust.

arguments
    NoisyIMU (1,1) struct
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

%% Validate required frozen Block 5 IMU fields

RequiredFields = { ...
    'Time_s', ...
    'SampleRate_Hz', ...
    'SampleCount', ...
    'Accelerometer_mps2', ...
    'Gyroscope_radps', ...
    'Available'};

for k = 1:numel(RequiredFields)
    if ~isfield(NoisyIMU, RequiredFields{k})
        error( ...
            "sensorsimulation:MissingField", ...
            "NoisyIMU is missing required field '%s'.", ...
            RequiredFields{k});
    end
end

%% Validate scalar metadata

if ~isscalar(NoisyIMU.SampleRate_Hz) || ...
        ~isnumeric(NoisyIMU.SampleRate_Hz) || ...
        ~isfinite(NoisyIMU.SampleRate_Hz) || ...
        NoisyIMU.SampleRate_Hz <= 0

    error( ...
        "sensorsimulation:InvalidSampleRate", ...
        "SampleRate_Hz must be a finite positive scalar.");
end

if ~isscalar(NoisyIMU.SampleCount) || ...
        ~isnumeric(NoisyIMU.SampleCount) || ...
        ~isfinite(NoisyIMU.SampleCount) || ...
        NoisyIMU.SampleCount < 1 || ...
        NoisyIMU.SampleCount ~= floor(NoisyIMU.SampleCount)

    error( ...
        "sensorsimulation:InvalidSampleCount", ...
        "SampleCount must be a positive integer scalar.");
end

N = NoisyIMU.SampleCount;

%% Validate time vector

if ~isnumeric(NoisyIMU.Time_s) || ...
        ~isvector(NoisyIMU.Time_s) || ...
        numel(NoisyIMU.Time_s) ~= N || ...
        any(~isfinite(NoisyIMU.Time_s))

    error( ...
        "sensorsimulation:InvalidTime", ...
        "Time_s must contain exactly SampleCount finite samples.");
end

Time_s = NoisyIMU.Time_s(:);

if any(diff(Time_s) <= 0)
    error( ...
        "sensorsimulation:NonMonotonicTime", ...
        "Time_s must be strictly increasing.");
end

%% Validate accelerometer measurement

if ~isnumeric(NoisyIMU.Accelerometer_mps2) || ...
        ~ismatrix(NoisyIMU.Accelerometer_mps2) || ...
        size(NoisyIMU.Accelerometer_mps2,1) ~= N || ...
        size(NoisyIMU.Accelerometer_mps2,2) ~= 3 || ...
        any(~isfinite(NoisyIMU.Accelerometer_mps2),'all')

    error( ...
        "sensorsimulation:InvalidAccelerometer", ...
        "Accelerometer_mps2 must be an N-by-3 finite numeric array.");
end

%% Validate gyroscope measurement

if ~isnumeric(NoisyIMU.Gyroscope_radps) || ...
        ~ismatrix(NoisyIMU.Gyroscope_radps) || ...
        size(NoisyIMU.Gyroscope_radps,1) ~= N || ...
        size(NoisyIMU.Gyroscope_radps,2) ~= 3 || ...
        any(~isfinite(NoisyIMU.Gyroscope_radps),'all')

    error( ...
        "sensorsimulation:InvalidGyroscope", ...
        "Gyroscope_radps must be an N-by-3 finite numeric array.");
end

%% Validate availability

if ~islogical(NoisyIMU.Available) || ...
        ~isvector(NoisyIMU.Available) || ...
        numel(NoisyIMU.Available) ~= N

    error( ...
        "sensorsimulation:InvalidAvailability", ...
        "Available must be an N-by-1 or 1-by-N logical vector.");
end

%% Copy input to preserve immutability

IMU = NoisyIMU;

%% Zero-corruption exact pass-through

if CorruptionSeverity == 0
    return;
end

%% Quadratic corruption severity

Alpha = (CorruptionSeverity / 100)^2;

%% Block 8 deterministic IMU fault envelopes

% Accelerometer full-scale fault:
%   +2 m/s^2 on each body axis.
AccelerometerFault_mps2 = ...
    Alpha * repmat([2 2 2],N,1);

% Gyroscope full-scale fault:
%   +5 deg/s on each body axis.
GyroscopeFault_radps = ...
    Alpha * repmat(deg2rad(5),N,3);

%% Apply deterministic corruption

IMU.Accelerometer_mps2 = ...
    NoisyIMU.Accelerometer_mps2 + AccelerometerFault_mps2;

IMU.Gyroscope_radps = ...
    NoisyIMU.Gyroscope_radps + GyroscopeFault_radps;

%% Preserve availability exactly

IMU.Available = NoisyIMU.Available;

end