function Inspection = InspectRun(RunID, Config)
%INSPECTRUN Inspect one production run without modifying anything.
%
%   Inspection = INSPECTRUN(RunID, Config) inspects the artifacts and
%   metadata of the given run and returns an eligibility verdict.
%   Inspection = INSPECTRUN(RunID) uses the default PreprocessingConfig.
%
%   RunID resolution order:
%       1. RunRegistry.json entry  -> PathSource 'RunRegistry.FinalRunDirectory'
%          (fallback 'RunFolderMatchFallback' if the recorded directory is
%          missing but production/Runs/<RunID> exists)
%       2. production/Runs/<RunID> -> PathSource 'RunFolderMatch'
%          (Category 'Unregistered', eligibility 'ReviewRequired')
%       3. production/WorkingRuns/<RunID> and production/FailedRuns/<RunID>
%          are inspected but excluded from normal selection.
%       4. Not found anywhere -> error 'Preprocessing:InspectRun:RunNotFound'
%
%   RunMetadata.Paths fields are known to be stale after finalization and
%   are never used for path resolution (the recorded value is returned in
%   Inspection.ReportedWorkingRunDirectory as untrusted diagnostic data).
%
%   Output fields:
%       Inspection.RunID, .ConfigSource, .Category, .PathSource
%       Inspection.RunDirectory, .InRegistry, .Eligibility
%       Inspection.Issues, .Warnings, .MissingSensors
%       Inspection.ReportedWorkingRunDirectory
%       Inspection.MetadataSections, .MetadataCounts
%       Inspection.Artifacts, .Summary
%
%   Artifacts entries contain: RelativePath, Kind ('Metadata', 'Csv',
%   'Mat', 'Folder'), Source ('Required', 'Inventory'), Exists, Bytes,
%   CheckOk, CheckDetail. CSV headers are checked against the naming
%   dialect of Config.Source and MAT files are checked for their expected
%   variable by file contents (whos), never by assumed load names.
%
%   Eligibility values: 'Eligible', 'ReviewRequired', 'Ineligible'.
%   Missing required sensors: 'Ineligible' under the 'Strict' policy,
%   'ReviewRequired' (processed as PARTIAL later) under 'Continue'.
%
%   Inspection is strictly read-only: no file is created, modified or
%   deleted.
%
%   Public Block 9 API entry point (together with DiscoverRuns,
%   PreprocessRun and GetPreprocessingReport).
%
%   See also: DiscoverRuns, PreprocessingConfig, SensorDataContracts.

    %% Validate Inputs

    if ~(ischar(RunID) && isrow(RunID)) || isempty(RunID)

        if isstring(RunID) && isscalar(RunID) && strlength(RunID) > 0

            RunID = char(RunID);

        else

            error( ...
                'Preprocessing:InspectRun:InvalidRunID', ...
                'RunID must be a nonempty character vector or scalar string.');

        end

    end

    if nargin < 2
        Config = preprocessing.PreprocessingConfig();
    end

    preprocessing.ValidatePreprocessingConfig(Config);
    Paths = preprocessing.ProjectPaths();

    %% Initialize Output

    Inspection = struct();
    Inspection.RunID = RunID;
    Inspection.ConfigSource = char(Config.Source);
    Inspection.Category = '';
    Inspection.PathSource = '';
    Inspection.RunDirectory = '';
    Inspection.InRegistry = false;
    Inspection.Eligibility = '';
    Inspection.Issues = {};
    Inspection.Warnings = {};
    Inspection.MissingSensors = {};
    Inspection.ReportedWorkingRunDirectory = '';
    Inspection.MetadataSections = {};
    Inspection.MetadataCounts = struct();
    Inspection.Artifacts = emptyArtifacts();
    Inspection.Summary = struct( ...
        'RequiredCount', 0, ...
        'RequiredPresent', 0, ...
        'InventoryCount', 0, ...
        'InventoryPresent', 0, ...
        'ChecksPassed', 0, ...
        'ChecksFailed', 0);

    %% Resolve The Run

    RegistryRuns = readRegistryRuns(Paths.RegistryFile);
    RegistryEntry = [];

    for Index = 1:numel(RegistryRuns)

        if strcmp(entryText(RegistryRuns(Index), 'RunID'), RunID)

            RegistryEntry = RegistryRuns(Index);
            break;

        end

    end

    if ~isempty(RegistryEntry)

        Inspection.InRegistry = true;
        Inspection.Category = 'Registered';
        Inspection.RunDirectory = ...
            entryText(RegistryEntry, 'FinalRunDirectory');
        Inspection.PathSource = 'RunRegistry.FinalRunDirectory';

        if ~isfolder(Inspection.RunDirectory)

            FallbackDirectory = fullfile(Paths.RunsRoot, RunID);

            if isfolder(FallbackDirectory)

                Inspection.RunDirectory = FallbackDirectory;
                Inspection.PathSource = 'RunFolderMatchFallback';
                Inspection.Issues{end + 1} = 'FinalRunDirectoryMissing';

            else

                Inspection.Issues{end + 1} = 'MissingRunFolder';
                Inspection.Eligibility = 'Ineligible';
                return;

            end

        end

    elseif isfolder(fullfile(Paths.RunsRoot, RunID))

        Inspection.Category = 'Unregistered';
        Inspection.RunDirectory = fullfile(Paths.RunsRoot, RunID);
        Inspection.PathSource = 'RunFolderMatch';
        Inspection.Issues{end + 1} = 'NotInRunRegistry';

    elseif isfolder(fullfile(Paths.WorkingRunsRoot, RunID))

        Inspection.Category = 'WorkingRun';
        Inspection.RunDirectory = fullfile(Paths.WorkingRunsRoot, RunID);
        Inspection.PathSource = 'ExcludedLocation';
        Inspection.Issues{end + 1} = 'ExcludedLocation:WorkingRuns';
        Inspection.Eligibility = 'Ineligible';
        return;

    elseif isfolder(fullfile(Paths.FailedRunsRoot, RunID))

        Inspection.Category = 'FailedRun';
        Inspection.RunDirectory = fullfile(Paths.FailedRunsRoot, RunID);
        Inspection.PathSource = 'ExcludedLocation';
        Inspection.Issues{end + 1} = 'ExcludedLocation:FailedRuns';
        Inspection.Eligibility = 'Ineligible';
        return;

    else

        error( ...
            'Preprocessing:InspectRun:RunNotFound', ...
            ['Run "%s" was not found in the registry, Runs, WorkingRuns ', ...
             'or FailedRuns.'], ...
            RunID);

    end

    %% Inspect Metadata

    MetadataPath = fullfile(Inspection.RunDirectory, 'RunMetadata.json');

    if isfile(MetadataPath)

        try

            Metadata = jsondecode(fileread(MetadataPath));

        catch DecodeFailure

            Metadata = [];
            Inspection.Issues{end + 1} = 'MetadataDecodeFailure';
            Inspection.Warnings{end + 1} = sprintf( ...
                'RunMetadata.json could not be decoded: %s', ...
                DecodeFailure.message);

        end

        if isstruct(Metadata) && isscalar(Metadata)

            Inspection.MetadataSections = sort(fieldnames(Metadata))';

            RequiredSections = { ...
                'Run', 'Project', 'Scenario', 'Configuration', ...
                'Paths', 'Validation', 'Telemetry'};
            MissingSections = ...
                RequiredSections(~ismember( ...
                    RequiredSections, Inspection.MetadataSections));

            if ~isempty(MissingSections)

                Inspection.Warnings{end + 1} = sprintf( ...
                    'MetadataSectionsMissing:%s', ...
                    strjoin(MissingSections, ','));

            end

            if isfield(Metadata, 'Run') && ...
                    isfield(Metadata.Run, 'RunID') && ...
                    ~strcmp(Metadata.Run.RunID, RunID)

                Inspection.Issues{end + 1} = 'MetadataRunIDMismatch';

            end

            if isfield(Metadata, 'Telemetry')

                Inspection.MetadataCounts = Metadata.Telemetry;

            end

            if isfield(Metadata, 'Paths') && ...
                    isfield(Metadata.Paths, 'WorkingRunDirectory')

                Inspection.ReportedWorkingRunDirectory = ...
                    Metadata.Paths.WorkingRunDirectory;

            end

        end

    else

        Inspection.Issues{end + 1} = 'MissingMetadataFile';

    end

    Inspection.Warnings{end + 1} = ...
        'RunMetadata.Paths ignored for resolution (stale after finalization).';

    %% Inspect Artifacts

    Contracts = preprocessing.SensorDataContracts();
    Artifacts = emptyArtifacts();
    NextIndex = 0;

    RequiredSpecs = requiredArtifactSpecs(Contracts, char(Config.Source));

    for Index = 1:numel(RequiredSpecs)

        Spec = RequiredSpecs{Index};
        NextIndex = NextIndex + 1;
        Artifacts(NextIndex) = inspectArtifact( ...
            Inspection.RunDirectory, Spec{1}, Spec{2}, 'Required');

    end

    InventorySpecs = inventoryArtifactSpecs(Contracts, char(Config.Source));

    for Index = 1:numel(InventorySpecs)

        Spec = InventorySpecs{Index};
        NextIndex = NextIndex + 1;
        Artifacts(NextIndex) = inspectArtifact( ...
            Inspection.RunDirectory, Spec{1}, Spec{2}, 'Inventory');

    end

    Inspection.Artifacts = Artifacts;

    %% Missing-Sensor Policy

    RequiredFlags = strcmp({Artifacts.Source}, 'Required') & ...
        strcmp({Artifacts.Kind}, 'Csv');
    RequiredCsv = Artifacts(RequiredFlags);
    Inspection.MissingSensors = {};

    for Index = 1:numel(RequiredCsv)

        if ~RequiredCsv(Index).Exists

            Tokens = strsplit(RequiredCsv(Index).RelativePath, filesep);
            StreamName = erase(Tokens{end}, '.csv');
            Inspection.MissingSensors{end + 1} = StreamName;

        end

    end

    RequiredSensors = Config.MissingSensors.RequiredSensors;
    MissingRequired = intersect(Inspection.MissingSensors, RequiredSensors);

    if ~isempty(MissingRequired)

        IssueText = sprintf('MissingRequiredSensor:%s', ...
            strjoin(MissingRequired, ','));

        if strcmpi(char(Config.MissingSensors.Policy), 'Strict')

            Inspection.Issues{end + 1} = IssueText;

        else

            Inspection.Warnings{end + 1} = [IssueText ' (Continue policy)'];

        end

    end

    MissingOptional = setdiff(Inspection.MissingSensors, RequiredSensors);

    if ~isempty(MissingOptional)

        Inspection.Warnings{end + 1} = sprintf('MissingSensor:%s', ...
            strjoin(MissingOptional, ','));

    end

    %% Summary And Eligibility

    RequiredMask = strcmp({Artifacts.Source}, 'Required');
    InventoryMask = strcmp({Artifacts.Source}, 'Inventory');
    CheckedMask = ~cellfun(@isnan, {Artifacts.CheckOk});

    Inspection.Summary = struct( ...
        'RequiredCount', sum(RequiredMask), ...
        'RequiredPresent', sum([Artifacts(RequiredMask).Exists]), ...
        'InventoryCount', sum(InventoryMask), ...
        'InventoryPresent', sum([Artifacts(InventoryMask).Exists]), ...
        'ChecksPassed', sum([Artifacts(CheckedMask).CheckOk] == true), ...
        'ChecksFailed', sum([Artifacts(CheckedMask).CheckOk] == false));

    for Index = 1:numel(Artifacts)

        if Artifacts(Index).Exists && ...
                isequal(Artifacts(Index).CheckOk, false)

            if strcmp(Artifacts(Index).Source, 'Required')

                Inspection.Issues{end + 1} = sprintf( ...
                    'ArtifactCheckFailed:%s', ...
                    Artifacts(Index).RelativePath);

            else

                Inspection.Warnings{end + 1} = sprintf( ...
                    'ArtifactCheckWarning:%s', ...
                    Artifacts(Index).RelativePath);

            end

        end

    end

    if strcmp(Inspection.Category, 'Unregistered')

        Inspection.Eligibility = 'ReviewRequired';

    elseif isempty(Inspection.Issues) && ...
            Inspection.Summary.RequiredPresent == ...
                Inspection.Summary.RequiredCount

        Inspection.Eligibility = 'Eligible';

    elseif isempty(Inspection.Issues)

        Inspection.Eligibility = 'Ineligible';

    elseif any(strcmp(Inspection.Issues, 'NotInRunRegistry'))

        Inspection.Eligibility = 'ReviewRequired';

    else

        Inspection.Eligibility = 'Ineligible';

    end

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function RegistryRuns = readRegistryRuns(RegistryFile)
%READREGISTRYRUNS Read registry entries; empty when no registry exists.

    RegistryRuns = struct([]);

    if ~isfile(RegistryFile)

        return;

    end

    Registry = jsondecode(fileread(RegistryFile));

    if isstruct(Registry) && isscalar(Registry) && isfield(Registry, 'Runs')

        RegistryRuns = Registry.Runs;

        if isempty(RegistryRuns)
            RegistryRuns = struct([]);
        else
            RegistryRuns = RegistryRuns(:);
        end

    end

