function Stream = DetectSensorOutliers(Config, Stream, StreamName)
%DETECTSENSOROUTLIERS Flag-only physical, statistical and change checks.
%
%   Stream = DETECTSENSOROUTLIERS(Config, Stream, StreamName) applies the
%   configurable outlier checks to one stream after ProcessSensorTimestamps
%   and InspectSensorQuality.
%
%   Checks (all flag-only: original measurements are always retained):
%       PhysicalOutlier   - value outside Config.Quality.Physical.Bounds
%                           (default empty: no physical limits are
%                           configured or invented).
%       StatisticalOutlier - windowed robust check (median and scaled MAD)
%                            using Config.Quality.Statistical.WindowSamples
%                            and .SigmaThreshold. Rolling comparisons are
%                            computed PER SEGMENT and never cross segment
%                           boundaries.
%       SuddenChange      - step between consecutive VALID samples exceeds
%                           Config.Quality.SuddenChange.Thresholds for the
%                           channel (default empty: disabled). Invalid
%                           samples are never used as previous-sample
%                           references.
%       StartupTransient  - rows within
%                           Config.Quality.StartupTransient.WindowSamples
%                           that carry any suspicious finding from the
%                           checks above. Such rows are flagged and fully
%                           retained (never trimmed or corrected).
%
%   Only rows with RowValid, MeasurementValid and finite channel values
%   participate in the rolling comparisons.
%
%   Added output fields:
%       Stream.Flags.PhysicalOutlier, .StatisticalOutlier,
%       .SuddenChange, .StartupTransient (Nx1 logical, any channel)
%       Stream.ChannelFlags.<Finding>.<CanonicalField> (Nx1 logical)
%       Stream.OutlierSummary - per-channel counts per finding
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: ProcessSensorTimestamps, InspectSensorQuality, QualityFlags.

    %% Validate Inputs

    preprocessing.ValidatePreprocessingConfig(Config);

    Required = {'RowValid', 'MeasurementValid', 'SegmentID'};

    if ~isstruct(Stream) || ~isscalar(Stream) || ...
            ~all(isfield(Stream, Required))

        error( ...
            ['Preprocessing:DetectSensorOutliers:', ...
             'MissingProcessingField'], ...
            ['Stream is missing processing fields; run ', ...
             'ProcessSensorTimestamps and InspectSensorQuality first.']);

    end

    Contracts = preprocessing.SensorDataContracts();

    if ~(ischar(StreamName) || (isstring(StreamName) && isscalar(StreamName))) ...
            || ~any(strcmp(char(StreamName), Contracts.Streams))

        error( ...
            'Preprocessing:DetectSensorOutliers:InvalidStreamName', ...
            'StreamName must be a canonical stream name.');

    end

    StreamName = char(StreamName);
    RowCount = numel(Stream.Time_s);
    RowValid = Stream.RowValid;
    MeasurementValid = Stream.MeasurementValid;
    SegmentID = Stream.SegmentID;

    %% Channel Flags

    Findings = { ...
        'PhysicalOutlier', ...
        'StatisticalOutlier', ...
        'SuddenChange', ...
        'StartupTransient'};
    ChannelFlags = struct();

    for FindingIndex = 1:numel(Findings)

        ChannelFlags.(Findings{FindingIndex}) = struct();

    end

    Summary = struct();
    Channels = Contracts.(StreamName).Channels;

    for Index = 1:numel(Channels)

        Channel = Channels(Index);
        FieldName = Channel.CanonicalField;

        if strcmp(FieldName, 'Time_s') || strcmp(FieldName, 'Available')

            continue;

        end

        Values = Stream.(FieldName);
        Eligible = RowValid & MeasurementValid & isfinite(Values);

        PhysicalFlag = physicalCheck( ...
            Config, FieldName, Values, Eligible);
        StatisticalFlag = statisticalCheck( ...
            Config, Stream, Values, Eligible, SegmentID);
        SuddenFlag = suddenChangeCheck( ...
            Config, Stream, FieldName, Values, Eligible, SegmentID);

        Suspicious = PhysicalFlag | StatisticalFlag | SuddenFlag | ...
            ~isfinite(Values);
        TransientFlag = startupTransientCheck( ...
            Config, Stream, Suspicious);

        ChannelFlags.PhysicalOutlier.(FieldName) = PhysicalFlag;
        ChannelFlags.StatisticalOutlier.(FieldName) = StatisticalFlag;
        ChannelFlags.SuddenChange.(FieldName) = SuddenFlag;
        ChannelFlags.StartupTransient.(FieldName) = TransientFlag;

        Summary.(FieldName) = struct( ...
            'PhysicalOutlierCount', sum(PhysicalFlag), ...
            'StatisticalOutlierCount', sum(StatisticalFlag), ...
            'SuddenChangeCount', sum(SuddenFlag), ...
            'StartupTransientCount', sum(TransientFlag));

    end

    %% Row-Level Flags (any channel)

    RowFlags = struct();

    for FindingIndex = 1:numel(Findings)

        RowFlags.(Findings{FindingIndex}) = anyFlag( ...
            ChannelFlags.(Findings{FindingIndex}), RowCount);

    end

    if isfield(Stream, 'Flags')

        Stream.Flags.PhysicalOutlier = RowFlags.PhysicalOutlier;
        Stream.Flags.StatisticalOutlier = RowFlags.StatisticalOutlier;
        Stream.Flags.SuddenChange = RowFlags.SuddenChange;
        Stream.Flags.StartupTransient = RowFlags.StartupTransient;

    else

        Stream.Flags = RowFlags;

    end

    %% Build Output

    Stream.ChannelFlags.PhysicalOutlier = ...
        ChannelFlags.PhysicalOutlier;
    Stream.ChannelFlags.StatisticalOutlier = ...
        ChannelFlags.StatisticalOutlier;
    Stream.ChannelFlags.SuddenChange = ...
        ChannelFlags.SuddenChange;
    Stream.ChannelFlags.StartupTransient = ...
        ChannelFlags.StartupTransient;
    Stream.OutlierSummary = Summary;

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function Flag = physicalCheck(Config, FieldName, Values, Eligible)
%PHYSICALCHECK Configured physical bounds (empty = not configured).

    Flag = false(size(Values));
    Bounds = Config.Quality.Physical.Bounds;

    if ~isfield(Bounds, FieldName)

        return;

    end

    Limit = Bounds.(FieldName);
    Flag = Eligible & (Values < Limit(1) | Values > Limit(2));

