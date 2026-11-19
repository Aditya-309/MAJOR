function WindNED_mps = WindProfile( ...
    Time_s, ...
    ConstantNED_mps, ...
    DisturbanceEnabled, ...
    DisturbanceNED_mps, ...
    StartTime_s, ...
    EndTime_s)
%WINDPROFILE Generate deterministic NED wind profile.
%
%   WindNED_mps = flightscenario.WindProfile( ...
%       Time_s, ...
%       ConstantNED_mps, ...
%       DisturbanceEnabled, ...
%       DisturbanceNED_mps, ...
%       StartTime_s, ...
%       EndTime_s)
%
%   Generates a deterministic wind profile consisting of a constant NED
%   wind component and an optional smooth disturbance component.
%
%   The disturbance is applied smoothly using a quintic smoothstep
%   transition over the event interval:
%
%       s(x) = 6x^5 - 15x^4 + 10x^3
%
%   The disturbance magnitude follows:
%
%       0 -> full disturbance -> 0
%
%   across the specified event window.
%
%   INPUTS
%
%       Time_s
%           Real finite scalar or vector containing evaluation times in
%           seconds.
%
%       ConstantNED_mps
%           3-element constant wind vector in NED coordinates:
%
%               [North; East; Down]
%
%           Units: m/s.
%
%       DisturbanceEnabled
%           Logical scalar specifying whether the disturbance is active.
%
%       DisturbanceNED_mps
%           3-element disturbance wind vector in NED coordinates.
%           Units: m/s.
%
%       StartTime_s
%           Disturbance event start time in seconds.
%
%       EndTime_s
%           Disturbance event end time in seconds.
%
%   OUTPUT
%
%       WindNED_mps
%
%           For scalar Time_s:
%
%               3x1 [North; East; Down]
%
%           For vector Time_s:
%
%               Nx3
%
%           Each row corresponds to one evaluation time.
%
%   NOTES
%
%       - The constant wind is always present.
%       - When DisturbanceEnabled is false, the disturbance timing and
%         magnitude inputs are not used in profile generation.
%       - The disturbance uses a symmetric smooth envelope.
%       - No randomness or hidden state is used.
%       - NED coordinate convention is preserved throughout.
%
%   MATLAB Version
%       MATLAB R2024b compatible.

    %% Input Validation

    validateattributes( ...
        Time_s, ...
        {'numeric'}, ...
        {'real', 'finite'}, ...
        mfilename, ...
        'Time_s', ...
        1);

    validateattributes( ...
        ConstantNED_mps, ...
        {'numeric'}, ...
        {'real', 'finite', 'numel', 3}, ...
        mfilename, ...
        'ConstantNED_mps', ...
        2);

    if ~islogical(DisturbanceEnabled) || ...
            ~isscalar(DisturbanceEnabled)

        error( ...
            'WindProfile:InvalidDisturbanceEnabled', ...
            ['DisturbanceEnabled must be a logical scalar.']);

    end

    validateattributes( ...
        DisturbanceNED_mps, ...
        {'numeric'}, ...
        {'real', 'finite', 'numel', 3}, ...
        mfilename, ...
        'DisturbanceNED_mps', ...
        4);

    validateattributes( ...
        StartTime_s, ...
        {'numeric'}, ...
        {'real', 'finite', 'scalar'}, ...
        mfilename, ...
        'StartTime_s', ...
        5);

    validateattributes( ...
        EndTime_s, ...
        {'numeric'}, ...
        {'real', 'finite', 'scalar'}, ...
        mfilename, ...
        'EndTime_s', ...
        6);

    if StartTime_s < 0

        error( ...
            'WindProfile:InvalidStartTime', ...
            'StartTime_s must be greater than or equal to zero.');

    end

    if EndTime_s <= StartTime_s

        error( ...
            'WindProfile:InvalidEventInterval', ...
            'EndTime_s must be strictly greater than StartTime_s.');

    end

    %% Normalize Wind Vectors

    ConstantNED_mps = ...
        reshape(double(ConstantNED_mps), 3, 1);

    DisturbanceNED_mps = ...
        reshape(double(DisturbanceNED_mps), 3, 1);

    %% Scalar Time Input

    if isscalar(Time_s)

        WindNED_mps = ConstantNED_mps;

        if DisturbanceEnabled

            Envelope = localDisturbanceEnvelope( ...
                Time_s, ...
                StartTime_s, ...
                EndTime_s);

            WindNED_mps = ...
                WindNED_mps + ...
                Envelope .* DisturbanceNED_mps;

        end

        return

    end

    %% Vector Time Input

    OriginalSize = size(Time_s);

    TimeVector_s = Time_s(:);

    NumberOfSamples = numel(TimeVector_s);

    WindNED_mps = ...
        repmat( ...
            ConstantNED_mps.', ...
            NumberOfSamples, ...
            1);

    if DisturbanceEnabled

        Envelope = localDisturbanceEnvelope( ...
            TimeVector_s, ...
            StartTime_s, ...
            EndTime_s);

        WindNED_mps = ...
            WindNED_mps + ...
            Envelope .* ...
            DisturbanceNED_mps.';

    end

    %% Preserve Vector Orientation Convention

    if iscolumn(Time_s)

        return

    end

    if isrow(Time_s)

        return

    end

    if numel(OriginalSize) > 2

        error( ...
            'WindProfile:UnsupportedTimeDimensions', ...
            ['Time_s must be a scalar, row vector, or column vector.']);

    end

end


function Envelope = localDisturbanceEnvelope( ...
    Time_s, ...
    StartTime_s, ...
    EndTime_s)
%LOCALDISTURBANCEENVELOPE Generate symmetric smooth disturbance envelope.

    Envelope = zeros(size(Time_s));

    MidTime_s = ...
        0.5 .* (StartTime_s + EndTime_s);

    RiseMask = ...
        Time_s >= StartTime_s & ...
        Time_s < MidTime_s;

    FallMask = ...
        Time_s >= MidTime_s & ...
        Time_s <= EndTime_s;

    if any(RiseMask, 'all')

        NormalizedTime = ...
            (Time_s(RiseMask) - StartTime_s) ./ ...
            (MidTime_s - StartTime_s);

        Envelope(RiseMask) = ...
            localQuinticSmoothStep(NormalizedTime);

    end

    if any(FallMask, 'all')

        NormalizedTime = ...
            (Time_s(FallMask) - MidTime_s) ./ ...
            (EndTime_s - MidTime_s);

        Envelope(FallMask) = ...
            1 - ...
            localQuinticSmoothStep(NormalizedTime);

    end

end


function SmoothFraction = localQuinticSmoothStep(NormalizedTime)
%LOCALQUINTICSMOOTHSTEP Quintic zero-slope transition.

    NormalizedTime = ...
        min(max(NormalizedTime, 0), 1);

    SmoothFraction = ...
        6 .* NormalizedTime.^5 - ...
        15 .* NormalizedTime.^4 + ...
        10 .* NormalizedTime.^3;

end