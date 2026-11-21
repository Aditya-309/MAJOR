function Validation = ValidatePreprocessedRun(Data, Config)
%VALIDATEPREPROCESSEDRUN Validate Block 9 input structure and contracts.
%
%   Validation = VALIDATEPREPROCESSEDRUN(Data, Config) checks that the
%   loaded PreprocessedData structure contains the hierarchy and canonical
%   fields the estimator consumes, that arrays are consistent, and that
%   the required streams for estimation are present and usable.
%
%   This is a consumer-side contract check, not a re-run of Block 9
%   preprocessing: timestamps are never re-cleaned, samples are never
%   reordered or deleted, and no standardization is re-applied.
%
%   Required estimation streams: IMU and GNSS. Magnetometer and AirData
%   must at least declare their presence or their explicit absence (the
%   stream may be missing only when its Status field says so; a missing
%   magnetometer forces diagnostic-only behaviour downstream).
%
%   Output:
%       Validation.Issues     - cellstr of blocking issues (empty on pass)
%       Validation.Warnings   - cellstr of non-blocking observations
%       Validation.Streams    - per-stream summary (status, sample count,
%                               nominal rate, segment count, outage count,
%                               availability/validity counts)
%       Validation.Passed     - logical, no blocking issues
%
%   Blocking failures raise no error here; callers decide. RunStateReconstruction
%   refuses to proceed when Passed is false and reports the issues.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: LoadPreprocessedRun, BuildMeasurementTimeline.

    Issues = {};
    Warnings = {};
    Streams = struct();

    if ~(isstruct(Data) && isscalar(Data))

        Validation = buildResult({'Data must be a scalar structure.'}, ...
            {'Not applicable.'}, struct());
        return

    end

    RequiredTop = {'RunInfo', 'NativeRate'};

    for Index = 1:numel(RequiredTop)

        if ~isfield(Data, RequiredTop{Index})

            Issues{end + 1} = sprintf( ...
                'Data is missing required top-level field "%s".', ...
                RequiredTop{Index}); %#ok<AGROW>

        end

    end

    if ~isempty(Issues)

        Validation = buildResult(Issues, Warnings, struct());
        return

    end

    if ~isfield(Data.RunInfo, 'PreprocessID') || ...
            ~isfield(Data.RunInfo, 'RunID') || ...
            ~isfield(Data.RunInfo, 'Status')

        Issues{end + 1} = ...
            'Data.RunInfo is missing RunID, PreprocessID or Status.';

    elseif ~strcmp(Data.RunInfo.Status, 'SUCCESS')

        Issues{end + 1} = sprintf( ...
            'Preprocessing status is "%s", not "SUCCESS".', ...
            Data.RunInfo.Status);

    end

    %% Canonical stream contracts (field names from SensorDataContracts)

    RequiredChannels = struct();
    RequiredChannels.IMU = { ...
        'Time_s', 'Accelerometer_X_mps2', 'Accelerometer_Y_mps2', ...
        'Accelerometer_Z_mps2', 'Gyroscope_X_radps', ...
        'Gyroscope_Y_radps', 'Gyroscope_Z_radps'};
    RequiredChannels.GNSS = { ...
        'Time_s', 'Latitude_rad', 'Longitude_rad', 'Altitude_m', ...
        'Velocity_North_mps', 'Velocity_East_mps', ...
        'Velocity_Down_mps'};
    RequiredChannels.AirData = { ...
        'Time_s', 'TrueAirspeed_mps', 'DynamicPressure_Pa'};
    RequiredChannels.Magnetometer = { ...
        'Time_s', 'MagneticFieldBody_X_T', 'MagneticFieldBody_Y_T', ...
        'MagneticFieldBody_Z_T'};

    AuditChannels = {'Available', 'RowValid', 'MeasurementValid', ...
        'SourceRowIdx', 'SourceTime_s', 'SegmentID'};

    StreamNames = fieldnames(RequiredChannels);

    for Index = 1:numel(StreamNames)

        StreamName = StreamNames{Index};

        if ~isfield(Data.NativeRate, StreamName)

            if strcmp(StreamName, 'IMU') || strcmp(StreamName, 'GNSS')

                Issues{end + 1} = sprintf( ...
                    'Required estimation stream "%s" is absent.', ...
                    StreamName); %#ok<AGROW>

            else

                Warnings{end + 1} = sprintf( ...
                    ['Optional stream "%s" is absent; its diagnostics ', ...
                     'will not be produced.'], ...
                    StreamName); %#ok<AGROW>

            end

            Streams.(StreamName) = struct('Status', 'Absent');
            continue

        end

        Stream = Data.NativeRate.(StreamName);
        StreamIssues = {};
        StreamWarnings = {};

        if ~isstruct(Stream) || ~isscalar(Stream)

            Issues{end + 1} = sprintf( ...
                'Stream "%s" is not a scalar structure.', StreamName); %#ok<AGROW>
            Streams.(StreamName) = struct('Status', 'Invalid');
            continue

        end

        RequiredFields = [RequiredChannels.(StreamName), AuditChannels];

        for FieldIndex = 1:numel(RequiredFields)

            if ~isfield(Stream, RequiredFields{FieldIndex})

                StreamIssues{end + 1} = sprintf( ...
                    'Stream "%s" is missing field "%s".', ...
                    StreamName, RequiredFields{FieldIndex}); %#ok<AGROW>

            end

        end

        if isempty(StreamIssues)

            SampleCount = numel(Stream.Time_s);

            if SampleCount < 2

                StreamIssues{end + 1} = sprintf( ...
                    'Stream "%s" has fewer than two samples.', ...
                    StreamName);

            else

                if any(~isfinite(Stream.Time_s))

                    StreamIssues{end + 1} = sprintf( ...
                        'Stream "%s" contains non-finite timestamps.', ...
                        StreamName);

                end

                if any(diff(Stream.Time_s) <= 0)

                    StreamIssues{end + 1} = sprintf( ...
                        ['Stream "%s" timestamps are not strictly ', ...
                         'increasing (Block 9 invariant violated).'], ...
                        StreamName);

                end

                ChannelNames = RequiredChannels.(StreamName);

                for ChannelIndex = 1:numel(ChannelNames)

                    Values = Stream.(ChannelNames{ChannelIndex});

                    if ~isnumeric(Values) || numel(Values) ~= SampleCount

                        StreamIssues{end + 1} = sprintf( ...
                            ['Stream "%s" channel "%s" is not a numeric ', ...
                             'array with one value per sample.'], ...
                            StreamName, ...
                            ChannelNames{ChannelIndex}); %#ok<AGROW>

                    end

                end

                AuditNumeric = {'SourceRowIdx', 'SourceTime_s', ...
                    'SegmentID'};

                for AuditIndex = 1:numel(AuditNumeric)

                    Values = Stream.(AuditNumeric{AuditIndex});

                    if ~isnumeric(Values) || numel(Values) ~= SampleCount

                        StreamIssues{end + 1} = sprintf( ...
                            ['Stream "%s" provenance field "%s" must be ', ...
                             'numeric with one value per sample.'], ...
                            StreamName, ...
                            AuditNumeric{AuditIndex}); %#ok<AGROW>

                    end

                end

                AuditLogical = {'Available', 'RowValid', ...
                    'MeasurementValid'};

                for AuditIndex = 1:numel(AuditLogical)

                    Values = Stream.(AuditLogical{AuditIndex});

                    if ~(islogical(Values) && numel(Values) == SampleCount)

                        StreamIssues{end + 1} = sprintf( ...
                            ['Stream "%s" flag "%s" must be logical with ', ...
                             'one value per sample.'], ...
                            StreamName, ...
                            AuditLogical{AuditIndex}); %#ok<AGROW>

                    end

                end

                if ~isequal(Stream.SourceRowIdx(:), (1:SampleCount)')

                    % Block 9 hard-enforces SourceRowIdx == (1:N)'.
                    StreamIssues{end + 1} = sprintf( ...
                        ['Stream "%s" SourceRowIdx is not 1:N as ', ...
                         'guaranteed by Block 9.'], ...
                        StreamName);

                end

            end

        end

        Summary = struct();
        Summary.Status = 'OK';

        if ~isempty(StreamIssues)

            Summary.Status = 'Invalid';

        end

        if isfield(Stream, 'SampleCount')

            Summary.SampleCount = Stream.SampleCount;

        else

            Summary.SampleCount = NaN;

        end

        if isfield(Stream, 'NominalRate_Hz')

            Summary.NominalRate_Hz = Stream.NominalRate_Hz;

        else

            Summary.NominalRate_Hz = NaN;

        end

        if isfield(Stream, 'TimestampSummary') && ...
                isfield(Stream.TimestampSummary, 'SegmentCount')

            Summary.SegmentCount = Stream.TimestampSummary.SegmentCount;

        else

            Summary.SegmentCount = NaN;

        end

        if isfield(Stream, 'Outages')

            Summary.OutageCount = numel(Stream.Outages);

        else

            Summary.OutageCount = NaN;

        end

        if isempty(StreamIssues) && isfield(Stream, 'Available')

            Summary.UnavailableCount = sum(~Stream.Available);
            Summary.MeasurementInvalidCount = ...
                sum(~Stream.MeasurementValid);

        end

        Streams.(StreamName) = Summary;
        Issues = [Issues, StreamIssues]; %#ok<AGROW>
        Warnings = [Warnings, StreamWarnings]; %#ok<AGROW>

    end

    %% Cross-checks against the explicit configuration

    if nargin >= 2 && isstruct(Config) && ...
            isfield(Config, 'Magnetometer') && ...
            Config.Magnetometer.EnableUpdates && ...
            ~isfield(Data.NativeRate, 'Magnetometer')

        Issues{end + 1} = [ ...
            'Configuration enables magnetometer updates but the input ', ...
            'has no Magnetometer stream. Disable the updates or supply ', ...
            'a run that contains the stream.'];

    end

    Validation = buildResult(Issues, Warnings, Streams);

end

function Validation = buildResult(Issues, Warnings, Streams)
    Validation = struct();
    Validation.Issues = Issues(:);
    Validation.Warnings = Warnings(:);
    Validation.Streams = Streams;
    Validation.Passed = isempty(Issues);
end
