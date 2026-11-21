function Timeline = BuildMeasurementTimeline(Data, Config)
%BUILDMEASUREMENTTIMELINE Build the chronological native-rate event timeline.
%
%   Timeline = BUILDMEASUREMENTTIMELINE(Data, Config) assembles every
%   usable sample of every loaded stream into one strictly chronological
%   event timeline processed at the samples' own timestamps. Streams are
%   never resampled to a common frequency and native-rate measurements
%   are never replaced by aligned data.
%
%   Event types (Timeline.EventCodes):
%       1 = IMUPropagation      (accelerometer + gyroscope input)
%       2 = GNSSPosition        (measurement update)
%       3 = GNSSVelocity        (measurement update)
%       4 = MagneticField       (measurement update when enabled,
%                                otherwise diagnostic-only)
%       5 = AirDataDiagnostic   (consistency diagnostics only)
%
%   Ordering: Time_s ascending, then event type ascending, then
%   SourceRowIdx ascending. Ties are therefore deterministic: at an equal
%   timestamp the IMU propagation event (which ends the propagation
%   interval and refreshes the held IMU input) precedes measurement
%   updates at the same instant. Forward estimation can never observe a
%   future measurement because events are processed strictly in this
%   order and propagation only ever spans (previous event, current event].
%
%   Event arrays (all E-by-1):
%       .Time_s, .Type, .Stream (cellstr), .SourceRowIdx, .SegmentID,
%       .MeasureIdx (index into the stream arrays),
%       .Eligible (logical), .ExclusionReason (cellstr),
%       .Z (E-by-6 raw values; for type 1: accel XYZ then gyro XYZ,
%           otherwise the measurement channels; unused slots NaN)
%
%   Eligibility applies the explicit measurement policy of the
%   configuration: the Block 9 flags named in RequiredFlagsTrue must be
%   true, the flags named in ExcludeFlagNames must be false, and the
%   event's own values must be finite. Every exclusion is recorded with
%   its reason; nothing is discarded silently.
%
%   Timeline fields:
%       .Events     - the arrays above
%       .EventCodes - struct mapping names to codes
%       .Streams    - per-stream summary (counts, exclusions)
%       .Outages    - Block 9 availability outage spans per stream
%       .BuiltFrom  - RunID / PreprocessID echo
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: LoadPreprocessedRun, InitializeState, RunFilter.

    EventCodes = struct( ...
        'IMUPropagation', 1, ...
        'GNSSPosition', 2, ...
        'GNSSVelocity', 3, ...
        'MagneticField', 4, ...
        'AirDataDiagnostic', 5);

    RequiredFlagsTrue = Config.MeasurementPolicy.RequiredFlagsTrue;
    ExcludeFlagNames = Config.MeasurementPolicy.ExcludeFlagNames;

    Time_s = zeros(0, 1);
    Type = zeros(0, 1);
    Stream = cell(0, 1);
    SourceRowIdx = zeros(0, 1);
    SegmentID = zeros(0, 1);
    MeasureIdx = zeros(0, 1);
    Eligible = false(0, 1);
    ExclusionReason = cell(0, 1);
    Z = zeros(0, 6);

    StreamSummary = struct();
    Outages = struct();

    %% IMU propagation events

    if isfield(Data.NativeRate, 'IMU')

        S = Data.NativeRate.IMU;
        N = numel(S.Time_s);
        [Elig, Reason] = rowEligibility(S, 1:N, RequiredFlagsTrue, ...
            ExcludeFlagNames);

        % Propagation input must exist on both channels.
        for Row = 1:N

            if Elig(Row) && any(~isfinite([ ...
                    S.Accelerometer_X_mps2(Row), ...
                    S.Accelerometer_Y_mps2(Row), ...
                    S.Accelerometer_Z_mps2(Row), ...
                    S.Gyroscope_X_radps(Row), ...
                    S.Gyroscope_Y_radps(Row), ...
                    S.Gyroscope_Z_radps(Row)]))

                Elig(Row) = false;
                Reason{Row} = 'NonFinitePropagationInput';

            end

        end

        Zimu = [ ...
            S.Accelerometer_X_mps2(:), S.Accelerometer_Y_mps2(:), ...
            S.Accelerometer_Z_mps2(:), S.Gyroscope_X_radps(:), ...
            S.Gyroscope_Y_radps(:), S.Gyroscope_Z_radps(:)];

        [Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z] = appendEvents( ...
            Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z, ...
            S.Time_s(:), EventCodes.IMUPropagation, 'IMU', ...
            S.SourceRowIdx(:), S.SegmentID(:), (1:N)', ...
            Elig, Reason, Zimu);

        StreamSummary.IMU = summarizeStream(N, Elig, Reason);
        StreamSummary.IMU.SampleRate_Hz = getFieldOr(S, 'NominalRate_Hz', NaN);

        if isfield(S, 'Outages')
            Outages.IMU = S.Outages;
        else
            Outages.IMU = struct([]);
        end

    end

    %% GNSS position and velocity events

    if isfield(Data.NativeRate, 'GNSS')

        S = Data.NativeRate.GNSS;
        N = numel(S.Time_s);
        [EligPos, ReasonPos] = rowEligibility(S, 1:N, ...
            RequiredFlagsTrue, ExcludeFlagNames);
        [EligVel, ReasonVel] = rowEligibility(S, 1:N, ...
            RequiredFlagsTrue, ExcludeFlagNames);

        Zpos = [S.Latitude_rad(:), S.Longitude_rad(:), ...
            S.Altitude_m(:), nan(N, 3)];
        Zvel = [S.Velocity_North_mps(:), S.Velocity_East_mps(:), ...
            S.Velocity_Down_mps(:), nan(N, 3)];

        for Row = 1:N

            if EligPos(Row) && any(~isfinite(Zpos(Row, 1:3)))
                EligPos(Row) = false;
                ReasonPos{Row} = 'NonFiniteMeasurement';
            end

            if EligVel(Row) && any(~isfinite(Zvel(Row, 1:3)))
                EligVel(Row) = false;
                ReasonVel{Row} = 'NonFiniteMeasurement';
            end

        end

        [Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z] = appendEvents( ...
            Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z, ...
            S.Time_s(:), EventCodes.GNSSPosition, 'GNSS', ...
            S.SourceRowIdx(:), S.SegmentID(:), (1:N)', ...
            EligPos, ReasonPos, Zpos);

        [Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z] = appendEvents( ...
            Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z, ...
            S.Time_s(:), EventCodes.GNSSVelocity, 'GNSS', ...
            S.SourceRowIdx(:), S.SegmentID(:), (1:N)', ...
            EligVel, ReasonVel, Zvel);

        StreamSummary.GNSS = summarizeStream(N, EligPos | EligVel, ...
            combineReasons(ReasonPos, ReasonVel));
        StreamSummary.GNSS.PositionEligible = sum(EligPos);
        StreamSummary.GNSS.VelocityEligible = sum(EligVel);
        StreamSummary.GNSS.SampleRate_Hz = getFieldOr(S, 'NominalRate_Hz', NaN);

        if isfield(S, 'Outages')
            Outages.GNSS = S.Outages;
        else
            Outages.GNSS = struct([]);
        end

    end

    %% Magnetometer events

    if isfield(Data.NativeRate, 'Magnetometer')

        S = Data.NativeRate.Magnetometer;
        N = numel(S.Time_s);
        [Elig, Reason] = rowEligibility(S, 1:N, RequiredFlagsTrue, ...
            ExcludeFlagNames);

        Zmag = [S.MagneticFieldBody_X_T(:), ...
            S.MagneticFieldBody_Y_T(:), ...
            S.MagneticFieldBody_Z_T(:), nan(N, 3)];

        for Row = 1:N

            if Elig(Row) && any(~isfinite(Zmag(Row, 1:3)))
                Elig(Row) = false;
                Reason{Row} = 'NonFiniteMeasurement';
            end

        end

        [Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z] = appendEvents( ...
            Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z, ...
            S.Time_s(:), EventCodes.MagneticField, 'Magnetometer', ...
            S.SourceRowIdx(:), S.SegmentID(:), (1:N)', ...
            Elig, Reason, Zmag);

        StreamSummary.Magnetometer = summarizeStream(N, Elig, Reason);
        StreamSummary.Magnetometer.SampleRate_Hz = ...
            getFieldOr(S, 'NominalRate_Hz', NaN);

        if isfield(S, 'Outages')
            Outages.Magnetometer = S.Outages;
        else
            Outages.Magnetometer = struct([]);
        end

    end

    %% AirData diagnostic events

    if isfield(Data.NativeRate, 'AirData')

        S = Data.NativeRate.AirData;
        N = numel(S.Time_s);
        [Elig, Reason] = rowEligibility(S, 1:N, RequiredFlagsTrue, ...
            ExcludeFlagNames);

        Zair = [S.TrueAirspeed_mps(:), S.DynamicPressure_Pa(:), ...
            nan(N, 4)];

        for Row = 1:N

            if Elig(Row) && any(~isfinite(Zair(Row, 1:2)))
                Elig(Row) = false;
                Reason{Row} = 'NonFiniteMeasurement';
            end

        end

        [Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z] = appendEvents( ...
            Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
            Eligible, ExclusionReason, Z, ...
            S.Time_s(:), EventCodes.AirDataDiagnostic, 'AirData', ...
            S.SourceRowIdx(:), S.SegmentID(:), (1:N)', ...
            Elig, Reason, Zair);

        StreamSummary.AirData = summarizeStream(N, Elig, Reason);
        StreamSummary.AirData.SampleRate_Hz = ...
            getFieldOr(S, 'NominalRate_Hz', NaN);

        if isfield(S, 'Outages')
            Outages.AirData = S.Outages;
        else
            Outages.AirData = struct([]);
        end

    end

    %% Deterministic chronological ordering

    SortMatrix = [Time_s, Type, SourceRowIdx];
    [~, Order] = sortrows(SortMatrix, [1, 2, 3]);

    Events = struct();
    Events.Time_s = Time_s(Order);
    Events.Type = Type(Order);
    Events.Stream = Stream(Order);
    Events.SourceRowIdx = SourceRowIdx(Order);
    Events.SegmentID = SegmentID(Order);
    Events.MeasureIdx = MeasureIdx(Order);
    Events.Eligible = Eligible(Order);
    Events.ExclusionReason = ExclusionReason(Order);
    Events.Z = Z(Order, :);

    Timeline = struct();
    Timeline.Events = Events;
    Timeline.EventCodes = EventCodes;
    Timeline.Streams = StreamSummary;
    Timeline.Outages = Outages;
    Timeline.BuiltFrom = struct( ...
        'RunID', Data.RunInfo.RunID, ...
        'PreprocessID', Data.RunInfo.PreprocessID);
    Timeline.TotalEvents = numel(Events.Time_s);