end

function Flag = statisticalCheck(Config, Stream, Values, Eligible, SegmentID)
%STATISTICALCHECK Per-segment windowed median/MAD check.

    Flag = false(size(Values));

    if ~Config.Quality.Statistical.Enabled

        return;

    end

    WindowSamples = Config.Quality.Statistical.WindowSamples;
    SigmaThreshold = Config.Quality.Statistical.SigmaThreshold;
    DeviationFloor = Config.Quality.Statistical.DeviationFloor;

    for SegmentIndex = 1:numel(Stream.Segments)

        Rows = find(Eligible & ...
            SegmentID == Stream.Segments(SegmentIndex).SegmentID);

        if numel(Rows) < 2

            continue;

        end

        Sample = Values(Rows);
        Center = movmedian(Sample, WindowSamples);
        Deviation = abs(Sample - Center);
        Sigma = 1.4826 * movmedian(Deviation, WindowSamples);

        Limit = max(SigmaThreshold * Sigma, DeviationFloor);
        Outlying = Deviation > Limit;
        Flag(Rows(Outlying)) = true;

    end

end

function Flag = suddenChangeCheck( ...
    Config, Stream, FieldName, Values, Eligible, SegmentID)
%SUDDENCHANGECHECK Consecutive valid-sample steps within segments.

    Flag = false(size(Values));
    Thresholds = Config.Quality.SuddenChange.Thresholds;

    if ~Config.Quality.SuddenChange.Enabled || ...
            ~isfield(Thresholds, FieldName)

        return;

    end

    Threshold = Thresholds.(FieldName);

    for SegmentIndex = 1:numel(Stream.Segments)

        Rows = find(Eligible & ...
            SegmentID == Stream.Segments(SegmentIndex).SegmentID);

        for Index = 2:numel(Rows)

            Step = abs(Values(Rows(Index)) - Values(Rows(Index - 1)));

            if Step > Threshold

                Flag(Rows(Index)) = true;

            end

        end

    end

end

function Flag = startupTransientCheck(Config, Stream, Suspicious)
%STARTUPTRANSIENTCHECK Flag suspicious values inside the startup window.

    Flag = false(size(Suspicious));

    Settings = Config.Quality.StartupTransient;

    if ~Settings.Enabled || Settings.WindowSamples <= 0

        return;

    end

    InWindow = Stream.SourceRowIdx <= Settings.WindowSamples;
    Flag = InWindow & Suspicious;

end

function RowFlag = anyFlag(ChannelFlagStruct, RowCount)
%ANYFLAG Row-level flag: any channel flagged for the row.

    RowFlag = false(RowCount, 1);
    Names = fieldnames(ChannelFlagStruct);

    for Index = 1:numel(Names)

        RowFlag = RowFlag | ChannelFlagStruct.(Names{Index});

    end

end
