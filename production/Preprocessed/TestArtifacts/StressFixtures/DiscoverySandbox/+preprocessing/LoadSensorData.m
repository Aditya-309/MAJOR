function Data = LoadSensorData(RunDirectory, Config, Format)
%LOADSENSORDATA Load and normalize the four sensor streams of one run.
%
%   Data = LOADSENSORDATA(RunDirectory, Config, Format) loads the four
%   canonical sensor streams (IMU, GNSS, AirData, Magnetometer) from the
%   configured source folder of a run directory and normalizes them
%   (schema + units) via NormalizeSensorSchema and NormalizeSensorUnits.
%
%   RunDirectory - resolved run folder (from InspectRun/RunRegistry)
%   Config       - validated preprocessing configuration
%   Format       - 'Auto' (default), 'Csv' or 'Mat'
%
%   Format behavior per stream (deterministic):
%       'Auto' - prefer the stream CSV file; when it is missing or
%                malformed, fall back to the source MAT file and record a
%                warning; when both fail the stream gets Status
%                'Missing' or 'Malformed'.
%       'Csv'  - CSV only, no fallback.
%       'Mat'  - MAT only (Level-5 and v7.3/HDF5 both supported).
%
%   MAT variable discovery uses file contents (whos), never assumed load
%   names: the expected variable name is preferred when present and
%   qualifies, otherwise any top-level variable that structurally contains
%   the stream is accepted and the name used is recorded in
%   Stream.SourceVariable.
%
%   GroundTruth and Block7 artifacts are NEVER read (ground truth must not
%   enter estimator input). Data.ExcludedSources records this.
%
%   Availability synthesis: for the ideal CSV dialect (which carries no
%   Available column) availability is synthesized all-true and recorded in
%   Stream.SynthesizedFields. See NormalizeSensorSchema.
%
%   Output fields:
%       Data.RunDirectory, Data.Source, Data.Format
%       Data.Streams.<StreamName> - per-stream struct with fields:
%           Status ('Loaded', 'Missing', 'Malformed')
%           Issues, Warnings
%           SourceFile, SourceFormat ('Csv', 'MatLevel5', 'MatV73')
%           SourceVariable, SourceDialect ('IdealCsv', 'RealisticCsv',
%           'Mat'), SampleCount, SourceSampleRate_Hz, SourceSampleCount
%           Canonical channel fields, Time_s, Available
%           SourceRowIdx, SourceTime_s, SourceFieldNames,
%           SynthesizedFields, UnitConversions, UnitsApplied
%       Data.MissingSensors, Data.Issues, Data.Warnings
%       Data.ExcludedSources, Data.Summary
%
%   Missing or malformed stream files never throw from this function:
%   they are reported per stream with Status and Issues (error identifiers
%   included). Invalid arguments and a missing run directory do throw.
%
%   Errors: Preprocessing:LoadSensorData:<Reason>
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: NormalizeSensorSchema, NormalizeSensorUnits,
%   SensorDataContracts, InspectRun.

    %% Validate Inputs

    if nargin < 3
        Format = 'Auto';
    end

    if ~(ischar(Format) || (isstring(Format) && isscalar(Format)))

        error( ...
            'Preprocessing:LoadSensorData:InvalidFormat', ...
            'Format must be a character vector or scalar string.');

    end

    Format = char(Format);
    ValidFormats = {'Auto', 'Csv', 'Mat'};

    if ~any(strcmp(Format, ValidFormats))

        error( ...
            'Preprocessing:LoadSensorData:InvalidFormat', ...
            'Format must be one of: %s.', ...
            strjoin(ValidFormats, ', '));

    end

    if nargin < 2 || isempty(Config)

        Config = preprocessing.PreprocessingConfig();

    end

    preprocessing.ValidatePreprocessingConfig(Config);

    if ~(ischar(RunDirectory) && isrow(RunDirectory)) && ...
            ~(isstring(RunDirectory) && isscalar(RunDirectory))

        error( ...
            'Preprocessing:LoadSensorData:InvalidRunDirectory', ...
            'RunDirectory must be a character vector or scalar string.');

    end

    RunDirectory = char(RunDirectory);

    if ~isfolder(RunDirectory)

        error( ...
            'Preprocessing:LoadSensorData:RunDirectoryNotFound', ...
            'Run directory "%s" does not exist.', ...
            RunDirectory);

    end

    Contracts = preprocessing.SensorDataContracts();
    SourceKind = char(Config.Source);

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        SourceFolder = Contracts.IMU.Files.IdealCsvFolder;

    else

        SourceFolder = Contracts.IMU.Files.RealisticCsvFolder;

    end

    %% Load Streams

    Streams = struct();
    MissingSensors = {};
    Issues = {};
    Warnings = {};
    SampleCounts = struct();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        [Stream, StreamIssues, StreamWarnings] = loadStream( ...
            RunDirectory, ...
            SourceFolder, ...
            StreamName, ...
            SourceKind, ...
            Format, ...
            Contracts);

        Streams.(StreamName) = Stream;
        SampleCounts.(StreamName) = Stream.SampleCount;

        if strcmp(Stream.Status, 'Missing')

            MissingSensors{end + 1} = StreamName;

        end

        for IssueIndex = 1:numel(StreamIssues)

            Issues{end + 1} = sprintf('%s | %s', ...
                StreamName, StreamIssues{IssueIndex});

        end

        for WarnIndex = 1:numel(StreamWarnings)

            Warnings{end + 1} = sprintf('%s | %s', ...
                StreamName, StreamWarnings{WarnIndex});

        end

    end

    %% Build Output

    Data = struct();
    Data.RunDirectory = RunDirectory;
    Data.Source = SourceKind;
    Data.Format = Format;
    Data.Streams = Streams;
    Data.MissingSensors = MissingSensors;
    Data.Issues = Issues;
    Data.Warnings = Warnings;
    Data.ExcludedSources = {'GroundTruthTelemetry', 'Block7'};

    Statuses = cellfun(@(Name) Streams.(Name).Status, ...
        Contracts.Streams, 'UniformOutput', false);

    Data.Summary = struct( ...
        'LoadedCount', sum(strcmp(Statuses, 'Loaded')), ...
        'MissingCount', sum(strcmp(Statuses, 'Missing')), ...
        'MalformedCount', sum(strcmp(Statuses, 'Malformed')), ...
        'SampleCounts', SampleCounts);

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function [Stream, Issues, Warnings] = loadStream( ...
    RunDirectory, ...
    SourceFolder, ...
    StreamName, ...
    SourceKind, ...
    Format, ...
    Contracts)
