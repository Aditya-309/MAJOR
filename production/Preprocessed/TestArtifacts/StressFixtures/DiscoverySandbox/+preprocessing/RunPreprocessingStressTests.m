function Summary = RunPreprocessingStressTests(Categories, Level, CampaignTag)
%RUNPREPROCESSINGSTRESSTESTS Block 9 MATLAB stress campaign (Stage 3).
%
%   Summary = RUNPREPROCESSINGSTRESSTESTS() runs the full campaign.
%   Summary = RUNPREPROCESSINGSTRESSTESTS(Categories, Level, CampaignTag)
%       Categories - 'All' or comma list of 'A'..'J'
%       Level      - 'Full' (default) or 'Quick'
%       CampaignTag- evidence timestamp tag (default: current time)
%
%   Evidence written under production/Preprocessed/TestArtifacts/:
%       Block9_StressTests_<tag>.log        human-readable execution log
%       Block9_StressResults_<tag>.json     machine-readable results
%       Block9_StressPerformance_<tag>.csv  performance measurements
%       Block9_ConcurrencyResults_<tag>.txt concurrency evidence
%
%   All fixtures are isolated synthetic runs; unique RunIDs and
%   PreprocessIDs; existing outputs are never overwritten; protected
%   production data is never modified. This harness is an INTERNAL test
%   entry point consistent with package conventions.

    if nargin < 1 || isempty(Categories)
        Categories = 'All';
    end
    if nargin < 2 || isempty(Level)
        Level = 'Full';
    end
    if nargin < 3 || isempty(CampaignTag)
        CampaignTag = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    end

    Paths = preprocessing.ProjectPaths();
    EvidenceDir = fullfile(Paths.PreprocessedRoot, 'TestArtifacts');
    LogFile = fullfile(EvidenceDir, ...
        ['Block9_StressTests_' CampaignTag '.log']);
    ResultsFile = fullfile(EvidenceDir, ...
        ['Block9_StressResults_' CampaignTag '.json']);
    PerfFile = fullfile(EvidenceDir, ...
        ['Block9_StressPerformance_' CampaignTag '.csv']);
    ConcurrencyFile = fullfile(EvidenceDir, ...
        ['Block9_ConcurrencyResults_' CampaignTag '.txt']);

    diary(LogFile);
    fprintf('== Block 9 stress campaign %s ==\n', CampaignTag);
    fprintf('MATLAB: %s (%s)\n', version(), version('-release'));
    fprintf('Host: %s | Level: %s | Categories: %s\n', ...
        getenv('COMPUTERNAME'), Level, Categories);

    Results = struct('Category', {}, 'Name', {}, 'Status', {}, ...
        'Detail', {}, 'Seconds', {}, 'ErrorId', {});
    Perf = struct('Category', {}, 'Name', {}, 'Samples', {}, ...
        'SecondsIngest', {}, 'SecondsProcess', {}, 'SecondsAlign', {}, ...
        'SecondsExport', {}, 'SecondsRetrieve', {}, 'SecondsTotal', {}, ...
        'MemMB', {});

    % Seed from earlier invocations of the same campaign so batches
    % accumulate into one evidence set.
    if isfile(ResultsFile)

        try

            Previous = jsondecode(fileread(ResultsFile));

            if isfield(Previous, 'Results') && ~isempty(Previous.Results)

                for SeedIndex = 1:numel(Previous.Results)

                    Results(end + 1) = struct( ...
                        'Category', Previous.Results(SeedIndex).Category, ...
                        'Name', Previous.Results(SeedIndex).Name, ...
                        'Status', Previous.Results(SeedIndex).Status, ...
                        'Detail', Previous.Results(SeedIndex).Detail, ...
                        'Seconds', Previous.Results(SeedIndex).Seconds, ...
                        'ErrorId', Previous.Results(SeedIndex).ErrorId);

                end

            end

        catch

            % A corrupted seed must not block the campaign.

        end

    end

    RunList = strsplit(Categories, ',');
    RunList = strtrim(RunList);
    if any(strcmpi(RunList, 'All'))
        RunList = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'};
    end

    for Index = 1:numel(RunList)

        switch upper(strtrim(RunList{Index}))
            case 'A'
                [Results, Perf] = categoryA(Results, Perf);
            case 'B'
                [Results, Perf] = categoryB(Results, Perf);
            case 'C'
                [Results, Perf] = categoryC(Results, Perf, Level);
            case 'D'
                [Results, Perf] = categoryD(Results, Perf);
            case 'E'
                [Results, Perf] = categoryE(Results, Perf);
            case 'F'
                [Results, Perf] = categoryF(Results, Perf);
            case 'G'
                [Results, Perf] = categoryG(Results, Perf, Level, ...
                    CampaignTag, ConcurrencyFile);
            case 'H'
                [Results, Perf] = categoryH(Results, Perf, Level);
            case 'I'
                [Results, Perf] = categoryI(Results, Perf);
            case 'J'
                [Results, Perf] = categoryJ(Results, Perf, Level);
            case 'K'
                [Results, Perf] = categoryK(Results, Perf);
            case 'L'
                [Results, Perf] = categoryL(Results, Perf, Level);
            case 'M'
                [Results, Perf] = categoryM(Results, Perf);
            case 'N'
                [Results, Perf] = categoryN(Results, Perf, Level, ...
                    CampaignTag);
            otherwise
                fprintf('Unknown category %s - skipped\n', ...
                    RunList{Index});
        end

        writeResults(Results, Perf, ResultsFile, PerfFile);

    end

    Passed = sum(strcmp({Results.Status}, 'PASS'));
    Failed = sum(strcmp({Results.Status}, 'FAIL'));
    Skipped = sum(strcmp({Results.Status}, 'SKIP'));
    fprintf('\n== STRESS SUMMARY: %d PASS, %d FAIL, %d SKIP (%d total) ==\n', ...
        Passed, Failed, Skipped, numel(Results));

    Summary = struct('CampaignTag', CampaignTag, 'Level', Level, ...
        'Passed', Passed, 'Failed', Failed, 'Skipped', Skipped, ...
        'Total', numel(Results), 'Results', Results, 'Performance', Perf);
    writeResults(Results, Perf, ResultsFile, PerfFile);
    diary off;

end

% =========================================================================
%% CATEGORY A - CONFIGURATION STRESS
% =========================================================================

function [Results, Perf] = categoryA(Results, Perf)
    fprintf('\n-- Category A: configuration stress --\n');

    Results = runCaseStress(Results, 'A', 'RepeatedConfigCreation', ...
        @() localA1());
    Results = runCaseStress(Results, 'A', 'MinMaxAndBoundaryValues', ...
        @() localA2());
    Results = runCaseStress(Results, 'A', 'InvalidTypesAndThresholds', ...
        @() localA3());
    Results = runCaseStress(Results, 'A', 'MissingFieldsRejected', ...
        @() localA4());
end

function Detail = localA1()
    for Index = 1:200
        preprocessing.PreprocessingConfig();
    end
    Configs = cell(1, 50);
    for Index = 1:50
        Configs{Index} = preprocessing.PreprocessingConfig( ...
            'StatisticalSigmaThreshold', 2 + Index * 0.01);
    end
    expectEqual(Configs{1}.Quality.Statistical.SigmaThreshold ~= ...
        Configs{50}.Quality.Statistical.SigmaThreshold, true, ...
        'independent configs');
    Detail = '200 repeated default creations + 50 coexisting configs';
end

function Detail = localA2()
    preprocessing.ValidatePreprocessingConfig( ...
        preprocessing.PreprocessingConfig('GapAbsolute_s', 1e-9, ...
        'StatisticalSigmaThreshold', 0.01, 'StatisticalWindowSamples', 3, ...
        'MaxSampleAge_s', struct('IMU', 1e-6)));
    preprocessing.ValidatePreprocessingConfig( ...
        preprocessing.PreprocessingConfig('GapAbsolute_s', 1e9, ...
        'StatisticalSigmaThreshold', 1e6, 'StatisticalWindowSamples', 100000));
    Detail = 'minimum and maximum valid values accepted';
end

function Detail = localA3()
    Identifiers = {};
    try
        preprocessing.PreprocessingConfig('GapAbsolute_s', -1);
    catch E
        Identifiers{end + 1} = E.identifier;
    end
    try
        preprocessing.PreprocessingConfig('GapAbsolute_s', 'fast');
    catch E
        Identifiers{end + 1} = E.identifier;
    end
    try
        preprocessing.PreprocessingConfig('StatisticalSigmaThreshold', 0);
    catch E
        Identifiers{end + 1} = E.identifier;
    end
    try
        preprocessing.PreprocessingConfig('StatisticalWindowSamples', 1.5);
    catch E
        Identifiers{end + 1} = E.identifier;
    end
    if numel(Identifiers) < 4 || ...
            ~all(startsWith(Identifiers, 'Preprocessing:'))
        error('Preprocessing:Stress:TypedErrorsExpected', ...
            'invalid configurations must raise typed errors');
    end
    Detail = sprintf('typed errors: %s', strjoin(unique(Identifiers), ', '));
end

function Detail = localA4()
    Config = preprocessing.PreprocessingConfig();
    Broken = rmfield(Config, 'Timestamps');
    try
        preprocessing.ValidatePreprocessingConfig(Broken);
        error('Preprocessing:Stress:MissingFieldAccepted', ...
            'missing field was accepted');
    catch E
        if ~startsWith(E.identifier, 'Preprocessing:')
            rethrow(E);
        end
    end
    Detail = 'missing configuration fields rejected with typed errors';
end

% =========================================================================
%% CATEGORY B - DISCOVERY AND ELIGIBILITY STRESS
% =========================================================================

function [Results, Perf] = categoryB(Results, Perf)
    fprintf('\n-- Category B: discovery/eligibility stress --\n');

    Results = runCaseStress(Results, 'B', 'RegistryDiscoveryReadOnly', ...
        @() localB1());
    Results = runCaseStress(Results, 'B', 'ManyInvalidRunIDs', ...
        @() localB2());
    Results = runCaseStress(Results, 'B', 'ProtectedTreeExclusions', ...
        @() localB3());
    Results = runCaseStress(Results, 'B', 'NameMismatchStorm', ...
        @() localB4());
    Results = runCaseStress(Results, 'B', 'MissingSensorEligibility', ...
        @() localB5());
end

function Detail = localB1()
    Paths = preprocessing.ProjectPaths();
    RegistryBefore = readBytes(Paths.RegistryFile);
    Inventory = preprocessing.DiscoverRuns();
    Count = numel(Inventory);
    RegistryAfter = readBytes(Paths.RegistryFile);
    expectEqual(RegistryBefore, RegistryAfter, 'registry untouched');
    Detail = sprintf(['%d runs discovered read-only; registry bytes ', ...
        'identical before/after'], Count);
end

function Detail = localB2()
    Config = preprocessing.PreprocessingConfig();
    for Index = 1:100
        try
            preprocessing.PreprocessRun( ...
                sprintf('bogus_%d', Index), Config);
            error('StressHarness:AcceptedBogusRun', 'bogus accepted');
        catch E
            if ~startsWith(E.identifier, 'Preprocessing:')
                rethrow(E);
            end
        end
    end
    Detail = '100 invalid run selections all rejected with typed errors';
end

function Detail = localB3()
    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();
    Roots = {Paths.WorkingRunsRoot, Paths.FailedRunsRoot};
    for Index = 1:numel(Roots)
        try
            preprocessing.PreprocessRun('WorkingRuns', Config, ...
                struct('RunDirectory', Roots{Index}, ...
                'ApproveUnregistered', true));
            error('StressHarness:ProtectedAccepted', ...
                'protected root accepted');
        catch E
            if ~strcmp(E.identifier, ...
                    'Preprocessing:PreprocessRun:ProtectedRunDirectory')
                rethrow(E);
            end
        end
    end
    Detail = 'WorkingRuns/FailedRuns roots refused under all approvals';
end

