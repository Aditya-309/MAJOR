function Stream = InspectSensorQuality(Config, Stream, StreamName)
%INSPECTSENSORQUALITY Availability, finiteness and per-channel statistics.
%
%   Stream = INSPECTSENSORQUALITY(Config, Stream, StreamName) adds quality
%   inspection to one stream after ProcessSensorTimestamps.
%
%   Checks:
%       - Availability outages (Available = false). Outages are recorded
%         separately from timestamp segmentation: they NEVER split
%         segments and never change RowValid. Findings: 'Unavailable'.
%       - NaN/Inf measurement values per channel. Findings:
%         'NonFiniteMeasurement'; MeasurementValid is set false for rows
%         with any non-finite measurement.
%
%   RowValid (structural), MeasurementValid (data validity) and Available
%   (sensor-reported) remain three distinct fields.
%
%   Suspected outliers are NOT handled here (see DetectSensorOutliers);
%   no measurement value is ever deleted or replaced.
%
%   Added output fields:
%       Stream.MeasurementValid  - Nx1 logical
%       Stream.Flags.Unavailable, .NonFiniteMeasurement (Nx1 logical)
%       Stream.ChannelFlags.NonFiniteMeasurement.<CanonicalField> (Nx1)
%       Stream.Outages           - outage span struct array
%       Stream.QualitySummary    - per-channel statistics and counts
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: ProcessSensorTimestamps, DetectSensorOutliers, QualityFlags.

    %% Validate Inputs

    preprocessing.ValidatePreprocessingConfig(Config);
    requireProcessedFields(Stream, 'InspectSensorQuality');

    Contracts = preprocessing.SensorDataContracts();

    if ~(ischar(StreamName) || (isstring(StreamName) && isscalar(StreamName))) ...
            || ~any(strcmp(char(StreamName), Contracts.Streams))

        error( ...
            'Preprocessing:InspectSensorQuality:InvalidStreamName', ...
            'StreamName must be a canonical stream name.');

    end

    StreamName = char(StreamName);
    RowCount = numel(Stream.Time_s);

    %% Measurement Finiteness

    ChannelFlags = struct();
    ChannelFlags.NonFiniteMeasurement = struct();
    MeasurementValid = true(RowCount, 1);
    Channels = Contracts.(StreamName).Channels;
    Summary = struct();

    for Index = 1:numel(Channels)

        Channel = Channels(Index);
        FieldName = Channel.CanonicalField;

        if strcmp(FieldName, 'Time_s') || strcmp(FieldName, 'Available')

            continue;

        end

        Values = Stream.(FieldName);
        NonFinite = ~isfinite(Values);

        ChannelFlags.NonFiniteMeasurement.(FieldName) = NonFinite;
        MeasurementValid = MeasurementValid & ~NonFinite;

        FiniteValues = Values(~NonFinite);

        if isempty(FiniteValues)

            ChannelSummary = struct( ...
                'FiniteCount', 0, ...
                'NonFiniteCount', sum(NonFinite), ...
                'Min', NaN, ...
                'Max', NaN, ...
                'Mean', NaN, ...
                'Median', NaN);

        else

            ChannelSummary = struct( ...
                'FiniteCount', numel(FiniteValues), ...
                'NonFiniteCount', sum(NonFinite), ...
                'Min', min(FiniteValues), ...
                'Max', max(FiniteValues), ...
                'Mean', mean(FiniteValues), ...
                'Median', median(FiniteValues));

        end

        Summary.(FieldName) = ChannelSummary;

    end

    %% Availability Outages (separate from segmentation)

    Unavailable = ~Stream.Available;
    Outages = outageRuns(Unavailable, Stream.Time_s);

    %% Row-Level Flags

    Flags = struct();
    Flags.Unavailable = Unavailable;
    Flags.NonFiniteMeasurement = ...
        any(struct2array2(ChannelFlags.NonFiniteMeasurement), 2);

    if isfield(Stream, 'Flags')

        Stream.Flags.Unavailable = Flags.Unavailable;
        Stream.Flags.NonFiniteMeasurement = Flags.NonFiniteMeasurement;

    else

        Stream.Flags = Flags;

    end

    %% Build Output

    Stream.MeasurementValid = MeasurementValid;
    Stream.ChannelFlags = ChannelFlags;
    Stream.Outages = Outages;

    QualitySummary = Summary;
    QualitySummary.Availability = struct( ...
        'UnavailableCount', sum(Unavailable), ...
        'OutageCount', numel(Outages));
    QualitySummary.MeasurementValidCount = sum(MeasurementValid);
    QualitySummary.MeasurementInvalidCount = sum(~MeasurementValid);
    Stream.QualitySummary = QualitySummary;

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function requireProcessedFields(Stream, FunctionName)
%REQUIREPROCESSEDFIELDS Timestamp processing must have run first.

    Required = {'RowValid', 'SegmentID', 'Segments'};

    if ~isstruct(Stream) || ~isscalar(Stream) || ...
            ~all(isfield(Stream, Required))

        error( ...
            sprintf('Preprocessing:%s:MissingProcessingField', ...
                FunctionName), ...
            ['Stream is missing timestamp-processing fields; run ', ...
             'ProcessSensorTimestamps first.']);

    end

end

function Outages = outageRuns(Unavailable, Time_s)
%OUTAGERUNS Consecutive unavailability spans (never segment breaks).

    Template = struct( ...
        'FirstRowIdx', 0, ...
        'LastRowIdx', 0, ...
        'SampleCount', 0, ...
        'StartTime_s', NaN, ...
        'EndTime_s', NaN);
    Outages = repmat(Template, 0, 1);

    RowCount = numel(Unavailable);
    Row = 1;

    while Row <= RowCount

        if ~Unavailable(Row)

            Row = Row + 1;
            continue;

        end

        FirstRow = Row;

        while Row <= RowCount && Unavailable(Row)

            Row = Row + 1;

        end

        LastRow = Row - 1;
        Span = Template;
        Span.FirstRowIdx = FirstRow;
        Span.LastRowIdx = LastRow;
        Span.SampleCount = LastRow - FirstRow + 1;
        Span.StartTime_s = Time_s(FirstRow);
        Span.EndTime_s = Time_s(LastRow);
        Outages(end + 1) = Span;

    end

end

function Matrix = struct2array2(FlagStruct)
%STRUCT2ARRAY2 Concatenate per-channel logical flags into a matrix.

    Names = fieldnames(FlagStruct);

    if isempty(Names)

        Matrix = false(0, 0);
        return;

    end

    Matrix = FlagStruct.(Names{1});

    for Index = 2:numel(Names)

        Matrix = [Matrix, FlagStruct.(Names{Index})]; %#ok<AGROW>

    end

end
