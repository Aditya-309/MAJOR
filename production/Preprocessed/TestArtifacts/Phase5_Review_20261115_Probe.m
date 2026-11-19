function Phase5_Review_20261115_Probe()
%PHASE5_REVIEW_20261115_PROBE Independent read-only review probes for
%Block 9 Phase 5. Review evidence only; uses isolated synthetic fixtures
%under TestArtifacts and writes nothing outside this folder. It does not
%modify any implementation, test or production file.

    Root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(Root);
    RunStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    ProbeRoot = fullfile( ...
        fileparts(mfilename('fullpath')), ...
        ['Phase5_Review_20261115_ProbeWork_' RunStamp]);

    if ~isfolder(ProbeRoot)
        mkdir(ProbeRoot);
    end

    fprintf('== P1: SourceRowIdx provenance mapping ==\n');
    probeProvenance();

    fprintf('== P2: overlapping failure-category counts ==\n');
    probeOverlappingCounts();

    fprintf('== P3: exact maximum-age and coverage boundary ==\n');
    probeMaxAgeBoundary();

    fprintf('== P4: JSON numeric preservation ==\n');
    probeJsonNumerics(ProbeRoot);

    fprintf('== P5: failed-export artifact state ==\n');
    probeFailedExportState(ProbeRoot);

    fprintf('== P6: empty/degenerate streams safety ==\n');
    probeEmptyStreams();

    fprintf('== P7: report Outputs vs actually exported files ==\n');
    probeReportOutputs(ProbeRoot);

    fprintf('PROBES DONE\n');

end

% -------------------------------------------------------------------------

