function Config = PreprocessingConfig(varargin)
%PREPROCESSINGCONFIG Create the Block 9 preprocessing configuration.
%
%   Config = PREPROCESSINGCONFIG() creates the default Block 9
%   preprocessing configuration.
%
%   Config = PREPROCESSINGCONFIG(Name,Value,...) allows the approved
%   configuration items to be overridden.
%
%   All thresholds are configurable. The defaults below are current code
%   defaults used as documented fallbacks; they are never claimed to be
%   settings recorded for any historical production run. The preprocessing
%   report always records the values used and their provenance.
%
%   Sections
%   --------
%   Config.Source
%       'RealisticSensorTelemetry' (default) or 'IdealSensorTelemetry'
%
%   Config.MissingSensors
%       .Policy          - 'Continue' (default) or 'Strict'
%       .RequiredSensors - canonical stream names (default: all four)
%
%   Config.Timestamps
%       .DuplicatePolicy   - 'KeepFirst' (default; only supported policy)
%       .GapAbsolute_s     - absolute gap threshold (default 1.0 s)
%       .GapRelative       - relative gap threshold (default 1.5)
%       .NominalRateSource - 'Auto' (default), 'Recorded', 'Measured',
%                            'CodeDefault'
%
%   Gap policy: a gap is flagged when EITHER configured threshold is
%   exceeded:
%
%       dt > GapAbsolute_s  OR  dt > GapRelative * NominalPeriod_s
%
%   Setting a threshold to [] disables that individual criterion. At
%   least one criterion must remain configured.
%
%   Nominal rate provenance chain ('Auto'): recorded per-run
%   configuration first, then measured timestamp intervals, then the
%   documented code default (SensorDataContracts.RateFallback_Hz). The
%   chosen source is recorded per stream in the outputs.
%
%   Config.Quality
%       .StartupTransient - .Enabled (true), .WindowSamples (5)
%       .Statistical      - .Enabled (true), .WindowSamples (51),
%                           .SigmaThreshold (4.0), .DeviationFloor (0.0)
%       .SuddenChange     - .Enabled (false), .Thresholds (struct())
%       .Physical         - .Bounds (struct(); canonical field -> [min max])
%
%   DeviationFloor is a numerical tolerance (canonical units) for the
%   statistical check: a sample is flagged only when its deviation exceeds
%   max(SigmaThreshold * Sigma, DeviationFloor). It prevents
%   floating-point-level deviations inside zero-MAD windows from being
%   flagged; 0.0 keeps the strict behavior (any deviation in a zero-MAD
%   window is flagged).
%
%   Outlier checks are flag-only: suspected outliers are never deleted or
%   replaced. Physical bounds default to empty (disabled) because no
%   physical limits are verified; they are supplied via configuration.
%
%   Config.Alignment
%       .Enabled         - false (default; alignment is optional)
%       .ReferenceStream - 'IMU' (default)
%       .MaxSampleAge_s  - struct(); stream name -> seconds; empty entry
%                          means the measured nominal period is used
%
%   Approved Name-Value parameters:
%       'Source', 'MissingSensorPolicy', 'RequiredSensors',
%       'GapAbsolute_s', 'GapRelative', 'NominalRateSource',
%       'StartupTransientEnabled', 'StartupTransientWindowSamples',
%       'StatisticalEnabled', 'StatisticalWindowSamples',
%       'StatisticalSigmaThreshold', 'StatisticalDeviationFloor',
%       'SuddenChangeEnabled', 'AlignmentEnabled', 'ReferenceStream',
%       'MaxSampleAge_s'
%
%   'StatisticalDeviationFloor' sets Config.Quality.Statistical.
%   DeviationFloor: a nonnegative numerical tolerance in the canonical
%   unit of the checked channel; a sample is flagged by the statistical
%   check only when its windowed-median deviation exceeds
%   max(SigmaThreshold * Sigma, DeviationFloor) (see above).
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: ValidatePreprocessingConfig, SensorDataContracts,
%   QualityFlags.

    %% Default Configuration

    Config = struct();
    Config.Name = 'Block9PreprocessingConfiguration';
    Config.Version = '1.0';

    Config.Source = 'RealisticSensorTelemetry';

    Config.MissingSensors = struct();
    Config.MissingSensors.Policy = 'Continue';
    Config.MissingSensors.RequiredSensors = ...
        {'IMU', 'GNSS', 'AirData', 'Magnetometer'};

    Config.Timestamps = struct();
    Config.Timestamps.DuplicatePolicy = 'KeepFirst';
    Config.Timestamps.GapAbsolute_s = 1.0;
    Config.Timestamps.GapRelative = 1.5;
    Config.Timestamps.NominalRateSource = 'Auto';

    Config.Quality = struct();
    Config.Quality.StartupTransient = struct( ...
        'Enabled', true, ...
        'WindowSamples', 5);
    Config.Quality.Statistical = struct( ...
        'Enabled', true, ...
        'WindowSamples', 51, ...
        'SigmaThreshold', 4.0, ...
        'DeviationFloor', 0.0);
    Config.Quality.SuddenChange = struct( ...
        'Enabled', false, ...
        'Thresholds', struct());
    Config.Quality.Physical = struct( ...
        'Bounds', struct());

    Config.Alignment = struct();
    Config.Alignment.Enabled = false;
    Config.Alignment.ReferenceStream = 'IMU';
    Config.Alignment.MaxSampleAge_s = struct();

    %% Apply Approved Optional Overrides

    if mod(nargin, 2) ~= 0

        error( ...
            'Preprocessing:PreprocessingConfig:InvalidNameValueArguments', ...
            'Name-value arguments must be supplied in pairs.');

    end

    for Index = 1:2:nargin

        Name = varargin{Index};
        Value = varargin{Index + 1};

        if ~(ischar(Name) || (isstring(Name) && isscalar(Name)))

            error( ...
                'Preprocessing:PreprocessingConfig:InvalidParameterName', ...
                ['Parameter names must be character vectors or scalar ', ...
                 'strings.']);

        end

        Name = char(Name);

        switch lower(Name)

            case 'source'

                Config.Source = Value;

            case 'missingsensorpolicy'

                Config.MissingSensors.Policy = Value;

            case 'requiredsensors'

                Config.MissingSensors.RequiredSensors = Value;

            case 'gapabsolute_s'

                Config.Timestamps.GapAbsolute_s = Value;

            case 'gaprelative'

                Config.Timestamps.GapRelative = Value;

            case 'nominalratesource'

                Config.Timestamps.NominalRateSource = Value;

            case 'startuptransientenabled'

                Config.Quality.StartupTransient.Enabled = Value;

            case 'startuptransientwindowsamples'

                Config.Quality.StartupTransient.WindowSamples = Value;

            case 'statisticalenabled'

                Config.Quality.Statistical.Enabled = Value;

            case 'statisticalwindowsamples'

                Config.Quality.Statistical.WindowSamples = Value;

            case 'statisticalsigmathreshold'

                Config.Quality.Statistical.SigmaThreshold = Value;

            case 'statisticaldeviationfloor'

                Config.Quality.Statistical.DeviationFloor = Value;

            case 'suddenchangeenabled'

                Config.Quality.SuddenChange.Enabled = Value;

            case 'alignmentenabled'

                Config.Alignment.Enabled = Value;

            case 'referencestream'

                Config.Alignment.ReferenceStream = Value;

            case 'maxsampleage_s'

                Config.Alignment.MaxSampleAge_s = Value;

            otherwise

                error( ...
                    'Preprocessing:PreprocessingConfig:UnknownParameter', ...
                    'Unknown configuration parameter "%s".', ...
                    Name);

        end

    end

    %% Validate The Assembled Configuration

    preprocessing.ValidatePreprocessingConfig(Config);

end