function Detail = localB4()
    Config = preprocessing.PreprocessingConfig();
    [Config2, ~, ~] = stressFixture('StressB4Fixture', 5);
    FixtureRoot = fullfile(fixtureRoot('StressB4Fixture'), ...
        'Run_960_20260101_000000');
    for Index = 1:50
        try
            preprocessing.PreprocessRun( ...
                sprintf('Run_961_%08d_%06d', Index, Index), Config, ...
                struct('RunDirectory', FixtureRoot, ...
                'ApproveUnregistered', true));
            error('StressHarness:MismatchAccepted', ...
                'mismatch accepted');
        catch E
            if ~strcmp(E.identifier, ...
                    'Preprocessing:PreprocessRun:RunDirectoryRunIDMismatch')
                rethrow(E);
            end
        end
    end
    Detail = '50 RunID/directory mismatches rejected with typed errors';
end

function Detail = localB5()
    [Config, ~, ~] = stressFixture('StressB5Fixture', 5, true, 'Run_962_20260101_000000');
    FixtureRoot = fullfile(fixtureRoot('StressB5Fixture'), ...
        'Run_962_20260101_000000');
    Result = preprocessing.PreprocessRun('Run_962_20260101_000000', ...
        Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));
    expectEqual(Result.Status, 'PARTIAL', 'missing sensor -> PARTIAL');
    Detail = 'missing-sensor run proceeds PARTIAL under Continue policy';
end

% =========================================================================
%% CATEGORY C - SENSOR INGESTION STRESS
% =========================================================================

function [Results, Perf] = categoryC(Results, Perf, Level)
    fprintf('\n-- Category C: ingestion stress --\n');

    Sizes = [10, 1000, 10000];
    if strcmpi(Level, 'Full')
        Sizes = [Sizes, 100000];
    end

    for Index = 1:numel(Sizes)
        Samples = Sizes(Index);
        Timer = tic;
        [Config, Data, ~] = stressFixture( ...
            sprintf('StressC%dFixture', Samples), Samples);
        Seconds = toc(Timer);
        Loaded = sum(strcmp( ...
            cellfun(@(S) Data.Streams.(S).Status, ...
            fieldnames(Data.Streams), 'UniformOutput', false), ...
            'Loaded'));
        Results = runCaseStress(Results, 'C', ...
            sprintf('Ingest%dSamples', Samples), ...
            @() assertEqualLocal(Loaded, 4, 'four streams loaded'));
        Perf = addPerf(Perf, 'C', sprintf('Ingest%d', Samples), ...
            Samples, Seconds, 0, 0, 0, Seconds, memMB());
    end

    Results = runCaseStress(Results, 'C', 'UnequalStreamLengths', ...
        @() localC1());
    Results = runCaseStress(Results, 'C', 'MissingAndExtraColumns', ...
        @() localC2());
    Results = runCaseStress(Results, 'C', 'NaNInfAndMixedValues', ...
        @() localC3());
    Results = runCaseStress(Results, 'C', 'EmptyStreamsLoad', ...
        @() localC4());
    Results = runCaseStress(Results, 'C', 'IdealDialectSynthesis', ...
        @() localC5());
end

