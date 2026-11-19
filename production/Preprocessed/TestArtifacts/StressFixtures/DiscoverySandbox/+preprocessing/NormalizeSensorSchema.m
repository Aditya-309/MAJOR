function Stream = NormalizeSensorSchema(Raw, StreamName, SourceDialect)
%NORMALIZESENSORSCHEMA Map raw source-dialect data to canonical fields.
%
%   Stream = NORMALIZESENSORSCHEMA(Raw, StreamName, SourceDialect) maps
%   the raw channel data of one sensor stream onto the canonical field
%   names of SensorDataContracts and adds the audit and trace fields.
%
%   Raw           - scalar structure of raw source-named numeric arrays
%   StreamName    - 'IMU', 'GNSS', 'AirData' or 'Magnetometer'
%   SourceDialect - 'IdealCsv', 'RealisticCsv' or 'Mat'
%
%   Dialect behavior:
%       IdealCsv / RealisticCsv
%           Raw fields use the per-axis CSV column names of the dialect.
%       Mat
%           Raw fields use the compact MAT field names; Nx3 arrays are
%           split into per-axis canonical fields using MatColumn.
%
%   Availability synthesis (explicitly documented): the Available channel
%   is synthesized as all-true ONLY when the source is the ideal CSV
%   dialect (ideal CSV files carry no Available column). The synthesis is
%   recorded in Stream.SynthesizedFields and
%   Stream.SourceFieldNames.Available = '<synthesized>'. For the realistic
%   CSV and MAT dialects a missing Available field is a schema error.
%   CSV availability values 0/1 are converted to logical.
%
%   Output fields:
%       Canonical channel fields (SensorDataContracts channel names)
%       Stream.SampleCount    - number of rows
%       Stream.Time_s         - canonical time vector
%       Stream.Available      - logical availability vector
%       Stream.SourceRowIdx   - original row indices 1..N (unmodified)
%       Stream.SourceTime_s   - original Time_s values (unmodified)
%       Stream.SourceFieldNames.<CanonicalField> - source field name
%           ('<synthesized>' when the channel was created by synthesis)
%       Stream.SynthesizedFields - cellstr of synthesized canonical fields
%
%   Pure function: no file access and no global state. Source values are
%   NOT unit-converted here (see NormalizeSensorUnits).
%
%   Errors: Preprocessing:NormalizeSensorSchema:<Reason>
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: NormalizeSensorUnits, LoadSensorData, SensorDataContracts.

    %% Validate Inputs

    if ~isstruct(Raw) || ~isscalar(Raw)

        error( ...
            'Preprocessing:NormalizeSensorSchema:InvalidRaw', ...
            'Raw must be a scalar structure.');

    end

    Contracts = preprocessing.SensorDataContracts();

    if ~(ischar(StreamName) || (isstring(StreamName) && isscalar(StreamName)))

        error( ...
            'Preprocessing:NormalizeSensorSchema:InvalidStreamName', ...
            'StreamName must be a character vector or scalar string.');

    end

    StreamName = char(StreamName);

    if ~any(strcmp(StreamName, Contracts.Streams))

        error( ...
            'Preprocessing:NormalizeSensorSchema:InvalidStreamName', ...
            'Unknown stream name "%s".', ...
            StreamName);

    end

    ValidDialects = {'IdealCsv', 'RealisticCsv', 'Mat'};

    if ~(ischar(SourceDialect) || ...
            (isstring(SourceDialect) && isscalar(SourceDialect))) || ...
            ~any(strcmp(char(SourceDialect), ValidDialects))

        error( ...
            'Preprocessing:NormalizeSensorSchema:UnknownDialect', ...
            'SourceDialect must be one of: %s.', ...
            strjoin(ValidDialects, ', '));

    end

    SourceDialect = char(SourceDialect);
    Channels = Contracts.(StreamName).Channels;

    %% Schema Field Check

    ExpectedSources = {};

    for Index = 1:numel(Channels)

        SourceName = sourceFieldName(Channels(Index), SourceDialect);

        if ~isempty(SourceName)

            ExpectedSources{end + 1} = SourceName;

        end

    end

    ExpectedSources = unique(ExpectedSources);
    FoundNames = fieldnames(Raw)';

    MissingNames = setdiff(ExpectedSources, FoundNames);

    if strcmp(SourceDialect, 'IdealCsv')

        % Ideal CSV carries no Available column; synthesis is allowed.
        MissingNames = setdiff(MissingNames, {'Available'});

    end

    if ~isempty(MissingNames)

        error( ...
            'Preprocessing:NormalizeSensorSchema:MissingSourceField', ...
            'Raw data is missing source field(s): %s.', ...
            strjoin(MissingNames, ', '));

    end

    ExtraNames = setdiff(FoundNames, ExpectedSources);

    if ~isempty(ExtraNames)

        error( ...
            'Preprocessing:NormalizeSensorSchema:UnexpectedSourceField', ...
            'Raw data has unexpected source field(s): %s.', ...
            strjoin(ExtraNames, ', '));

    end

    %% Determine Row Count

    TimeChannel = Channels(1);
    TimeSourceName = sourceFieldName(TimeChannel, SourceDialect);
    TimeData = extractColumn(Raw, TimeSourceName, TimeChannel, ...
        SourceDialect);

    if ~isnumeric(TimeData) || ~isreal(TimeData) || isempty(TimeData)

        error( ...
            'Preprocessing:NormalizeSensorSchema:InvalidSourceData', ...
            'Source field "%s" must be a nonempty real numeric vector.', ...
            TimeSourceName);

    end

    SampleCount = numel(TimeData);

    %% Map Channels

    Stream = struct();
    StreamFieldNames = struct();
    SynthesizedFields = {};

    for Index = 1:numel(Channels)

        Channel = Channels(Index);
        SourceName = sourceFieldName(Channel, SourceDialect);

        if isempty(SourceName)

            % Ideal CSV availability: synthesize all-true and document.
            Values = true(SampleCount, 1);
            StreamFieldNames.(Channel.CanonicalField) = '<synthesized>';
            SynthesizedFields{end + 1} = Channel.CanonicalField;

        elseif strcmp(Channel.CanonicalField, 'Available') && ...
                ~isfield(Raw, SourceName)

            Values = true(SampleCount, 1);
            StreamFieldNames.(Channel.CanonicalField) = '<synthesized>';
            SynthesizedFields{end + 1} = Channel.CanonicalField;

        else

            Values = extractColumn(Raw, SourceName, Channel, SourceDialect);

            if ~(isnumeric(Values) || islogical(Values)) || ...
                    ~isreal(Values) || numel(Values) ~= SampleCount

                error( ...
                    ['Preprocessing:NormalizeSensorSchema:', ...
                     'InvalidSourceData'], ...
                    ['Source field "%s" must be a real numeric ', ...
                     'vector of %d rows.'], ...
                    SourceName, ...
                    SampleCount);

            end

            Values = Values(:);
            StreamFieldNames.(Channel.CanonicalField) = SourceName;

        end

        if strcmp(Channel.CanonicalField, 'Available')

            Values = toLogicalAvailability(Values, SourceName);

        end

        Stream.(Channel.CanonicalField) = Values;

    end

    %% Audit And Trace Fields

    Stream.SampleCount = SampleCount;
    Stream.SourceRowIdx = (1:SampleCount).';
    Stream.SourceTime_s = TimeData(:);
    Stream.SourceFieldNames = StreamFieldNames;
    Stream.SynthesizedFields = SynthesizedFields;

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function SourceName = sourceFieldName(Channel, SourceDialect)
%SOURCEFIELDNAME Source field name of one channel for one dialect.

    switch SourceDialect

        case 'IdealCsv'

            SourceName = Channel.IdealCsvField;

        case 'RealisticCsv'

            SourceName = Channel.RealisticCsvField;

        otherwise

            SourceName = Channel.MatField;

    end