function probeProvenance()
%P1a The Phase-4 entry point hard-rejects SourceRowIdx ~= 1..N, so the
%    array index always equals the original source-file row inside the
%    sanctioned pipeline. P1b BuildAlignedSensorData itself trusts its
%    input without remapping through Stream.SourceRowIdx.

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 0.5, 'AirData', 0.5));

    % P1a: offset numbering must be rejected upstream.
    try
        buildStream('AirData', [0; 0.25; 0.55; 0.85; 0.95], ...
            (101:105).', {[10; 20; 30; 40; 50], ...
            [100; 200; 300; 400; 500]}, Config);
        fprintf('  [FINDING P1a] offset SourceRowIdx was NOT rejected.\n');
    catch Caught
        fprintf(['  [OK P1a] offset SourceRowIdx rejected upstream: ', ...
            '%s\n'], Caught.message);
    end

    % P1b: hand-built stream bypassing Phase 4 (contract violation)
    % exposes BuildAlignedSensorData's internal trust assumption.
    Ref = makeRawStream('IMU', (0:9).' * 0.1, (1:10).', ...
        {zeros(10, 1), zeros(10, 1), -9.8 * ones(10, 1), ...
         zeros(10, 1), zeros(10, 1), zeros(10, 1)});
    Src = makeRawStream('AirData', [0; 0.25; 0.55; 0.85; 0.95], ...
        (101:105).', {[10; 20; 30; 40; 50], ...
        [100; 200; 300; 400; 500]});

    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    Air = Aligned.Streams.AirData;

    fprintf('  ref rows carried (mapped)  : %s\n', ...
        mat2str(Aligned.ReferenceSourceRowIdx(1:3).'));
    fprintf('  source rows carried (raw)  : %s\n', ...
        mat2str(Air.SourceRowIdx.'));
    fprintf('  stream SourceRowIdx field  : %s\n', ...
        mat2str(Src.SourceRowIdx.'));

    if ~isequal(Air.SourceRowIdx, Src.SourceRowIdx(Air.SourceRowIdx))
        fprintf(['  [FINDING P1b] BuildAlignedSensorData stores the ', ...
            'ARRAY INDEX (lines 262/265), not Stream.SourceRowIdx(', ...
            'row); the reference side maps through the field (line ', ...
            '112). Safe only because ProcessSensorTimestamps.m:112 ', ...
            'enforces SourceRowIdx == (1:N)''. Defense-in-depth gap, ', ...
            'not a live pipeline defect.\n']);
    else
        fprintf('  [OK P1b] provenance mapped through Stream.SourceRowIdx\n');
    end

end

% -------------------------------------------------------------------------

function Stream = makeRawStream(SensorName, Time_s, SourceRowIdx, ...
    ChannelColumns)
%MAKERAWSTREAM Hand-built processed-shaped stream (bypasses Phase 4 on
%   purpose, to expose internal trust assumptions of the aligner).

    RowCount = numel(Time_s);
    Stream = struct();
    Stream.Status = 'Loaded';
    Stream.Time_s = Time_s(:);
    Stream.SourceRowIdx = SourceRowIdx(:);
    Stream.RowValid = true(RowCount, 1);
    Stream.SegmentID = ones(RowCount, 1);
    Stream.Available = true(RowCount, 1);
    Stream.MeasurementValid = true(RowCount, 1);
    Stream.NominalPeriod_s = 0.5;

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(SensorName).Channels;
    ColIdx = 0;

    for Index = 1:numel(Channels)

        FieldName = Channels(Index).CanonicalField;

        if strcmp(FieldName, 'Time_s') || strcmp(FieldName, 'Available')
            continue;
        end

        ColIdx = ColIdx + 1;
        Stream.(FieldName) = ChannelColumns{ColIdx}(:);

    end

end

% -------------------------------------------------------------------------

function probeOverlappingCounts()
%P2 Failure categories overlap and are counted independently.

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 0.5, 'AirData', 0.1));

    Ref = buildStream('IMU', 0.2, 1, ...
        {0, 0, -9.8, 0, 0, 0}, Config);
    Src = buildStream('AirData', 0, 1, {10, 100}, Config);

    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    C = Aligned.Summary.AirData;
    Air = Aligned.Streams.AirData;

    fprintf(['  ref 0.2 s vs source 0 s, MaxAge 0.1 s: ', ...
        'age=%.3f AgeOk=%d WithinCoverage=%d\n'], ...
        Air.SampleAge_s, Air.AgeOk, Air.WithinCoverage);
    fprintf(['  Total=%d Valid=%d Invalid=%d NoSource=%d Stale=%d ', ...
        'Beyond=%d Unavail=%d SrcInvalid=%d\n'], ...
        C.TotalSamples, C.ValidCount, C.InvalidCount, C.NoSourceCount, ...
        C.StaleCount, C.BeyondCoverageCount, C.SourceUnavailableCount, ...
        C.SourceInvalidCount);

    if C.StaleCount == 1 && C.BeyondCoverageCount == 1 && ...
            C.InvalidCount == 1
        fprintf(['  [OBSERVED P2] one invalid sample counted in BOTH ', ...
            'StaleCount and BeyondCoverageCount (categories overlap, ', ...
            'only Valid/Invalid partition the total); documented in ', ...
            'code as independent counts.\n']);
    end

end

% -------------------------------------------------------------------------

function probeMaxAgeBoundary()
%P3 Inclusive boundary semantics at age == MaxAge and tref == tlast.

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 0.5, 'AirData', 0.1));

    Ref = buildStream('IMU', [0.1; 0.2], [1; 2], ...
        {zeros(2, 1), zeros(2, 1), -9.8 * ones(2, 1), ...
         zeros(2, 1), zeros(2, 1), zeros(2, 1)}, Config);
    Src = buildStream('AirData', [0; 0.2], [1; 2], ...
        {[10; 20], [100; 200]}, Config);

    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    Air = Aligned.Streams.AirData;

    fprintf(['  age==MaxAge (0.1==0.1): AgeOk=%d ', ...
        '(INCLUSIVE at line 268: Age_s <= MaxAge_s)\n'], Air.AgeOk(1));
    fprintf(['  tref==tlast  (0.2==0.2): WithinCoverage=%d ', ...
        '(INCLUSIVE at line 269)\n'], Air.WithinCoverage(2));
    fprintf('  AlignedValid = [%d %d]\n', Air.AlignedValid);

end

% -------------------------------------------------------------------------

function probeJsonNumerics(ProbeRoot)
%P4 Finite numerics must remain JSON numbers; logicals stay booleans.

    [Config, Data, ProcessedStreams] = buildFixture(ProbeRoot, false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_910_20260101_000000__PP_20260101_000000_01');
    OutputDirectory = fullfile(ProbeRoot, 'JsonNumerics');
    RunInfo.OutputDirectory = OutputDirectory;

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    Report.FiniteArray = [1.5, 2.5, 3.5];
    Report.MixedArray = [1.5, NaN, Inf, -Inf];
    Report.ScalarFinite = 42.5;
    Report.ScalarNan = NaN;
    Report.TrueFlag = true;

    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory);
    Decoded = jsondecode(fileread(Artifacts.JsonFile));

    fprintf('  FiniteArray : %s (class %s)\n', ...
        mat2str(Decoded.FiniteArray), class(Decoded.FiniteArray));
    fprintf('  ScalarFinite: %g (class %s)\n', ...
        Decoded.ScalarFinite, class(Decoded.ScalarFinite));
    fprintf('  TrueFlag    : class %s\n', class(Decoded.TrueFlag));
    fprintf('  ScalarNan   : "%s"\n', Decoded.ScalarNan);
    fprintf('  MixedArray  :');
    disp(Decoded.MixedArray);

    if isnumeric(Decoded.FiniteArray) && ...
            isequal(Decoded.FiniteArray(:).', [1.5, 2.5, 3.5]) && ...
            isnumeric(Decoded.ScalarFinite) && ...
            islogical(Decoded.TrueFlag) && ...
            isnumeric(Decoded.MixedArray{1}) && ...
            strcmp(Decoded.MixedArray{2}, 'NaN')
        fprintf('  [OK P4] finite numerics numeric, non-finite marked, logical boolean.\n');
    else
        fprintf('  [FINDING P4] JSON type conversion problem, see above.\n');
    end

end

% -------------------------------------------------------------------------

function probeFailedExportState(ProbeRoot)
%P5 What remains on disk when export fails mid-way.

    [Config, Data, ProcessedStreams] = buildFixture(ProbeRoot, false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    Broken = ProcessedStreams;
    Broken.IMU.Time_s = Broken.IMU.Time_s(1:2);
    RunInfo = buildRunInfo('', ...
        'Run_911_20260101_000000__PP_20260101_000000_01');
    OutputDirectory = fullfile(ProbeRoot, 'FailedExport');
    RunInfo.OutputDirectory = OutputDirectory;
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, Broken, Aligned, RunInfo);

    try
        preprocessing.ExportPreprocessedData( ...
            Config, Data, Broken, Aligned, Report, OutputDirectory);
        fprintf('  [FINDING P5] broken stream exported without error!\n');
    catch Caught
        fprintf('  export error (expected): %s\n', Caught.identifier);
    end

    Listing = dir(OutputDirectory);
    Names = setdiff({Listing.name}, {'.', '..'});
    fprintf('  directory after FAILED export: %s\n', strjoin(Names, ', '));

    JsonFile = fullfile(OutputDirectory, 'PreprocessingReport.json');
    if isfile(JsonFile)
        Decoded = jsondecode(fileread(JsonFile));
        fprintf(['  [FINDING P5] leftover JSON claims RunInfo.Status = ', ...
            '"%s" although the export FAILED and Review CSVs are ', ...
            'missing. GetPreprocessingReport.m has no check for a ', ...
            'ProcessingFailed.txt marker (grep-verified).\n'], ...
            Decoded.RunInfo.Status);
    end

end

% -------------------------------------------------------------------------

function probeEmptyStreams()
%P6 Degenerate streams must not crash alignment.

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 0.5, 'AirData', 0.5));

    Ref = buildStream('IMU', (0:3).' * 0.1, (1:4).', ...
        {zeros(4, 1), zeros(4, 1), -9.8 * ones(4, 1), ...
         zeros(4, 1), zeros(4, 1), zeros(4, 1)}, Config);
    Ref.RowValid(:) = false;

    Src = buildStream('AirData', [0; 0.1], [1; 2], {[10; 20], [100; 200]}, ...
        Config);
    Src.RowValid(:) = false;

    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    fprintf('  all-invalid reference: Status=%s, %d aligned rows\n', ...
        Aligned.Status, numel(Aligned.Time_s));
    if strcmp(Aligned.Status, 'Generated') && isempty(Aligned.Time_s)
        fprintf('  [OK P6] empty reference handled without fabricated rows.\n');
    end

end

% -------------------------------------------------------------------------

function probeReportOutputs(ProbeRoot)
%P7 Report.Outputs lists CSVs that are never written for missing sensors.

    [Config, Data, ProcessedStreams] = buildFixture(ProbeRoot, true);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_912_20260101_000000__PP_20260101_000000_01');
    OutputDirectory = fullfile(ProbeRoot, 'OutputsProbe');
    RunInfo.OutputDirectory = OutputDirectory;
    RunInfo.Status = 'PARTIAL';

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory);

    fprintf('  Report.Outputs.ReviewFiles fields : %s\n', ...
        strjoin(fieldnames(Report.Outputs.ReviewFiles), ', '));
    fprintf('  Artifacts.ReviewFiles fields      : %s\n', ...
        strjoin(fieldnames(Artifacts.ReviewFiles), ', '));
    if isfield(Report.Outputs.ReviewFiles, 'GNSS') && ...
            ~isfield(Artifacts.ReviewFiles, 'GNSS') && ...
            ~isfile(Report.Outputs.ReviewFiles.GNSS)
        fprintf(['  [FINDING P7] JSON report names a GNSS review CSV ', ...
            'that is never written for the missing sensor.\n']);
    end