end

function Text = entryText(Entry, FieldName)
%ENTRYTEXT Registry entry text field with missing-field tolerance.

    if isfield(Entry, FieldName) && ischar(Entry.(FieldName))

        Text = Entry.(FieldName);

    else

        Text = '';

    end

end

function Artifacts = emptyArtifacts()
%EMPTYARTIFACTS Artifact struct array template.

    Template = struct( ...
        'RelativePath', '', ...
        'Kind', '', ...
        'Source', '', ...
        'Exists', false, ...
        'Bytes', NaN, ...
        'CheckOk', NaN, ...
        'CheckDetail', '');
    Artifacts = repmat(Template, 0, 1);

end

function Specs = requiredArtifactSpecs(Contracts, SourceKind)
%REQUIREDARTIFACTSPECS Required artifact relative paths for the source.

    Specs = {{'RunMetadata.json', 'Metadata'}};

    for Index = 1:numel(Contracts.Streams)

        Stream = Contracts.(Contracts.Streams{Index});

        if strcmp(SourceKind, 'IdealSensorTelemetry')

            SourceFolder = Stream.Files.IdealCsvFolder;

        else

            SourceFolder = Stream.Files.RealisticCsvFolder;

        end

        Specs{end + 1} = { ...
            fullfile(SourceFolder, csvFileName(Stream, SourceKind)), 'Csv'};

    end

    Specs{end + 1} = { ...
        fullfile( ...
            matFolder(Contracts.IMU.Files, SourceKind), ...
            matFileName(Contracts.IMU.Files, SourceKind)), ...
        'Mat'};