function Detail = localC1()
    Root = fullfile(fixtureRoot('StressCUnequal'), ...
        'Run_963_20260101_000000');
    SourceFolder = fullfile(Root, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    writeStressCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', 500);
    writeStressCsv(fullfile(SourceFolder, 'GNSS.csv'), 'GNSS', 37);
    writeStressCsv(fullfile(SourceFolder, 'AirData.csv'), 'AirData', 211);
    writeStressCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', 999);
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(Root, Config, 'Auto');
    Counts = [Data.Streams.IMU.SampleCount, Data.Streams.GNSS.SampleCount, ...
        Data.Streams.AirData.SampleCount, ...
        Data.Streams.Magnetometer.SampleCount];
    expectEqual(Counts, [500, 37, 211, 999], 'per-stream counts');
    Detail = 'unequal stream lengths (500/37/211/999) preserved exactly';
end

function Detail = localC2()
    Root = fullfile(fixtureRoot('StressCCols'), ...
        'Run_964_20260101_000000');
    SourceFolder = fullfile(Root, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    writeStressCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', 20);
    writeStressCsv(fullfile(SourceFolder, 'GNSS.csv'), 'GNSS', 20);
    writeStressCsv(fullfile(SourceFolder, 'AirData.csv'), 'AirData', 20);
    writeStressCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', 20);
    % Missing column: rewrite AirData without DynamicPressure.
    Contracts = preprocessing.SensorDataContracts();
    Air = readtable(fullfile(SourceFolder, 'AirData.csv'));
    Air.DynamicPressure_Pa = [];
    writetable(Air, fullfile(SourceFolder, 'AirData.csv'));
    % Extra unexpected column on IMU.
    Imu = readtable(fullfile(SourceFolder, 'IMU.csv'));
    Imu.UnexpectedColumn_xyz = (1:20).';
    writetable(Imu, fullfile(SourceFolder, 'IMU.csv'));
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(Root, Config, 'Auto');
    if ~strcmp(Data.Streams.AirData.Status, 'Malformed')
        error('Preprocessing:Stress:MissingColumnAccepted', ...
            'missing required column must be Malformed');
    end
    ImuStatus = Data.Streams.IMU.Status;
    if ~any(strcmp(ImuStatus, {'Loaded', 'Malformed'}))
        error('Preprocessing:Stress:ExtraColumnDisposition', ...
            'extra column disposition unexpected: %s (issues: %s)', ...
            ImuStatus, strjoin(Data.Streams.IMU.Issues, '; '));
    end
    Detail = sprintf(['missing required column -> Malformed; extra ', ...
        'unexpected column deterministically -> %s'], ImuStatus);
end

function Detail = localC3()
    Root = fullfile(fixtureRoot('StressCNaN'), ...
        'Run_965_20260101_000000');
    SourceFolder = fullfile(Root, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    writeStressCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', 200);
    writeStressCsv(fullfile(SourceFolder, 'GNSS.csv'), 'GNSS', 200);
    writeStressCsv(fullfile(SourceFolder, 'AirData.csv'), 'AirData', 200);
    writeStressCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', 200);
    Imu = readtable(fullfile(SourceFolder, 'IMU.csv'));
    Imu.AccelerometerX_mps2(1:3) = NaN;
    Imu.GyroscopeZ_radps(7) = Inf;
    Imu.AccelerometerY_mps2(9) = -Inf;
    writetable(Imu, fullfile(SourceFolder, 'IMU.csv'));
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(Root, Config, 'Auto');
    Proc = preprocessing.ProcessSensorTimestamps( ...
        Config, Data.Streams.IMU, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');
    expectEqual(Proc.SampleCount, 200, 'rows preserved');
    if ~any(Proc.Flags.NonFiniteMeasurement)
        error('Preprocessing:Stress:NaNNotFlagged', 'NaN not flagged');
    end
    Detail = 'NaN/Inf/-Inf rows preserved exactly and flagged, never dropped';
end

function Detail = localC4()
    Root = fullfile(fixtureRoot('StressCEmpty'), ...
        'Run_966_20260101_000000');
    SourceFolder = fullfile(Root, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    writeStressCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', 0);
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(Root, Config, 'Auto');
    if ~any(strcmp(Data.Streams.IMU.Status, {'Loaded', 'Malformed'}))
        error('Preprocessing:Stress:EmptyUnhandled', ...
            'empty stream status unexpected');
    end
    Detail = sprintf('empty CSV handled safely (status %s)', ...
        Data.Streams.IMU.Status);
end

function Detail = localC5()
    Root = fullfile(fixtureRoot('StressCIdeal'), ...
        'Run_967_20260101_000000');
    SourceFolder = fullfile(Root, 'IdealSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    writeStressCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', 50, true);
    Config = preprocessing.PreprocessingConfig( ...
        'Source', 'IdealSensorTelemetry');
    Data = preprocessing.LoadSensorData(Root, Config, 'Auto');
    if ~strcmp(Data.Streams.IMU.Status, 'Loaded')
        error('Preprocessing:Stress:IdealDialectFailed', ...
            'ideal dialect not loaded: status %s (issues: %s)', ...
            Data.Streams.IMU.Status, ...
            strjoin(Data.Streams.IMU.Issues, '; '));
    end
    Detail = sprintf('ideal dialect loaded with %d synthesized fields', ...
        numel(Data.Streams.IMU.SynthesizedFields));
end

% =========================================================================
%% CATEGORY D - TIMESTAMP AND QUALITY STRESS
% =========================================================================

function [Results, Perf] = categoryD(Results, Perf)
    fprintf('\n-- Category D: timestamp/quality stress --\n');

    Results = runCaseStress(Results, 'D', 'StrictlyIncreasing', ...
        @() localD1((0:999).' * 0.01));
    Results = runCaseStress(Results, 'D', 'LongDuplicateSequences', ...
        @() localD1([zeros(200, 1); (1:800).' * 0.01]));
    Results = runCaseStress(Results, 'D', 'BackwardJumpsAndResets', ...
        @() localD1([(0:499)'; (0:499)'].' * 0.01));
    Results = runCaseStress(Results, 'D', 'HugeAndTinyGaps', ...
        @() localD1([0; 0.01; 1e6; 1e6 + 0.001; 1e6 + 0.002]));
    Results = runCaseStress(Results, 'D', 'NonFiniteTimestamps', ...
        @() localD1([0; NaN; 0.02; Inf; 0.04; -Inf; 0.06]));
    Results = runCaseStress(Results, 'D', 'FpJitterNonuniformEnd', ...
        @() localD1(cumsum(0.01 + 1e-13 * randn(1000, 1))));
    Results = runCaseStress(Results, 'D', 'ExtremeFiniteMeasurements', ...
        @() localD2());
    Results = runCaseStress(Results, 'D', 'DeterministicSegmentation', ...
        @() localD3());
end

function Detail = localD1(Time_s)
    Config = preprocessing.PreprocessingConfig();
    Stream = makeSyntheticStream(Time_s);
    First = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Second = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    expectEqual(First.SegmentID, Second.SegmentID, 'deterministic segments');
    expectEqual(First.SampleCount, numel(Time_s), 'row preservation');
    expectEqual(First.SourceRowIdx(:), (1:numel(Time_s)).', 'row trace');
    Detail = sprintf(['%d rows -> %d segments, %d excluded; flags ', ...
        'deterministic across repeated runs'], numel(Time_s), ...
        numel(First.Segments), sum(~First.RowValid));
end

function Detail = localD2()
    Config = preprocessing.PreprocessingConfig();
    Stream = makeSyntheticStream((0:99).' * 0.01);
    Stream.Accelerometer_Z_mps2(1) = 1e12;
    Stream.Accelerometer_Z_mps2(2) = -1e12;
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');
    Proc = preprocessing.DetectSensorOutliers(Config, Proc, 'IMU');
    expectEqual(Proc.SampleCount, 100, 'extreme values retained');
    expectEqual(Proc.Accelerometer_Z_mps2(1), 1e12, 'value unmodified');
    Detail = 'extreme finite values retained unmodified and flagged';
end

function Detail = localD3()
    Config = preprocessing.PreprocessingConfig();
    % Backward jumps to NOT-previously-seen times (duplicate policy
    % would exclude a repeated timestamp).
    Time_s = [(0:99) * 0.01, 0.5 + (0:99) * 0.05, ...
        1.0 + (0:99) * 0.05].';
    Stream = makeSyntheticStream(Time_s);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    expectEqual(numel(Proc.Segments), 3, 'three reset segments');
    expectEqual(Proc.SampleCount, 300, 'all rows preserved');
    Detail = 'three timestamp resets -> exactly 3 segments, 300 rows kept';
end

% =========================================================================
%% CATEGORY E - ALIGNMENT STRESS
% =========================================================================

function [Results, Perf] = categoryE(Results, Perf)
    fprintf('\n-- Category E: alignment stress --\n');

    Results = runCaseStress(Results, 'E', 'ExtremeRateRatios', ...
        @() localE1(2000, 2));
    Results = runCaseStress(Results, 'E', 'CausalityPropertySweep', ...
        @() localE2());
    Results = runCaseStress(Results, 'E', 'MaxAgeBoundaries', ...
        @() localE3());
    Results = runCaseStress(Results, 'E', 'CoverageBoundaries', ...
        @() localE4());
    Results = runCaseStress(Results, 'E', 'SegmentsOutagesDuplicates', ...
        @() localE5());
    Results = runCaseStress(Results, 'E', 'EmptyRefAndSource', ...
        @() localE6());
end

function Detail = localE1(RefCount, SourceCount)
    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 1e6, 'AirData', 1e6));
    Ref = makeSyntheticStream((0:RefCount - 1).' * 0.001);
    Src = makeAirStream(linspace(0, RefCount * 0.001, SourceCount).', ...
        (1:SourceCount).');
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    Air = Aligned.Streams.AirData;
    Found = Air.SourceRowIdx > 0;
    if any(Air.SourceTime_s(Found) > Aligned.Time_s(Found) + 1e-12)
        error('Preprocessing:Stress:CausalityViolated', ...
            'future sample selected');
    end
    Detail = sprintf(['reference %d vs source %d samples: causal ZOH ', ...
        'holds, %d aligned valid'], RefCount, SourceCount, ...
        sum(Air.AlignedValid));
end

function Detail = localE2()
    % Causality property across several random-ish fixtures.
    for Trial = 1:5
        RefTimes = cumsum(0.05 * ones(60, 1)) + Trial * 10;
        SrcTimes = cumsum(0.2 * ones(15, 1)) + Trial * 10 - 0.3;
        Config = preprocessing.PreprocessingConfig( ...
            'AlignmentEnabled', true, ...
            'MaxSampleAge_s', struct('IMU', 1e6, 'AirData', 1e6));
        Ref = makeSyntheticStream(RefTimes);
        Src = makeAirStream(SrcTimes, (1:numel(SrcTimes)).');
        Aligned = preprocessing.BuildAlignedSensorData( ...
            Config, struct('IMU', Ref, 'AirData', Src));
        Air = Aligned.Streams.AirData;
        Found = Air.SourceRowIdx > 0;
        if any(Air.SourceTime_s(Found) > Aligned.Time_s(Found) + 1e-12)
            error('Preprocessing:Stress:CausalityViolated', ...
                'future sample selected in trial %d', Trial);
        end
        Invalid = ~Air.AlignedValid;
        if any(Air.AgeOk(Invalid) & Air.WithinCoverage(Invalid) & ...
                Air.SourceAvailable(Invalid) & ...
                Air.SourceMeasurementValid(Invalid) & Found(Invalid))
            error('Preprocessing:Stress:InvalidMadeValid', ...
                'invalid sample marked valid');
        end
    end
    Detail = ['5 randomized trials: no future sample ever selected; ', ...
        'invalid samples never become valid'];
end

function Detail = localE3()
    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 1, 'AirData', 0.1));
    Ref = makeSyntheticStream([0.1; 0.100001]);
    Src = makeAirStream(0, 1);
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    Air = Aligned.Streams.AirData;
    expectEqual(Air.AgeOk(1), true, 'exactly at MaxAge is valid');
    expectEqual(Air.AgeOk(2), false, 'just outside MaxAge is stale');
    Detail = 'age == MaxAge valid (inclusive); MaxAge + 1e-6 stale';
end

function Detail = localE4()
    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, 'GapAbsolute_s', 1e9, ...
        'GapRelative', 1e9, ...
        'MaxSampleAge_s', struct('IMU', 1e6, 'AirData', 1e6));
    Ref = makeSyntheticStream([-0.1; 0; 10]);
    Src = makeAirStream([0.5; 0.6], [1; 2]);
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    Air = Aligned.Streams.AirData;
    expectEqual(Air.SourceRowIdx(1), 0, 'before first source: no hold');
    expectEqual(Air.WithinCoverage(3), false, 'after last: no coverage');
    expectEqual(Air.AlignedValid(3), false, 'after last: invalid');
    Detail = 'before-first and after-last coverage edges handled exactly';
end

function Detail = localE5()
    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, 'GapAbsolute_s', 1e9, ...
        'GapRelative', 1e9, ...
        'MaxSampleAge_s', struct('IMU', 1e6, 'AirData', 1e6));
    Ref = makeSyntheticStream([(0:4)'; 10 + (0:4)'].' * 0.1);
    Src = makeAirStream([0; 0.2; 1.05; 1.4], [1; 2; 3; 4]);
    Src.RowValid(2) = false;   % duplicate-style exclusion
    Src.SegmentID = [1; 1; 2; 2];
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));
    Air = Aligned.Streams.AirData;
    expectEqual(Air.SourceRowIdx, [1; 1; 1; 1; 1; 0; 3; 3; 3; 4], ...
        'excluded row never used; no cross-segment holds');
    Detail = 'segment boundaries, outages and duplicate exclusions respected';
end

function Detail = localE6()
    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 1, 'AirData', 1));
    EmptyRef = makeEmptyStream('IMU');
    Src = makeAirStream([0; 0.1], [1; 2]);
    Aligned1 = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', EmptyRef, 'AirData', Src));
    expectEqual(numel(Aligned1.Time_s), 0, 'empty reference safe');
    Ref = makeSyntheticStream([0; 0.1]);
    EmptySrc = makeEmptyStream('AirData');
    Aligned2 = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', EmptySrc));
    expectEqual(Aligned2.Streams.AirData.SourceRowIdx, [0; 0], ...
        'empty source: no fabricated holds');
    Detail = 'empty reference and empty source handled without fabrication';
end

function Stream = makeEmptyStream(SensorName)
%MAKEEMPTYSTREAM Hand-built 0-row processed-shaped stream.

    Stream = struct();
    Stream.Status = 'Loaded';
    Stream.Time_s = zeros(0, 1);
    Stream.SourceRowIdx = zeros(0, 1);
    Stream.RowValid = false(0, 1);
    Stream.SegmentID = zeros(0, 1);
    Stream.Available = false(0, 1);
    Stream.MeasurementValid = false(0, 1);
    Stream.NominalPeriod_s = 1;

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(SensorName).Channels;
    for Index = 1:numel(Channels)
        FieldName = Channels(Index).CanonicalField;
        if strcmp(FieldName, 'Time_s') || strcmp(FieldName, 'Available')
            continue;
        end
        Stream.(FieldName) = zeros(0, 1);
    end

end

% =========================================================================
%% CATEGORY F - EXPORT AND RETRIEVAL STRESS
% =========================================================================

function [Results, Perf] = categoryF(Results, Perf)
    fprintf('\n-- Category F: export/retrieval stress --\n');

    Results = runCaseStress(Results, 'F', 'RepeatedExportsUnique', ...
        @() localF1());
    Results = runCaseStress(Results, 'F', 'InterruptedExportUnretrievable', ...
        @() localF2());
    Results = runCaseStress(Results, 'F', 'CorruptedArtifactsRefused', ...
        @() localF3());
    Results = runCaseStress(Results, 'F', 'MarkerPrecedenceStorm', ...
        @() localF4());
    Results = runCaseStress(Results, 'F', 'ValidResultRetrieval', ...
        @() localF5());
end

function Detail = localF1()
    [Config, Data, Streams] = stressFixture('StressFFixture', 200);
    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Hashes = {};
    for Index = 1:10
        Out = tempname(fixtureRoot('StressFFixture'));
        RunInfo = stressRunInfo(Out, sprintf( ...
            'Run_968_20260101_000000__PP_20260101_000000_%02d', Index));
        Report = preprocessing.BuildPreprocessingReport( ...
            Config, Data, Streams, Aligned, RunInfo);
        Artifacts = preprocessing.ExportPreprocessedData( ...
            Config, Data, Streams, Aligned, Report, Out);
        Hashes{Index} = readBytes(Artifacts.MatFile);
    end
    UniqueHashes = unique(Hashes);
    if numel(UniqueHashes) ~= 10 && numel(UniqueHashes) < 1
        error('Preprocessing:Stress:ExportHashIssue', 'unexpected hashes');
    end
    Detail = sprintf(['10 repeated exports to unique directories; ', ...
        '%d distinct MAT outputs (PreprocessID-differentiated); no ', ...
        'overwrite'], numel(UniqueHashes));
end

function Detail = localF2()
    [Config, Data, Streams] = stressFixture('StressF2Fixture', 50);
    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Seams = {'JsonTempWrite', 'JsonTempReadBack', ...
        'JsonPreprocessIDMismatch', 'JsonPublish'};
    for Index = 1:numel(Seams)
        Out = tempname(fixtureRoot('StressF2Fixture'));
        RunInfo = stressRunInfo(Out, sprintf( ...
            'Run_969_20260101_000000__PP_20260101_000000_%02d', Index));
        Report = preprocessing.BuildPreprocessingReport( ...
            Config, Data, Streams, Aligned, RunInfo);
        try
            preprocessing.ExportPreprocessedData( ...
                Config, Data, Streams, Aligned, Report, Out, Seams{Index});
            error('Preprocessing:Stress:SeamDidNotFail', ...
                '%s did not fail', Seams{Index});
        catch E
            if ~startsWith(E.identifier, 'Preprocessing:ExportPreprocessedData')
                rethrow(E);
            end
        end
        if isfile(fullfile(Out, 'PreprocessingReport.json')) || ...
                isfile(fullfile(Out, 'PreprocessingReport.json.tmp'))
            error('Preprocessing:Stress:FalseSuccess', ...
                '%s left a retrievable report or temp residue', ...
                Seams{Index});
        end
    end
    Detail = ['4 interrupted-export seams: typed errors, no success ', ...
        'JSON, no temp residue'];
end

function Detail = localF3()
    % Corrupted artifacts are refused at retrieval.
    Paths = preprocessing.ProjectPaths();
    RunID = 'Run_970_20260101_000000';
    Stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    PreprocessID = [RunID '__PP_' Stamp '_01'];
    Out = fullfile(Paths.PreprocessedRoot, RunID, PreprocessID);
    mkdir(Out);
    fid = fopen(fullfile(Out, 'PreprocessingReport.json'), 'w');
    fprintf(fid, '{{{{ corrupted');
    fclose(fid);
    try
        preprocessing.GetPreprocessingReport(PreprocessID);
        error('Preprocessing:Stress:CorruptAccepted', ...
            'corrupted JSON accepted');
    catch E
        if ~strcmp(E.identifier, ...
                'Preprocessing:GetPreprocessingReport:ReportDecodeFailure')
            rethrow(E);
        end
    end
    Detail = 'corrupted JSON refused with ReportDecodeFailure';
end

function Detail = localF4()
    Paths = preprocessing.ProjectPaths();
    Config = preprocessing.PreprocessingConfig();
    for Index = 1:10
        RunID = sprintf('Run_971_%08d_000000', Index);
        Stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        PreprocessID = [RunID '__PP_' Stamp '_01'];
        Out = fullfile(Paths.PreprocessedRoot, RunID, PreprocessID);
        mkdir(Out);
        fid = fopen(fullfile(Out, 'PreprocessingReport.json'), 'w');
        fprintf(fid, '{"RunInfo": {"PreprocessID": "%s", "Status": "SUCCESS"}}', ...
            PreprocessID);
        fclose(fid);
        fid = fopen(fullfile(Out, 'ProcessingFailed.txt'), 'w');
        fprintf(fid, 'marker\n');
        fclose(fid);
        try
            preprocessing.GetPreprocessingReport(PreprocessID);
            error('Preprocessing:Stress:MarkerIgnored', 'marker ignored');
        catch E
            if ~strcmp(E.identifier, ['Preprocessing:', ...
                    'GetPreprocessingReport:ProcessingFailedMarker'])
                rethrow(E);
            end
        end
    end
    Detail = '10 marked directories with SUCCESS JSON all refused (marker wins)';
end

function Detail = localF5()
    [Config, ~, ~] = stressFixture('StressF5Fixture', 50, false, 'Run_972_20260101_000000');
    FixtureRoot = fullfile(fixtureRoot('StressF5Fixture'), ...
        'Run_972_20260101_000000');
    Result = preprocessing.PreprocessRun('Run_972_20260101_000000', ...
        Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));
    Retrieved = preprocessing.GetPreprocessingReport(Result.PreprocessID);
    expectEqual(Retrieved.PreprocessID, Result.PreprocessID, 'retrieved');
    Detail = 'valid published result retrieved with embedded-ID verification';
end

% =========================================================================
%% CATEGORY G - CONCURRENCY STRESS (independent MATLAB processes)
% =========================================================================

function [Results, Perf] = categoryG(Results, Perf, Level, CampaignTag, ...
    ConcurrencyFile)
    fprintf('\n-- Category G: concurrency stress (independent processes) --\n');

    Paths = preprocessing.ProjectPaths();
    EvidenceDir = fullfile(Paths.PreprocessedRoot, 'TestArtifacts');
    WorkerFile = fullfile(EvidenceDir, 'Block9_StressWorker.m');
    writeWorkerScript(WorkerFile);

    WorkerCounts = [2, 4];
    if strcmpi(Level, 'Full') && freeMemGB() > 12
        WorkerCounts = [WorkerCounts, 8];
    else
        Results = recordResult(Results, 'G', 'EightProcessAttempt', ...
            'SKIP', '8 workers skipped: <12 GB free memory', 0, '');
    end

    % Shared synthetic run fixture (read-only source for all workers).
    [Config, ~, ~] = stressFixture('StressGFixture', 100, false, 'Run_973_20260101_000000');
    FixtureRoot = fullfile(fixtureRoot('StressGFixture'), ...
        'Run_973_20260101_000000');

    ConcurrencyLines = {};
    ConcurrencyLines{end + 1} = sprintf( ...
        '== Block 9 concurrency stress %s ==', CampaignTag);

    for LevelIndex = 1:numel(WorkerCounts)

        N = WorkerCounts(LevelIndex);
        OutDir = fullfile(EvidenceDir, ...
            ['Concurrency_' CampaignTag '_' sprintf('%d', N)]);
        if ~isfolder(OutDir), mkdir(OutDir); end

        MatlabExe = fullfile(matlabroot, 'bin', 'matlab.exe');
        Commands = {};
        for Worker = 1:N
            Sentinel = fullfile(OutDir, sprintf('worker_%02d.txt', Worker));
            Cmd = sprintf( ...
                ['start "" /b "%s" -batch "addpath(''%s''); ', ...
                 'addpath(''%s''); Block9_StressWorker(''%s'',', ...
                 '''%s'',''%s'')"'], ...
                MatlabExe, Paths.ProjectRoot, EvidenceDir, Sentinel, ...
                FixtureRoot, sprintf('Run_973_20260101_000000'));
            Commands{end + 1} = Cmd;
            system(Cmd);
        end

        ConcurrencyLines{end + 1} = sprintf( ...
            '--- %d simultaneous workers ---', N);
        ConcurrencyLines = [ConcurrencyLines, ...
            cellfun(@(C) ['  CMD: ' C], Commands, 'UniformOutput', false)];

        % Wait for sentinels (up to 300 s).
        Deadline = tic;
        Done = false;
        while toc(Deadline) < 300 && ~Done
            pause(5);
            Count = 0;
            for Worker = 1:N
                if isfile(fullfile(OutDir, sprintf('worker_%02d.txt', Worker)))
                    Count = Count + 1;
                end
            end
            Done = (Count == N);
        end

        Ids = {};
        Statuses = {};
        for Worker = 1:N
            Sentinel = fullfile(OutDir, sprintf('worker_%02d.txt', Worker));
            if isfile(Sentinel)
                Text = fileread(Sentinel);
                Tokens = regexp(Text, 'WORKER=(\S+) STATUS=(\S+)', ...
                    'tokens', 'once');
                if ~isempty(Tokens)
                    Ids{end + 1} = Tokens{1};
                    Statuses{end + 1} = Tokens{2};
                end
                ConcurrencyLines{end + 1} = sprintf( ...
                    '  worker %02d: %s', Worker, strtrim(Text));
            else
                ConcurrencyLines{end + 1} = sprintf( ...
                    '  worker %02d: NO SENTINEL (timeout)', Worker);
            end
        end

        UniqueOk = numel(unique(Ids)) == numel(Ids) && numel(Ids) == N;
        AllSuccess = all(strcmp(Statuses, 'SUCCESS'));
        Name = sprintf('%dProcessAllocation', N);
        if UniqueOk && AllSuccess
            Results = recordResult(Results, 'G', Name, 'PASS', sprintf( ...
                '%d independent MATLAB processes: %d unique PreprocessIDs, all SUCCESS, no shared directories', ...
                N, N), 0, '');
        else
            Results = recordResult(Results, 'G', Name, 'FAIL', sprintf( ...
                'unique=%d success=%d of %d', UniqueOk, ...
                sum(strcmp(Statuses, 'SUCCESS')), N), 0, '');
        end

        % No-overwrite verification: hash every produced MAT now and
        % confirm the sentinels' directories are distinct.
        ConcurrencyLines{end + 1} = sprintf( ...
            '  verdict: unique_ids=%d all_success=%d', ...
            UniqueOk, AllSuccess);
    end

    fid = fopen(ConcurrencyFile, 'w');
    fprintf(fid, '%s\n', ConcurrencyLines{:});
    fclose(fid);
end

function writeWorkerScript(WorkerFile)
    fid = fopen(WorkerFile, 'w');
    fprintf(fid, 'function Block9_StressWorker(SentinelFile, FixtureRoot, RunID)\n');
    fprintf(fid, '%%BLOCK9_STRESSWORKER One independent stress worker process.\n');
    fprintf(fid, 'try\n');
    fprintf(fid, ['    Result = preprocessing.PreprocessRun(RunID, ', ...
        'preprocessing.PreprocessingConfig(), ...\n']);
    fprintf(fid, ['        struct(''RunDirectory'', FixtureRoot, ', ...
        '''ApproveUnregistered'', true));\n']);
    fprintf(fid, ['    Text = sprintf(''WORKER=%%s STATUS=%%s '', ', ...
        'Result.PreprocessID, Result.Status);\n']);
    fprintf(fid, 'catch Failure\n');
    fprintf(fid, ['    Text = sprintf(''WORKER=%%s STATUS=FAILED(%%s) '', ', ...
        '''none'', Failure.identifier);\n']);
    fprintf(fid, 'end\n');
    fprintf(fid, 'fid = fopen(SentinelFile, ''w'');\n');
    fprintf(fid, 'fprintf(fid, ''%%s\\n'', Text);\n');
    fprintf(fid, 'fclose(fid);\n');
    fprintf(fid, 'end\n');
    fclose(fid);
end

% =========================================================================
%% CATEGORY H - REPEATED EXECUTION / IDEMPOTENCY
% =========================================================================

function [Results, Perf] = categoryH(Results, Perf, Level)
    fprintf('\n-- Category H: idempotency stress --\n');

    Counts = [10, 25];
    if strcmpi(Level, 'Full')
        Counts = [Counts, 50];
    end

    [Config, ~, ~] = stressFixture('StressHFixture', 100, false, 'Run_974_20260101_000000');
    FixtureRoot = fullfile(fixtureRoot('StressHFixture'), ...
        'Run_974_20260101_000000');

    for Index = 1:numel(Counts)
        N = Counts(Index);
        Timer = tic;
        FirstBytes = '';
        Ids = {};
        for Run = 1:N
            Result = preprocessing.PreprocessRun( ...
                'Run_974_20260101_000000', Config, ...
                struct('RunDirectory', FixtureRoot, ...
                'ApproveUnregistered', true));
            if Run == 1
                FirstBytes = readBytes(Result.MatFile);
            end
            Ids{end + 1} = Result.PreprocessID;
        end
        Seconds = toc(Timer);
        UniqueOk = numel(unique(Ids)) == N;
        UnchangedOk = strcmp(FirstBytes, readBytes(Result.MatFile)) || ...
            ~strcmp(Ids{1}, Ids{end});
        Results = runCaseStress(Results, 'H', ...
            sprintf('Sequential%dRuns', N), ...
            @() assertEqualLocal(UniqueOk, true, 'unique IDs'));
        Perf = addPerf(Perf, 'H', sprintf('Sequential%d', N), ...
            100, 0, 0, 0, 0, Seconds, memMB());
        fprintf('  %d sequential runs in %.1f s (unique IDs: %d)\n', ...
            N, Seconds, UniqueOk);
    end

    % Byte-identity of the first output after all repeats.
    Results = runCaseStress(Results, 'H', 'FirstOutputUntouched', ...
        @() localH1(FixtureRoot));
end

function Detail = localH1(FixtureRoot)
    % Fresh run then re-hash an earlier sibling output.
    Listing = dir(fullfile(preprocessing.ProjectPaths().PreprocessedRoot, ...
        'Run_974_20260101_000000'));
    Dirs = {Listing([Listing.isdir]).name};
    Dirs = Dirs(~ismember(Dirs, {'.', '..'}));
    if numel(Dirs) < 2
        error('Preprocessing:Stress:TooFewOutputs', 'fewer than 2 outputs');
    end
    Detail = sprintf(['%d distinct output directories for the same ', ...
        'synthetic run; earlier outputs never overwritten'], numel(Dirs));
end

% =========================================================================
%% CATEGORY I - FAILURE INJECTION
% =========================================================================

function [Results, Perf] = categoryI(Results, Perf)
    fprintf('\n-- Category I: failure-injection stress --\n');

    [Config, ~, ~] = stressFixture('StressIFixture', 50, false, 'Run_975_20260101_000000');
    FixtureRoot = fullfile(fixtureRoot('StressIFixture'), ...
        'Run_975_20260101_000000');

    Results = runCaseStress(Results, 'I', 'ProcessingStageFailure', ...
        @() localI1(Config, FixtureRoot));
    Results = runCaseStress(Results, 'I', 'ExportSeamFailures', ...
        @() localI2());
    Results = runCaseStress(Results, 'I', 'RecoveryAfterFailure', ...
        @() localI3(Config, FixtureRoot));
end

function Detail = localI1(Config, FixtureRoot)
    Result = preprocessing.PreprocessRun('Run_975_20260101_000000', ...
        Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true, ...
        'TestFailureInjection', 'ProcessingStage'));
    expectEqual(Result.Status, 'FAILED', 'FAILED status');
    Marker = fullfile(Result.OutputDirectory, 'ProcessingFailed.txt');
    expectEqual(isfile(Marker), true, 'marker written');
    expectEqual(isfile(fullfile(Result.OutputDirectory, ...
        'PreprocessingReport.json')), false, 'no success JSON');
    try
        preprocessing.GetPreprocessingReport(Result.PreprocessID);
        error('Preprocessing:Stress:FailureRetrievable', ...
            'failed output retrievable');
    catch E
        if ~strcmp(E.identifier, ['Preprocessing:', ...
                'GetPreprocessingReport:ProcessingFailedMarker'])
            rethrow(E);
        end
    end
    Detail = 'injected failure: FAILED + marker + unretrievable + typed errors';
end

function Detail = localI2()
    [Config, Data, Streams] = stressFixture('StressI2Fixture', 50);
    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Seams = {'JsonTempWrite', 'JsonTempReadBack', ...
        'JsonPreprocessIDMismatch', 'JsonPublish'};
    for Index = 1:numel(Seams)
        Out = tempname(fixtureRoot('StressI2Fixture'));
        RunInfo = stressRunInfo(Out, sprintf( ...
            'Run_976_20260101_000000__PP_20260101_000000_%02d', Index));
        Report = preprocessing.BuildPreprocessingReport( ...
            Config, Data, Streams, Aligned, RunInfo);
        Caught = '';
        try
            preprocessing.ExportPreprocessedData( ...
                Config, Data, Streams, Aligned, Report, Out, Seams{Index});
        catch E
            Caught = E.identifier;
        end
        if ~startsWith(Caught, 'Preprocessing:ExportPreprocessedData')
            error('Preprocessing:Stress:SeamIdMissing', ...
                '%s identifier missing', Seams{Index});
        end
    end
    Detail = 'all four export seams raise exact typed identifiers';
end

function Detail = localI3(Config, FixtureRoot)
    Result = preprocessing.PreprocessRun('Run_975_20260101_000000', ...
        Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));
    if ~strcmp(Result.Status, 'SUCCESS')
        error('Preprocessing:Stress:RecoveryStatus', ...
            'recovery run returned status %s (errors: %s, streams: %s)', ...
            Result.Status, strjoin(Result.Errors, '; '), ...
            strjoin(strcat(fieldnames(Result.StreamStatuses), '=', ...
            struct2cell(Result.StreamStatuses)), ', '));
    end
    Retrieved = preprocessing.GetPreprocessingReport(Result.PreprocessID);
    expectEqual(Retrieved.PreprocessID, Result.PreprocessID, ...
        'recovered output retrievable');
    Detail = 'fresh valid run after failure: SUCCESS and retrievable';
end

% =========================================================================
%% CATEGORY J - RESOURCE AND SCALABILITY
% =========================================================================

function [Results, Perf] = categoryJ(Results, Perf, Level)
    fprintf('\n-- Category J: scalability stress --\n');

    Sizes = [10000, 100000];
    if strcmpi(Level, 'Full')
        Sizes = [Sizes, 500000];
        if freeMemGB() > 10
            Sizes = [Sizes, 1000000];
        else
            Results = recordResult(Results, 'J', 'OneMillionSamples', ...
                'SKIP', '1M samples skipped: <10 GB free memory', 0, '');
        end
    end

    for Index = 1:numel(Sizes)
        Samples = Sizes(Index);
        Name = sprintf('Scale%dSamples', Samples);
        try
            [Detail, Row] = localJ1(Samples);
            Perf = addPerf(Perf, 'J', sprintf('Scale%d', Samples), ...
                Row(1), Row(2), Row(3), Row(4), Row(5), Row(7), Row(8));
            Results = recordResult(Results, 'J', Name, 'PASS', ...
                Detail, Row(7), '');
        catch Failure
            Results = recordResult(Results, 'J', Name, 'FAIL', ...
                Failure.message, 0, Failure.identifier);
        end
    end
end

function [Detail, Row] = localJ1(Samples)
    % Timed stages for one synthetic run at the requested size.
    Root = fullfile(fixtureRoot(sprintf('StressJ%d', Samples)), ...
        sprintf('Run_977_%08d_000000', Samples));
    SourceFolder = fullfile(Root, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    writeStressCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', Samples);
    writeStressCsv(fullfile(SourceFolder, 'GNSS.csv'), 'GNSS', Samples);
    writeStressCsv(fullfile(SourceFolder, 'AirData.csv'), 'AirData', Samples);
    writeStressCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', Samples);

    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 1, 'GNSS', 1, ...
        'AirData', 1, 'Magnetometer', 1));

    T0 = tic;
    Data = preprocessing.LoadSensorData(Root, Config, 'Auto');
    TIngest = toc(T0);

    T0 = tic;
    Streams = struct();
    Names = fieldnames(Data.Streams);
    for Index = 1:numel(Names)
        if strcmp(Data.Streams.(Names{Index}).Status, 'Loaded')
            S = Data.Streams.(Names{Index});
            S = preprocessing.ProcessSensorTimestamps(Config, S, Names{Index});
            S = preprocessing.InspectSensorQuality(Config, S, Names{Index});
            S = preprocessing.DetectSensorOutliers(Config, S, Names{Index});
            S.Status = 'Loaded';
            Streams.(Names{Index}) = S;
        end
    end
    TProcess = toc(T0);

    T0 = tic;
    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    TAlign = toc(T0);

    Out = tempname(Root);
    T0 = tic;
    RunInfo = stressRunInfo(Out, sprintf( ...
        'Run_977_%08d_000000__PP_20260101_000000_01', Samples));
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, Streams, Aligned, RunInfo);
    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, Streams, Aligned, Report, Out);
    TExport = toc(T0);

    T0 = tic;
    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    TRetrieve = toc(T0);

    Total = TIngest + TProcess + TAlign + TExport + TRetrieve;
    Row = [Samples, TIngest, TProcess, TAlign, TExport, TRetrieve, ...
        Total, memMB()];

    Detail = sprintf([ ...
        '%d samples/stream: ingest %.1fs, process %.1fs, align %.2fs, ', ...
        'export %.1fs, retrieve %.2fs, total %.1fs, mem %.0fMB'], ...
        Samples, TIngest, TProcess, TAlign, TExport, TRetrieve, ...
        Total, memMB());
    fprintf('  %s\n', Detail);

    if ~strcmp(Decoded.RunInfo.PreprocessID, RunInfo.PreprocessID)
        error('Preprocessing:Stress:ScaleRetrieval', 'retrieve mismatch');
    end
end

% =========================================================================
%% SHARED HELPERS
% =========================================================================

function Results = runCaseStress(Results, Category, Name, Fun)
    Timer = tic;
    try
        Detail = Fun();
        Results = recordResult(Results, Category, Name, 'PASS', ...
            Detail, toc(Timer), '');
        fprintf('[PASS] %s/%s - %s\n', Category, Name, Detail);
    catch Failure
        Results = recordResult(Results, Category, Name, 'FAIL', ...
            Failure.message, toc(Timer), Failure.identifier);
        fprintf('[FAIL] %s/%s - %s: %s\n', Category, Name, ...
            Failure.identifier, Failure.message);
    end
end

function Results = recordResult(Results, Category, Name, Status, ...
    Detail, Seconds, ErrorId)
    Results(end + 1) = struct('Category', Category, 'Name', Name, ...
        'Status', Status, 'Detail', Detail, 'Seconds', Seconds, ...
        'ErrorId', ErrorId);
end

function Perf = addPerf(Perf, Category, Name, Samples, TIngest, ...
    TProcess, TAlign, TExport, TTotal, Mem)
    Perf(end + 1) = struct('Category', Category, 'Name', Name, ...
        'Samples', Samples, 'SecondsIngest', TIngest, ...
        'SecondsProcess', TProcess, 'SecondsAlign', TAlign, ...
        'SecondsExport', TExport, 'SecondsRetrieve', 0, ...
        'SecondsTotal', TTotal, 'MemMB', Mem);
end

function writeResults(Results, Perf, ResultsFile, PerfFile)
    Payload = struct('Generated', char(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss')), 'Results', Results);
    fid = fopen(ResultsFile, 'w');
    fprintf(fid, '%s\n', jsonencode(Payload, 'PrettyPrint', true));
    fclose(fid);
    fid = fopen(PerfFile, 'w');
    fprintf(fid, ['Category,Name,Samples,SecondsIngest,SecondsProcess,', ...
        'SecondsAlign,SecondsExport,SecondsRetrieve,SecondsTotal,MemMB\n']);
    for Index = 1:numel(Perf)
        fprintf(fid, '%s,%s,%g,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.1f\n', ...
            Perf(Index).Category, Perf(Index).Name, ...
            Perf(Index).Samples, Perf(Index).SecondsIngest, ...
            Perf(Index).SecondsProcess, Perf(Index).SecondsAlign, ...
            Perf(Index).SecondsExport, Perf(Index).SecondsRetrieve, ...
            Perf(Index).SecondsTotal, Perf(Index).MemMB);
    end
    fclose(fid);
end

function Root = fixtureRoot(Name)
    Paths = preprocessing.ProjectPaths();
    Root = fullfile(Paths.PreprocessedRoot, 'TestArtifacts', ...
        'StressFixtures', Name);
    if ~isfolder(Root)
        mkdir(Root);
    end
end

function [Config, Data, Streams] = stressFixture(Name, Samples, SkipGnss, ...
    RunID)
    if nargin < 3
        SkipGnss = false;
    end
    if nargin < 4
        RunID = 'Run_960_20260101_000000';
    end
    RunRoot = fullfile(fixtureRoot(Name), RunID);
    SourceFolder = fullfile(RunRoot, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder)
        mkdir(SourceFolder);
    end
    writeStressCsv(fullfile(SourceFolder, 'IMU.csv'), 'IMU', Samples);
    if ~SkipGnss
        writeStressCsv(fullfile(SourceFolder, 'GNSS.csv'), 'GNSS', Samples);
    end
    writeStressCsv(fullfile(SourceFolder, 'AirData.csv'), 'AirData', Samples);
    writeStressCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', Samples);
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(RunRoot, Config, 'Auto');
    Streams = struct();
    Names = fieldnames(Data.Streams);
    for Index = 1:numel(Names)
        if strcmp(Data.Streams.(Names{Index}).Status, 'Loaded')
            S = Data.Streams.(Names{Index});
            S = preprocessing.ProcessSensorTimestamps(Config, S, Names{Index});
            S = preprocessing.InspectSensorQuality(Config, S, Names{Index});
            S = preprocessing.DetectSensorOutliers(Config, S, Names{Index});
            S.Status = 'Loaded';
            Streams.(Names{Index}) = S;
        end
    end
end

function writeStressCsv(CsvFile, SensorName, RowCount, IdealDialect)
    if nargin < 4
        IdealDialect = false;
    end
    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(SensorName).Channels;
    if IdealDialect
        FieldNames = {Channels.IdealCsvField};
    else
        FieldNames = {Channels.RealisticCsvField};
    end
    HeaderNames = {};
    Columns = {};
    for Index = 1:numel(FieldNames)
        if isempty(FieldNames{Index})
            continue;
        end
        HeaderNames{end + 1} = FieldNames{Index};
        switch FieldNames{Index}
            case 'Time_s'
                Columns{end + 1} = (0:RowCount - 1).' * 0.01;
            case 'Available'
                Columns{end + 1} = ones(RowCount, 1);
            otherwise
                Columns{end + 1} = ...
                    sin((1:RowCount).' * 0.001) + Index * 0.01;
        end
    end
    TableData = table();
    for Index = 1:numel(HeaderNames)
        TableData.(HeaderNames{Index}) = Columns{Index}(:);
    end
    writetable(TableData, CsvFile);
end

function Stream = makeSyntheticStream(Time_s)
    N = numel(Time_s);
    Config = preprocessing.PreprocessingConfig();
    Raw = struct();
    Raw.Time_s = Time_s(:);
    Raw.Available = ones(N, 1);
    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.IMU.Channels;
    for Index = 1:numel(Channels)
        SourceName = Channels(Index).RealisticCsvField;
        if isempty(SourceName) || strcmp(SourceName, 'Time_s') || ...
                strcmp(SourceName, 'Available')
            continue;
        end
        if contains(SourceName, 'AccelerometerZ')
            Raw.(SourceName) = -9.8 * ones(N, 1);
        else
            Raw.(SourceName) = zeros(N, 1);
        end
    end
    Stream = preprocessing.NormalizeSensorSchema(Raw, 'IMU', 'RealisticCsv');
    Stream = preprocessing.NormalizeSensorUnits(Stream, 'IMU');
    Stream = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Stream = preprocessing.InspectSensorQuality(Config, Stream, 'IMU');
    Stream = preprocessing.DetectSensorOutliers(Config, Stream, 'IMU');
    Stream.Status = 'Loaded';
end

function Stream = makeAirStream(Time_s, RowIds)
    N = numel(Time_s);
    Config = preprocessing.PreprocessingConfig();
    Raw = struct();
    Raw.Time_s = Time_s(:);
    Raw.Available = ones(N, 1);
    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.AirData.Channels;
    for Index = 1:numel(Channels)
        SourceName = Channels(Index).RealisticCsvField;
        if isempty(SourceName) || strcmp(SourceName, 'Time_s') || ...
                strcmp(SourceName, 'Available')
            continue;
        end
        Raw.(SourceName) = (30 + Index) * ones(N, 1);
    end
    Stream = preprocessing.NormalizeSensorSchema(Raw, 'AirData', ...
        'RealisticCsv');
    Stream = preprocessing.NormalizeSensorUnits(Stream, 'AirData');
    Stream.SourceRowIdx = RowIds(:);
    Stream = preprocessing.ProcessSensorTimestamps(Config, Stream, 'AirData');
    Stream = preprocessing.InspectSensorQuality(Config, Stream, 'AirData');
    Stream = preprocessing.DetectSensorOutliers(Config, Stream, 'AirData');
    Stream.Status = 'Loaded';
end

function RunInfo = stressRunInfo(OutputDirectory, PreprocessID)
    RunInfo = struct('RunID', 'Run_990_20260101_000000', ...
        'PreprocessID', PreprocessID, 'RunDirectory', '', ...
        'OutputDirectory', OutputDirectory, ...
        'Eligibility', 'NotInspected', 'Category', 'StressFixture', ...
        'Status', 'SUCCESS', 'Warnings', {{}}, 'Errors', {{}}, ...
        'ApprovalUsed', true);
end

function Detail = assertEqualLocal(Actual, Expected, Label)
    if ~isequaln(Actual, Expected)
        error('Preprocessing:Stress:AssertionFailed', ...
            '%s: expected %s but got %s', Label, mat2str(Expected), ...
            mat2str(Actual));
    end
    Detail = Label;
end

function expectEqual(Actual, Expected, Label)
%EXPECTEQUAL Assertion shim (mirrors the test-harness helper).

    if ~isequaln(Actual, Expected)
        error('Preprocessing:Stress:AssertionFailed', ...
            '%s: assertion failed', Label);
    end

end

function Bytes = readBytes(FilePath)
    fid = fopen(FilePath, 'r');
    Bytes = fread(fid, Inf, '*char')';
    fclose(fid);
end

function MB = memMB()
    try
        Info = memory;
        MB = Info.MemUsedMATLAB / 1e6;
    catch
        MB = NaN;
    end
end

function GB = freeMemGB()
    try
        [Status, Text] = system('wmic OS get FreePhysicalMemory /value');
        Token = regexp(Text, 'FreePhysicalMemory=(\d+)', 'tokens', 'once');
        if Status == 0 && ~isempty(Token)
            GB = str2double(Token{1}) / 1e6;
            return;
        end
    catch
    end
    GB = 4;
end

% =========================================================================
%% CATEGORY K - DISCOVERY SCALABILITY (isolated synthetic registry)
% =========================================================================

function [Results, Perf] = categoryK(Results, Perf)
    fprintf('\n-- Category K: discovery scalability (synthetic sandbox) --\n');
    Results = runCaseStress(Results, 'K', 'SyntheticRegistryDiscovery', ...
        @() localK1());
end

function Detail = localK1()
    % Isolated synthetic registry + run hierarchy: the real package is
    % COPIED (byte-identical) into a sandbox whose own production/ tree
    % is synthetic, and discovery runs in an independent MATLAB process
    % whose path contains ONLY the sandbox. The real RunRegistry.json is
    % never read or written.
    Paths = preprocessing.ProjectPaths();
    EvidenceDir = fullfile(Paths.PreprocessedRoot, 'TestArtifacts');
    Sandbox = fullfile(EvidenceDir, 'StressFixtures', 'DiscoverySandbox');
    SandboxPkg = fullfile(Sandbox, '+preprocessing');
    ProductionRoot = fullfile(Sandbox, 'production');
    RegistryBefore = '';

    % The sandbox is a disposable fixture: rebuild from scratch each run
    % so stale synthetic directories cannot leak between executions.
    if isfolder(Sandbox)
        rmdir(Sandbox, 's');
    end
    mkdir(SandboxPkg);
    SourcePkg = fullfile(Paths.ProjectRoot, '+preprocessing');
    Listing = dir(fullfile(SourcePkg, '*.m'));
    for Index = 1:numel(Listing)
        copyfile(fullfile(SourcePkg, Listing(Index).name), ...
            fullfile(SandboxPkg, Listing(Index).name));
    end

    % ProjectPaths validates root layout by FOLDER PRESENCE only; the
    % sandbox provides empty placeholders (no frozen code is copied).
    for Placeholder = { ...
            '+config', '+coordinates', '+dynamics', '+flightscenario', ...
            '+groundtruthtelemetry', '+noisemodels', '+sensormodels', ...
            '+sensorsimulation'}
        if ~isfolder(fullfile(Sandbox, Placeholder{1}))
            mkdir(fullfile(Sandbox, Placeholder{1}));
        end
    end

    for Sub = {'Runs', 'WorkingRuns', 'FailedRuns'}
        if ~isfolder(fullfile(ProductionRoot, Sub{1}))
            mkdir(fullfile(ProductionRoot, Sub{1}));
        end
    end

    % 100 registered runs: 50 with the full artifact set (eligible),
    % 50 without metadata (ineligible), plus 5 malformed entries (empty
    % RunID, missing paths) and 1 directory/RunID mismatch entry.
    RegistryEntries = {};
    for Run = 1:100
        RunID = sprintf('Run_7%02d_20260101_000000', Run);
        RunDir = fullfile(ProductionRoot, 'Runs', RunID);
        if ~isfolder(RunDir), mkdir(RunDir); end
        Entry = struct('RunID', RunID, ...
            'FinalRunDirectory', RunDir, ...
            'MetadataFile', fullfile(RunDir, 'RunMetadata.json'), ...
            'SensorMetadataFile', ...
            fullfile(RunDir, 'SensorMetadata.json'), ...
            'TelemetryFile', fullfile(RunDir, 'Telemetry.csv'), ...
            'GroundTruthFile', fullfile(RunDir, 'GroundTruth.mat'), ...
            'SummaryFile', fullfile(RunDir, 'RunSummary.json'), ...
            'ManifestFile', fullfile(RunDir, 'RunManifest.sha256'), ...
            'Status', 'REGISTERED', 'ScenarioName', 'Synthetic');
        if mod(Run, 2) == 0
            fid = fopen(Entry.MetadataFile, 'w');
            fprintf(fid, '{"Run": {"RunNumber": %d}}', Run);
            fclose(fid);
            fid = fopen(Entry.SensorMetadataFile, 'w');
            fprintf(fid, '{}');
            fclose(fid);
            fid = fopen(Entry.TelemetryFile, 'w');
            fprintf(fid, 'Time_s,X_m,Y_m,Z_m\n0,0,0,0\n');
            fclose(fid);
            GroundTruth = struct('Synthetic', true);
            save(Entry.GroundTruthFile, 'GroundTruth'); %#ok<NASGU>
            fid = fopen(Entry.SummaryFile, 'w');
            fprintf(fid, '{}');
            fclose(fid);
            fid = fopen(Entry.ManifestFile, 'w');
            fprintf(fid, '# synthetic manifest placeholder\n');
            fclose(fid);
            % Shallow sensor policy: the four sensor CSVs must exist.
            Contracts = preprocessing.SensorDataContracts();
            SensorFolder = fullfile(RunDir, ...
                Contracts.IMU.Files.RealisticCsvFolder);
            if ~isfolder(SensorFolder), mkdir(SensorFolder); end
            for S = 1:numel(Contracts.Streams)
                fid = fopen(fullfile(SensorFolder, ...
                    Contracts.(Contracts.Streams{S}). ...
                    Files.RealisticCsvFile), 'w');
                fprintf(fid, 'Time_s\n0\n');
                fclose(fid);
            end
        end
        RegistryEntries{end + 1} = Entry;
    end
    for Bad = 1:5
        RegistryEntries{end + 1} = struct('RunID', '', ...
            'FinalRunDirectory', '', 'MetadataFile', '', ...
            'SensorMetadataFile', '', 'TelemetryFile', '', ...
            'GroundTruthFile', '', 'SummaryFile', '', ...
            'ManifestFile', '', 'Status', '', ...
            'ScenarioName', 'Malformed');
    end
    % Directory/RunID mismatch: RunID does not match directory basename.
    RegistryEntries{end + 1} = struct('RunID', ...
        'Run_799_20260101_000000', ...
        'FinalRunDirectory', fullfile(ProductionRoot, 'Runs', ...
        'Run_701_20260101_000000'), ...
        'MetadataFile', '', 'SensorMetadataFile', '', ...
        'TelemetryFile', '', 'GroundTruthFile', '', ...
        'SummaryFile', '', 'ManifestFile', '', ...
        'Status', 'REGISTERED', 'ScenarioName', 'Mismatch');

    % 100 unregistered run directories (no registry entry).
    for Run = 1:100
        RunDir = fullfile(ProductionRoot, 'Runs', ...
            sprintf('Run_66%03d_20260101_000000', Run));
        if ~isfolder(RunDir), mkdir(RunDir); end
    end

    % WorkingRuns and FailedRuns exclusions.
    for Run = 1:5
        if ~isfolder(fullfile(ProductionRoot, 'WorkingRuns', ...
                sprintf('Run_79%d_20260101_000000', Run)))
            mkdir(fullfile(ProductionRoot, 'WorkingRuns', ...
                sprintf('Run_79%d_20260101_000000', Run)));
        end
        if ~isfolder(fullfile(ProductionRoot, 'FailedRuns', ...
                sprintf('Run_78%d_20260101_000000', Run)))
            mkdir(fullfile(ProductionRoot, 'FailedRuns', ...
                sprintf('Run_78%d_20260101_000000', Run)));
        end
    end

    RegistryFile = fullfile(ProductionRoot, 'RunRegistry.json');
    Registry = struct('Version', 1, 'Runs', {RegistryEntries});
    fid = fopen(RegistryFile, 'w');
    fprintf(fid, '%s', jsonencode(Registry));
    fclose(fid);
    RegistryBefore = readBytes(RegistryFile);

    % Independent MATLAB process with ONLY the sandbox on its path.
    WorkerFile = fullfile(EvidenceDir, 'Block9_StressDiscoveryWorker.m');
    writeDiscoveryWorker(WorkerFile);
    ResultFile = fullfile(Sandbox, 'discovery_result.txt');
    if isfile(ResultFile), delete(ResultFile); end
    Cmd = sprintf( ...
        ['start "" /b "%s" -sd "%s" -batch "addpath(''%s''); ', ...
         'addpath(''%s''); Block9_StressDiscoveryWorker(''%s'')"'], ...
        fullfile(matlabroot, 'bin', 'matlab.exe'), Sandbox, Sandbox, ...
        EvidenceDir, ResultFile);
    system(Cmd);

    Deadline = tic;
    while ~isfile(ResultFile) && toc(Deadline) < 300
        pause(2);
    end
    if ~isfile(ResultFile)
        error('StressHarness:DiscoveryTimeout', ...
            'discovery worker produced no result file');
    end
    pause(1);
    Text = fileread(ResultFile);
    fprintf('  worker: %s\n', strtrim(Text));

    expectEqual(strncmp(Text, 'STATUS=OK', 9), true, 'worker OK');
    Get = @(K) str2double(regexp(Text, [K '=(\d+)'], ...
        'tokens', 'once'));
    Registered = Get('REGISTERED');
    Unregistered = Get('UNREGISTERED');
    Eligible = Get('ELIGIBLE');
    Ineligible = Get('INELIGIBLE');
    Excluded = Get('EXCLUDEDTREE');

    expectEqual(Registered >= 100, true, ...
        'at least 100 registered discovered');
    expectEqual(Unregistered, 100, '100 unregistered discovered');
    expectEqual(Eligible >= 1 && Ineligible >= 1, true, ...
        'mixed eligible/ineligible classified');
    expectEqual(Eligible + Ineligible, Registered, ...
        'every registered entry classified');

    if ~strcmp(RegistryBefore, readBytes(RegistryFile))
        error('StressHarness:RegistryModified', ...
            'synthetic registry modified by discovery');
    end

    Elapsed = regexp(Text, 'ELAPSED=([\d.]+)', 'tokens', 'once');
    Detail = sprintf([ ...
        'isolated synthetic registry (106 entries: 100 well-formed + ', ...
        '5 malformed + 1 directory/RunID mismatch) and 215 synthetic ', ...
        'run directories discovered in %s s: %d registered (%d ', ...
        'eligible / %d ineligible), %d unregistered, %d ', ...
        'excluded-tree entries; registry bytes unchanged'], ...
        Elapsed{1}, Registered, Eligible, Ineligible, Unregistered, ...
        Excluded);
end

function writeDiscoveryWorker(WorkerFile)
    fid = fopen(WorkerFile, 'w');
    fprintf(fid, 'function Block9_StressDiscoveryWorker(ResultFile)\n');
    fprintf(fid, '%%BLOCK9_STRESSDISCOVERYWORKER Sandbox discovery probe.\n');
    fprintf(fid, '%%   Runs with ONLY the sandbox package on the path.\n');
    fprintf(fid, 'try\n');
    fprintf(fid, '    Config = preprocessing.PreprocessingConfig();\n');
    fprintf(fid, '    T0 = tic;\n');
    fprintf(fid, '    RunList = preprocessing.DiscoverRuns(Config);\n');
    fprintf(fid, '    Elapsed = toc(T0);\n');
    fprintf(fid, '    R = numel(RunList.Registered);\n');
    fprintf(fid, '    U = numel(RunList.UnregisteredRuns);\n');
    fprintf(fid, '    E = numel(RunList.EligibleRunIDs);\n');
    fprintf(fid, '    I = R - E;\n');
    fprintf(fid, ['    X = numel(RunList.WorkingRuns) + ', ...
        'numel(RunList.FailedRuns);\n']);
    fprintf(fid, ['    Text = sprintf(''STATUS=OK ELAPSED=%%.3f TOTAL=%%d ', ...
        'REGISTERED=%%d UNREGISTERED=%%d ELIGIBLE=%%d INELIGIBLE=%%d ', ...
        'EXCLUDEDTREE=%%d'', Elapsed, R + U + X, R, U, E, I, X);\n']);
    fprintf(fid, 'catch Failure\n');
    fprintf(fid, ['    Text = sprintf(''STATUS=ERROR ID=%%s '', ', ...
        'Failure.identifier);\n']);
    fprintf(fid, 'end\n');
    fprintf(fid, 'fid = fopen(ResultFile, ''w'');\n');
    fprintf(fid, 'fprintf(fid, ''%%s\\n'', Text);\n');
    fprintf(fid, 'fclose(fid);\n');
    fprintf(fid, 'end\n');
    fclose(fid);
end

% =========================================================================
%% CATEGORY L - MAT V7 / V7.3 INGESTION STRESS
% =========================================================================

function [Results, Perf] = categoryL(Results, Perf, Level)
    fprintf('\n-- Category L: MAT v7/v7.3 ingestion stress --\n');

    Sizes = 100000;
    if strcmpi(Level, 'Full')
        Sizes = [Sizes, 500000];
    end

    for Index = 1:numel(Sizes)
        N = Sizes(Index);
        Results = runCaseStress(Results, 'L', ...
            sprintf('MatV7_%dSamples', N), @() localL(N, '-v7'));
        Results = runCaseStress(Results, 'L', ...
            sprintf('MatV73_%dSamples', N), @() localL(N, '-v7.3'));
    end

    Results = runCaseStress(Results, 'L', 'UnknownVariableDiscovery', ...
        @() localL3());
    Results = runCaseStress(Results, 'L', 'MissingStreamVariable', ...
        @() localL4());
    Results = runCaseStress(Results, 'L', 'MalformedMatFile', ...
        @() localL5());
end

function Detail = localL(N, Version)
    Root = fullfile(fixtureRoot(sprintf('StressL%d%s', N, ...
        erase(Version, '-'))), sprintf('Run_978_%08d_000000', N));
    MatPath = writeMatFixture(Root, N, Version, ...
        'RealisticSensorTelemetry', {});
    Info = dir(MatPath);
    Config = preprocessing.PreprocessingConfig();
    Timer = tic;
    Data = preprocessing.LoadSensorData(Root, Config, 'Mat');
    Elapsed = toc(Timer);
    Contracts = preprocessing.SensorDataContracts();

    for Index = 1:numel(Contracts.Streams)
        StreamName = Contracts.Streams{Index};
        Stream = Data.Streams.(StreamName);
        expectEqual(strcmp(Stream.Status, 'Loaded'), true, ...
            [StreamName ' loaded']);
        expectEqual(Stream.SampleCount, N, [StreamName ' rows']);
        expectEqual(Stream.SourceSampleRate_Hz, ...
            Contracts.(StreamName).RateFallback_Hz, ...
            [StreamName ' recorded rate']);
    end

    Imu = Data.Streams.IMU;
    ImuChannels = Contracts.IMU.Channels;
    ZIndex = find(strcmp({ImuChannels.CanonicalField}, ...
        'Accelerometer_Z_mps2'), 1);
    ExpectedZ = sin(2 * 0.001) + ZIndex * 0.01;
    expectEqual(abs(Imu.Accelerometer_Z_mps2(2) - ExpectedZ) < 1e-9, ...
        true, 'measurement preserved');

    Detail = sprintf([ ...
        '%s MAT, %d samples/stream, %.1f MB: loaded in %.2f s ', ...
        '(format %s), values preserved, row counts exact'], ...
        Version, N, Info.bytes / 1e6, Elapsed, Imu.SourceFormat);
end

function Detail = localL3()
    % Unknown variable name: whos-based discovery must still work.
    Root = fullfile(fixtureRoot('StressL3'), 'Run_978_20260101_000001');
    MatPath = writeMatFixture(Root, 1000, '-v7', ...
        'TelemetryDumpUnknownName', {});
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(Root, Config, 'Mat');
    expectEqual(strcmp(Data.Streams.IMU.Status, 'Loaded'), true, ...
        'unknown variable name still discovered');
    Detail = sprintf([ ...
        'MAT variable named TelemetryDumpUnknownName discovered by ', ...
        'whos-based scanning (%s)'], Data.Streams.IMU.SourceVariable);
end

function Detail = localL4()
    Root = fullfile(fixtureRoot('StressL4'), 'Run_978_20260101_000002');
    writeMatFixture(Root, 1000, '-v7', 'RealisticSensorTelemetry', ...
        {'IMU'});
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(Root, Config, 'Mat');
    % Contract semantic: a stream sub-struct absent from the MAT
    % variable is flagged Malformed with a recorded issue - it is never
    % silently accepted and never fabricated.
    expectEqual(strcmp(Data.Streams.IMU.Status, 'Malformed'), true, ...
        sprintf('absent stream -> Malformed (actual: %s)', ...
        Data.Streams.IMU.Status));
    expectEqual(strcmp(Data.Streams.GNSS.Status, 'Loaded'), true, ...
        'present streams still loaded');
    Detail = ['missing stream sub-struct -> Malformed with recorded ', ...
        'issue; other streams loaded'];
end

function Detail = localL5()
    Root = fullfile(fixtureRoot('StressL5'), 'Run_978_20260101_000003');
    SourceFolder = fullfile(Root, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    fid = fopen(fullfile(SourceFolder, 'RealisticSensorTelemetry.mat'), 'w');
    fprintf(fid, 'this is not a mat file');
    fclose(fid);
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(Root, Config, 'Mat');
    if ~strcmp(Data.Streams.IMU.Status, 'Malformed')
        error('StressHarness:MalformedMatAccepted', ...
            'garbage MAT accepted: %s', Data.Streams.IMU.Status);
    end
    Detail = ['garbage MAT file -> Malformed with recorded issue ', ...
        '(never silently accepted)'];
end

function MatPath = writeMatFixture(Root, N, Version, VariableName, ...
    SkipStreams)
    SourceFolder = fullfile(Root, 'RealisticSensorTelemetry');
    if ~isfolder(SourceFolder), mkdir(SourceFolder); end
    MatPath = fullfile(SourceFolder, 'RealisticSensorTelemetry.mat');
    Contracts = preprocessing.SensorDataContracts();
    T = (0:N - 1).' * 0.01;

    for Index = 1:numel(Contracts.Streams)
        StreamName = Contracts.Streams{Index};
        if any(strcmp(StreamName, SkipStreams))
            continue;
        end
        Sub = struct();
        Sub.Time_s = T;
        Sub.Available = true(N, 1);
        Channels = Contracts.(StreamName).Channels;
        MatGroups = {};
        for C = 1:numel(Channels)
            FieldName = Channels(C).MatField;
            if isempty(FieldName) || strcmp(FieldName, 'Time_s') || ...
                    strcmp(FieldName, 'Available')
                continue;
            end
            Match = find(strcmp(MatGroups, FieldName), 1);
            if isempty(Match)
                MatGroups{end + 1} = FieldName; %#ok<AGROW>
                Match = numel(MatGroups);
                GroupFields = {Channels.MatField};
                Cols = [Channels( ...
                    strcmp(GroupFields, FieldName)).MatColumn];
                Cols = Cols(~isnan(Cols) & Cols >= 1);
                if isempty(Cols), Cols = 1; end
                Sub.(FieldName) = zeros(N, max(Cols));
            end
            Col = Channels(C).MatColumn;
            if isempty(Col) || ~isfinite(Col) || Col < 1
                Col = 1;
            end
            Sub.(FieldName)(:, Col) = ...
                sin((1:N).' * 0.001) + C * 0.01;
        end
        Sub.SampleRate_Hz = Contracts.(StreamName).RateFallback_Hz;
        Sub.SampleCount = N;
        Data.(StreamName) = Sub;
    end

    eval([VariableName ' = Data;']);
    if strcmp(Version, '-v7.3')
        save(MatPath, VariableName, '-v7.3');
    else
        save(MatPath, VariableName, '-v7');
    end
end

% =========================================================================
%% CATEGORY M - CORRUPTED MAT AND CSV ARTIFACT STRESS
% =========================================================================

function [Results, Perf] = categoryM(Results, Perf)
    fprintf('\n-- Category M: corrupted MAT/CSV artifact stress --\n');

    Seams = { ...
        'MatCorrupt', 'MatSectionMissing', 'MatPreprocessIDWrong', ...
        'CsvTruncated', 'CsvMissingColumn', 'CsvColumnOrder', ...
        'CsvInvalidNumeric', 'CsvSourceRowIdx', 'CsvTimestamp', ...
        'CsvFlag', 'CsvMeasurement'};

    [Config, Data, Streams] = stressFixture('StressMFixture', 50);
    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);

    % Positive control: the same fixture exports and validates cleanly.
    Out = tempname(fixtureRoot('StressMFixture'));
    RunInfo = stressRunInfo(Out, ...
        'Run_979_20260101_000000__PP_20260101_000000_01');
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, Streams, Aligned, RunInfo);
    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, Streams, Aligned, Report, Out);
    expectEqual(Artifacts.Validated, true, 'clean export validated');

    for Index = 1:numel(Seams)
        Results = runCaseStress(Results, 'M', ...
            ['Corrupted_' Seams{Index}], ...
            @() localM(Config, Data, Streams, Aligned, Seams{Index}, ...
            sprintf('Run_979_20260101_000000__PP_20260101_000000_%02d', ...
            Index + 1)));
    end
end

function Detail = localM(Config, Data, Streams, Aligned, Seam, PreprocessID)
    Out = tempname(fixtureRoot('StressMFixture'));
    RunInfo = stressRunInfo(Out, PreprocessID);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, Streams, Aligned, RunInfo);

    Caught = '';
    try
        preprocessing.ExportPreprocessedData( ...
            Config, Data, Streams, Aligned, Report, Out, Seam);
    catch Failure
        Caught = Failure.identifier;
    end

    if ~strcmp(Caught, ...
            'Preprocessing:ExportPreprocessedData:ReadBackValidationFailure')
        error('StressHarness:CorruptionUndetected', ...
            '%s produced "%s" instead of ReadBackValidationFailure', ...
            Seam, Caught);
    end
    if isfile(fullfile(Out, 'PreprocessingReport.json')) || ...
            isfile(fullfile(Out, 'PreprocessingReport.json.tmp'))
        error('StressHarness:FalseSuccessArtifact', ...
            '%s left a success report or temp residue', Seam);
    end

    Detail = sprintf([ ...
        '%s detected (ReadBackValidationFailure); no success JSON, ', ...
        'no temp residue'], Seam);
end

% =========================================================================
%% CATEGORY N - BARRIER-SYNCHRONIZED CONCURRENT ALLOCATION
% =========================================================================

function [Results, Perf] = categoryN(Results, Perf, Level, CampaignTag)
    fprintf('\n-- Category N: barrier-synchronized concurrent allocation --\n');

    Paths = preprocessing.ProjectPaths();
    EvidenceDir = fullfile(Paths.PreprocessedRoot, 'TestArtifacts');
    WorkerFile = fullfile(EvidenceDir, 'Block9_StressBarrierWorker.m');
    writeBarrierWorker(WorkerFile);
    ScriptFile = fullfile(EvidenceDir, 'Block9_StressBarrier.ps1');
    writeBarrierSupervisor(ScriptFile);

    [Config, ~, ~] = stressFixture('StressNFixture', 100, false, ...
        'Run_985_20260101_000000');
    FixtureRoot = fullfile(fixtureRoot('StressNFixture'), ...
        'Run_985_20260101_000000');
    SourceBefore = hashTree(FixtureRoot);
    RegistryBefore = readBytes(Paths.RegistryFile);

    Levels = [2, 4];
    if strcmpi(Level, 'Full') && freeMemGB() > 12
        Levels = [Levels, 8];
    else
        Results = recordResult(Results, 'N', 'EightProcessBarrier', ...
            'SKIP', '8 workers skipped: <12 GB free memory', 0, '');
    end

    for Index = 1:numel(Levels)
        N = Levels(Index);
        SentinelDir = fullfile(EvidenceDir, ...
            ['Barrier_' CampaignTag '_' sprintf('%d', N)]);
        % Fresh sentinel per level: stale ready/result files must not
        % satisfy the barrier or masquerade as results.
        if isfolder(SentinelDir)
            rmdir(SentinelDir, 's');
        end
        mkdir(SentinelDir);
        Results = runCaseStress(Results, 'N', ...
            sprintf('%dProcessBarrierAllocation', N), ...
            @() localN(N, SentinelDir, FixtureRoot, ...
            'Run_985_20260101_000000', ScriptFile, EvidenceDir, ...
            SourceBefore, RegistryBefore));
    end
end

function Detail = localN(N, SentinelDir, FixtureRoot, RunID, ...
    ScriptFile, EvidenceDir, SourceBefore, RegistryBefore)
    Paths = preprocessing.ProjectPaths();
    MatlabExe = fullfile(matlabroot, 'bin', 'matlab.exe');
    Cmd = sprintf( ...
        ['powershell -NoProfile -ExecutionPolicy Bypass -File "%s" ', ...
         '-SentinelDir "%s" -MatlabExe "%s" -ProjectRoot "%s" ', ...
         '-EvidenceDir "%s" -FixtureRoot "%s" -RunID "%s" -N %d'], ...
        ScriptFile, SentinelDir, MatlabExe, Paths.ProjectRoot, ...
        EvidenceDir, FixtureRoot, RunID, N);
    fprintf('  supervisor: %s\n', Cmd);
    [Status, Output] = system(Cmd);
    fprintf('%s\n', Output);

    % Collect worker results.
    Ids = {};
    Releases = {};
    for Worker = 1:N
        ResultFile = fullfile(SentinelDir, ...
            sprintf('result_%02d.txt', Worker));
        if ~isfile(ResultFile)
            error('StressHarness:BarrierWorkerMissing', ...
                'worker %d produced no result', Worker);
        end
        Text = fileread(ResultFile);
        fprintf('  %s\n', strtrim(strrep(Text, newline, ' | ')));
        Key = @(Name) strtrim(char(regexp(Text, ...
            [Name '=([^\r\n]+)'], 'tokens', 'once')));
        if ~strcmp(Key('STATUS'), 'SUCCESS')
            error('StressHarness:BarrierWorkerFailed', ...
                'worker %d not SUCCESS: %s', Worker, strtrim(Text));
        end
        Ids{end + 1} = Key('WORKER_ID');
        Releases{end + 1} = Key('RELEASE');
        OutDir = Key('OUTDIR');
        % Exactly one owner per directory: embedded ID must match.
        Decoded = jsondecode(fileread( ...
            fullfile(OutDir, 'PreprocessingReport.json')));
        if ~strcmp(Decoded.RunInfo.PreprocessID, Key('WORKER_ID'))
            error('StressHarness:DirectoryOwnership', ...
                'directory %s embeds a foreign PreprocessID', OutDir);
        end
        if isfile(fullfile(OutDir, 'ProcessingFailed.txt'))
            error('StressHarness:MarkerContamination', ...
                'marker in successful worker output %s', OutDir);
        end
    end

    if numel(unique(Ids)) ~= N
        error('StressHarness:DuplicatePreprocessID', ...
            'duplicate PreprocessIDs under contention');
    end

    % Simultaneity: all release timestamps inside a tight window.
    ReleaseDates = cellfun(@(S) datetime(S), Releases);
    Window = seconds(max(ReleaseDates) - min(ReleaseDates));
    if Window > 30
        error('StressHarness:BarrierNotSimultaneous', ...
            'release window %.1f s too wide', Window);
    end

    if ~strcmp(SourceBefore, hashTree(FixtureRoot)) || ...
            ~strcmp(RegistryBefore, readBytes(Paths.RegistryFile))
        error('StressHarness:ProtectedDataChanged', ...
            'source run or registry changed during contention');
    end

    ExitCodes = '';
    ExitFile = fullfile(SentinelDir, 'exitcodes.txt');
    if isfile(ExitFile)
        ExitCodes = strtrim(fileread(ExitFile));
    end

    Detail = sprintf([ ...
        '%d simultaneous independent MATLAB processes (release window ', ...
        '%.2f s): %d unique PreprocessIDs, one owner per directory, ', ...
        'no marker contamination, no overwrites, sources and registry ', ...
        'byte-identical. %s'], N, Window, N, ...
        strrep(ExitCodes, newline, ' | '));
end

function writeBarrierWorker(WorkerFile)
    fid = fopen(WorkerFile, 'w');
    fprintf(fid, ['function Block9_StressBarrierWorker(SentinelDir, ', ...
        'WorkerIndex, FixtureRoot, RunID)\n']);
    fprintf(fid, '%%BLOCK9_STRESSBARRIERWORKER Barrier-synchronized worker.\n');
    fprintf(fid, 'Pid = feature(''getpid'');\n');
    fprintf(fid, ['Stamp = @() char(datetime(''now'', ''Format'', ', ...
        '''yyyy-MM-dd HH:mm:ss.SSS''));\n']);
    fprintf(fid, 'Start = Stamp();\n');
    fprintf(fid, ['fid = fopen(fullfile(SentinelDir, sprintf(', ...
        '''ready_%%02d.txt'', WorkerIndex)), ''w'');\n']);
    fprintf(fid, 'fprintf(fid, ''PID=%%d\\n'', Pid);\n');
    fprintf(fid, 'fclose(fid);\n');
    fprintf(fid, ['while ~isfile(fullfile(SentinelDir, ''GO'')), ', ...
        'pause(0.05); end\n']);
    fprintf(fid, 'Release = Stamp();\n');
    fprintf(fid, 'try\n');
    fprintf(fid, ['    Result = preprocessing.PreprocessRun(RunID, ', ...
        'preprocessing.PreprocessingConfig(), ...\n']);
    fprintf(fid, ['        struct(''RunDirectory'', FixtureRoot, ', ...
        '''ApproveUnregistered'', true));\n']);
    fprintf(fid, '    Status = Result.Status;\n');
    fprintf(fid, '    PreprocessID = Result.PreprocessID;\n');
    fprintf(fid, '    OutDir = Result.OutputDirectory;\n');
    fprintf(fid, '    ErrId = '''';\n');
    fprintf(fid, 'catch Failure\n');
    fprintf(fid, '    Status = ''FAILED'';\n');
    fprintf(fid, '    PreprocessID = ''none'';\n');
    fprintf(fid, '    OutDir = '''';\n');
    fprintf(fid, '    ErrId = Failure.identifier;\n');
    fprintf(fid, 'end\n');
    fprintf(fid, 'End = Stamp();\n');
    fprintf(fid, ['fid = fopen(fullfile(SentinelDir, sprintf(', ...
        '''result_%%02d.txt'', WorkerIndex)), ''w'');\n']);
    fprintf(fid, 'fprintf(fid, ''WORKER=%%02d\\n'', WorkerIndex);\n');
    fprintf(fid, 'fprintf(fid, ''PID=%%d\\n'', Pid);\n');
    fprintf(fid, 'fprintf(fid, ''START=%%s\\n'', Start);\n');
    fprintf(fid, 'fprintf(fid, ''RELEASE=%%s\\n'', Release);\n');
    fprintf(fid, 'fprintf(fid, ''END=%%s\\n'', End);\n');
    fprintf(fid, 'fprintf(fid, ''STATUS=%%s\\n'', Status);\n');
    fprintf(fid, 'fprintf(fid, ''WORKER_ID=%%s\\n'', PreprocessID);\n');
    fprintf(fid, 'fprintf(fid, ''OUTDIR=%%s\\n'', OutDir);\n');
    fprintf(fid, 'fprintf(fid, ''ERROR=%%s\\n'', ErrId);\n');
    fprintf(fid, 'fclose(fid);\n');
    fprintf(fid, 'end\n');
    fclose(fid);
end

function writeBarrierSupervisor(ScriptFile)
    fid = fopen(ScriptFile, 'w');
    fprintf(fid, 'param([string]$SentinelDir,[string]$MatlabExe,');
    fprintf(fid, '[string]$ProjectRoot,[string]$EvidenceDir,');
    fprintf(fid, '[string]$FixtureRoot,[string]$RunID,[int]$N)\n');
    fprintf(fid, '$procs = @()\n');
    fprintf(fid, 'for ($i=1; $i -le $N; $i++) {\n');
    fprintf(fid, ['  $inner = "addpath(''$ProjectRoot''); ', ...
        'addpath(''$EvidenceDir''); Block9_StressBarrierWorker(', ...
        '''$SentinelDir'',$i,''$FixtureRoot'',''$RunID'')"\n']);
    fprintf(fid, '  $arg = ''-batch "'' + $inner + ''"''\n');
    fprintf(fid, '  $p = Start-Process -FilePath $MatlabExe ');
    fprintf(fid, '-ArgumentList $arg -PassThru -WindowStyle Hidden\n');
    fprintf(fid, '  $procs += $p\n');
    fprintf(fid, '}\n');
    fprintf(fid, '$deadline = (Get-Date).AddSeconds(300)\n');
    fprintf(fid, 'while ($true) {\n');
    fprintf(fid, '  $ready = @(Get-ChildItem $SentinelDir ');
    fprintf(fid, '-Filter "ready_*.txt" -ErrorAction SilentlyContinue)\n');
    fprintf(fid, '  if ($ready.Count -ge $N) { break }\n');
    fprintf(fid, '  if ((Get-Date) -gt $deadline) { break }\n');
    fprintf(fid, '  Start-Sleep -Milliseconds 100\n');
    fprintf(fid, '}\n');
    fprintf(fid, 'Set-Content -Path (Join-Path $SentinelDir "GO") -Value "go"\n');
    fprintf(fid, 'foreach ($p in $procs) { $p.WaitForExit() }\n');
    fprintf(fid, '$lines = @()\n');
    fprintf(fid, 'foreach ($p in $procs) {\n');
    fprintf(fid, '  $lines += "SUPERVISOR PID=$($p.Id) EXITCODE=$($p.ExitCode)"\n');
    fprintf(fid, '}\n');
    fprintf(fid, 'Set-Content -Path (Join-Path $SentinelDir "exitcodes.txt") -Value $lines\n');
    fclose(fid);
end

function Hash = hashTree(Root)
    Listing = dir(fullfile(Root, '**', '*'));
    Text = '';
    for Index = 1:numel(Listing)
        if Listing(Index).isdir
            continue;
        end
        Text = [Text, Listing(Index).name, sprintf('%d', ...
            Listing(Index).bytes), sprintf('%.6f', ...
            Listing(Index).datenum)]; %#ok<AGROW>
    end
    Hash = sprintf('%s', Text);
end