%LOADSTREAM Load one stream with the documented format preference.

    Issues = {};
    Warnings = {};
    Stream = streamTemplate(StreamName, Contracts);

    StreamContract = Contracts.(StreamName);

    CsvIssues = {};
    PreferCsv = ~strcmp(Format, 'Mat');
    PreferMat = ~strcmp(Format, 'Csv');

    if PreferCsv

        CsvPath = fullfile(RunDirectory, SourceFolder, ...
            csvFileName(StreamContract.Files, SourceKind));

        if isfile(CsvPath)

            try

                [Raw, ~] = readCsvRaw(CsvPath);

                Stream = finalizeStream(Stream, Raw, StreamName, ...
                    dialectName(SourceKind), CsvPath, 'Csv', '', ...
                    NaN, NaN);

                return;

            catch Failure

                CsvIssues{end + 1} = sprintf('%s: %s', ...
                    Failure.identifier, Failure.message);

            end

        end

    end

    if PreferMat

        MatPath = fullfile(RunDirectory, SourceFolder, ...
            matFileName(StreamContract.Files, SourceKind));

        if isfile(MatPath)

            try

                [Raw, VarName, MatFormat, SourceRate, SourceCount] = ...
                    readMatStream(MatPath, StreamName, ...
                        expectedMatVariable(StreamContract.Files, ...
                            SourceKind));

                Stream = finalizeStream(Stream, Raw, StreamName, 'Mat', ...
                    MatPath, MatFormat, VarName, ...
                    SourceRate, SourceCount);

                if ~isempty(CsvIssues)

                    Warnings = [Warnings, CsvIssues, ...
                        {'CSV read failed; MAT fallback used.'}];

                end

                return;

            catch Failure

                Issues = [CsvIssues, {sprintf('%s: %s', ...
                    Failure.identifier, Failure.message)}];
                Stream.Status = 'Malformed';
                Stream.Issues = Issues;
                return;

            end

        end

    end

    if ~isempty(CsvIssues)

        Issues = CsvIssues;
        Stream.Status = 'Malformed';

    else

        Stream.Status = 'Missing';
        Issues = {'Sensor files not found for the requested format.'};

    end

    Stream.Issues = Issues;

