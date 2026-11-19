function [Artifacts, FinalizedReport] = ExportPreprocessedData( ...
    Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory, ...
    TestFailureInjection)
%EXPORTPREPROCESSEDDATA Export MAT, JSON and review CSV artifacts.
%
%   Artifacts = EXPORTPREPROCESSEDDATA(Config, Data, ProcessedStreams,
%   Aligned, Report, OutputDirectory) writes the approved output layout:
%
%       <OutputDirectory>/PreprocessedData.mat
%       <OutputDirectory>/PreprocessingReport.json
%       <OutputDirectory>/Review/<Stream>.csv   (loaded streams only)
%
%   MAT hierarchy (Level-5 / v7 format; documented in ProcessingInfo.
%   MatFormat; chosen for universal readability, dataset sizes are far
%   below the v7 limits):
%       PreprocessedData.RunInfo
%       PreprocessedData.Configuration
%       PreprocessedData.OriginalData
%       PreprocessedData.NativeRate
%       PreprocessedData.AlignedData
%       PreprocessedData.QualitySummary
%       PreprocessedData.ProcessingInfo
%
%   JSON: deterministic field names; logical values stay JSON booleans;
%   NaN/Inf numerics are converted to the explicit string markers
%   'NaN', 'Inf', '-Inf' so the document is always valid JSON; unknown or
%   unrecorded values appear as 'NotRecorded' / 'NotMeasured' strings from
%   BuildPreprocessingReport. The MAT keeps native numeric NaN values.
%
%   Review CSVs carry canonical SI-unit measurement columns plus
%   SourceRowIdx, Time_s, SegmentID, RowValid, MeasurementValid,
%   Available and one 0/1 column per row-level quality flag. Values are
%   never corrected, smoothed or replaced. No file is written for a
%   missing or malformed stream.
%
%   The destination must not already exist ('OutputDirectoryExists');
%   existing results are never overwritten. Every artifact is read back
%   and validated ('ReadBackValidationFailure'). The success report JSON
%   is published transactionally: written to a temporary file in the
%   output directory, decoded and PreprocessID-verified there, then
%   renamed to PreprocessingReport.json as the success commit point - no
%   failure-prone operation runs after publication. Temporary files are
%   removed on every failure path ('MatWriteFailure' / 'CsvWriteFailure'
%   / 'JsonWriteFailure'). The optional trailing TestFailureInjection
%   argument is a test-only seam ('', 'JsonTempWrite',
%   'JsonTempReadBack', 'JsonPreprocessIDMismatch', 'JsonPublish').
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: BuildPreprocessingReport, PreprocessRun, GetPreprocessingReport.

    %% Validate Inputs

    preprocessing.ValidatePreprocessingConfig(Config);

    if nargin < 7

        TestFailureInjection = '';

    end

    AllowedInjections = { ...
        '', 'JsonTempWrite', 'JsonTempReadBack', ...
        'JsonPreprocessIDMismatch', 'JsonPublish', ...
        'MatCorrupt', 'MatSectionMissing', 'MatPreprocessIDWrong', ...
        'CsvTruncated', 'CsvMissingColumn', 'CsvColumnOrder', ...
        'CsvInvalidNumeric', 'CsvSourceRowIdx', 'CsvTimestamp', ...
        'CsvFlag', 'CsvMeasurement'};

    if ~(ischar(TestFailureInjection) || ...
            (isstring(TestFailureInjection) && ...
            isscalar(TestFailureInjection))) || ...
            ~any(strcmp(char(TestFailureInjection), AllowedInjections))

        error( ...
            'Preprocessing:ExportPreprocessedData:InvalidOptions', ...
            ['TestFailureInjection must be empty or one of: ', ...
             'JsonTempWrite, JsonTempReadBack, JsonPreprocessIDMismatch, ', ...
             'JsonPublish (test-only seam).']);

    end

    if ~(ischar(OutputDirectory) || ...
            (isstring(OutputDirectory) && isscalar(OutputDirectory)))

        error( ...
            'Preprocessing:ExportPreprocessedData:InvalidOutputDirectory', ...
            'OutputDirectory must be a character vector or scalar string.');

    end

    OutputDirectory = char(OutputDirectory);

    if isfile(OutputDirectory)

        error( ...
            'Preprocessing:ExportPreprocessedData:InvalidOutputDirectory', ...
            '"%s" exists and is a file.', ...
            OutputDirectory);

    end

    if isfolder(OutputDirectory)

        Listing = dir(OutputDirectory);
        Listing = Listing(~ismember({Listing.name}, {'.', '..'}));

        if ~isempty(Listing)

            error( ...
                ['Preprocessing:ExportPreprocessedData:', ...
                 'OutputDirectoryExists'], ...
                ['Output directory "%s" already contains files; ', ...
                 'existing results are never overwritten.'], ...
                OutputDirectory);

        end

        % An empty existing directory is accepted (it may have been
        % reserved by PreprocessRun's unique-ID allocation).

    else

        ParentDirectory = fileparts(OutputDirectory);

        if ~isempty(ParentDirectory) && ~isfolder(ParentDirectory) && ...
                isfile(ParentDirectory)

            error( ...
                ['Preprocessing:ExportPreprocessedData:', ...
                 'InvalidOutputDirectory'], ...
                'Parent of "%s" is an existing file.', ...
                OutputDirectory);

        end

        try

            [Created, Message] = mkdir(OutputDirectory);

        catch CreationFailure

            error( ...
                ['Preprocessing:ExportPreprocessedData:', ...
                 'InvalidOutputDirectory'], ...
                'Output directory "%s" could not be created: %s', ...
                OutputDirectory, ...
                CreationFailure.message);

        end

        if ~Created || ~isfolder(OutputDirectory)

            error( ...
                ['Preprocessing:ExportPreprocessedData:', ...
                 'InvalidOutputDirectory'], ...
                'Output directory "%s" could not be created: %s', ...
                OutputDirectory, ...
                Message);

        end

    end

    %% Export Review CSVs

    ReviewDirectory = fullfile(OutputDirectory, 'Review');

    if ~isfolder(ReviewDirectory)

        [Created, Message] = mkdir(ReviewDirectory);

        if ~Created

            error( ...
                ['Preprocessing:ExportPreprocessedData:', ...
                 'CsvWriteFailure'], ...
                'Review directory could not be created: %s', ...
                Message);

        end

    end

    ReviewFiles = struct();

    for Index = 1:numel(preprocessing.SensorDataContracts().Streams)

        StreamName = preprocessing.SensorDataContracts().Streams{Index};

        if ~isfield(ProcessedStreams, StreamName) || ...
                ~strcmp(ProcessedStreams.(StreamName).Status, 'Loaded')

            continue;

        end

        CsvFile = fullfile(ReviewDirectory, [StreamName '.csv']);

        try

            writeReviewCsv(CsvFile, ProcessedStreams.(StreamName), ...
                StreamName);

        catch CsvFailure

            error( ...
                ['Preprocessing:ExportPreprocessedData:', ...
                 'CsvWriteFailure'], ...
                'CSV export to "%s" failed: %s', ...
                CsvFile, ...
                CsvFailure.message);

        end

        ReviewFiles.(StreamName) = CsvFile;

    end

    % Test-only corruption seam (never active on the default path): the
    % CSV read-back validators below must reject these artifacts.
    if startsWith(char(TestFailureInjection), 'Csv')

        corruptCsvForTest( ...
            fullfile(ReviewDirectory, 'IMU.csv'), ...
            char(TestFailureInjection));

    end

    %% Finalize Output Inventory (F-04)
    % Only files actually written are listed as completed outputs; the
    % four contract paths remain available as ExpectedReviewFiles.

    Report.Outputs.ReviewFiles = ReviewFiles;
    Report.Outputs.ReviewFilesStatus = 'Written';

    %% Export MAT

    MatFile = fullfile(OutputDirectory, 'PreprocessedData.mat');

    PreprocessedData = buildMatHierarchy( ...
        Config, Data, ProcessedStreams, Aligned, Report, ...
        Report.RunInfo.PreprocessID);

    try

        save(MatFile, 'PreprocessedData', '-v7');

    catch MatFailure

        error( ...
            'Preprocessing:ExportPreprocessedData:MatWriteFailure', ...
            'MAT export to "%s" failed: %s', ...
            MatFile, ...
            MatFailure.message);

    end

    % Test-only corruption seam (never active on the default path): the
    % read-back validators below must reject these artifacts.
    switch char(TestFailureInjection)

        case 'MatCorrupt'

            fid = fopen(MatFile, 'w');
            fprintf(fid, 'not a mat file');
            fclose(fid);

        case 'MatSectionMissing'

            Tmp = load(MatFile);
            PreprocessedData = rmfield( ...
                Tmp.PreprocessedData, 'AlignedData');
            save(MatFile, 'PreprocessedData', '-v7');

        case 'MatPreprocessIDWrong'

            Tmp = load(MatFile);
            PreprocessedData = Tmp.PreprocessedData;
            PreprocessedData.ProcessingInfo.PreprocessID = ...
                'Run_000_00000000_000000__PP_00000000_000000_99';
            save(MatFile, 'PreprocessedData', '-v7');

    end

    %% Read-Back Validation (MAT and review CSVs)

    try

        Loaded = load(MatFile);

        if ~isfield(Loaded, 'PreprocessedData')

            error('MAT file does not contain PreprocessedData.');

        end

        RequiredSections = { ...
            'RunInfo', 'Configuration', 'OriginalData', 'NativeRate', ...
            'AlignedData', 'QualitySummary', 'ProcessingInfo'};

        for SectionIndex = 1:numel(RequiredSections)

            if ~isfield(Loaded.PreprocessedData, ...
                    RequiredSections{SectionIndex})

                error('MAT hierarchy missing section %s.', ...
                    RequiredSections{SectionIndex});

            end

        end

        StreamNames = fieldnames(ReviewFiles);

        % F-06 content round-trip: ProcessingInfo consistency and
        % GroundTruth exclusion are verified on every export.
        if ~strcmp(Loaded.PreprocessedData.ProcessingInfo.PreprocessID, ...
                Report.RunInfo.PreprocessID)

            error('MAT ProcessingInfo PreprocessID does not match.');

        end

        if ~isfield(Loaded.PreprocessedData.ProcessingInfo, ...
                'GroundTruthExcluded') || ~isequal( ...
                Loaded.PreprocessedData.ProcessingInfo.GroundTruthExcluded, ...
                true)

            error('MAT GroundTruthExcluded flag missing or false.');

        end

        for StreamIndex = 1:numel(StreamNames)

            StreamName = StreamNames{StreamIndex};
            TableData = readtable(ReviewFiles.(StreamName));
            Stream = ProcessedStreams.(StreamName);
            Pd = Loaded.PreprocessedData;

            % MAT OriginalData audit rows and NativeRate measurement
            % content must round-trip exactly.
            if ~isfield(Pd.OriginalData, StreamName) || ...
                    ~isequaln(Pd.OriginalData.(StreamName).SourceRowIdx, ...
                    Data.Streams.(StreamName).SourceRowIdx) || ...
                    ~isequaln(Pd.OriginalData.(StreamName).SourceTime_s, ...
                    Data.Streams.(StreamName).SourceTime_s)

                error('MAT OriginalData %s failed content validation.', ...
                    StreamName);

            end

            if ~isfield(Pd.NativeRate, StreamName) || ...
                    ~isequaln(Pd.NativeRate.(StreamName), Stream)

                error('MAT NativeRate %s failed content validation.', ...
                    StreamName);

            end

            % CSV round-trip: exact schema and column order, row count,
            % provenance, original timestamps, flags and measurement
            % values.
            ExpectedColumns = expectedCsvColumns(StreamName);

            if ~isequal(TableData.Properties.VariableNames, ...
                    ExpectedColumns)

                error('CSV "%s" column schema/order mismatch.', ...
                    StreamName);

            end

            if height(TableData) ~= Stream.SampleCount || ...
                    ~isequaln(TableData.SourceRowIdx(:), ...
                    Stream.SourceRowIdx(:))

                error('CSV "%s" failed read-back validation.', ...
                    StreamName);

            end

            % Defect correction (closure): columns 2-6 (Time_s,
            % SegmentID, RowValid, MeasurementValid, Available) were
            % written but never compared on read-back; original timestamp
            % corruption could pass silently. All written columns are now
            % validated.
            for ColumnIndex = 2:numel(ExpectedColumns)

                ColumnName = ExpectedColumns{ColumnIndex};
                TableValues = TableData.(ColumnName);

                if strncmp(ColumnName, 'Flags_', 6)

                    StreamValues = Stream.Flags.(ColumnName(7:end));

                else

                    StreamValues = Stream.(ColumnName);

                end

                if ~numericColumnsMatch(TableValues, StreamValues)

                    error('CSV "%s" column %s failed read-back.', ...
                        StreamName, ColumnName);

                end

            end

        end

    catch ValidationFailure

        error( ...
            ['Preprocessing:ExportPreprocessedData:', ...
             'ReadBackValidationFailure'], ...
            'Exported artifacts failed read-back validation: %s', ...
            ValidationFailure.message);

    end

    %% Export JSON (transactional: temporary -> validate -> publish)
    % Publication under the final name is the success commit point: no
    % failure-prone operation runs after it. A failed export can never
    % leave a retrievable success report.

    JsonFile = fullfile(OutputDirectory, 'PreprocessingReport.json');
    TempJsonFile = fullfile(OutputDirectory, 'PreprocessingReport.json.tmp');

    try

        if strcmp(char(TestFailureInjection), 'JsonTempWrite')

            error('simulated temporary JSON write failure');

        end

        JsonText = jsonencode(jsonSafe(Report), 'PrettyPrint', true);
        fid = fopen(TempJsonFile, 'w');

        if fid < 0

            error('temporary JSON file could not be created');

        end

        try

            fprintf(fid, '%s\n', JsonText);

        catch WriteFailure

            fclose(fid);
            rethrow(WriteFailure);

        end

        fclose(fid);

        if strcmp(char(TestFailureInjection), 'JsonTempReadBack')

            fid = fopen(TempJsonFile, 'w');
            fprintf(fid, 'not valid json {{{');
            fclose(fid);

        elseif strcmp(char(TestFailureInjection), 'JsonPreprocessIDMismatch')

            fid = fopen(TempJsonFile, 'w');
            fprintf(fid, '%s\n', jsonencode(struct('RunInfo', ...
                struct('PreprocessID', ...
                'Run_000_00000000_000000__PP_00000000_000000_99'))));
            fclose(fid);

        end

    catch JsonFailure

        safeDelete(TempJsonFile);
        error( ...
            'Preprocessing:ExportPreprocessedData:JsonWriteFailure', ...
            'JSON export to "%s" failed: %s', ...
            TempJsonFile, ...
            JsonFailure.message);

    end

    %% Validate Temporary JSON Before Publication

    try

        Decoded = jsondecode(fileread(TempJsonFile));

        if ~isstruct(Decoded) || ~isfield(Decoded, 'RunInfo') || ...
                ~isfield(Decoded.RunInfo, 'PreprocessID') || ...
                ~strcmp(Decoded.RunInfo.PreprocessID, ...
                Report.RunInfo.PreprocessID)

            error('temporary JSON PreprocessID does not match.');

        end

        if ~isfield(Decoded.RunInfo, 'Status') || ...
                ~strcmp(Decoded.RunInfo.Status, Report.Status)

            error('temporary JSON RunInfo.Status does not match.');

        end

        if ~isfield(Decoded.RunInfo, 'ApprovalUsed') || ...
                ~islogical(Decoded.RunInfo.ApprovalUsed)

            error('temporary JSON logical fields lost their type.');

        end

        DecodedReview = {};

        if isfield(Decoded, 'Outputs') && isstruct(Decoded.Outputs) && ...
                isfield(Decoded.Outputs, 'ReviewFiles') && ...
                isstruct(Decoded.Outputs.ReviewFiles)

            DecodedReview = fieldnames(Decoded.Outputs.ReviewFiles);

        end

        if ~isequal(sort(DecodedReview), sort(fieldnames(ReviewFiles)))

            error(['temporary JSON Outputs.ReviewFiles does not ', ...
                'match the written files.']);

        end

    catch ValidationFailure

        safeDelete(TempJsonFile);
        error( ...
            ['Preprocessing:ExportPreprocessedData:', ...
             'ReadBackValidationFailure'], ...
            'Temporary JSON failed read-back validation: %s', ...
            ValidationFailure.message);

    end

    %% Publish JSON (success commit point)

    if strcmp(char(TestFailureInjection), 'JsonPublish')

        safeDelete(TempJsonFile);

    end

    [Published, Message] = movefile(TempJsonFile, JsonFile);

    if ~Published

        safeDelete(TempJsonFile);
        error( ...
            'Preprocessing:ExportPreprocessedData:JsonWriteFailure', ...
            'JSON publication to "%s" failed: %s', ...
            JsonFile, ...
            Message);

    end

    %% Build Output

    Artifacts = struct();
    Artifacts.OutputDirectory = OutputDirectory;
    Artifacts.MatFile = MatFile;
    Artifacts.JsonFile = JsonFile;
    Artifacts.ReviewDirectory = ReviewDirectory;
    Artifacts.ReviewFiles = ReviewFiles;
    Artifacts.MatFormat = 'Level-5 (v7)';
    Artifacts.Validated = true;
    FinalizedReport = Report;

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function PreprocessedData = buildMatHierarchy( ...
    Config, Data, ProcessedStreams, Aligned, Report, PreprocessID)
%BUILDMATHIERARCHY Assemble the approved seven-section MAT structure.

    Contracts = preprocessing.SensorDataContracts();

    PreprocessedData = struct();
    PreprocessedData.RunInfo = Report.RunInfo;
    PreprocessedData.Configuration = struct( ...
        'Config', Config, ...
        'Provenance', Report.ConfigurationProvenance);

    OriginalData = struct();
    NativeRate = struct();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if ~isfield(Data.Streams, StreamName)

            continue;

        end

        LoadedStream = Data.Streams.(StreamName);

        OriginalData.(StreamName) = struct( ...
            'LoadStatus', LoadedStream.Status, ...
            'SourceFile', LoadedStream.SourceFile, ...
            'SourceFormat', LoadedStream.SourceFormat, ...
            'SourceVariable', LoadedStream.SourceVariable, ...
            'SourceDialect', LoadedStream.SourceDialect, ...
            'SourceRowIdx', LoadedStream.SourceRowIdx, ...
            'SourceTime_s', LoadedStream.SourceTime_s, ...
            'SourceFieldNames', LoadedStream.SourceFieldNames, ...
            'SynthesizedFields', {LoadedStream.SynthesizedFields}, ...
            'UnitConversions', LoadedStream.UnitConversions, ...
            'SourceSampleRate_Hz', LoadedStream.SourceSampleRate_Hz, ...
            'SourceSampleCount', LoadedStream.SourceSampleCount, ...
            'LoadIssues', {LoadedStream.Issues}, ...
            'LoadWarnings', {LoadedStream.Warnings});

        if isfield(ProcessedStreams, StreamName) && ...
                strcmp(ProcessedStreams.(StreamName).Status, 'Loaded')

            NativeRate.(StreamName) = ProcessedStreams.(StreamName);

        end

    end

    PreprocessedData.OriginalData = OriginalData;
    PreprocessedData.NativeRate = NativeRate;
    PreprocessedData.AlignedData = Aligned;

    QualitySummary = struct();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if isfield(ProcessedStreams, StreamName) && ...
                strcmp(ProcessedStreams.(StreamName).Status, 'Loaded')

            Stream = ProcessedStreams.(StreamName);
            QualitySummary.(StreamName) = struct( ...
                'TimestampSummary', Stream.TimestampSummary, ...
                'QualitySummary', Stream.QualitySummary, ...
                'OutlierSummary', Stream.OutlierSummary, ...
                'OutageCount', numel(Stream.Outages), ...
                'SegmentCount', numel(Stream.Segments));

        else

            QualitySummary.(StreamName) = 'NotMeasured';

        end

    end

    PreprocessedData.QualitySummary = QualitySummary;

    PreprocessedData.ProcessingInfo = struct( ...
        'PreprocessID', PreprocessID, ...
        'Status', Report.Status, ...
        'ProcessingTimestamp', Report.RunInfo.ProcessingTimestamp, ...
        'MATLABRelease', Report.RunInfo.MATLABRelease, ...
        'MATLABVersion', Report.RunInfo.MATLABVersion, ...
        'MatFormat', 'Level-5 (v7)', ...
        'ArtifactPaths', Report.Outputs, ...
        'Warnings', {Report.Warnings}, ...
        'Errors', {Report.Errors}, ...
        'ExcludedSources', {Data.ExcludedSources}, ...
        'GroundTruthExcluded', true);

end

function writeReviewCsv(CsvFile, Stream, StreamName)
%WRITEREVIEWCSV Write one normalized review CSV (values unmodified).

    FlagNames = { ...
        'NonFiniteTimestamp', 'BackwardTimestamp', ...
        'DuplicateTimestampLater', 'UnexpectedGap', 'Unavailable', ...
        'NonFiniteMeasurement', 'PhysicalOutlier', 'StatisticalOutlier', ...
        'SuddenChange', 'StartupTransient'};

    Columns = table();
    Columns.SourceRowIdx = Stream.SourceRowIdx;
    Columns.Time_s = Stream.Time_s;
    Columns.SegmentID = Stream.SegmentID;
    Columns.RowValid = double(Stream.RowValid);
    Columns.MeasurementValid = double(Stream.MeasurementValid);
    Columns.Available = double(Stream.Available);

    for Index = 1:numel(FlagNames)

        Columns.(['Flags_' FlagNames{Index}]) = ...
            double(Stream.Flags.(FlagNames{Index}));

    end

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(StreamName).Channels;

    for Index = 1:numel(Channels)

        FieldName = Channels(Index).CanonicalField;

        if ~strcmp(FieldName, 'Time_s') && ~strcmp(FieldName, 'Available')

            Columns.(FieldName) = Stream.(FieldName);

        end

    end

    writetable(Columns, CsvFile);

end

function Value = jsonSafe(Value)
%JSONSAFE Recursively convert NaN/Inf numerics to explicit markers.

    if isstruct(Value)

        Names = fieldnames(Value);

        for Index = 1:numel(Value)

            for NameIndex = 1:numel(Names)

                Value(Index).(Names{NameIndex}) = ...
                    jsonSafe(Value(Index).(Names{NameIndex}));

            end

        end

    elseif iscell(Value)

        for Index = 1:numel(Value)

            Value{Index} = jsonSafe(Value{Index});

        end

    elseif isnumeric(Value) && ~islogical(Value)

        Mask = ~isfinite(Value);

        if any(Mask(:))

            CellValue = num2cell(Value);

            for Index = 1:numel(CellValue)

                Element = CellValue{Index};

                if isnan(Element)

                    CellValue{Index} = 'NaN';

                elseif Element == Inf

                    CellValue{Index} = 'Inf';

                elseif Element == -Inf

                    CellValue{Index} = '-Inf';

                end

            end

            if isscalar(Value)
                Value = CellValue{1};
            else
                Value = CellValue;
            end
        end
    end

end

function safeDelete(FilePath)
%SAFEDELETE Best-effort removal of an unpublished temporary file.

    try

        if isfile(FilePath)

            delete(FilePath);

        end

    catch

        % Best-effort cleanup only; the typed error already reported.

    end

end

function corruptCsvForTest(CsvFile, Mode)
%CORRUPTCSVFORTEST Test-only artifact corruption (seam support).

    TableData = readtable(CsvFile);

    switch Mode

        case 'CsvTruncated'

            TableData = TableData(1:2, :);

        case 'CsvMissingColumn'

            TableData.Time_s = [];

        case 'CsvColumnOrder'

            Names = TableData.Properties.VariableNames;
            First = Names{7};
            Names{7} = Names{8};
            Names{8} = First;
            TableData = TableData(:, [1:6, 8, 7, 9:numel(Names)]);

        case 'CsvInvalidNumeric'

            Column = TableData.Accelerometer_X_mps2;
            Cells = num2cell(Column);
            Cells{1} = 'garbage';
            TableData.Accelerometer_X_mps2 = Cells;

        case 'CsvSourceRowIdx'

            TableData.SourceRowIdx = TableData.SourceRowIdx + 1;

        case 'CsvTimestamp'

            TableData.Time_s = TableData.Time_s + 0.5;

        case 'CsvFlag'

            TableData.Flags_Unavailable = ...
                1 - TableData.Flags_Unavailable;

        case 'CsvMeasurement'

            TableData.Accelerometer_Z_mps2 = ...
                TableData.Accelerometer_Z_mps2 + 1;

    end

    writetable(TableData, CsvFile);

end

function Names = expectedCsvColumns(StreamName)
%EXPECTEDCOLUMNS Canonical review CSV schema and column order.

    Names = {'SourceRowIdx', 'Time_s', 'SegmentID', 'RowValid', ...
        'MeasurementValid', 'Available'};
    FlagNames = { ...
        'NonFiniteTimestamp', 'BackwardTimestamp', ...
        'DuplicateTimestampLater', 'UnexpectedGap', 'Unavailable', ...
        'NonFiniteMeasurement', 'PhysicalOutlier', 'StatisticalOutlier', ...
        'SuddenChange', 'StartupTransient'};

    for Index = 1:numel(FlagNames)

        Names{end + 1} = ['Flags_' FlagNames{Index}];

    end

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(StreamName).Channels;

    for Index = 1:numel(Channels)

        FieldName = Channels(Index).CanonicalField;

        if ~strcmp(FieldName, 'Time_s') && ~strcmp(FieldName, 'Available')

            Names{end + 1} = FieldName;

        end

    end

end

function TF = numericColumnsMatch(A, B)
%NUMERICCOLUMNSMATCH FP-text-safe column comparison.

    A = A(:);
    B = B(:);

    if numel(A) ~= numel(B)

        TF = false;
        return;

    end

    Equal = (A == B) | (isnan(A) & isnan(B));
    Close = abs(A - B) <= 1e-12 .* max(1, abs(B));
    TF = all(Equal | Close);

end
