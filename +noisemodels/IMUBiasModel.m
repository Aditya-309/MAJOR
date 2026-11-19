function Bias = IMUBiasModel(Time_s, Config)
%IMUBIASMODEL Generate IMU turn-on and in-run stochastic bias.
%
%   Bias = noisemodels.IMUBiasModel(Time_s, Config)
%
%   Generates the two approved IMU bias components:
%
%       1. Constant per-flight turn-on bias
%       2. First-order Gauss-Markov in-run bias
%
%   Accelerometer:
%       Turn-on bias sigma = Config.IMU.AccelTurnOnBiasSigma_mps2
%       In-run bias sigma  = Config.IMU.AccelInRunBiasSigma_mps2
%       Correlation time   = Config.IMU.AccelInRunBiasCorrelationTime_s
%
%   Gyroscope:
%       Turn-on bias sigma = Config.IMU.GyroTurnOnBiasSigma_radps
%       In-run bias sigma  = Config.IMU.GyroInRunBiasSigma_radps
%       Correlation time   = Config.IMU.GyroInRunBiasCorrelationTime_s
%
%   The turn-on bias is drawn once and remains constant for the complete
%   supplied flight timeline.
%
%   The in-run bias is a stationary first-order Gauss-Markov process:
%
%       b(k) = phi*b(k-1) + q(k)
%
%       phi = exp(-dt/tau)
%
%       var(q) = sigma^2 * (1 - phi^2)
%
%   Output fields:
%
%       Time_s
%       SampleCount
%       AccelerometerTurnOnBias_mps2
%       AccelerometerInRunBias_mps2
%       AccelerometerTotalBias_mps2
%       GyroscopeTurnOnBias_radps
%       GyroscopeInRunBias_radps
%       GyroscopeTotalBias_radps
%
%   Columns correspond to:
%
%       [X Y Z]
%
%   This function:
%       - uses a local reproducible random stream
%       - does not modify MATLAB's global RNG state
%       - supports irregular sampling intervals
%       - keeps turn-on and in-run bias distinguishable
%
%   This function does NOT:
%       - generate measurement white noise
%       - generate scale-factor errors
%       - apply corruption severity
%       - modify sensor telemetry
%       - implement outages or faults

    %% Validate input count

    if nargin ~= 2
        error( ...
            'ASRTE:IMUBiasModel:InvalidInputCount', ...
            'IMUBiasModel requires Time_s and Config.');
    end

    %% Validate time

    if ~(isnumeric(Time_s) && isreal(Time_s) && ...
            isvector(Time_s) && ~isempty(Time_s))

        error( ...
            'ASRTE:IMUBiasModel:InvalidTime', ...
            'Time_s must be a nonempty real numeric vector.');

    end

    Time_s = Time_s(:);

    if any(~isfinite(Time_s))
        error( ...
            'ASRTE:IMUBiasModel:NonFiniteTime', ...
            'Time_s must contain only finite values.');
    end

    if numel(Time_s) > 1 && any(diff(Time_s) <= 0)
        error( ...
            'ASRTE:IMUBiasModel:NonMonotonicTime', ...
            'Time_s must be strictly increasing.');
    end

    %% Validate configuration

    if ~isstruct(Config)
        error( ...
            'ASRTE:IMUBiasModel:InvalidConfig', ...
            'Config must be a structure.');
    end

    if ~isfield(Config, 'RandomSeed')
        error( ...
            'ASRTE:IMUBiasModel:MissingConfigField', ...
            'Config is missing RandomSeed.');
    end

    if ~isfield(Config, 'IMU')
        error( ...
            'ASRTE:IMUBiasModel:MissingConfigField', ...
            'Config is missing IMU configuration.');
    end

    RequiredFields = { ...
        'AccelTurnOnBiasSigma_mps2', ...
        'AccelInRunBiasSigma_mps2', ...
        'AccelInRunBiasCorrelationTime_s', ...
        'GyroTurnOnBiasSigma_radps', ...
        'GyroInRunBiasSigma_radps', ...
        'GyroInRunBiasCorrelationTime_s'};

    for k = 1:numel(RequiredFields)

        if ~isfield(Config.IMU, RequiredFields{k})

            error( ...
                'ASRTE:IMUBiasModel:MissingIMUField', ...
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
            'ASRTE:IMUBiasModel:InvalidRandomSeed', ...
            'Config.RandomSeed must be a nonnegative integer scalar.');

    end

    %% Read parameters

    AccelTurnOnSigma = ...
        Config.IMU.AccelTurnOnBiasSigma_mps2;

    AccelInRunSigma = ...
        Config.IMU.AccelInRunBiasSigma_mps2;

    AccelTau = ...
        Config.IMU.AccelInRunBiasCorrelationTime_s;

    GyroTurnOnSigma = ...
        Config.IMU.GyroTurnOnBiasSigma_radps;

    GyroInRunSigma = ...
        Config.IMU.GyroInRunBiasSigma_radps;

    GyroTau = ...
        Config.IMU.GyroInRunBiasCorrelationTime_s;

    %% Validate parameters