end

% -------------------------------------------------------------------------
%% FIXTURE HELPERS (synthetic; nothing touches production data)
% -------------------------------------------------------------------------

function Stream = buildStream(SensorName, Time_s, SourceRowIdx, ...
    ChannelColumns, Config)
%BUILDSTREAM Normalized + Phase-4-processed synthetic stream.

    RowCount = numel(Time_s);
    Raw = struct();
    Raw.Time_s = Time_s(:);
    Raw.Available = ones(RowCount, 1);

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(SensorName).Channels;
    ColIdx = 0;

    for Index = 1:numel(Channels)

        SourceName = Channels(Index).RealisticCsvField;

        if isempty(SourceName) || strcmp(SourceName, 'Time_s') || ...
                strcmp(SourceName, 'Available')
            continue;
        end

        ColIdx = ColIdx + 1;
        Raw.(SourceName) = ChannelColumns{ColIdx}(:);

    end

    Stream = preprocessing.NormalizeSensorSchema( ...
        Raw, SensorName, 'RealisticCsv');
    Stream = preprocessing.NormalizeSensorUnits(Stream, SensorName);
    Stream.SourceRowIdx = SourceRowIdx(:);

    Stream = preprocessing.ProcessSensorTimestamps( ...
        Config, Stream, SensorName);
    Stream = preprocessing.InspectSensorQuality( ...
        Config, Stream, SensorName);
    Stream = preprocessing.DetectSensorOutliers( ...
        Config, Stream, SensorName);
    Stream.Status = 'Loaded';