end

%% Local helpers

function [Eligible, Reason] = rowEligibility(S, Rows, RequiredFlagsTrue, ...
    ExcludeFlagNames)

    Count = numel(Rows);
    Eligible = true(Count, 1);
    Reason = repmat({''}, Count, 1);

    for Index = 1:numel(RequiredFlagsTrue)

        FlagName = RequiredFlagsTrue{Index};
        Values = resolveFlag(S, FlagName);

        if isempty(Values)
            continue
        end

        Bad = ~Values(:);

        for Row = 1:Count

            if Bad(Row) && Eligible(Row)

                Eligible(Row) = false;
                Reason{Row} = ['Flagged_' FlagName];

            end

        end

    end

    for Index = 1:numel(ExcludeFlagNames)

        FlagName = ExcludeFlagNames{Index};
        Values = resolveFlag(S, FlagName);

        if isempty(Values)
            continue
        end

        for Row = 1:Count

            if Values(Row) && Eligible(Row)

                Eligible(Row) = false;
                Reason{Row} = ['ExcludedFlag_' FlagName];

            end

        end

    end

end

function Values = resolveFlag(S, FlagName)
    % Block 9 keeps validity flags at the stream top level and the
    % quality findings under S.Flags.<name>; both are resolved here so
    % policy names can address either location.
    if isfield(S, FlagName)
        Values = S.(FlagName);
    elseif isfield(S, 'Flags') && isfield(S.Flags, FlagName)
        Values = S.Flags.(FlagName);
    else
        Values = [];
    end
