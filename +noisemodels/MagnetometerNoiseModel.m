function Noise = MagnetometerNoiseModel(Time_s, Config)
%MAGNETOMETERNOISEMODEL Generate stochastic magnetometer measurement noise.
%
%   Noise = noisemodels.MagnetometerNoiseModel(Time_s, Config)
%
%   Generates the approved Gaussian measurement-error model for the
%   Honeywell HMR2300 magnetometer.
%
%   Approved Block 5 parameter:
%
%       Magnetometer Gaussian sigma = 0.12 microTesla
%
%   IMPORTANT:
%       Honeywell does not publish an exact broadband Gaussian noise
%       standard deviation for this model. The configured 0.12 microTesla
%       value is therefore an engineering stochastic interpretation based
%       on the HMR2300 published accuracy specification.
%
%       It must NOT be represented as a Honeywell-published Gaussian noise
%       density or standard deviation.
%
%   The generated measurement error is independently applied to the three
%   magnetic-field axes:
%
%       e_B = sigma_B * N(0,1)
%
%   The noise unit is microTesla.
%
%   Output fields:
%
%       Time_s
%       SampleCount
%       MagnetometerNoise_uT
%
%   Columns correspond to:
%
%       [X Y Z]
%
%   This function:
%       - generates Gaussian magnetic-field measurement noise
%       - uses the configured noise sigma
%       - generates independent X/Y/Z realizations
%       - uses a local reproducible random stream
%       - does not modify MATLAB's global RNG state
%       - preserves the supplied timeline
%
%   This function does NOT:
%       - generate magnetometer bias
%       - generate scale-factor errors
%       - generate misalignment
%       - apply corruption severity
%       - modify magnetometer telemetry
%       - implement saturation
%       - implement dropout or outage
%       - implement estimator/trust decisions
%
%   Inputs:
%       Time_s : strictly increasing, finite time vector [s]
%       Config : Block 5 sensor-noise configuration structure
%
%   Required configuration fields:
%       Config.RandomSeed
%       Config.Magnetometer.NoiseSigma_uT

    if nargin ~= 2
        error( ...
            'ASRTE:MagnetometerNoiseModel:InvalidInputCount', ...
            'MagnetometerNoiseModel requires Time_s and Config.');
    end

    if ~(isnumeric(Time_s) && isreal(Time_s) && ...
            isvector(Time_s) && ~isempty(Time_s))
        error( ...
            'ASRTE:MagnetometerNoiseModel:InvalidTime', ...
            'Time_s must be a nonempty real numeric vector.');
    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))
        error( ...
            'ASRTE:MagnetometerNoiseModel:NonFiniteTime', ...
            'Time_s must contain only finite values.');
    end

    if numel(Time_s) > 1 && any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:MagnetometerNoiseModel:NonMonotonicTime', ...
            'Time_s must be strictly increasing.');
    end

    if ~isstruct(Config)
        error( ...
            'ASRTE:MagnetometerNoiseModel:InvalidConfig', ...
            'Config must be a structure.');
    end

    if ~isfield(Config, 'RandomSeed')
        error( ...
            'ASRTE:MagnetometerNoiseModel:MissingConfigField', ...
            'Config is missing RandomSeed.');
    end

    if ~isfield(Config, 'Magnetometer')
        error( ...
            'ASRTE:MagnetometerNoiseModel:MissingConfigField', ...
            'Config is missing Magnetometer configuration.');
    end

    if ~isfield(Config.Magnetometer, 'NoiseSigma_uT')
        error( ...
            'ASRTE:MagnetometerNoiseModel:MissingMagnetometerField', ...
            'Config.Magnetometer is missing NoiseSigma_uT.');
    end

    Seed = Config.RandomSeed;

    if ~(isnumeric(Seed) && isreal(Seed) && ...
            isscalar(Seed) && isfinite(Seed) && ...
            Seed >= 0 && Seed == floor(Seed))
        error( ...
            'ASRTE:MagnetometerNoiseModel:InvalidRandomSeed', ...
            'Config.RandomSeed must be a nonnegative integer scalar.');
    end

    Sigma = Config.Magnetometer.NoiseSigma_uT;

    if ~(isnumeric(Sigma) && isreal(Sigma) && ...
            isscalar(Sigma) && isfinite(Sigma) && Sigma >= 0)
        error( ...
            'ASRTE:MagnetometerNoiseModel:InvalidNoiseSigma', ...
            ['Config.Magnetometer.NoiseSigma_uT must be a ', ...
             'finite, real, nonnegative scalar.']);
    end

    Stream = RandStream( ...
        'mt19937ar', ...
        'Seed', double(Seed));

    N = numel(Time_s);

    MagnetometerNoise = ...
        Sigma .* randn(Stream, N, 3);

    Noise = struct();

    Noise.Time_s = Time_s;
    Noise.SampleCount = N;

    Noise.MagnetometerNoise_uT = ...
        MagnetometerNoise;
end