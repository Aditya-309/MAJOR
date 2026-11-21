function Config = EstimationConfig(varargin)
%ESTIMATIONCONFIG Create the Block 10 state-estimation configuration.
%
%   Config = ESTIMATIONCONFIG() creates the default Block 10 estimation
%   configuration.
%
%   Config = ESTIMATIONCONFIG(Name,Value,...) allows the approved
%   configuration items to be overridden. Unknown names are rejected.
%
%   Every noise parameter originates from the frozen Block 5 sensor-error
%   configuration (+noisemodels/SensorNoiseConfig.m) and is recorded with
%   its source in Config.NoiseProvenance. No parameter is invented; a
%   value that could not be established is exposed as an explicitly
%   unresolved requirement rather than hidden behind an arbitrary default.
%
%   Sections
%   --------
%   Config.State
%       .Model            - 'ZYX15' (approved 15-state representation)
%       .PitchWarning_deg - Euler pitch singularity warning threshold
%       .PitchHardStop_deg- hard-stop threshold; at or beyond it valid
%                           propagation stops and affected estimates are
%                           marked invalid (T(phi,theta) is unbounded at
%                           |pitch| = 90 deg; the thresholds are set with
%                           a documented margin below the singularity:
%                           warning at 85 deg, stop at 89 deg)
%
%   Config.Noise
%       .GNSS
%           .HorizontalSigma_m        - 0.85   (Block 5 GNSS.HorizontalNoiseSigma_m)
%           .VerticalSigma_m          - 1.80   (Block 5 GNSS.VerticalNoiseSigma_m)
%           .VelocitySigma_mps        - 0.03   (Block 5 GNSS.VelocityNoiseSigma_mps)
%           .BiasSigmaHorizontal_m    - 0.30   (Block 5 GNSS.BiasSigmaHorizontal_m)
%           .BiasSigmaVertical_m      - 0.45   (Block 5 GNSS.BiasSigmaVertical_m)
%           .BiasCorrelationTime_s    - 60     (Block 5 GNSS.BiasCorrelationTime_s)
%           .IncludeBiasInR           - true
%               The 15-state model carries no GNSS bias states, so the
%               slowly varying GNSS bias (Gauss-Markov, tau 60 s) is
%               folded conservatively into R as added steady-state
%               variance: R_pos = Sigma_noise^2 + Sigma_bias^2 per axis.
%       .IMU
%           .AccelVRW_mps2SqrtHz      - 0.06/sqrt(3600)  (Block 5 IMU.AccelVRW_mps2SqrtHz)
%           .GyroARW_radpsSqrtHz      - deg2rad(0.06)/60  (Block 5 IMU.GyroARW_radpsSqrtHz)
%           .AccelInRunBiasSigma_mps2 - 0.075e-3*9.80665 (Block 5 IMU.AccelInRunBiasSigma_mps2)
%           .GyroInRunBiasSigma_radps - deg2rad(0.45)/3600 (Block 5 IMU.GyroInRunBiasSigma_radps)
%           .InRunBiasCorrelationTime_s - 100   (Block 5 IMU.*InRunBiasCorrelationTime_s)
%           .AccelTurnOnBiasSigma_mps2- 3.0e-3*9.80665  (Block 5 IMU.AccelTurnOnBiasSigma_mps2)
%           .GyroTurnOnBiasSigma_radps- deg2rad(20)/3600 (Block 5 IMU.GyroTurnOnBiasSigma_radps)
%           The accelerometer and gyroscope bias states are modelled as
%           random walks. The diffusion coefficients are derived from the
%           Block 5 first-order Gauss-Markov in-run bias model by matching
%           the initial covariance decay:
%               sigma_RW = sigma_inrun * sqrt(2 / tau).
%       .Magnetometer
%           .Sigma_T                  - 0.12e-6 (Block 5 Magnetometer.NoiseSigma_uT in T)
%
%   Config.Magnetometer
%       .EnableUpdates    - true (attitude measurement updates)
%       .ReferenceModel   - 'WMM' (Aerospace Toolbox wrldmagm)
%       .ModelYear        - 2024
%   The reference model, units and conventions match the frozen simulator
%   (+sensormodels/GenerateIdealMagnetometer.m uses wrldmagm with model
%   epoch 2024 and B_body = Cbn' * B_NED). The simulated magnetometer has
%   no calibration or bias terms (Block 5 MagnetometerNoiseModel is
%   Gaussian only). Set EnableUpdates=false to keep magnetometer
%   measurements diagnostic-only.
%
%   Config.MeasurementPolicy
%       .RequiredFlagsTrue  - {'Available','RowValid','MeasurementValid'}
%       .ExcludeFlagNames   - {'StartupTransient'} (default: the Block 9
%                            startup-transient rows of this corpus carry
%                            physically spurious samples (t=0 accel spike
%                            ~650 m/s^2); they are excluded from
%                            propagation and every exclusion is recorded,
%                            never silent. Additional Block 9 per-row
%                            flag names may be listed (e.g.
%                            {'StatisticalOutlier'}); validity-flag
%                            handling is always applied on top.)
%       .Gate
%           .Enabled        - false (innovation gate is a statistical
%                             design parameter; the default policy uses
%                             Block 9 validity only)
%           .Probability    - 0.999 (chi-square gate probability when
%                             enabled; shared by both filters)
%
%   Config.Initialization
%       .OriginPolicy     - 'FirstEligibleGNSSFix' (local NED anchor)
%       .AttitudeSource   - 'AccelerometerMagnetometer' (default) or
%                           'Prior'
%       .AlignmentWindow  - 'Forward' (default; alignment window
%                           [t_init, t_init + Window_s], classic
%                           alignment; the initial state is a documented
%                           alignment product) or 'Trailing' (strictly
%                           causal window [t_init - Window_s, t_init])
%       .Window_s         - 1.0 (low-dynamic verification and leveling
%                           window at the start of the run)
%       .PriorAttitude    - struct(roll,pitch,yaw in rad and
%                           sigma_rad [roll pitch yaw], Provenance);
%                           used only when AttitudeSource='Prior'
%   Leveling tolerances are derived from the Block 5 noise parameters
%   (5 sigma of turn-on bias plus discrete white noise over the measured
%   sample interval) inside InitializeState; they are not hardcoded.
%   Bias priors are zero-mean; their covariance comes from the Block 5
%   turn-on bias sigmas. The simulator's realized bias is never read.
%
%   Config.Smoothing
%       .FullFlight       - true (MaxNumSmoothingSteps covers every
%                           recorded forward step of the selected flight)
%       .MemoryLimit_MB   - 4096 (resource preflight limit; exceeding it
%                           is reported as an explicit limitation and no
%                           shorter window is silently substituted)
%
%   Config.Integrity
%       .Weights - struct over {'Consistency','CovarianceValidity',
%                  'SensorSupport','InnovationHealth'}; default 0.25 each.
%                  Rationale: the indicator is a transparent engineering
%                  composite; with no validated basis for unequal
%                  weighting, equal weights are used and declared. The
%                  indicator exposes its components and is not a
%                  probability or certified safety measure.
%
%   Config.Diagnostics
%       .MismatchWindow_s       - 10 (persistence window for residual
%                                 pattern detection; documented as a
%                                 engineering window covering >= 100
%                                 GNSS updates at the 10 Hz code rate)
%       .DisagreementSigmaGate  - 3 (EKF/UKF disagreement is reported
%                                 when the state difference exceeds this
%                                 many combined standard deviations;
%                                 documented statistical scale)
%       .SmoothingRevisionSigma - 3 (as above, for retrospective
%                                 revisions)
%
%   Config.Evaluation
%       .EnableGroundTruthEvaluation - true (runs strictly AFTER the
%                                 forward and smoothed reconstruction has
%                                 completed; ground truth is never an
%                                 estimator input)
%       .CoverageSigmas       - [1 2 3]
%
%   Config.Output
%       .EstimationRoot     - '' (empty resolves to production/Estimation;
%                             tests pass an external directory here)
%       .WriteMat, .WriteReportJson, .WriteReviewCsv - true
%
%   Config.ImplementationVersion - '1.0' (recorded in outputs)
%
%   Approved Name-Value parameters:
%       'PitchWarning_deg', 'PitchHardStop_deg', 'MagnetometerUpdates',
%       'InnovationGate', 'InnovationGateProbability',
%       'ExcludeFlagNames', 'AttitudeSource', 'AlignmentWindow',
%       'InitWindow_s',
%       'FullFlightSmoothing', 'SmoothingMemoryLimit_MB',
%       'MismatchWindow_s', 'DisagreementSigmaGate',
%       'SmoothingRevisionSigma', 'EnableGroundTruthEvaluation',
%       'EstimationRoot', 'WriteMat', 'WriteReportJson',
%       'WriteReviewCsv', 'GNSSIncludeBiasInR'
%
%   INTERNAL function. Not part of the public Block 10 API. The public
%   API is EstimationConfig, DiscoverRuns, InspectRun,
%   RunStateReconstruction and GetEstimationReport.
%
%   See also: ValidateEstimationConfig, BuildNoiseModels,
%   RunStateReconstruction.

    %% Default Configuration

    Config = struct();
    Config.Name = 'Block10EstimationConfiguration';
    Config.Version = '1.0';
    Config.ImplementationVersion = '1.0';

    Config.State = struct();
    Config.State.Model = 'ZYX15';
    Config.State.PitchWarning_deg = 85;
    Config.State.PitchHardStop_deg = 89;

    Config.Noise = struct();
    Config.Noise.GNSS = struct( ...
        'HorizontalSigma_m', 0.85, ...
        'VerticalSigma_m', 1.80, ...
        'VelocitySigma_mps', 0.03, ...
        'BiasSigmaHorizontal_m', 0.30, ...
        'BiasSigmaVertical_m', 0.45, ...
        'BiasCorrelationTime_s', 60, ...
        'IncludeBiasInR', true);
    Config.Noise.IMU = struct( ...
        'AccelVRW_mps2SqrtHz', 0.06 / sqrt(3600), ...
        'GyroARW_radpsSqrtHz', deg2rad(0.06) / 60, ...
        'AccelInRunBiasSigma_mps2', 0.075e-3 * 9.80665, ...
        'GyroInRunBiasSigma_radps', deg2rad(0.45) / 3600, ...
        'InRunBiasCorrelationTime_s', 100, ...
        'AccelTurnOnBiasSigma_mps2', 3.0e-3 * 9.80665, ...
        'GyroTurnOnBiasSigma_radps', deg2rad(20) / 3600);
    Config.Noise.Magnetometer = struct( ...
        'Sigma_T', 0.12e-6);

    Config.NoiseProvenance = struct();
    Config.NoiseProvenance.Source = [ ...
        'Block 5 +noisemodels/SensorNoiseConfig.m sensor-error ', ...
        'configuration (values are continuous-time noise coefficients ', ...
        'as documented in +noisemodels/IMUNoiseModel.m)'];
    Config.NoiseProvenance.GNSS = struct( ...
        'HorizontalSigma_m', 'SensorNoiseConfig.GNSS.HorizontalNoiseSigma_m', ...
        'VerticalSigma_m', 'SensorNoiseConfig.GNSS.VerticalNoiseSigma_m', ...
        'VelocitySigma_mps', 'SensorNoiseConfig.GNSS.VelocityNoiseSigma_mps', ...
        'BiasSigmaHorizontal_m', 'SensorNoiseConfig.GNSS.BiasSigmaHorizontal_m', ...
        'BiasSigmaVertical_m', 'SensorNoiseConfig.GNSS.BiasSigmaVertical_m', ...
        'BiasCorrelationTime_s', 'SensorNoiseConfig.GNSS.BiasCorrelationTime_s');
    Config.NoiseProvenance.IMU = struct( ...
        'AccelVRW_mps2SqrtHz', 'SensorNoiseConfig.IMU.AccelVRW_mps2SqrtHz', ...
        'GyroARW_radpsSqrtHz', 'SensorNoiseConfig.IMU.GyroARW_radpsSqrtHz', ...
        'AccelInRunBiasSigma_mps2', 'SensorNoiseConfig.IMU.AccelInRunBiasSigma_mps2', ...
        'GyroInRunBiasSigma_radps', 'SensorNoiseConfig.IMU.GyroInRunBiasSigma_radps', ...
        'InRunBiasCorrelationTime_s', 'SensorNoiseConfig.IMU.*InRunBiasCorrelationTime_s', ...
        'AccelTurnOnBiasSigma_mps2', 'SensorNoiseConfig.IMU.AccelTurnOnBiasSigma_mps2', ...
        'GyroTurnOnBiasSigma_radps', 'SensorNoiseConfig.IMU.GyroTurnOnBiasSigma_radps');
    Config.NoiseProvenance.Magnetometer = struct( ...
        'Sigma_T', 'SensorNoiseConfig.Magnetometer.NoiseSigma_uT (converted uT -> T)');

    Config.Magnetometer = struct();
    Config.Magnetometer.EnableUpdates = true;
    Config.Magnetometer.ReferenceModel = 'WMM';
    Config.Magnetometer.ModelYear = 2024;

    Config.MeasurementPolicy = struct();
    Config.MeasurementPolicy.RequiredFlagsTrue = ...
        {'Available', 'RowValid', 'MeasurementValid'};
    Config.MeasurementPolicy.ExcludeFlagNames = {'StartupTransient'};
    Config.MeasurementPolicy.Gate = struct( ...
        'Enabled', false, ...
        'Probability', 0.999);
    % IMU held-input policy (reviewer finding F1): the piecewise-constant
    % propagation input is bounded in age. Defaults derived from the
    % nominal IMU rate of the project data streams (100 Hz):
    %   MaxDegraded_s = 0.5  -> 50 consecutive missing IMU samples;
    %       propagation continues on the held input but estimates are
    %       flagged Degraded.
    %   MaxInvalid_s  = 2.0  -> 200 consecutive missing IMU samples; the
    %       held input no longer represents the vehicle, propagation
    %       stops, the state is carried unchanged and estimates are
    %       marked invalid (same policy as the pitch hard stop).
    Config.MeasurementPolicy.IMUHold = struct( ...
        'MaxDegraded_s', 0.5, ...
        'MaxInvalid_s', 2.0, ...
        'NominalRate_Hz', 100);

    Config.Initialization = struct();
    Config.Initialization.OriginPolicy = 'FirstEligibleGNSSFix';
    Config.Initialization.AttitudeSource = 'AccelerometerMagnetometer';
    Config.Initialization.AlignmentWindow = 'Forward';
    Config.Initialization.Window_s = 1.0;
    % Minimum samples for a stability statistic to count as demonstrated
    % (reviewer finding F8): one observation cannot demonstrate stability,
    % and two make every median-based deviation statistic degenerate
    % (median equals one of the samples, deviation ignores one direction).
    % Three samples make the median and the max-deviation-from-median
    % statistics non-degenerate. Applied uniformly to the accelerometer
    % direction, gyroscope rate-variation and magnetometer direction
    % criteria and to the magnetometer yaw decision.
    Config.Initialization.MinStabilitySamples = 3;
    Config.Initialization.PriorAttitude = struct( ...
        'roll_rad', NaN, 'pitch_rad', NaN, 'yaw_rad', NaN, ...
        'sigma_rad', [NaN, NaN, NaN], ...
        'Provenance', '');

    Config.Smoothing = struct();
    Config.Smoothing.FullFlight = true;
    Config.Smoothing.MemoryLimit_MB = 4096;

    Config.Integrity = struct();
    Config.Integrity.Weights = struct( ...
        'Consistency', 0.25, ...
        'CovarianceValidity', 0.25, ...
        'SensorSupport', 0.25, ...
        'InnovationHealth', 0.25);
    Config.Integrity.WeightRationale = [ ...
        'Equal weights: the indicator is a transparent engineering ', ...
        'composite and no validated basis exists for unequal weighting ', ...
        'in this project. The indicator is not a probability and not a ', ...
        'certified safety measure.'];

    Config.Diagnostics = struct();
    Config.Diagnostics.MismatchWindow_s = 10;
    Config.Diagnostics.DisagreementSigmaGate = 3;
    Config.Diagnostics.SmoothingRevisionSigma = 3;

    Config.Evaluation = struct();
    Config.Evaluation.EnableGroundTruthEvaluation = true;
    Config.Evaluation.CoverageSigmas = [1, 2, 3];

    Config.Output = struct();
    Config.Output.EstimationRoot = '';
    Config.Output.WriteMat = true;
    Config.Output.WriteReportJson = true;
    Config.Output.WriteReviewCsv = true;

    %% Apply Optional Overrides

    if mod(nargin, 2) ~= 0

        error( ...
            'Estimation:EstimationConfig:InvalidNameValueArguments', ...
            'Name-value arguments must be supplied in pairs.');

    end

    for k = 1:2:nargin

        Name = varargin{k};
        Value = varargin{k + 1};

        if ~(ischar(Name) || (isstring(Name) && isscalar(Name)))

            error( ...
                'Estimation:EstimationConfig:InvalidParameterName', ...
                ['Parameter names must be character vectors or ', ...
                 'scalar strings.']);

        end

        Name = char(Name);

        switch lower(Name)

            case 'pitchwarning_deg'
                Config.State.PitchWarning_deg = Value;

            case 'pitchhardstop_deg'
                Config.State.PitchHardStop_deg = Value;

            case 'magnetometerupdates'
                Config.Magnetometer.EnableUpdates = Value;

            case 'gnssincludebiasinr'
                Config.Noise.GNSS.IncludeBiasInR = Value;

            case 'innovationgate'
                Config.MeasurementPolicy.Gate.Enabled = Value;

            case 'innovationgateprobability'
                Config.MeasurementPolicy.Gate.Probability = Value;

            case 'excludeflagnames'
                Config.MeasurementPolicy.ExcludeFlagNames = Value;

            case 'attitudesource'
                Config.Initialization.AttitudeSource = Value;

            case 'alignmentwindow'
                Config.Initialization.AlignmentWindow = Value;

            case 'initwindow_s'
                Config.Initialization.Window_s = Value;

            case 'fullflightsmoothing'
                Config.Smoothing.FullFlight = Value;

            case 'smoothingmemorylimit_mb'
                Config.Smoothing.MemoryLimit_MB = Value;

            case 'mismatchwindow_s'
                Config.Diagnostics.MismatchWindow_s = Value;

            case 'disagreementsigmagate'
                Config.Diagnostics.DisagreementSigmaGate = Value;

            case 'smoothingrevisionsigma'
                Config.Diagnostics.SmoothingRevisionSigma = Value;

            case 'enablegroundtruthevaluation'
                Config.Evaluation.EnableGroundTruthEvaluation = Value;

            case 'estimationroot'
                Config.Output.EstimationRoot = Value;

            case 'writemat'
                Config.Output.WriteMat = Value;

            case 'writereportjson'
                Config.Output.WriteReportJson = Value;

            case 'writereviewcsv'
                Config.Output.WriteReviewCsv = Value;

            otherwise

                error( ...
                    'Estimation:EstimationConfig:UnknownParameter', ...
                    'Unknown configuration parameter "%s".', ...
                    Name);

        end

    end

end