end

function Stream = streamTemplate(StreamName, Contracts)
%STREAMTEMPLATE Consistent per-stream output shape (empty data).

    Template = struct( ...
        'Status', 'Missing', ...
        'Issues', {{}}, ...
        'Warnings', {{}}, ...
        'SourceFile', '', ...
        'SourceFormat', '', ...
        'SourceVariable', '', ...
        'SourceDialect', '', ...
        'SampleCount', 0, ...
        'SourceSampleRate_Hz', NaN, ...
        'SourceSampleCount', NaN, ...
        'UnitsApplied', false, ...
        'SourceRowIdx', zeros(0, 1), ...
        'SourceTime_s', zeros(0, 1), ...
        'SourceFieldNames', struct(), ...
        'SynthesizedFields', {{}}, ...
        'UnitConversions', struct());
    Stream = Template;

    Channels = Contracts.(StreamName).Channels;

    for Index = 1:numel(Channels)

        Stream.(Channels(Index).CanonicalField) = zeros(0, 1);

    end

end

function Stream = finalizeStream( ...
    Stream, ...
    Raw, ...
    StreamName, ...
    SourceDialect, ...
    SourceFile, ...
    SourceFormat, ...
    SourceVariable, ...
    SourceRate, ...
    SourceCount)
%FINALIZESTREAM Schema + unit normalization and metadata stamping.

    SchemaStream = preprocessing.NormalizeSensorSchema( ...
        Raw, StreamName, SourceDialect);
    SchemaStream = preprocessing.NormalizeSensorUnits( ...
        SchemaStream, StreamName);

    FieldNames = fieldnames(SchemaStream);

    for Index = 1:numel(FieldNames)

        Stream.(FieldNames{Index}) = SchemaStream.(FieldNames{Index});

    end

    Stream.Status = 'Loaded';
    Stream.SourceFile = SourceFile;
    Stream.SourceFormat = SourceFormat;
    Stream.SourceVariable = SourceVariable;
    Stream.SourceDialect = SourceDialect;
    Stream.SourceSampleRate_Hz = SourceRate;
    Stream.SourceSampleCount = SourceCount;

end

function [Raw, HeaderNames] = readCsvRaw(FilePath)
%READCSVRAW Read one CSV into raw source-named columns.

    fid = fopen(FilePath, 'r');

    if fid < 0

        error( ...
            'Preprocessing:LoadSensorData:FileOpenFailure', ...
            'CSV file "%s" could not be opened.', ...
            FilePath);

    end

    Cleanup = onCleanup(@() fclose(fid));
    HeaderLine = fgetl(fid);

    if ~ischar(HeaderLine)

        error( ...
            'Preprocessing:LoadSensorData:EmptyFile', ...
            'CSV file "%s" has no header line.', ...
            FilePath);

    end

    HeaderNames = strsplit(HeaderLine, ',');
    HeaderNames = strrep(HeaderNames, char(13), '');

    if isempty(HeaderNames) || any(cellfun(@isempty, HeaderNames)) || ...
            ~all(cellfun(@isvarname, HeaderNames))

        error( ...
            'Preprocessing:LoadSensorData:MalformedHeader', ...
            'CSV file "%s" has a malformed header line.', ...
            FilePath);

    end

    Values = readmatrix(FilePath, 'NumHeaderLines', 1);

    if isempty(Values) || size(Values, 2) ~= numel(HeaderNames)

        error( ...
            'Preprocessing:LoadSensorData:MalformedFile', ...
            ['CSV file "%s" data block does not match its header ', ...
             'width or is empty.'], ...
            FilePath);

    end

    Raw = struct();

    for Index = 1:numel(HeaderNames)

        Raw.(HeaderNames{Index}) = Values(:, Index);

    end

