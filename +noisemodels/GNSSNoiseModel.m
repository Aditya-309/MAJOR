function Noise = GNSSNoiseModel(Time_s, Config)
%GNSSNOISEMODEL Generate GNSS Gaussian white measurement noise.
%
%   Noise = noisemodels.GNSSNoiseModel(Time_s, Config)
%
%   Generates independent zero-mean Gaussian white measurement noise for
%   the GNSS position and velocity channels.
%
%   Position noise:
%       North      sigma = Config.GNSS.HorizontalNoiseSigma_m
%       East       sigma = Config.GNSS.HorizontalNoiseSigma_m
%       Down/Up    sigma = Config.GNSS.VerticalNoiseSigma_m
%
%   Velocity noise:
%       North      sigma = Config.GNSS.VelocityNoiseSigma_mps
%       East       sigma = Config.GNSS.VelocityNoiseSigma_mps
%       Down       sigma = Config.GNSS.VelocityNoiseSigma_mps
%
%   The generated errors are:
%       - zero mean
%       - Gaussian distributed
%       - temporally white
%       - independent between position and velocity channels
%       - reproducible for a fixed Config.RandomSeed
%
%   Position noise is returned in metres in a local NED-style component
%   representation. It is NOT expressed in latitude/longitude radians.
%
%   This function does not:
%       - generate GNSS bias
%       - apply corruption severity scaling
%       - modify telemetry
%       - implement outages or faults
%       - modify the global MATLAB random-number generator state
%
%   Those responsibilities belong to later Block 5 / Block 8 components.

    %% Validate inputs

    if nargin ~= 2
        error( ...
            'ASRTE:GNSSNoiseModel:InvalidInputCount', ...
            'GNSSNoiseModel requires Time_s and Config.');
    end

    if ~(isnumeric(Time_s) && isreal(Time_s) && ...
            isvector(Time_s) && ~isempty(Time_s))

        error( ...
            'ASRTE:GNSSNoiseModel:InvalidTime', ...
            'Time_s must be a nonempty real numeric vector.');

    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))
        error( ...
            'ASRTE:GNSSNoiseModel:NonFiniteTime', ...
            'Time_s must contain only finite values.');
    end

    if numel(Time_s) > 1 && any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:GNSSNoiseModel:NonMonotonicTime', ...
            'Time_s must be strictly increasing.');
    end

    if ~isstruct(Config)
        error( ...
            'ASRTE:GNSSNoiseModel:InvalidConfig', ...
            'Config must be a structure.');
    end

    RequiredTopLevel = {'RandomSeed', 'GNSS'};

    for k = 1:numel(RequiredTopLevel)

        if ~isfield(Config, RequiredTopLevel{k})
            error( ...
                'ASRTE:GNSSNoiseModel:MissingConfigField', ...
                'Config is missing required field "%s".', ...
                RequiredTopLevel{k});
        end

    end

    RequiredGNSS = { ...
        'HorizontalNoiseSigma_m', ...
        'VerticalNoiseSigma_m', ...
        'VelocityNoiseSigma_mps'};

    for k = 1:numel(RequiredGNSS)

        if ~isfield(Config.GNSS, RequiredGNSS{k})
            error( ...
                'ASRTE:GNSSNoiseModel:MissingGNSSField', ...
                'Config.GNSS is missing required field "%s".', ...
                RequiredGNSS{k});
        end

    end

    %% Validate random seed

    Seed = Config.RandomSeed;

    if ~(isnumeric(Seed) && isreal(Seed) && ...
            isscalar(Seed) && isfinite(Seed) && ...
            Seed >= 0 && Seed == floor(Seed))

        error( ...
            'ASRTE:GNSSNoiseModel:InvalidRandomSeed', ...
            'Config.RandomSeed must be a nonnegative integer scalar.');

    end

    %% Validate noise parameters

    HorizontalSigma = ...
        Config.GNSS.HorizontalNoiseSigma_m;

    VerticalSigma = ...
        Config.GNSS.VerticalNoiseSigma_m;

    VelocitySigma = ...
        Config.GNSS.VelocityNoiseSigma_mps;

    SigmaValues = [ ...
        HorizontalSigma, ...
        VerticalSigma, ...
        VelocitySigma];

    if any(~isnumeric(SigmaValues)) || ...
            any(~isreal(SigmaValues)) || ...
            any(~isfinite(SigmaValues)) || ...
            any(SigmaValues < 0)

        error( ...
            'ASRTE:GNSSNoiseModel:InvalidNoiseSigma', ...
            'GNSS noise standard deviations must be finite, real, nonnegative scalars.');

    end

    if ~isscalar(HorizontalSigma) || ...
            ~isscalar(VerticalSigma) || ...
            ~isscalar(VelocitySigma)

        error( ...
            'ASRTE:GNSSNoiseModel:InvalidNoiseSigma', ...
            'GNSS noise standard deviations must be scalar values.');

    end

    %% Create an independent local random stream
    %
    % A local stream prevents this function from modifying MATLAB's global
    % RNG state. A fixed seed therefore produces reproducible GNSS noise.

    Stream = RandStream( ...
        'mt19937ar', ...
        'Seed', double(Seed));

    N = numel(Time_s);

    %% Generate position noise

    PositionNoise_m = zeros(N, 3);

    PositionNoise_m(:, 1) = ...
        HorizontalSigma .* randn(Stream, N, 1);

    PositionNoise_m(:, 2) = ...
        HorizontalSigma .* randn(Stream, N, 1);

    PositionNoise_m(:, 3) = ...
        VerticalSigma .* randn(Stream, N, 1);

    %% Generate velocity noise

    VelocityNoise_mps = ...
        VelocitySigma .* randn(Stream, N, 3);

    %% Assemble output

    Noise = struct();

    Noise.Time_s = Time_s;

    Noise.SampleCount = N;

    Noise.PositionNoise_m = PositionNoise_m;

    Noise.VelocityNoise_mps = VelocityNoise_mps;

end