end

function Specs = inventoryArtifactSpecs(Contracts, SourceKind)
%INVENTORYARTIFACTSPECS Non-required inventory artifact relative paths.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        OtherKind = 'RealisticSensorTelemetry';

    else

        OtherKind = 'IdealSensorTelemetry';

    end

    Specs = {};

    for Index = 1:numel(Contracts.Streams)

        Stream = Contracts.(Contracts.Streams{Index});

        if strcmp(OtherKind, 'IdealSensorTelemetry')

            SourceFolder = Stream.Files.IdealCsvFolder;

        else

            SourceFolder = Stream.Files.RealisticCsvFolder;

        end

        Specs{end + 1} = { ...
            fullfile(SourceFolder, csvFileName(Stream, OtherKind)), 'Csv'};

    end

    Specs{end + 1} = { ...
        fullfile( ...
            matFolder(Contracts.IMU.Files, OtherKind), ...
            matFileName(Contracts.IMU.Files, OtherKind)), ...
        'Mat'};

    Specs{end + 1} = { ...
        fullfile('GroundTruth', 'GroundTruthTelemetry.csv'), 'Csv'};
    Specs{end + 1} = { ...
        fullfile('GroundTruth', 'GroundTruthTelemetry.mat'), 'Mat'};
    Specs{end + 1} = {'Block7', 'Folder'};

