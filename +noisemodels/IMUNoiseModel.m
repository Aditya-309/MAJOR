function Noise = IMUNoiseModel(Time_s, Config)
%IMUNOISEMODEL Generate IMU Gaussian white measurement noise.
%
%   Noise = noisemodels.IMUNoiseModel(Time_s, Config)
%
%   Generates independent zero-mean Gaussian white measurement noise for
%   the three accelerometer axes and three gyroscope axes.
%
%   Accelerometer noise:
%       Config.IMU.AccelVRW_mps2SqrtHz
%
%   Gyroscope noise:
%       Config.IMU.GyroARW_radpsSqrtHz
%
%   The configured values are already converted to SI-compatible
%   continuous-time noise coefficients. For a discrete measurement
%   interval dt, the corresponding measurement standard deviation is:
%
%       sigma_discrete = sigma_continuous / sqrt(dt)
%
%   Therefore the generated noise correctly reflects the sampling
%   interval represented by Time_s.
%
%   Output:
%
%       Noise.Time_s
%       Noise.SampleCount
%       Noise.AccelerometerNoise_mps2
%       Noise.GyroscopeNoise_radps
%
%   The three columns correspond to the sensor body axes:
%
%       [X Y Z]
%
%   This function:
%       - generates Gaussian white measurement noise
%       - uses an independent local reproducible random stream
%       - preserves the supplied timeline
%       - does not modify MATLAB's global RNG state
%
%   This function does NOT:
%       - generate turn-on bias
%       - generate in-run bias
%       - generate scale-factor errors
%       - apply corruption severity
%       - modify telemetry
%       - implement outages or faults

    %% Validate input count

    if nargin ~= 2
        error( ...
            'ASRTE:IMUNoiseModel:InvalidInputCount', ...
            'IMUNoiseModel requires Time_s and Config.');
    end

    %% Validate time

    if ~(isnumeric(Time_s) && isreal(Time_s) && ...
            isvector(Time_s) && ~isempty(Time_s))

        error( ...
            'ASRTE:IMUNoiseModel:InvalidTime', ...
            'Time_s must be a nonempty real numeric vector.');

    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))
        error( ...
            'ASRTE:IMUNoiseModel:NonFiniteTime', ...
            'Time_s must contain only finite values.');
    end

    if numel(Time_s) > 1 && any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:IMUNoiseModel:NonMonotonicTime', ...
            'Time_s must be strictly increasing.');
    end

    %% Validate configuration structure

    if ~isstruct(Config)
        error( ...
            'ASRTE:IMUNoiseModel:InvalidConfig', ...
            'Config must be a structure.');
    end

    if ~isfield(Config, 'RandomSeed')
        error( ...
            'ASRTE:IMUNoiseModel:MissingConfigField', ...
            'Config is missing RandomSeed.');
    end

    if ~isfield(Config, 'IMU')
        error( ...
            'ASRTE:IMUNoiseModel:MissingConfigField', ...
            'Config is missing IMU configuration.');
    end

    RequiredFields = { ...
        'AccelVRW_mps2SqrtHz', ...
        'GyroARW_radpsSqrtHz'};

    for k = 1:numel(RequiredFields)

        if ~isfield(Config.IMU, RequiredFields{k})

            error( ...
                'ASRTE:IMUNoiseModel:MissingIMUField', ...
                'Config.IMU is missing required field "%s".', ...
                RequiredFields{k});

        end

    end

    %% Validate random seed

    Seed = Config.RandomSeed;

    if ~(isnumeric(Seed) && isreal(Seed) && ...
            isscalar(Seed) && isfinite(Seed) && ...
            Seed >= 0 && Seed == floor(Seed))

        error( ...
            'ASRTE:IMUNoiseModel:InvalidRandomSeed', ...
            'Config.RandomSeed must be a nonnegative integer scalar.');

    end

    %% Read noise coefficients

    AccelVRW = Config.IMU.AccelVRW_mps2SqrtHz;
    GyroARW = Config.IMU.GyroARW_radpsSqrtHz;

    %% Validate noise coefficients

    if ~(isnumeric(AccelVRW) && isreal(AccelVRW) && ...
            isscalar(AccelVRW) && isfinite(AccelVRW) && ...
            AccelVRW >= 0)

        error( ...
            'ASRTE:IMUNoiseModel:InvalidAccelVRW', ...
            ['Accelerometer VRW must be a finite, ', ...
             'real, nonnegative scalar.']);

    end

    if ~(isnumeric(GyroARW) && isreal(GyroARW) && ...
            isscalar(GyroARW) && isfinite(GyroARW) && ...
            GyroARW >= 0)

        error( ...
            'ASRTE:IMUNoiseModel:InvalidGyroARW', ...
            ['Gyroscope ARW must be a finite, ', ...
             'real, nonnegative scalar.']);

    end

    %% Create local reproducible random stream

    Stream = RandStream( ...
        'mt19937ar', ...
        'Seed', double(Seed));

    N = numel(Time_s);

    %% Allocate outputs

    AccelerometerNoise = zeros(N, 3);
    GyroscopeNoise = zeros(N, 3);

    %% Generate discrete white noise

    if N > 1

        for k = 2:N

            dt = Time_s(k) - Time_s(k - 1);

            DiscreteAccelSigma = ...
                AccelVRW / sqrt(dt);

            DiscreteGyroSigma = ...
                GyroARW / sqrt(dt);

            AccelerometerNoise(k, :) = ...
                DiscreteAccelSigma .* randn(Stream, 1, 3);

            GyroscopeNoise(k, :) = ...
                DiscreteGyroSigma .* randn(Stream, 1, 3);

        end

    end

    %% Assemble output

    Noise = struct();

    Noise.Time_s = Time_s;

    Noise.SampleCount = N;

    Noise.AccelerometerNoise_mps2 = ...
        AccelerometerNoise;

    Noise.GyroscopeNoise_radps = ...
        GyroscopeNoise;

end