end

function [Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
    Eligible, ExclusionReason, Z] = appendEvents( ...
    Time_s, Type, Stream, SourceRowIdx, SegmentID, MeasureIdx, ...
    Eligible, ExclusionReason, Z, ...
    EventTime_s, EventCode, StreamName, EventSourceRowIdx, ...
    EventSegmentID, EventMeasureIdx, EventEligible, EventReason, EventZ)

    Count = numel(EventTime_s);

    Time_s = [Time_s; EventTime_s(:)];
    Type = [Type; repmat(EventCode, Count, 1)];
    Stream = [Stream; repmat({StreamName}, Count, 1)];
    SourceRowIdx = [SourceRowIdx; EventSourceRowIdx(:)];
    SegmentID = [SegmentID; EventSegmentID(:)];
    MeasureIdx = [MeasureIdx; EventMeasureIdx(:)];
    Eligible = [Eligible; EventEligible(:)];
    ExclusionReason = [ExclusionReason; EventReason(:)];
    Z = [Z; EventZ];

end

function Summary = summarizeStream(Count, Elig, Reason)
    Summary = struct();
    Summary.TotalEvents = Count;
    Summary.Eligible = sum(Elig);
    Summary.Excluded = sum(~Elig);
    Summary.ExclusionReasons = struct();

    for Index = 1:numel(Reason)

        if ~isempty(Reason{Index})

            if ~isfield(Summary.ExclusionReasons, Reason{Index})
                Summary.ExclusionReasons.(Reason{Index}) = 0;
            end

            Summary.ExclusionReasons.(Reason{Index}) = ...
                Summary.ExclusionReasons.(Reason{Index}) + 1;

        end

    end

end

function Value = getFieldOr(S, FieldName, DefaultValue)
    if isfield(S, FieldName)
        Value = S.(FieldName);
    else
        Value = DefaultValue;
    end
end

function Reason = combineReasons(ReasonA, ReasonB)
    Count = numel(ReasonA);
    Reason = cell(Count, 1);

    for Index = 1:Count

        if isempty(ReasonA{Index})
            Reason{Index} = ReasonB{Index};
        else
            Reason{Index} = ReasonA{Index};
        end

    end

end