end

function Name = csvFileName(Stream, SourceKind)
%CSVFILENAME Source CSV file name for the dialect.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        Name = Stream.Files.IdealCsvFile;

    else

        Name = Stream.Files.RealisticCsvFile;

    end

end

function Name = matFileName(Files, SourceKind)
%MATFILENAME Source MAT file name for the dialect.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        Name = Files.IdealMatFile;

    else

        Name = Files.RealisticMatFile;

    end

end

function Folder = matFolder(Files, SourceKind)
%MATFOLDER Source folder holding the MAT file for the dialect.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        Folder = Files.IdealCsvFolder;

    else

        Folder = Files.RealisticCsvFolder;

    end

end

function Entry = inspectArtifact( ...
    RunDirectory, ...
    RelativePath, ...
    Kind, ...
    Source)
%INSPECTARTIFACT Presence and content checks for one artifact.
%
%   The naming dialect of each artifact is derived from its location
%   (IdealSensorTelemetry/ vs RealisticSensorTelemetry/); artifacts
%   outside those folders (GroundTruth, Block7) are presence-checked only.

    Template = struct( ...
        'RelativePath', '', ...
        'Kind', '', ...
        'Source', '', ...
        'Exists', false, ...
        'Bytes', NaN, ...
        'CheckOk', NaN, ...
        'CheckDetail', '');
    Entry = Template;

    Entry.RelativePath = RelativePath;
    Entry.Kind = Kind;
    Entry.Source = Source;

    if startsWith(RelativePath, 'IdealSensorTelemetry')

        ArtifactKind = 'IdealSensorTelemetry';

    elseif startsWith(RelativePath, 'RealisticSensorTelemetry')

        ArtifactKind = 'RealisticSensorTelemetry';

    else

        ArtifactKind = '';

    end

    FullPath = fullfile(RunDirectory, RelativePath);

    if strcmp(Kind, 'Folder')

        Entry.Exists = isfolder(FullPath);

        if Entry.Exists

            Listing = dir(FullPath);
            FileCount = sum(~[Listing.isdir]) ;
            Entry.Bytes = NaN;
            Entry.CheckOk = true;
            Entry.CheckDetail = sprintf('%d files in folder', FileCount);

        end

        return;

    end

    Entry.Exists = isfile(FullPath);

    if ~Entry.Exists

        Entry.CheckDetail = 'missing';
        return;

    end

    Info = dir(FullPath);
    Entry.Bytes = Info(1).bytes;

    switch Kind

        case 'Csv'

            [~, BaseName] = fileparts(RelativePath);

            if ~isempty(ArtifactKind) && ...
                    ismember(BaseName, preprocessing.SensorDataContracts().Streams)

                [Ok, Detail] = csvCheck(FullPath, ...
                    expectedCsvFields( ...
                        preprocessing.SensorDataContracts(), ...
                        BaseName, ...
                        ArtifactKind));

            else

                Ok = true;
                Detail = 'presence checked (no dialect contract)';

            end

            Entry.CheckOk = Ok;
            Entry.CheckDetail = Detail;

        case 'Mat'

            if isempty(ArtifactKind)

                Entry.CheckOk = true;
                Entry.CheckDetail = 'presence checked (no dialect contract)';

            else

                [Ok, Detail] = matCheck(FullPath, ...
                    expectedMatVariable( ...
                        preprocessing.SensorDataContracts(), ...
                        ArtifactKind));
                Entry.CheckOk = Ok;
                Entry.CheckDetail = Detail;

            end

        otherwise

            Entry.CheckOk = true;
            Entry.CheckDetail = 'presence checked';

    end

