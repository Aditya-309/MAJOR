function Result = PreprocessRun(RunID, Config, Options)
%PREPROCESSRUN Orchestrate Block 9 preprocessing for one run.
%
%   Result = PREPROCESSRUN(RunID, Config) preprocesses the requested run
%   and exports the approved artifacts to
%   production/Preprocessed/<RunID>/<PreprocessID>/.
%   Result = PREPROCESSRUN(RunID) uses the default PreprocessingConfig.
%   Result = PREPROCESSRUN(RunID, Config, Options) accepts:
%       Options.ApproveUnregistered (default false) - explicit approval
%           required to process a run that is not in RunRegistry.json.
%       Options.RunDirectory (default '') - explicit run directory
%           override for synthetic/bench runs. The override is recorded
%           in the result and does NOT bypass the safety controls:
%           - the directory basename must equal RunID
%             ('Preprocessing:PreprocessRun:RunDirectoryRunIDMismatch');
%           - path canonicalization must succeed
%             ('Preprocessing:PreprocessRun:PathCanonicalizationFailure');
%           - directories at or under WorkingRuns/FailedRuns are refused
%             ('Preprocessing:PreprocessRun:ProtectedRunDirectory');
%           - a registered run at that directory must satisfy the
%             standard eligibility rules; any other directory requires
%             Options.ApproveUnregistered - supplying Options.RunDirectory
%             never counts as approval
%             ('Preprocessing:PreprocessRun:ApprovalRequired').
%       Options.TestFailureInjection (default '') - TEST-ONLY controlled
%           failure hook used to exercise the failure path and the
%           ProcessingFailed.txt marker; 'ProcessingStage' raises
%           'Preprocessing:PreprocessRun:InjectedTestFailure' inside the
%           processing stage.
%
%   Processing sequence:
%       1. Configuration validated.
%       2. Run resolved via InspectRun (registry FinalRunDirectory; stale
%          RunMetadata.Paths never trusted).
%       3. Eligibility enforced: 'Eligible' proceeds; 'Unregistered'
%          requires Options.ApproveUnregistered; a Continue-policy run
%          with missing sensor files proceeds as PARTIAL; everything else
%          raises 'Preprocessing:PreprocessRun:RunNotEligible'.
%       4. Sensor data loaded (LoadSensorData), normalized, and processed
%          with the Phase-4 timestamp/quality/outlier functions.
%       5. Strict missing-sensor policy enforced
%          ('Preprocessing:PreprocessRun:MissingRequiredSensor').
%       6. Aligned data built only when Config.Alignment.Enabled.
%       7. Report built (BuildPreprocessingReport).
%       8. MAT, JSON and review CSVs exported and read back
%          (ExportPreprocessedData).
%
%   Status semantics:
%       'SUCCESS' - all required processing and exports completed.
%       'PARTIAL' - required processing completed but an optional sensor
%                   or optional operation was unavailable or skipped.
%       'FAILED'  - a required operation failed; the output directory
%                   carries a ProcessingFailed.txt marker and must not be
%                   treated as a result. Nothing pre-existing is deleted.
%
%   A unique PreprocessID <RunID>__PP_<yyyymmdd_HHMMSS>_<nn> is allocated
%   per call; existing outputs are never overwritten or reused.
%
%   Public Block 9 API entry point (together with DiscoverRuns, InspectRun
%   and GetPreprocessingReport).
%
%   See also: GetPreprocessingReport, ExportPreprocessedData,
%   BuildAlignedSensorData, InspectRun.

    %% Validate Inputs

    if nargin < 2 || isempty(Config)

        Config = preprocessing.PreprocessingConfig();

    end

    preprocessing.ValidatePreprocessingConfig(Config);

    if nargin < 3 || isempty(Options)

        Options = struct();

    end

    if ~isstruct(Options) || ~isscalar(Options)

        error( ...
            'Preprocessing:PreprocessRun:InvalidOptions', ...
            'Options must be a scalar structure.');

    end

    if ~isfield(Options, 'ApproveUnregistered')
        Options.ApproveUnregistered = false;
    end

    if ~isfield(Options, 'RunDirectory')
        Options.RunDirectory = '';
    end

    if ~(islogical(Options.ApproveUnregistered) && ...
            isscalar(Options.ApproveUnregistered))

        error( ...
            'Preprocessing:PreprocessRun:InvalidOptions', ...
            'Options.ApproveUnregistered must be a logical scalar.');

    end

    if ~(ischar(Options.RunDirectory) || ...
            (isstring(Options.RunDirectory) && isscalar(Options.RunDirectory)))

        error( ...
            'Preprocessing:PreprocessRun:InvalidOptions', ...
            'Options.RunDirectory must be a text scalar.');

    end

    if ~isfield(Options, 'TestFailureInjection')
        Options.TestFailureInjection = '';
    end

    if ~(ischar(Options.TestFailureInjection) || ...
            (isstring(Options.TestFailureInjection) && ...
            isscalar(Options.TestFailureInjection)))

        error( ...
            'Preprocessing:PreprocessRun:InvalidOptions', ...
            'Options.TestFailureInjection must be a text scalar.');

    end

    if ~isempty(char(Options.TestFailureInjection)) && ...
            ~strcmp(char(Options.TestFailureInjection), 'ProcessingStage')

        error( ...
            'Preprocessing:PreprocessRun:InvalidOptions', ...
            ['Options.TestFailureInjection must be empty or ', ...
             '''ProcessingStage''.']);

    end

    if ~(ischar(RunID) && isrow(RunID)) && ...
            ~(isstring(RunID) && isscalar(RunID))

        error( ...
            'Preprocessing:PreprocessRun:InvalidRunID', ...
            'RunID must be a nonempty character vector or scalar string.');

    end

    RunID = char(RunID);
    Paths = preprocessing.ProjectPaths();

    %% Resolve Run And Enforce Eligibility

    ApprovalUsed = false;

    if ~isempty(char(Options.RunDirectory))

        RunDirectory = char(Options.RunDirectory);

        % Fail closed: canonicalization must succeed before any path
        % comparison or existence check; an uncanonicalized path is never
        % compared or processed. The canonical path becomes the recorded
        % provenance (no traversal or relative remnants).
        CanonicalRun = canonicalPath(RunDirectory);
        RunDirectory = CanonicalRun;

        if ~isfolder(CanonicalRun)

            error( ...
                'Preprocessing:PreprocessRun:RunNotEligible', ...
                'Options.RunDirectory "%s" does not exist.', ...
                RunDirectory);

        end

        % Protected locations are refused before any other rule so path
        % manipulation cannot bypass the WorkingRuns/FailedRuns exclusion.
        if isSameOrDescendant(CanonicalRun, ...
                canonicalPath(Paths.WorkingRunsRoot)) || ...
                isSameOrDescendant(CanonicalRun, ...
                canonicalPath(Paths.FailedRunsRoot))

            error( ...
                ['Preprocessing:PreprocessRun:', ...
                 'ProtectedRunDirectory'], ...
                ['Options.RunDirectory "%s" lies at or inside the ', ...
                 'protected WorkingRuns/FailedRuns trees and cannot be ', ...
                 'processed as a completed run.'], ...
                RunDirectory);

        end

        [~, BaseName] = fileparts(CanonicalRun);

        if ~strcmp(BaseName, RunID)

            error( ...
                ['Preprocessing:PreprocessRun:', ...
                 'RunDirectoryRunIDMismatch'], ...
                ['Options.RunDirectory basename "%s" does not match ', ...
                 'RunID "%s"; a run directory is never relabeled as ', ...
                 'another run.'], ...
                BaseName, RunID);

        end

        try

            Inspection = preprocessing.InspectRun(RunID, Config);

        catch InspectFailure

            if strcmp(InspectFailure.identifier, ...
                    'Preprocessing:InspectRun:RunNotFound')

                Inspection = [];

            else

                rethrow(InspectFailure);

            end

        end

        if ~isempty(Inspection) && strcmp( ...
                canonicalPath(Inspection.RunDirectory), CanonicalRun)

            % The registered run directory for this RunID: the standard
            % eligibility rules apply unchanged.
            RunDirectory = Inspection.RunDirectory;
            ApprovalUsed = applyEligibilityGate( ...
                Inspection, Config, Options, RunID);
            Eligibility = Inspection.Eligibility;
            Category = Inspection.Category;

        else

            % Not the registered run directory (synthetic/bench): an
            % explicit approval is required. Supplying Options.RunDirectory
            % never counts as approval.
            if ~Options.ApproveUnregistered

                error( ...
                    ['Preprocessing:PreprocessRun:', ...
                     'ApprovalRequired'], ...
                    ['Options.RunDirectory "%s" is not the registered ', ...
                     'run directory for "%s"; explicit approval ', ...
                     '(Options.ApproveUnregistered) is required. ', ...
                     'Supplying Options.RunDirectory does not ', ...
                     'constitute approval.'], ...
                    RunDirectory, RunID);

            end

            ApprovalUsed = true;
            Eligibility = 'Unregistered';
            Category = 'SyntheticOverride';

        end

    else

        Inspection = preprocessing.InspectRun(RunID, Config);
        RunDirectory = Inspection.RunDirectory;
        ApprovalUsed = applyEligibilityGate( ...
            Inspection, Config, Options, RunID);
        Eligibility = Inspection.Eligibility;
        Category = Inspection.Category;

    end

    %% Load Sensor Data (read-only stage)

    Data = preprocessing.LoadSensorData(RunDirectory, Config, 'Auto');

    RequiredSensors = Config.MissingSensors.RequiredSensors;
    MissingRequired = intersect(Data.MissingSensors, RequiredSensors);

    if ~isempty(MissingRequired) && ...
            strcmpi(char(Config.MissingSensors.Policy), 'Strict')

        error( ...
            'Preprocessing:PreprocessRun:MissingRequiredSensor', ...
            ['Strict missing-sensor policy: required sensor(s) absent: ', ...
             '%s.'], ...
            strjoin(MissingRequired, ', '));

    end

    %% Allocate Unique Output Directory

    [PreprocessID, OutputDirectory] = allocateOutputDirectory( ...
        RunID, Paths.PreprocessedRoot);

    %% Processing And Export Stage

    Warnings = Data.Warnings;
    Errors = {};

    try

        if ~isempty(char(Options.TestFailureInjection))

            error( ...
                'Preprocessing:PreprocessRun:InjectedTestFailure', ...
                ['Controlled test failure injected ', ...
                 '(Options.TestFailureInjection=''%s'').'], ...
                char(Options.TestFailureInjection));

        end

        ProcessedStreams = struct();
        StreamStatuses = struct();
        Contracts = preprocessing.SensorDataContracts();

        for Index = 1:numel(Contracts.Streams)

            StreamName = Contracts.Streams{Index};

            if ~isfield(Data.Streams, StreamName) || ...
                    ~strcmp(Data.Streams.(StreamName).Status, 'Loaded')

                continue;

            end

            Stream = Data.Streams.(StreamName);
            Stream = preprocessing.ProcessSensorTimestamps( ...
                Config, Stream, StreamName);
            Stream = preprocessing.InspectSensorQuality( ...
                Config, Stream, StreamName);
            Stream = preprocessing.DetectSensorOutliers( ...
                Config, Stream, StreamName);

            ProcessedStreams.(StreamName) = Stream;

        end

        StreamNames = fieldnames(Data.Streams);

        for Index = 1:numel(StreamNames)

            StreamStatuses.(StreamNames{Index}) = ...
                Data.Streams.(StreamNames{Index}).Status;

        end

        Aligned = preprocessing.BuildAlignedSensorData( ...
            Config, ProcessedStreams);

        AlignmentSkipped = Config.Alignment.Enabled && ...
            ~strcmp(Aligned.Status, 'Generated');

        %% Determine Preliminary Status

        IsPartial = ~isempty(Data.MissingSensors) || ...
            ~isempty(Data.Issues) || AlignmentSkipped;

        if IsPartial

            Status = 'PARTIAL';

        else

            Status = 'SUCCESS';

        end

        %% Build Report And Export

        RunInfo = struct( ...
            'RunID', RunID, ...
            'PreprocessID', PreprocessID, ...
            'RunDirectory', RunDirectory, ...
            'OutputDirectory', OutputDirectory, ...
            'Eligibility', Eligibility, ...
            'Category', Category, ...
            'Status', Status, ...
            'Warnings', {Warnings}, ...
            'Errors', {Errors}, ...
            'ApprovalUsed', ApprovalUsed);

        Report = preprocessing.BuildPreprocessingReport( ...
            Config, Data, ProcessedStreams, Aligned, RunInfo);

        [Artifacts, Report] = preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, ...
            OutputDirectory);

    catch ProcessingFailure

        Errors = {sprintf('%s: %s', ...
            ProcessingFailure.identifier, ProcessingFailure.message)};
        Status = 'FAILED';

        if isfolder(OutputDirectory)

            MarkerFile = fullfile(OutputDirectory, 'ProcessingFailed.txt');

            try

                fid = fopen(MarkerFile, 'w');

                if fid > 0

                    fprintf(fid, '%s\n', Errors{1});
                    fclose(fid);

                end

            catch

                % Marker writing is best-effort; the returned FAILED
                % status remains authoritative.

            end

        end

        Result = struct();
        Result.RunID = RunID;
        Result.PreprocessID = PreprocessID;
        Result.Status = Status;
        Result.OutputDirectory = OutputDirectory;
        Result.Eligibility = Eligibility;
        Result.Category = Category;
        Result.ApprovalUsed = ApprovalUsed;
        Result.AlignedEnabled = Config.Alignment.Enabled;
        Result.StreamStatuses = struct();
        Result.MatFile = '';
        Result.JsonFile = '';
        Result.ReviewFiles = struct();
        Result.Warnings = Warnings;
        Result.Errors = Errors;
        Result.Report = [];
        return;

    end

    %% Build Result

    Result = struct();
    Result.RunID = RunID;
    Result.PreprocessID = PreprocessID;
    Result.Status = Status;
    Result.OutputDirectory = OutputDirectory;
    Result.Eligibility = Eligibility;
    Result.Category = Category;
    Result.ApprovalUsed = ApprovalUsed;
    Result.AlignedEnabled = Config.Alignment.Enabled;
    Result.StreamStatuses = StreamStatuses;
    Result.MatFile = Artifacts.MatFile;
    Result.JsonFile = Artifacts.JsonFile;
    Result.ReviewFiles = Artifacts.ReviewFiles;
    Result.Warnings = Warnings;
    Result.Errors = Errors;
    Result.Report = Report;

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function [PreprocessID, OutputDirectory] = allocateOutputDirectory( ...
    RunID, PreprocessedRoot)
%ALLOCATEOUTPUTDIRECTORY Allocate a unique PreprocessID and create its dir.
%   Ownership is established by EXCLUSIVE directory creation (F-07):
%   java.nio.file.Files.createDirectory fails if the directory already
%   exists, so two concurrent MATLAB sessions can never claim the same
%   PreprocessID directory. A successful mkdir is never treated as proof
%   of exclusive ownership. Existing output directories are never reused
%   or overwritten; a claimed name moves to the next sequence number.

    Stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    ParentDirectory = fullfile(PreprocessedRoot, RunID);

    try

        java.nio.file.Files.createDirectories( ...
            java.io.File(ParentDirectory).toPath(), ...
            javaArray('java.nio.file.attribute.FileAttribute', 0));

    catch ParentFailure

        error( ...
            ['Preprocessing:PreprocessRun:', ...
             'OutputDirectoryCreationFailure'], ...
            'Could not create "%s": %s', ...
            ParentDirectory, ...
            regexprep(ParentFailure.message, '[\x00-\x1F]', ' '));

    end

    for Sequence = 1:99

        PreprocessID = sprintf('%s__PP_%s_%02d', RunID, Stamp, Sequence);
        OutputDirectory = fullfile( ...
            PreprocessedRoot, RunID, PreprocessID);

        try

            java.nio.file.Files.createDirectory( ...
                java.io.File(OutputDirectory).toPath(), ...
                javaArray('java.nio.file.attribute.FileAttribute', 0));
            return;

        catch CreationFailure

            if isfolder(OutputDirectory) || isfile(OutputDirectory)

                % The name is already claimed (possibly by a concurrent
                % session whose ownership is respected): never reuse it.
                continue;

            end

            error( ...
                ['Preprocessing:PreprocessRun:', ...
                 'OutputDirectoryCreationFailure'], ...
                'Could not create "%s": %s', ...
                OutputDirectory, ...
                regexprep(CreationFailure.message, '[\x00-\x1F]', ' '));

        end

    end

    error( ...
        'Preprocessing:PreprocessRun:PreprocessIDExhausted', ...
        ['Could not allocate a unique PreprocessID for run "%s" ', ...
         '(99 collisions).'], ...
        RunID);

end

function ApprovalUsed = applyEligibilityGate(Inspection, Config, Options, ...
    RunID)
%APPLYELIGIBILITYGATE Shared eligibility rules for both resolution paths.

    ApprovalUsed = false;
    ContinuePolicy = strcmpi( ...
        char(Config.MissingSensors.Policy), 'Continue');
    MissingOnly = isempty(Inspection.Issues) && ...
        ~isempty(Inspection.MissingSensors);

    if strcmp(Inspection.Eligibility, 'Eligible')

        % proceed

    elseif strcmp(Inspection.Category, 'Unregistered')

        if ~Options.ApproveUnregistered

            error( ...
                ['Preprocessing:PreprocessRun:', ...
                 'ApprovalRequired'], ...
                ['Run "%s" is not in RunRegistry.json; explicit ', ...
                 'approval (Options.ApproveUnregistered) is ', ...
                 'required.'], ...
                RunID);

        end

        ApprovalUsed = true;

    elseif MissingOnly && ContinuePolicy

        % proceed as PARTIAL later

    else

        error( ...
            'Preprocessing:PreprocessRun:RunNotEligible', ...
            'Run "%s" is not eligible: %s.', ...
            RunID, ...
            strjoin(Inspection.Issues, '; '));

    end

end

function Canonical = canonicalPath(PathText)
%CANONICALPATH Canonical absolute path (resolves .. and symlinks).
%   Fail closed: a path that cannot be canonicalized raises a typed error
%   and is never used for comparison or processing. Relative paths are
%   resolved against the MATLAB working directory (pwd), never against
%   the JVM launch directory.

    try

        JavaFile = java.io.File(char(PathText));

        if ~JavaFile.isAbsolute()

            JavaFile = java.io.File(fullfile(pwd, char(PathText)));

        end

        Canonical = char(JavaFile.getCanonicalPath());

    catch

        error( ...
            ['Preprocessing:PreprocessRun:', ...
             'PathCanonicalizationFailure'], ...
            ['Path "%s" could not be canonicalized; an ', ...
             'uncanonicalized path is never used for comparison or ', ...
             'processing.'], ...
            regexprep(char(PathText), '[\x00-\x1F]', '?'));

    end

end

function TF = isSameOrDescendant(PathText, RootText)
%ISSAMEORDESCENDANT True when PathText is RootText or lies beneath it.

    PathText = char(PathText);
    RootText = char(RootText);

    if length(RootText) > 1 && (RootText(end) == '\' || RootText(end) == '/')

        RootText = RootText(1:end - 1);

    end

    Prefix = [RootText filesep];
    TF = strcmpi(PathText, RootText) || ...
        strncmpi(PathText, Prefix, length(Prefix));

end