end

function Values = extractColumn(Raw, SourceName, Channel, SourceDialect)
%EXTRACTCOLUMN Extract one channel column from the raw data.

    Data = Raw.(SourceName);

    if ~strcmp(SourceDialect, 'Mat')

        Values = Data(:);
        return;

    end

    IsNumericData = isnumeric(Data) || islogical(Data);

    if Channel.MatColumn == 0

        if ~IsNumericData || ~isreal(Data) || ~isvector(Data)

            error( ...
                'Preprocessing:NormalizeSensorSchema:InvalidSourceData', ...
                'MAT field "%s" must be a real numeric or logical vector.', ...
                SourceName);

        end

        Values = Data(:);

    else

        if ~IsNumericData || ~isreal(Data) || ~ismatrix(Data) || ...
                size(Data, 2) < Channel.MatColumn

            error( ...
                'Preprocessing:NormalizeSensorSchema:InvalidSourceData', ...
                ['MAT field "%s" must be a real numeric matrix with ', ...
                 'at least %d columns.'], ...
                SourceName, ...
                Channel.MatColumn);

        end

        Values = Data(:, Channel.MatColumn);

    end

end

function Values = toLogicalAvailability(Values, SourceName)
%TOLOGICALAVAILABILITY Convert 0/1 or logical availability to logical.

    if islogical(Values)

        return;

    end

    if any(Values ~= 0 & Values ~= 1)

        error( ...
            'Preprocessing:NormalizeSensorSchema:InvalidSourceData', ...
            ['Availability field "%s" must contain only 0/1 or ', ...
             'logical values.'], ...
            SourceName);

    end

    Values = logical(Values);

end
