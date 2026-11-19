function Bias = GNSSBiasModel(Time_s, Config)
%GNSSBIASMODEL Generate slowly varying GNSS stochastic bias.
%
%   Bias = noisemodels.GNSSBiasModel(Time_s, Config)
%
%   Generates a first-order Gauss-Markov stochastic bias process for GNSS
%   position measurements.
%
%   States:
%       North   horizontal bias [m]
%       East    horizontal bias [m]
%       Vertical bias            [m]
%
%   Model:
%
%       b(k) = phi*b(k-1) + q(k)
%
%       phi = exp(-dt/tau)
%
%       q variance = sigma^2 * (1 - phi^2)
%
%   This produces a stationary zero-mean Gauss-Markov process whose
%   long-term standard deviation is the configured bias sigma.
%
%   Approved Block 5 parameters:
%       Horizontal bias sigma = 0.30 m
%       Vertical bias sigma   = 0.45 m
%       Correlation time      = 60 s
%
%   These parameters are engineering model choices and are not claimed to
%   be direct OEM7720 stochastic specifications.
%
%   This function does not:
%       - generate white GNSS measurement noise
%       - apply corruption severity scaling
%       - modify telemetry
%       - implement outages or faults
%
%   Those responsibilities belong to separate Block 5 / Block 8 models.

    %% Validate input count

    if nargin ~= 2
        error( ...
            'ASRTE:GNSSBiasModel:InvalidInputCount', ...
            'GNSSBiasModel requires Time_s and Config.');
    end

    %% Validate time

    if ~(isnumeric(Time_s) && isreal(Time_s) && ...
            isvector(Time_s) && ~isempty(Time_s))

        error( ...
            'ASRTE:GNSSBiasModel:InvalidTime', ...
            'Time_s must be a nonempty real numeric vector.');

    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))
        error( ...
            'ASRTE:GNSSBiasModel:NonFiniteTime', ...
            'Time_s must contain only finite values.');
    end

    if numel(Time_s) > 1 && any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:GNSSBiasModel:NonMonotonicTime', ...
            'Time_s must be strictly increasing.');
    end

    %% Validate configuration

    if ~isstruct(Config)
        error( ...
            'ASRTE:GNSSBiasModel:InvalidConfig', ...
            'Config must be a structure.');
    end

    RequiredTopLevel = {'RandomSeed', 'GNSS'};

    for k = 1:numel(RequiredTopLevel)

        if ~isfield(Config, RequiredTopLevel{k})
            error( ...
                'ASRTE:GNSSBiasModel:MissingConfigField', ...
                'Config is missing required field "%s".', ...
                RequiredTopLevel{k});
        end

    end

    RequiredGNSS = { ...
        'BiasSigmaHorizontal_m', ...
        'BiasSigmaVertical_m', ...
        'BiasCorrelationTime_s'};

    for k = 1:numel(RequiredGNSS)

        if ~isfield(Config.GNSS, RequiredGNSS{k})
            error( ...
                'ASRTE:GNSSBiasModel:MissingGNSSField', ...
                'Config.GNSS is missing required field "%s".', ...
                RequiredGNSS{k});
        end

    end

    %% Validate seed

    Seed = Config.RandomSeed;

    if ~(isnumeric(Seed) && isreal(Seed) && ...
            isscalar(Seed) && isfinite(Seed) && ...
            Seed >= 0 && Seed == floor(Seed))

        error( ...
            'ASRTE:GNSSBiasModel:InvalidRandomSeed', ...
            'Config.RandomSeed must be a nonnegative integer scalar.');

    end

    %% Read model parameters

    SigmaHorizontal = ...
        Config.GNSS.BiasSigmaHorizontal_m;

    SigmaVertical = ...
        Config.GNSS.BiasSigmaVertical_m;

    Tau = ...
        Config.GNSS.BiasCorrelationTime_s;

    %% Validate model parameters

    if ~(isnumeric(SigmaHorizontal) && ...
            isreal(SigmaHorizontal) && ...
            isscalar(SigmaHorizontal) && ...
            isfinite(SigmaHorizontal) && ...
            SigmaHorizontal >= 0)

        error( ...
            'ASRTE:GNSSBiasModel:InvalidHorizontalSigma', ...
            'Horizontal GNSS bias sigma must be finite, real, and nonnegative.');

    end

    if ~(isnumeric(SigmaVertical) && ...
            isreal(SigmaVertical) && ...
            isscalar(SigmaVertical) && ...
            isfinite(SigmaVertical) && ...
            SigmaVertical >= 0)

        error( ...
            'ASRTE:GNSSBiasModel:InvalidVerticalSigma', ...
            'Vertical GNSS bias sigma must be finite, real, and nonnegative.');

    end

    if ~(isnumeric(Tau) && ...
            isreal(Tau) && ...
            isscalar(Tau) && ...
            isfinite(Tau) && ...
            Tau > 0)

        error( ...
            'ASRTE:GNSSBiasModel:InvalidCorrelationTime', ...
            'GNSS bias correlation time must be finite, real, scalar, and positive.');

    end

    %% Create local reproducible random stream

    Stream = RandStream( ...
        'mt19937ar', ...
        'Seed', double(Seed));

    N = numel(Time_s);

    %% Allocate output

    Bias_m = zeros(N, 3);

    %% Generate Gauss-Markov process

    if N > 1

        for k = 2:N

            dt = Time_s(k) - Time_s(k - 1);

            Phi = exp(-dt / Tau);

            InnovationScaleHorizontal = ...
                SigmaHorizontal * sqrt(1 - Phi^2);

            InnovationScaleVertical = ...
                SigmaVertical * sqrt(1 - Phi^2);

            Innovation = [ ...
                InnovationScaleHorizontal * randn(Stream, 1);
                InnovationScaleHorizontal * randn(Stream, 1);
                InnovationScaleVertical   * randn(Stream, 1)];

            Bias_m(k, :) = ...
                Phi .* Bias_m(k - 1, :) + Innovation.';

        end

    end

    %% Assemble output

    Bias = struct();

    Bias.Time_s = Time_s;

    Bias.SampleCount = N;

    Bias.PositionBias_m = Bias_m;

end