end

function [Config, Data, ProcessedStreams] = buildFixture( ...
    ProbeRoot, SkipGnss)
%BUILDFIXTURE Full synthetic run directory + processed streams.

    if SkipGnss
        SourceRoot = fullfile(ProbeRoot, 'RunSourceNoGnss');
    else
        SourceRoot = fullfile(ProbeRoot, 'RunSource');
    end

    SourceFolder = fullfile(SourceRoot, 'RealisticSensorTelemetry');

    if ~isfolder(SourceFolder)
        mkdir(SourceFolder);
    end

    writeFixtureCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', 5);

    if ~SkipGnss
        writeFixtureCsv(fullfile(SourceFolder, 'GNSS.csv'), 'GNSS', 5);
    end

    writeFixtureCsv(fullfile(SourceFolder, 'AirData.csv'), 'AirData', 5);
    writeFixtureCsv( ...
        fullfile(SourceFolder, 'Magnetometer.csv'), 'Magnetometer', 5);

    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(SourceRoot, Config, 'Auto');

    ProcessedStreams = struct();
    Contracts = preprocessing.SensorDataContracts();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if strcmp(Data.Streams.(StreamName).Status, 'Loaded')

            Stream = Data.Streams.(StreamName);
            Stream = preprocessing.ProcessSensorTimestamps( ...
                Config, Stream, StreamName);
            Stream = preprocessing.InspectSensorQuality( ...
                Config, Stream, StreamName);
            Stream = preprocessing.DetectSensorOutliers( ...
                Config, Stream, StreamName);
            Stream.Status = 'Loaded';
            ProcessedStreams.(StreamName) = Stream;

        end

    end

end

function writeFixtureCsv(CsvFile, SensorName, RowCount)
%WRITEFIXTURECSV Contract-shaped realistic-dialect synthetic CSV.

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(SensorName).Channels;
    HeaderNames = {};

    for Index = 1:numel(Channels)

        SourceName = Channels(Index).RealisticCsvField;

        if ~isempty(SourceName)
            HeaderNames{end + 1} = SourceName;
        end

    end

    fid = fopen(CsvFile, 'w');
    Cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', strjoin(HeaderNames, ','));

    for Row = 1:RowCount

        for Col = 1:numel(HeaderNames)

            if Col > 1
                fprintf(fid, ',');
            end

            switch HeaderNames{Col}
                case 'Time_s'
                    fprintf(fid, '%.15g', (Row - 1) * 0.01);
                case 'Available'
                    fprintf(fid, '%d', 1);
                otherwise
                    fprintf(fid, '%.15g', Row * 0.001 * Col);
            end

        end

        fprintf(fid, '\n');

    end

end

function RunInfo = buildRunInfo(OutputDirectory, PreprocessID)
%BUILDRUNINFO Minimal RunInfo for report/export probes.

    RunInfo = struct( ...
        'RunID', 'Run_910_20260101_000000', ...
        'PreprocessID', PreprocessID, ...
        'RunDirectory', '', ...
        'OutputDirectory', OutputDirectory, ...
        'Eligibility', 'NotInspected', ...
        'Category', 'ReviewProbe', ...
        'Status', 'SUCCESS', ...
        'Warnings', {{}}, ...
        'Errors', {{}}, ...
        'ApprovalUsed', false);

end