end

function Expected = expectedCsvFields(Contracts, StreamName, SourceKind)
%EXPECTEDCSVFIELDS Expected header fields for one stream and one dialect.

    if ~isfield(Contracts, StreamName)

        Expected = {};
        return;

    end

    Channels = Contracts.(StreamName).Channels;

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        FieldNames = {Channels.IdealCsvField};

    else

        FieldNames = {Channels.RealisticCsvField};

    end

    Expected = FieldNames(~cellfun(@isempty, FieldNames));

end

function VarName = expectedMatVariable(Contracts, SourceKind)
%EXPECTEDMATVARIABLE Expected top-level MAT variable for one source.

    if strcmp(SourceKind, 'IdealSensorTelemetry')

        VarName = Contracts.IMU.Files.IdealMatVariable;

    else

        VarName = Contracts.IMU.Files.RealisticMatVariable;

    end

end

function [Ok, Detail] = csvCheck(FilePath, ExpectedFields)
%CSVCHECK Compare the CSV header against expected dialect fields.

    fid = fopen(FilePath, 'r');

    if fid < 0

        Ok = false;
        Detail = 'file could not be opened';
        return;

    end

    Cleanup = onCleanup(@() fclose(fid));
    HeaderLine = fgetl(fid);

    if ~ischar(HeaderLine)

        Ok = false;
        Detail = 'empty file';
        return;

    end

    FoundFields = strsplit(HeaderLine, ',');
    FoundFields = strrep(FoundFields, char(13), '');

    Ok = numel(FoundFields) == numel(ExpectedFields) && ...
        all(strcmp(FoundFields, ExpectedFields));

    if Ok

        Detail = sprintf('%d header fields match the dialect', ...
            numel(FoundFields));

    else

        Detail = sprintf('header mismatch; found [%s], expected [%s]', ...
            strjoin(FoundFields, ', '), ...
            strjoin(ExpectedFields, ', '));

    end

end

function [Ok, Detail] = matCheck(FilePath, ExpectedVariable)
%MATCHKECT Check expected MAT variable by file contents (whos).

    Info = whos('-file', FilePath);
    VarNames = {Info.name};
    Ok = any(strcmp(VarNames, ExpectedVariable));

    if Ok

        Detail = sprintf('variable "%s" found among {%s}', ...
            ExpectedVariable, strjoin(VarNames, ', '));

    else

        Detail = sprintf('variable "%s" missing; file contains {%s}', ...
            ExpectedVariable, strjoin(VarNames, ', '));

    end

end
