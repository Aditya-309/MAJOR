function Timeline = BuildSensorTimeline( ...
    GroundTruth, ...
    SampleRate_Hz)
%BUILDSENSORTIMELINE Build a deterministic native sensor timeline.
%
%   Timeline = BUILDSENSORTIMELINE(GroundTruth, SampleRate_Hz) generates a
%   deterministic sensor timeline spanning the exact time interval covered
%   by the frozen GroundTruth telemetry.
%
%   The GroundTruth telemetry is never modified or resampled. This function
%   only constructs the independent native timeline required by a sensor.
%
%   The returned structure contains:
%
%       Timeline.Time_s
%       Timeline.SampleRate_Hz
%       Timeline.SampleCount
%
%   The timeline always includes the GroundTruth start time. Uniform native
%   sampling is generated using:
%
%       t(k) = t0 + k / SampleRate_Hz
%
%   for all samples within the GroundTruth time span. If the final uniformly
%   spaced sample does not coincide exactly with the GroundTruth end time,
%   the exact final GroundTruth time is appended deterministically.
%
%   This ensures complete coverage of the GroundTruth simulation interval
%   without modifying GroundTruth or introducing stochastic behavior.

    %% Validate Inputs

    if ~isstruct(GroundTruth) || ~isscalar(GroundTruth)
        error( ...
            'ASRTE:SensorTimeline:InvalidGroundTruthStructure', ...
            'GroundTruth must be a scalar structure.');
    end

    if ~isfield(GroundTruth, 'Time_s')
        error( ...
            'ASRTE:SensorTimeline:MissingTime', ...
            'GroundTruth must contain the Time_s field.');
    end

    Time_s = GroundTruth.Time_s;

    if ~isnumeric(Time_s) || ...
            ~isreal(Time_s) || ...
            ~isvector(Time_s) || ...
            isempty(Time_s) || ...
            any(~isfinite(Time_s))

        error( ...
            'ASRTE:SensorTimeline:InvalidGroundTruthTime', ...
            ['GroundTruth.Time_s must be a nonempty finite ', ...
             'real numeric vector.']);
    end

    Time_s = Time_s(:);

    if numel(Time_s) < 2
        error( ...
            'ASRTE:SensorTimeline:InsufficientGroundTruthSamples', ...
            ['GroundTruth.Time_s must contain at least two samples ', ...
             'to define a simulation interval.']);
    end

    if any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:SensorTimeline:NonIncreasingGroundTruthTime', ...
            'GroundTruth.Time_s must be strictly increasing.');
    end

    if ~isnumeric(SampleRate_Hz) || ...
            ~isreal(SampleRate_Hz) || ...
            ~isscalar(SampleRate_Hz) || ...
            ~isfinite(SampleRate_Hz) || ...
            SampleRate_Hz <= 0

        error( ...
            'ASRTE:SensorTimeline:InvalidSampleRate', ...
            'SampleRate_Hz must be a positive finite real scalar.');
    end

    %% Extract Time Bounds

    StartTime_s = Time_s(1);

    EndTime_s = Time_s(end);

    SamplePeriod_s = ...
        1 / SampleRate_Hz;

    Duration_s = ...
        EndTime_s - StartTime_s;

    %% Build Uniform Native Timeline

    UniformSampleCount = ...
        floor(Duration_s / SamplePeriod_s);

    UniformTime_s = ...
        StartTime_s + ...
        (0:UniformSampleCount).' * SamplePeriod_s;

    %% Ensure Exact Simulation-End Coverage
    %
    % Floating-point arithmetic can produce an endpoint that differs from
    % EndTime_s by a very small numerical amount. A scale-aware tolerance
    % prevents duplicate endpoint insertion in that case.

    TimeTolerance_s = ...
        16 * eps(max( ...
            1, ...
            max(abs([StartTime_s, EndTime_s]))));

    if abs(UniformTime_s(end) - EndTime_s) ...
            <= TimeTolerance_s

        UniformTime_s(end) = ...
            EndTime_s;

    elseif UniformTime_s(end) < EndTime_s

        UniformTime_s(end + 1, 1) = ...
            EndTime_s;

    else

        error( ...
            'ASRTE:SensorTimeline:InternalTimelineError', ...
            ['Generated sensor timeline exceeded the GroundTruth ', ...
             'simulation end time.']);

    end

    %% Final Timeline Validation

    if any(~isfinite(UniformTime_s)) || ...
            any(diff(UniformTime_s) <= 0)

        error( ...
            'ASRTE:SensorTimeline:InvalidGeneratedTimeline', ...
            ['The generated sensor timeline must be finite and ', ...
             'strictly increasing.']);

    end

    if UniformTime_s(1) ~= StartTime_s || ...
            UniformTime_s(end) ~= EndTime_s

        error( ...
            'ASRTE:SensorTimeline:IncompleteCoverage', ...
            ['The generated sensor timeline must span the exact ', ...
             'GroundTruth start and end times.']);

    end

    %% Build Output

    Timeline = struct();

    Timeline.Time_s = ...
        UniformTime_s;

    Timeline.SampleRate_Hz = ...
        SampleRate_Hz;

    Timeline.SampleCount = ...
        numel(UniformTime_s);

end