end

function [Raw, VarName, MatFormat, SourceRate, SourceCount] = ...
    readMatStream(FilePath, StreamName, ExpectedVariable)
%READMATSTREAM Discover the telemetry variable and extract one stream.

    MatFormat = detectMatFormat(FilePath);

    try

        Info = whos('-file', FilePath);
        VarNames = sort({Info.name});

        if any(strcmp(VarNames, ExpectedVariable))

            VarNames = [ ...
                ExpectedVariable, ...
                VarNames(~strcmp(VarNames, ExpectedVariable))];

        end

    catch Failure

        error( ...
            'Preprocessing:LoadSensorData:MalformedMatFile', ...
            'MAT file "%s" is unreadable: %s', ...
            FilePath, ...
            Failure.message);

    end

    for Index = 1:numel(VarNames)

        Candidate = VarNames{Index};

        try

            Loaded = load(FilePath, Candidate);

        catch

            continue;

        end

        Value = Loaded.(Candidate);

        if ~isstruct(Value) || ~isscalar(Value)

            continue;

        end

        if isfield(Value, StreamName) && isstruct(Value.(StreamName)) && ...
                isscalar(Value.(StreamName))

            Sub = Value.(StreamName);

        elseif isfield(Value, 'Time_s')

            Sub = Value;

        else

            continue;

        end

        if ~isfield(Sub, 'Time_s')

            continue;

        end

        [Raw, SourceRate, SourceCount] = splitMatStream(Sub);
        VarName = Candidate;
        return;

    end

    error( ...
        'Preprocessing:LoadSensorData:NoSuitableVariable', ...
        ['MAT file "%s" contains no variable structurally providing ', ...
         'stream "%s".'], ...
        FilePath, ...
        StreamName);

end

function [Raw, SourceRate, SourceCount] = splitMatStream(Sub)
%SPLITMATSTREAM Separate bookkeeping fields from channel fields.

    Raw = Sub;
    SourceRate = NaN;
    SourceCount = NaN;

    if isfield(Raw, 'SampleRate_Hz')

        SourceRate = Raw.SampleRate_Hz;
        Raw = rmfield(Raw, 'SampleRate_Hz');

    end

    if isfield(Raw, 'SampleCount')

        SourceCount = Raw.SampleCount;
        Raw = rmfield(Raw, 'SampleCount');

    end

end

function MatFormat = detectMatFormat(FilePath)
%DETECTMATFORMAT Classify MAT format from the file header text.

    fid = fopen(FilePath, 'rb');

    if fid < 0

        error( ...
            'Preprocessing:LoadSensorData:FileOpenFailure', ...
            'MAT file "%s" could not be opened.', ...
            FilePath);

    end

    Cleanup = onCleanup(@() fclose(fid));
    Head = fread(fid, 128, '*char')';

    if contains(Head, '7.3')

        MatFormat = 'MatV73';

    elseif contains(Head, 'MATLAB')

        MatFormat = 'MatLevel5';

    else

        MatFormat = 'MatUnknown';

    end

end

function Name = csvFileName(Files, SourceKind)
%CSVFILENAME Source CSV file name for the configured source.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        Name = Files.IdealCsvFile;

    else

        Name = Files.RealisticCsvFile;

    end

end

function Name = matFileName(Files, SourceKind)
%MATFILENAME Source MAT file name for the configured source.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        Name = Files.IdealMatFile;

    else

        Name = Files.RealisticMatFile;

    end

end

function Name = expectedMatVariable(Files, SourceKind)
%EXPECTEDMATVARIABLE Preferred MAT variable name for the source.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        Name = Files.IdealMatVariable;

    else

        Name = Files.RealisticMatVariable;

    end

end

function Dialect = dialectName(SourceKind)
%DIALECTNAME CSV schema dialect name for the configured source.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        Dialect = 'IdealCsv';

    else

        Dialect = 'RealisticCsv';

    end

end
