function Stream = ProcessSensorTimestamps( ...
    Config, ...
    Stream, ...
    StreamName, ...
    RecordedRate_Hz)
%PROCESSSENSORTIMESTAMPS Timestamp validation and segmentation of a stream.
%
%   Stream = PROCESSSENSORTIMESTAMPS(Config, Stream, StreamName) adds
%   timestamp quality processing to one schema/unit-normalized stream.
%   Stream = PROCESSSENSORTIMESTAMPS(..., RecordedRate_Hz) supplies an
%   externally recorded sample rate for the nominal-rate provenance chain.
%
%   Row handling (all original rows are preserved as audit data):
%       - The original row order is checked first and is NEVER modified.
%       - No samples are ever created, deleted or interpolated.
%       - Backward jumps and unexpected gaps are detected between
%         ORIGINAL ADJACENT rows in original order, BEFORE and
%         INDEPENDENTLY of duplicate exclusion. A row can carry several
%         findings at once (for example both 'DuplicateTimestampLater'
%         and 'BackwardTimestamp'); duplicate removal never conceals a
%         timestamp defect.
%       - Duplicate timestamps: the first occurrence is kept in
%         estimator-ready data (RowValid true); later occurrences are
%         flagged 'DuplicateTimestampLater' and excluded (RowValid false).
%       - Non-finite timestamps are flagged 'NonFiniteTimestamp' and
%         excluded.
%       - A discontinuity event (backward jump, gap, non-finite time)
%         starts a new segment at that row when the row is eligible; when
%         the row is excluded, the break is held pending and the NEXT
%         eligible row starts the new segment. The recorded BreakReason
%         is the chronologically first unprocessed discontinuity.
%       - Availability outages do NOT split segments (see
%         InspectSensorQuality) and never affect RowValid.
%
%   Gap policy (OR semantics): a gap is flagged when EITHER configured
%   threshold is exceeded:
%       dt > GapAbsolute_s  OR  dt > GapRelative * NominalPeriod_s
%
%   Nominal-rate provenance chain (per stream, recorded in the output):
%       1. 'Recorded'    - RecordedRate_Hz argument, else the MAT artifact
%                          field Stream.SourceSampleRate_Hz when present.
%       2. 'Measured'    - median of the strictly positive ORIGINAL
%                          ADJACENT finite sample intervals (never
%                          bridging across excluded rows); the reported
%                          interval count is the exact number of those
%                          intervals.
%       3. 'CodeDefault' - SensorDataContracts.RateFallback_Hz (code
%                          default reference, not historical evidence).
%   Config.Timestamps.NominalRateSource forces one link of the chain.
%
%   Added output fields:
%       Stream.RowValid       - Nx1 logical (structural row validity)
%       Stream.SegmentID      - Nx1 double (0 = excluded row)
%       Stream.Segments       - segment diagnostics struct array
%       Stream.NominalRate_Hz, .NominalPeriod_s, .NominalRateSource,
%       Stream.NominalRateEvidence
%       Stream.TimestampSummary
%       Stream.Flags.NonFiniteTimestamp, .BackwardTimestamp,
%       .DuplicateTimestampLater, .UnexpectedGap (Nx1 logical)
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: InspectSensorQuality, DetectSensorOutliers, QualityFlags.

    %% Validate Inputs

    if nargin < 4
        RecordedRate_Hz = [];
    end

    preprocessing.ValidatePreprocessingConfig(Config);

    if ~isstruct(Stream) || ~isscalar(Stream) || ...
            ~all(isfield(Stream, {'Time_s', 'SourceRowIdx'}))

        error( ...
            'Preprocessing:ProcessSensorTimestamps:MissingStreamField', ...
            ['Stream must be a scalar structure with Time_s and ', ...
             'SourceRowIdx fields (run NormalizeSensorSchema first).']);

    end

    Time_s = Stream.Time_s;
    SourceRowIdx = Stream.SourceRowIdx;
    RowCount = numel(Time_s);

    if ~isnumeric(Time_s) || ~isreal(Time_s) || ~iscolumn(Time_s) || ...
            ~isequal(numel(SourceRowIdx), RowCount)

        error( ...
            'Preprocessing:ProcessSensorTimestamps:InvalidTimeVector', ...
            'Time_s must be a real numeric column matching SourceRowIdx.');

    end

    if ~(isempty(RecordedRate_Hz) || ...
            (isnumeric(RecordedRate_Hz) && isreal(RecordedRate_Hz) && ...
             isscalar(RecordedRate_Hz) && isfinite(RecordedRate_Hz) && ...
             RecordedRate_Hz > 0))

        error( ...
            'Preprocessing:ProcessSensorTimestamps:InvalidRecordedRate', ...
            'RecordedRate_Hz must be [] or a positive finite scalar.');

    end

    %% Row-Order Check

    if any(SourceRowIdx ~= (1:RowCount).')

        error( ...
            'Preprocessing:ProcessSensorTimestamps:RowOrderViolation', ...
            ['SourceRowIdx must be the unmodified original order ', ...
             '1..N; row reordering is not permitted.']);

    end

    %% Non-Finite Timestamps

    Flags = struct();
    Flags.NonFiniteTimestamp = ~isfinite(Time_s);

    %% Duplicate Timestamps (first occurrence kept)

    DuplicateLater = false(RowCount, 1);
    FiniteRows = find(~Flags.NonFiniteTimestamp);

    if ~isempty(FiniteRows)

        [~, FirstIndex] = unique(Time_s(FiniteRows), 'stable');
        FirstOfValue = false(numel(FiniteRows), 1);
        FirstOfValue(FirstIndex) = true;
        DuplicateLater(FiniteRows) = ~FirstOfValue;

    end

    Flags.DuplicateTimestampLater = DuplicateLater;

    RowValid = ~(Flags.NonFiniteTimestamp | DuplicateLater);

    %% Nominal-Rate Provenance

    [NominalRate_Hz, NominalPeriod_s, RateSource, RateEvidence] = ...
        resolveNominalRate( ...
            Config, StreamName, Stream, Time_s, RecordedRate_Hz);

    %% Adjacent-Timestamp Discontinuity Scan
    %
    % Backward jumps and gaps are detected between ORIGINAL ADJACENT rows
    % in original row order, before and independently of duplicate
    % exclusion, so duplicate removal can never conceal a timestamp
    % defect. A row may therefore carry several findings at once (for
    % example both DuplicateTimestampLater and BackwardTimestamp).

    Flags.BackwardTimestamp = false(RowCount, 1);
    Flags.UnexpectedGap = false(RowCount, 1);
    GapEvent_dt_s = NaN(RowCount, 1);

    for Row = 2:RowCount

        if Flags.NonFiniteTimestamp(Row) || ...
                Flags.NonFiniteTimestamp(Row - 1)

            continue;

        end

        AdjacentDt_s = Time_s(Row) - Time_s(Row - 1);

        if AdjacentDt_s < 0

            Flags.BackwardTimestamp(Row) = true;

        elseif isGapExceeded(AdjacentDt_s, Config, NominalPeriod_s)

            Flags.UnexpectedGap(Row) = true;
            GapEvent_dt_s(Row) = AdjacentDt_s;

        end

    end

    %% Segmentation Walk (event-driven, original row order)
    %
    % A discontinuity event (backward jump, gap, or non-finite time)
    % starts a new segment at that row when the row is eligible. When the
    % event row is excluded (duplicate or non-finite), the break is held
    % pending and the NEXT eligible row starts the new segment. The
    % recorded BreakReason is the chronologically first unprocessed
    % discontinuity, so a defect is never concealed by a later event.

    SegmentID = zeros(RowCount, 1);
    SegmentCount = 0;
    PendingBreakReason = '';
    PendingGap_dt_s = NaN;
    Segments = emptySegments();

    for Row = 1:RowCount

        OwnReason = '';

        if Flags.BackwardTimestamp(Row)

            OwnReason = 'BackwardTimestamp';

        elseif Flags.UnexpectedGap(Row)

            OwnReason = 'UnexpectedGap';

        end

        if ~RowValid(Row)

            if isempty(PendingBreakReason)

                if ~isempty(OwnReason)

                    PendingBreakReason = OwnReason;
                    PendingGap_dt_s = GapEvent_dt_s(Row);

                elseif Flags.NonFiniteTimestamp(Row)

                    PendingBreakReason = 'NonFiniteTimestamp';

                end

            end

            continue;

        end

        if SegmentCount == 0

            if ~isempty(PendingBreakReason)

                BreakReason = PendingBreakReason;
                Gap_dt_s = PendingGap_dt_s;

            else

                BreakReason = 'Start';
                Gap_dt_s = NaN;

            end

        elseif ~isempty(PendingBreakReason)

            BreakReason = PendingBreakReason;
            Gap_dt_s = PendingGap_dt_s;

        elseif ~isempty(OwnReason)

            BreakReason = OwnReason;
            Gap_dt_s = GapEvent_dt_s(Row);

        else

            SegmentID(Row) = SegmentCount;
            Segments(SegmentCount).LastRowIdx = Row;
            Segments(SegmentCount).ValidSampleCount = ...
                Segments(SegmentCount).ValidSampleCount + 1;
            Segments(SegmentCount).EndTime_s = Time_s(Row);
            continue;

        end

        SegmentCount = SegmentCount + 1;
        Segment = struct( ...
            'SegmentID', SegmentCount, ...
            'FirstRowIdx', Row, ...
            'LastRowIdx', Row, ...
            'ValidSampleCount', 1, ...
            'StartTime_s', Time_s(Row), ...
            'EndTime_s', Time_s(Row), ...
            'BreakReason', BreakReason, ...
            'Gap_dt_s', Gap_dt_s);
        Segments(SegmentCount) = Segment;
        SegmentID(Row) = SegmentCount;
        PendingBreakReason = '';
        PendingGap_dt_s = NaN;

    end

    %% Summary

    TimestampSummary = struct( ...
        'TotalRows', RowCount, ...
        'ValidRows', sum(RowValid), ...
        'ExcludedRows', sum(~RowValid), ...
        'NonFiniteTimeCount', sum(Flags.NonFiniteTimestamp), ...
        'DuplicateCount', sum(Flags.DuplicateTimestampLater), ...
        'BackwardCount', sum(Flags.BackwardTimestamp), ...
        'GapCount', sum(Flags.UnexpectedGap), ...
        'SegmentCount', SegmentCount);

    %% Build Output

    Stream.RowValid = RowValid;
    Stream.SegmentID = SegmentID;
    Stream.Segments = Segments;
    Stream.NominalRate_Hz = NominalRate_Hz;
    Stream.NominalPeriod_s = NominalPeriod_s;
    Stream.NominalRateSource = RateSource;
    Stream.NominalRateEvidence = RateEvidence;
    Stream.TimestampSummary = TimestampSummary;

    if isfield(Stream, 'Flags')

        Stream.Flags.NonFiniteTimestamp = Flags.NonFiniteTimestamp;
        Stream.Flags.BackwardTimestamp = Flags.BackwardTimestamp;
        Stream.Flags.DuplicateTimestampLater = Flags.DuplicateTimestampLater;
        Stream.Flags.UnexpectedGap = Flags.UnexpectedGap;

    else

        Stream.Flags = Flags;

    end

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function Segments = emptySegments()
%EMPTYSEGMENTS Segment struct array template.

    Template = struct( ...
        'SegmentID', 0, ...
        'FirstRowIdx', 0, ...
        'LastRowIdx', 0, ...
        'ValidSampleCount', 0, ...
        'StartTime_s', NaN, ...
        'EndTime_s', NaN, ...
        'BreakReason', '', ...
        'Gap_dt_s', NaN);
    Segments = repmat(Template, 0, 1);

end

function IsGap = isGapExceeded(dt_s, Config, NominalPeriod_s)
%ISGAPEXCEEDED OR semantics: either configured threshold exceeded.

    IsGap = false;

    if ~isempty(Config.Timestamps.GapAbsolute_s) && ...
            dt_s > Config.Timestamps.GapAbsolute_s

        IsGap = true;

    end

    if ~isempty(Config.Timestamps.GapRelative) && ...
            dt_s > Config.Timestamps.GapRelative * NominalPeriod_s

        IsGap = true;

    end

end

function [Rate_Hz, Period_s, Source, Evidence] = resolveNominalRate( ...
    Config, StreamName, Stream, Time_s, RecordedRate_Hz)
%RESOLVENOMINALRATE Recorded -> Measured -> CodeDefault provenance chain.

    Contracts = preprocessing.SensorDataContracts();
    Mode = char(Config.Timestamps.NominalRateSource);

    RecordedAvailable = false;
    RecordedValue = NaN;
    RecordedEvidence = '';

    if ~isempty(RecordedRate_Hz)

        RecordedAvailable = true;
        RecordedValue = RecordedRate_Hz;
        RecordedEvidence = 'caller-supplied recorded rate';

    elseif isfield(Stream, 'SourceSampleRate_Hz') && ...
            isnumeric(Stream.SourceSampleRate_Hz) && ...
            isscalar(Stream.SourceSampleRate_Hz) && ...
            isfinite(Stream.SourceSampleRate_Hz) && ...
            Stream.SourceSampleRate_Hz > 0

        RecordedAvailable = true;
        RecordedValue = Stream.SourceSampleRate_Hz;
        RecordedEvidence = ...
            'Stream.SourceSampleRate_Hz (recorded MAT artifact field)';

    end

    MeasuredAvailable = false;
    MeasuredValue = NaN;
    MeasuredIntervalCount = 0;

    % Measured rate uses the strictly positive ORIGINAL ADJACENT finite
    % sample intervals in original row order, never bridging across
    % excluded rows.
    AllIntervals = diff(Time_s);
    BothFinite = isfinite(Time_s(1:end-1)) & isfinite(Time_s(2:end));
    PositiveIntervals = AllIntervals(BothFinite & AllIntervals > 0);

    if ~isempty(PositiveIntervals)

        MeasuredAvailable = true;
        MeasuredValue = median(PositiveIntervals);
        MeasuredIntervalCount = numel(PositiveIntervals);

    end

    CodeDefaultValue = Contracts.(StreamName).RateFallback_Hz;
    CodeDefaultEvidence = [ ...
        'SensorDataContracts.RateFallback_Hz (code default reference, ', ...
        'not evidence of historical run sample rates)'];

    switch Mode

        case 'Recorded'

            UseRecorded = true;
            UseMeasured = false;
            UseCodeDefault = false;

        case 'Measured'

            UseRecorded = false;
            UseMeasured = true;
            UseCodeDefault = false;

        case 'CodeDefault'

            UseRecorded = false;
            UseMeasured = false;
            UseCodeDefault = true;

        otherwise

            UseRecorded = RecordedAvailable;
            UseMeasured = ~UseRecorded && MeasuredAvailable;
            UseCodeDefault = ~UseRecorded && ~UseMeasured;

    end

    if UseRecorded

        if ~RecordedAvailable

            error( ...
                ['Preprocessing:ProcessSensorTimestamps:', ...
                 'RecordedRateUnavailable'], ...
                ['No recorded sample rate is available for stream ', ...
                 '"%s".'], ...
                StreamName);

        end

        Rate_Hz = RecordedValue;
        Source = 'Recorded';
        Evidence = RecordedEvidence;

    elseif UseMeasured

        if ~MeasuredAvailable

            error( ...
                ['Preprocessing:ProcessSensorTimestamps:', ...
                 'MeasuredRateUnavailable'], ...
                ['Sample intervals are not measurable for stream ', ...
                 '"%s".'], ...
                StreamName);

        end

        Rate_Hz = 1 / MeasuredValue;
        Source = 'Measured';
        Evidence = sprintf( ...
            'median of %d positive original adjacent finite intervals', ...
            MeasuredIntervalCount);

    else

        Rate_Hz = CodeDefaultValue;
        Source = 'CodeDefault';
        Evidence = CodeDefaultEvidence;

    end

    Period_s = 1 / Rate_Hz;

end