SigmaValues = [ ...
    AccelTurnOnSigma, ...
    AccelInRunSigma, ...
    GyroTurnOnSigma, ...
    GyroInRunSigma];

if ~isnumeric(SigmaValues) || ...
        ~isreal(SigmaValues) || ...
        any(~isfinite(SigmaValues)) || ...
        any(SigmaValues < 0)

    error( ...
        'ASRTE:IMUBiasModel:InvalidBiasSigma', ...
        'IMU bias standard deviations must be finite, real, scalar, and nonnegative.');

end

TauValues = [AccelTau, GyroTau];

if ~isnumeric(TauValues) || ...
        ~isreal(TauValues) || ...
        any(~isfinite(TauValues)) || ...
        any(TauValues <= 0)

    error( ...
        'ASRTE:IMUBiasModel:InvalidCorrelationTime', ...
        'IMU bias correlation times must be finite, real, scalar, and positive.');

end

    %% Local reproducible random stream

    Stream = RandStream( ...
        'mt19937ar', ...
        'Seed', double(Seed));

    N = numel(Time_s);

    %% Generate constant turn-on biases

    AccelTurnOnBias = ...
        AccelTurnOnSigma .* randn(Stream, 1, 3);

    GyroTurnOnBias = ...
        GyroTurnOnSigma .* randn(Stream, 1, 3);

    %% Allocate in-run bias

    AccelInRunBias = zeros(N, 3);
    GyroInRunBias = zeros(N, 3);

    %% Generate Gauss-Markov in-run bias

    if N > 1

        for k = 2:N

            dt = Time_s(k) - Time_s(k - 1);

            %% Accelerometer

            PhiAccel = exp(-dt / AccelTau);

            AccelInnovationSigma = ...
                AccelInRunSigma * sqrt(1 - PhiAccel^2);

            AccelInnovation = ...
                AccelInnovationSigma .* randn(Stream, 1, 3);

            AccelInRunBias(k, :) = ...
                PhiAccel .* AccelInRunBias(k - 1, :) + ...
                AccelInnovation;

            %% Gyroscope

            PhiGyro = exp(-dt / GyroTau);

            GyroInnovationSigma = ...
                GyroInRunSigma * sqrt(1 - PhiGyro^2);

            GyroInnovation = ...
                GyroInnovationSigma .* randn(Stream, 1, 3);

            GyroInRunBias(k, :) = ...
                PhiGyro .* GyroInRunBias(k - 1, :) + ...
                GyroInnovation;

        end

    end

    %% Expand constant turn-on biases over timeline

    AccelTurnOnBiasTimeline = ...
        repmat(AccelTurnOnBias, N, 1);

    GyroTurnOnBiasTimeline = ...
        repmat(GyroTurnOnBias, N, 1);

    %% Total bias

    AccelTotalBias = ...
        AccelTurnOnBiasTimeline + AccelInRunBias;

    GyroTotalBias = ...
        GyroTurnOnBiasTimeline + GyroInRunBias;

    %% Assemble output

    Bias = struct();

    Bias.Time_s = Time_s;

    Bias.SampleCount = N;

    Bias.AccelerometerTurnOnBias_mps2 = ...
        AccelTurnOnBiasTimeline;

    Bias.AccelerometerInRunBias_mps2 = ...
        AccelInRunBias;

    Bias.AccelerometerTotalBias_mps2 = ...
        AccelTotalBias;

    Bias.GyroscopeTurnOnBias_radps = ...
        GyroTurnOnBiasTimeline;

    Bias.GyroscopeInRunBias_radps = ...
        GyroInRunBias;

    Bias.GyroscopeTotalBias_radps = ...
        GyroTotalBias;

end