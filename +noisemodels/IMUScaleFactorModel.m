function ScaleFactor = IMUScaleFactorModel(Time_s, Config)
%IMUSCALEFACTORMODEL Generate constant per-flight IMU scale-factor errors.
%
%   ScaleFactor = noisemodels.IMUScaleFactorModel(Time_s, Config)
%
%   Generates independent constant scale-factor error terms for the
%   accelerometer and gyroscope axes.
%
%   Approved Block 5 model:
%
%       Accelerometer scale-factor sigma = 120 ppm
%       Gyroscope scale-factor sigma     = 300 ppm
%
%   The scale-factor error is represented as a dimensionless fractional
%   quantity. For example:
%
%       120 ppm = 120e-6
%
%   A single scale-factor realization is generated for each axis and
%   remains constant throughout the supplied flight timeline.
%
%   Output fields:
%
%       Time_s
%       SampleCount
%       AccelerometerScaleFactor
%       GyroscopeScaleFactor
%
%   Columns correspond to:
%
%       [X Y Z]
%
%   The generated values represent fractional scale-factor errors and are
%   intended to be applied later by the sensor-telemetry corruption stage.
%
%   This function:
%       - generates one constant realization per flight
%       - uses independent X/Y/Z realizations
%       - uses a local reproducible random stream
%       - does not modify MATLAB's global RNG state
%       - preserves the supplied timeline
%
%   This function does NOT:
%       - modify sensor measurements
%       - generate additive measurement noise
%       - generate sensor bias
%       - apply corruption severity
%       - implement saturation
%       - implement misalignment
%       - implement outages or faults
%
%   Inputs:
%       Time_s : strictly increasing, finite time vector [s]
%       Config : Block 5 sensor-noise configuration structure
%
%   Required configuration fields:
%       Config.RandomSeed
%       Config.IMU.AccelScaleFactorSigma
%       Config.IMU.GyroScaleFactorSigma
%
%   Example:
%       Config = noisemodels.SensorNoiseConfig();
%       t = (0:0.01:10)';
%       SF = noisemodels.IMUScaleFactorModel(t, Config);

    if nargin ~= 2
        error( ...
            'ASRTE:IMUScaleFactorModel:InvalidInputCount', ...
            'IMUScaleFactorModel requires Time_s and Config.');
    end

    if ~(isnumeric(Time_s) && isreal(Time_s) && ...
            isvector(Time_s) && ~isempty(Time_s))
        error( ...
            'ASRTE:IMUScaleFactorModel:InvalidTime', ...
            'Time_s must be a nonempty real numeric vector.');
    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))
        error( ...
            'ASRTE:IMUScaleFactorModel:NonFiniteTime', ...
            'Time_s must contain only finite values.');
    end

    if numel(Time_s) > 1 && any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:IMUScaleFactorModel:NonMonotonicTime', ...
            'Time_s must be strictly increasing.');
    end

    if ~isstruct(Config)
        error( ...
            'ASRTE:IMUScaleFactorModel:InvalidConfig', ...
            'Config must be a structure.');
    end

    if ~isfield(Config, 'RandomSeed')
        error( ...
            'ASRTE:IMUScaleFactorModel:MissingConfigField', ...
            'Config is missing RandomSeed.');
    end

    if ~isfield(Config, 'IMU')
        error( ...
            'ASRTE:IMUScaleFactorModel:MissingConfigField', ...
            'Config is missing IMU configuration.');
    end

    RequiredFields = { ...
        'AccelScaleFactorSigma', ...
        'GyroScaleFactorSigma'};

    for k = 1:numel(RequiredFields)
        if ~isfield(Config.IMU, RequiredFields{k})
            error( ...
                'ASRTE:IMUScaleFactorModel:MissingIMUField', ...
                'Config.IMU is missing required field "%s".', ...
                RequiredFields{k});
        end
    end

    Seed = Config.RandomSeed;

    if ~(isnumeric(Seed) && isreal(Seed) && ...
            isscalar(Seed) && isfinite(Seed) && ...
            Seed >= 0 && Seed == floor(Seed))
        error( ...
            'ASRTE:IMUScaleFactorModel:InvalidRandomSeed', ...
            'Config.RandomSeed must be a nonnegative integer scalar.');
    end

    AccelSigma = Config.IMU.AccelScaleFactorSigma;
    GyroSigma = Config.IMU.GyroScaleFactorSigma;

    SigmaValues = [AccelSigma, GyroSigma];

    if ~(isnumeric(SigmaValues) && isreal(SigmaValues) && ...
            all(isfinite(SigmaValues)) && ...
            all(SigmaValues >= 0))
        error( ...
            'ASRTE:IMUScaleFactorModel:InvalidScaleFactorSigma', ...
            ['IMU scale-factor standard deviations must be ', ...
             'finite, real, scalar, and nonnegative.']);
    end

    Stream = RandStream( ...
        'mt19937ar', ...
        'Seed', double(Seed));

    N = numel(Time_s);

    AccelScaleFactor = ...
        AccelSigma .* randn(Stream, 1, 3);

    GyroScaleFactor = ...
        GyroSigma .* randn(Stream, 1, 3);

    AccelScaleFactorTimeline = ...
        repmat(AccelScaleFactor, N, 1);

    GyroScaleFactorTimeline = ...
        repmat(GyroScaleFactor, N, 1);

    ScaleFactor = struct();

    ScaleFactor.Time_s = Time_s;
    ScaleFactor.SampleCount = N;

    ScaleFactor.AccelerometerScaleFactor = ...
        AccelScaleFactorTimeline;

    ScaleFactor.GyroscopeScaleFactor = ...
        GyroScaleFactorTimeline;
end