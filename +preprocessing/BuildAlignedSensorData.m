function Aligned = BuildAlignedSensorData(Config, Streams)
%BUILDALIGNEDSENSORDATA Optional causal ZOH alignment on a reference timeline.
%
%   Aligned = BUILDALIGNEDSENSORDATA(Config, Streams) builds the optional
%   aligned representation of the processed sensor streams. Streams is the
%   struct of Phase-4-processed streams (fields IMU, GNSS, AirData,
%   Magnetometer as available).
%
%   When Config.Alignment.Enabled is false (default), no aligned samples
%   are generated: Aligned.Enabled is false, Aligned.Status is
%   'Disabled', and Aligned.Streams is empty. The native-rate streams are
%   never modified by this function.
%
%   When enabled:
%       - The reference timeline is Config.Alignment.ReferenceStream
%         (default 'IMU'), restricted to its estimator-ready rows
%         (RowValid true).
%       - For each other stream, each reference sample receives the LAST
%         source sample with Time_s <= reference time (causal zero-order
%         hold). Future samples are never used and nothing is
%         extrapolated: a reference time beyond the last source sample of
%         its segment is marked WithinCoverage false.
%       - Candidates must belong to the SAME Phase-4 segment as the
%         reference sample; samples are never bridged across segments.
%       - Rows excluded by Phase 4 (later duplicates, non-finite times)
%         are never used as sources.
%       - The configured maximum sample age is enforced per stream
%         (Config.Alignment.MaxSampleAge_s.<Stream>; an absent entry uses
%         the stream's measured NominalPeriod_s). Violations are marked
%         AgeOk false and AlignedValid false.
%       - Availability and measurement validity are propagated from the
%         held source row; AlignedValid is true only when the source row
%         exists, is within coverage, is within the age limit, and is
%         available and measurement-valid.
%       - SourceRowIdx, SourceTime_s and SampleAge_s identify exactly
%         which original sample was held.
%
%   Output fields:
%       Aligned.Enabled, .Status ('Disabled', 'Generated', 'Skipped'),
%       .ReferenceStream, .Time_s, .SegmentID, .ReferenceSourceRowIdx,
%       .MaxSampleAge_s.<Stream> = struct('Seconds', ..., 'Source', ...)
%       .Streams.<Stream> with fields:
%           Time_s, SegmentID, ReferenceSourceRowIdx,
%           SourceRowIdx (0 = none), SourceTime_s, SampleAge_s,
%           AgeOk, WithinCoverage, SourceAvailable,
%           SourceMeasurementValid, AlignedValid (all Nx1),
%           canonical measurement fields (NaN when no source sample)
%       .SkippedStreams, .Summary.<Stream> counts
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: PreprocessRun, BuildPreprocessingReport, ProcessSensorTimestamps.

    %% Validate Inputs

    preprocessing.ValidatePreprocessingConfig(Config);

    if ~isstruct(Streams) || ~isscalar(Streams)

        error( ...
            'Preprocessing:BuildAlignedSensorData:InvalidStreams', ...
            'Streams must be a scalar structure of processed streams.');

    end

    Contracts = preprocessing.SensorDataContracts();

    %% Disabled Result

    Aligned = struct();
    Aligned.Enabled = Config.Alignment.Enabled;
    Aligned.Status = 'Disabled';
    Aligned.ReferenceStream = '';
    Aligned.Time_s = zeros(0, 1);
    Aligned.SegmentID = zeros(0, 1);
    Aligned.ReferenceSourceRowIdx = zeros(0, 1);
    Aligned.MaxSampleAge_s = struct();
    Aligned.Streams = struct();
    Aligned.SkippedStreams = {};
    Aligned.Summary = struct();

    if ~Config.Alignment.Enabled

        Aligned.Summary.Note = ...
            'Alignment disabled by configuration; no aligned samples generated.';
        return;

    end

    %% Reference Timeline

    ReferenceName = char(Config.Alignment.ReferenceStream);
    Aligned.ReferenceStream = ReferenceName;

    if ~isfield(Streams, ReferenceName) || ...
            ~isstruct(Streams.(ReferenceName)) || ...
            ~isfield(Streams.(ReferenceName), 'RowValid') || ...
            ~strcmp(Streams.(ReferenceName).Status, 'Loaded')

        Aligned.Status = 'Skipped';
        Aligned.Summary.SkipReason = 'ReferenceStreamUnavailable';
        return;

    end

    Ref = Streams.(ReferenceName);
    RefRows = find(Ref.RowValid);

    Aligned.Time_s = Ref.Time_s(RefRows);
    Aligned.SegmentID = Ref.SegmentID(RefRows);
    Aligned.ReferenceSourceRowIdx = Ref.SourceRowIdx(RefRows);
    Aligned.Status = 'Generated';

    %% Align Each Stream

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if ~isfield(Streams, StreamName) || ...
                ~isstruct(Streams.(StreamName)) || ...
                ~isfield(Streams.(StreamName), 'RowValid') || ...
                ~strcmp(Streams.(StreamName).Status, 'Loaded')

            Aligned.SkippedStreams{end + 1} = StreamName;
            continue;

        end

        Stream = Streams.(StreamName);

        if isfield(Config.Alignment.MaxSampleAge_s, StreamName)

            MaxAge_s = Config.Alignment.MaxSampleAge_s.(StreamName);
            AgeSource = 'Configured';

        else

            MaxAge_s = Stream.NominalPeriod_s;
            AgeSource = 'NominalPeriod';

        end

        Aligned.MaxSampleAge_s.(StreamName) = struct( ...
            'Seconds', MaxAge_s, ...
            'Source', AgeSource);

        [AlignedStream, Counts] = alignOneStream( ...
            Stream, Contracts.(StreamName).Channels, ...
            Aligned.Time_s, Aligned.SegmentID, ...
            Aligned.ReferenceSourceRowIdx, MaxAge_s);

        Aligned.Streams.(StreamName) = AlignedStream;
        Aligned.Summary.(StreamName) = Counts;

    end

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function [AlignedStream, Counts] = alignOneStream( ...
    Stream, Channels, RefTime_s, RefSegmentID, ...
    RefSourceRowIdx, MaxAge_s)
%ALIGNONESTREAM Causal zero-order hold of one stream onto the reference.

    SampleCount = numel(RefTime_s);

    Template = struct( ...
        'Time_s', RefTime_s, ...
        'SegmentID', RefSegmentID, ...
        'ReferenceSourceRowIdx', RefSourceRowIdx, ...
        'SourceRowIdx', zeros(SampleCount, 1), ...
        'SourceTime_s', NaN(SampleCount, 1), ...
        'SampleAge_s', NaN(SampleCount, 1), ...
        'AgeOk', false(SampleCount, 1), ...
        'WithinCoverage', false(SampleCount, 1), ...
        'SourceAvailable', false(SampleCount, 1), ...
        'SourceMeasurementValid', false(SampleCount, 1), ...
        'AlignedValid', false(SampleCount, 1));
    AlignedStream = Template;

    for ChannelIndex = 1:numel(Channels)

        FieldName = Channels(ChannelIndex).CanonicalField;

        if strcmp(FieldName, 'Time_s') || strcmp(FieldName, 'Available')

            continue;

        end

        AlignedStream.(FieldName) = NaN(SampleCount, 1);

    end

    SourceRowIdxAll = zeros(SampleCount, 1);
    SourceTimeAll = NaN(SampleCount, 1);
    AgeAll = NaN(SampleCount, 1);
    AgeOkAll = false(SampleCount, 1);
    WithinAll = false(SampleCount, 1);
    SrcAvailAll = false(SampleCount, 1);
    SrcValidAll = false(SampleCount, 1);
    ValidAll = false(SampleCount, 1);
    ValueStorage = struct();

    for ChannelIndex = 1:numel(Channels)

        FieldName = Channels(ChannelIndex).CanonicalField;

        if ~strcmp(FieldName, 'Time_s') && ~strcmp(FieldName, 'Available')

            ValueStorage.(FieldName) = NaN(SampleCount, 1);

        end

    end

    SegmentIDs = unique(RefSegmentID);

    for SegmentIndex = 1:numel(SegmentIDs)

        Segment = SegmentIDs(SegmentIndex);

        if Segment <= 0

            continue;

        end

        SourceRows = find(Stream.RowValid & Stream.SegmentID == Segment);
        RefRows = find(RefSegmentID == Segment);

        if isempty(SourceRows) || isempty(RefRows)

            continue;

        end

        SourceTimes = Stream.Time_s(SourceRows);
        LastSourceTime = SourceTimes(end);
        SourcePointer = 0;

        for RefIndex = RefRows.'

            while SourcePointer < numel(SourceRows) && ...
                    SourceTimes(SourcePointer + 1) <= RefTime_s(RefIndex)

                SourcePointer = SourcePointer + 1;

            end

            if SourcePointer == 0

                continue;

            end

            SourceRow = SourceRows(SourcePointer);
            Age_s = RefTime_s(RefIndex) - SourceTimes(SourcePointer);

            % F-03: provenance is mapped through the stream's own
            % SourceRowIdx field (the original source-file row). The
            % Phase-4 entry point enforces SourceRowIdx == (1:N)'
            % (ProcessSensorTimestamps RowOrderViolation), so this equals
            % the array index inside the sanctioned pipeline; the mapping
            % keeps the contract explicit for any upstream state.
            SourceRowIdxAll(RefIndex) = Stream.SourceRowIdx(SourceRow);
            SourceTimeAll(RefIndex) = SourceTimes(SourcePointer);
            AgeAll(RefIndex) = Age_s;
            AgeOkAll(RefIndex) = Age_s <= MaxAge_s;
            WithinAll(RefIndex) = RefTime_s(RefIndex) <= LastSourceTime;
            SrcAvailAll(RefIndex) = Stream.Available(SourceRow);
            SrcValidAll(RefIndex) = Stream.MeasurementValid(SourceRow);
            ValidAll(RefIndex) = AgeOkAll(RefIndex) && ...
                WithinAll(RefIndex) && ...
                SrcAvailAll(RefIndex) && SrcValidAll(RefIndex);

            FieldNames = fieldnames(ValueStorage);

            for FieldIndex = 1:numel(FieldNames)

                Values = Stream.(FieldNames{FieldIndex});
                ValueStorage.(FieldNames{FieldIndex})(RefIndex) = ...
                    Values(SourceRow);

            end

        end

    end

    AlignedStream.SourceRowIdx = SourceRowIdxAll;
    AlignedStream.SourceTime_s = SourceTimeAll;
    AlignedStream.SampleAge_s = AgeAll;
    AlignedStream.AgeOk = AgeOkAll;
    AlignedStream.WithinCoverage = WithinAll;
    AlignedStream.SourceAvailable = SrcAvailAll;
    AlignedStream.SourceMeasurementValid = SrcValidAll;
    AlignedStream.AlignedValid = ValidAll;

    FieldNames = fieldnames(ValueStorage);

    for FieldIndex = 1:numel(FieldNames)

        AlignedStream.(FieldNames{FieldIndex}) = ...
            ValueStorage.(FieldNames{FieldIndex});

    end

    Found = SourceRowIdxAll > 0;

    Counts = struct( ...
        'TotalSamples', SampleCount, ...
        'ValidCount', sum(ValidAll), ...
        'InvalidCount', sum(~ValidAll), ...
        'NoSourceCount', sum(~Found), ...
        'StaleCount', sum(Found & ~AgeOkAll), ...
        'BeyondCoverageCount', sum(Found & ~WithinAll), ...
        'SourceUnavailableCount', sum(Found & ~SrcAvailAll), ...
        'SourceInvalidCount', sum(Found & ~SrcValidAll));

end
