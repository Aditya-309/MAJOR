function Noise = AirspeedNoiseModel(Time_s, Config)
%AIRSPEEDNOISEMODEL Generate stochastic airspeed measurement noise.
%
%   Noise = noisemodels.AirspeedNoiseModel(Time_s, Config)
%
%   Generates the approved Gaussian measurement-error model for the
%   Aeroprobe muADS Atlas air-data system.
%
%   Approved Block 5 parameter:
%
%       Airspeed Gaussian sigma = 1.0 m/s
%
%   IMPORTANT:
%       Aeroprobe's published Atlas documentation provides an airspeed
%       error envelope rather than a directly specified Gaussian noise
%       standard deviation. The configured 1.0 m/s value is therefore an
%       engineering stochastic interpretation of that published error
%       envelope. It must not be represented as an Aeroprobe-published
%       Gaussian noise density or standard deviation.
%
%   The generated measurement error is:
%
%       e_V = sigma_V * N(0,1)
%
%   Each timeline sample receives an independent Gaussian realization.
%
%   Output fields:
%
%       Time_s
%       SampleCount
%       AirspeedNoise_mps
%
%   This function:
%       - generates Gaussian measurement noise
%       - uses the configured airspeed noise sigma
%       - uses a local reproducible random stream
%       - does not modify MATLAB's global RNG state
%       - preserves the supplied timeline
%
%   This function does NOT:
%       - generate airspeed bias
%       - apply corruption severity
%       - modify sensor telemetry
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
%       Config.Airspeed.NoiseSigma_mps

    if nargin ~= 2
        error( ...
            'ASRTE:AirspeedNoiseModel:InvalidInputCount', ...
            'AirspeedNoiseModel requires Time_s and Config.');
    end

    if ~(isnumeric(Time_s) && isreal(Time_s) && ...
            isvector(Time_s) && ~isempty(Time_s))
        error( ...
            'ASRTE:AirspeedNoiseModel:InvalidTime', ...
            'Time_s must be a nonempty real numeric vector.');
    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))
        error( ...
            'ASRTE:AirspeedNoiseModel:NonFiniteTime', ...
            'Time_s must contain only finite values.');
    end

    if numel(Time_s) > 1 && any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:AirspeedNoiseModel:NonMonotonicTime', ...
            'Time_s must be strictly increasing.');
    end

    if ~isstruct(Config)
        error( ...
            'ASRTE:AirspeedNoiseModel:InvalidConfig', ...
            'Config must be a structure.');
    end

    if ~isfield(Config, 'RandomSeed')
        error( ...
            'ASRTE:AirspeedNoiseModel:MissingConfigField', ...
            'Config is missing RandomSeed.');
    end

    if ~isfield(Config, 'Airspeed')
        error( ...
            'ASRTE:AirspeedNoiseModel:MissingConfigField', ...
            'Config is missing Airspeed configuration.');
    end

    if ~isfield(Config.Airspeed, 'NoiseSigma_mps')
        error( ...
            'ASRTE:AirspeedNoiseModel:MissingAirspeedField', ...
            'Config.Airspeed is missing NoiseSigma_mps.');
    end

    Seed = Config.RandomSeed;

    if ~(isnumeric(Seed) && isreal(Seed) && ...
            isscalar(Seed) && isfinite(Seed) && ...
            Seed >= 0 && Seed == floor(Seed))
        error( ...
            'ASRTE:AirspeedNoiseModel:InvalidRandomSeed', ...
            'Config.RandomSeed must be a nonnegative integer scalar.');
    end

    Sigma = Config.Airspeed.NoiseSigma_mps;

    if ~(isnumeric(Sigma) && isreal(Sigma) && ...
            isscalar(Sigma) && isfinite(Sigma) && Sigma >= 0)
        error( ...
            'ASRTE:AirspeedNoiseModel:InvalidNoiseSigma', ...
            ['Config.Airspeed.NoiseSigma_mps must be a ', ...
             'finite, real, nonnegative scalar.']);
    end

    Stream = RandStream( ...
        'mt19937ar', ...
        'Seed', double(Seed));

    N = numel(Time_s);

    AirspeedNoise = Sigma .* randn(Stream, N, 1);

    Noise = struct();

    Noise.Time_s = Time_s;
    Noise.SampleCount = N;
    Noise.AirspeedNoise_mps = AirspeedNoise;
end