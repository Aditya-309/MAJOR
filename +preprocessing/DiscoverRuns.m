function RunList = DiscoverRuns(Config)
%DISCOVERRUNS Discover production runs from the registry and run folders.
%
%   RunList = DISCOVERRUNS(Config) inspects RunRegistry.json and the actual
%   production run folders and returns a structured run inventory.
%   RunList = DISCOVERRUNS() uses the default PreprocessingConfig.
%
%   Registered runs are resolved through the registry field
%   Runs(<k>).FinalRunDirectory. The RunMetadata.Paths fields are known to
%   be stale after finalization and are never used for path resolution.
%
%   Categories:
%       'Registered'   - registry entries (normal selection candidates)
%       'Unregistered' - run folders in production/Runs without registry
%                        entries (surfaced for explicit review only, never
%                        auto-selected)
%       'WorkingRun'   - folders in production/WorkingRuns (excluded from
%                        normal selection)
%       'FailedRun'    - folders in production/FailedRuns (excluded)
%
%   Output fields:
%       RunList.GeneratedAt    - generation timestamp (character vector)
%       RunList.RegistryFile   - registry path used
%       RunList.Registered     - registry-backed entry struct array
%       RunList.UnregisteredRuns - unregistered run folder entries
%       RunList.WorkingRuns    - excluded WorkingRuns entries
%       RunList.FailedRuns     - excluded FailedRuns entries
%       RunList.EligibleRunIDs - cellstr of registered eligible run IDs
%       RunList.Summary        - per-category counts
%
%   Every entry contains the fields: RunID, Category, RegistryStatus,
%   RunDirectory, MetadataFile, HasRunFolder, HasMetadataFile, PathSource,
%   Eligibility, Issues, Warnings, ScenarioSelector, ScenarioID,
%   ScenarioName, CreatedAt, FinalizedAt, RegisteredAt.
%
%   Eligibility values: 'Eligible', 'ReviewRequired', 'Ineligible'.
%   Sensor-level completeness checks belong to InspectRun; discovery only
%   applies the shallow missing-sensor policy (CSV presence per stream of
%   the configured source).
%
%   Discovery is strictly read-only: no file is created, modified or
%   deleted.
%
%   Public Block 9 API entry point (together with InspectRun, PreprocessRun
%   and GetPreprocessingReport).
%
%   See also: InspectRun, PreprocessingConfig, ProjectPaths.

    %% Validate Inputs

    if nargin < 1
        Config = preprocessing.PreprocessingConfig();
    end

    preprocessing.ValidatePreprocessingConfig(Config);

    Paths = preprocessing.ProjectPaths();

    if ~isfile(Paths.RegistryFile)

        error( ...
            'Preprocessing:DiscoverRuns:RegistryNotFound', ...
            'Run registry not found at "%s".', ...
            Paths.RegistryFile);

    end

    %% Read Registry

    try

        Registry = jsondecode(fileread(Paths.RegistryFile));

    catch DecodeFailure

        error( ...
            'Preprocessing:DiscoverRuns:RegistryDecodeFailure', ...
            'Run registry could not be decoded: %s', ...
            DecodeFailure.message);

    end

    if ~isstruct(Registry) || ~isscalar(Registry) || ...
            ~all(isfield(Registry, {'Version', 'Runs'}))

        error( ...
            'Preprocessing:DiscoverRuns:InvalidRegistryStructure', ...
            ['Run registry must be a scalar structure with Version and ', ...
             'Runs fields.']);

    end

    RegistryRuns = Registry.Runs;

    if isempty(RegistryRuns)
        RegistryRuns = struct([]);
    end

    RegistryRuns = RegistryRuns(:);

    %% Build Entry Template

    EmptyEntry = struct( ...
        'RunID', '', ...
        'Category', '', ...
        'RegistryStatus', '', ...
        'RunDirectory', '', ...
        'MetadataFile', '', ...
        'HasRunFolder', false, ...
        'HasMetadataFile', false, ...
        'PathSource', '', ...
        'Eligibility', '', ...
        'Issues', {{}}, ...
        'Warnings', {{}}, ...
        'ScenarioSelector', NaN, ...
        'ScenarioID', NaN, ...
        'ScenarioName', '', ...
        'CreatedAt', '', ...
        'FinalizedAt', '', ...
        'RegisteredAt', '');

    %% Registered Runs

    Registered = repmat(EmptyEntry, numel(RegistryRuns), 1);

    for Index = 1:numel(RegistryRuns)

        RegistryEntry = RegistryRuns(Index);
        Entry = EmptyEntry;

        Entry.RunID = entryText(RegistryEntry, 'RunID');
        Entry.Category = 'Registered';
        Entry.RegistryStatus = entryText(RegistryEntry, 'Status');
        Entry.RunDirectory = entryText(RegistryEntry, 'FinalRunDirectory');
        Entry.MetadataFile = entryText(RegistryEntry, 'MetadataFile');
        Entry.PathSource = 'RunRegistry.FinalRunDirectory';
        Entry.ScenarioSelector = entryNumber(RegistryEntry, 'ScenarioSelector');
        Entry.ScenarioID = entryNumber(RegistryEntry, 'ScenarioID');
        Entry.ScenarioName = entryText(RegistryEntry, 'ScenarioName');
        Entry.CreatedAt = entryText(RegistryEntry, 'CreatedAt');
        Entry.FinalizedAt = entryText(RegistryEntry, 'FinalizedAt');
        Entry.RegisteredAt = entryText(RegistryEntry, 'RegisteredAt');

        Entry.HasRunFolder = isfolder(Entry.RunDirectory);
        Entry.HasMetadataFile = isfile(Entry.MetadataFile);

        if ~Entry.HasRunFolder

            FallbackDirectory = fullfile(Paths.RunsRoot, Entry.RunID);

            if isfolder(FallbackDirectory)

                Entry.RunDirectory = FallbackDirectory;
                Entry.MetadataFile = ...
                    fullfile(FallbackDirectory, 'RunMetadata.json');
                Entry.HasRunFolder = true;
                Entry.HasMetadataFile = isfile(Entry.MetadataFile);
                Entry.PathSource = 'RunFolderMatchFallback';
                Entry.Issues{end + 1} = 'FinalRunDirectoryMissing';
                Entry.Warnings{end + 1} = ...
                    'Resolved via RunsRoot folder fallback.';

            else

                Entry.Issues{end + 1} = 'MissingRunFolder';

            end

        end

        if ~Entry.HasMetadataFile

            Entry.Issues{end + 1} = 'MissingMetadataFile';

        end

        [Entry.Eligibility, Entry.Issues, Entry.Warnings] = ...
            applyShallowSensorPolicy( ...
                Config, ...
                Entry.RunDirectory, ...
                Entry.HasRunFolder, ...
                Entry.Issues, ...
                Entry.Warnings);

        if isempty(Entry.Eligibility)

            if isempty(Entry.Issues)

                Entry.Eligibility = 'Eligible';

            else

                Entry.Eligibility = 'Ineligible';

            end

        end

        Registered(Index) = Entry;

    end

    %% Folder Cross-Check

    RunFolderNames = listRunFolders(Paths.RunsRoot);
    RegisteredIDs = {Registered.RunID};
    UnregisteredNames = RunFolderNames( ...
        ~ismember(RunFolderNames, RegisteredIDs));

    UnregisteredRuns = repmat(EmptyEntry, numel(UnregisteredNames), 1);

    for Index = 1:numel(UnregisteredNames)

        Entry = EmptyEntry;
        Entry.RunID = UnregisteredNames{Index};
        Entry.Category = 'Unregistered';
        Entry.RegistryStatus = 'NOT_REGISTERED';
        Entry.RunDirectory = fullfile(Paths.RunsRoot, Entry.RunID);
        Entry.MetadataFile = fullfile(Entry.RunDirectory, 'RunMetadata.json');
        Entry.HasRunFolder = isfolder(Entry.RunDirectory);
        Entry.HasMetadataFile = isfile(Entry.MetadataFile);
        Entry.PathSource = 'RunFolderMatch';
        Entry.Eligibility = 'ReviewRequired';
        Entry.Issues{end + 1} = 'NotInRunRegistry';

        UnregisteredRuns(Index) = Entry;

    end

    %% Excluded Locations

    WorkingNames = listRunFolders(Paths.WorkingRunsRoot);
    WorkingRuns = repmat(EmptyEntry, numel(WorkingNames), 1);

    for Index = 1:numel(WorkingNames)

        WorkingRuns(Index) = excludedEntry( ...
            EmptyEntry, ...
            WorkingNames{Index}, ...
            Paths.WorkingRunsRoot, ...
            'WorkingRun', ...
            'ExcludedLocation:WorkingRuns');

    end

    FailedNames = listRunFolders(Paths.FailedRunsRoot);
    FailedRuns = repmat(EmptyEntry, numel(FailedNames), 1);

    for Index = 1:numel(FailedNames)

        FailedRuns(Index) = excludedEntry( ...
            EmptyEntry, ...
            FailedNames{Index}, ...
            Paths.FailedRunsRoot, ...
            'FailedRun', ...
            'ExcludedLocation:FailedRuns');

    end

    %% Eligible Run IDs

    EligibleRunIDs = {};

    for Index = 1:numel(Registered)

        if strcmp(Registered(Index).Eligibility, 'Eligible')

            EligibleRunIDs{end + 1} = Registered(Index).RunID;

        end

    end

    %% Build Output

    RunList = struct();
    RunList.GeneratedAt = char(datetime( ...
        'now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
    RunList.RegistryFile = Paths.RegistryFile;
    RunList.Registered = Registered;
    RunList.UnregisteredRuns = UnregisteredRuns;
    RunList.WorkingRuns = WorkingRuns;
    RunList.FailedRuns = FailedRuns;
    RunList.EligibleRunIDs = EligibleRunIDs;

    RunList.Summary = struct( ...
        'RegisteredCount', numel(Registered), ...
        'RunFolderCount', numel(RunFolderNames), ...
        'UnregisteredCount', numel(UnregisteredRuns), ...
        'WorkingRunCount', numel(WorkingRuns), ...
        'FailedRunCount', numel(FailedRuns), ...
        'EligibleCount', numel(EligibleRunIDs));

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function Names = listRunFolders(Root)
%LISTRUNFOLDERS Sorted folder names under Root (dots excluded).

    Listing = dir(Root);
    Listing = Listing([Listing.isdir]);
    Names = {Listing.name};
    Names = sort(Names(~ismember(Names, {'.', '..'})));

end

function Text = entryText(Entry, FieldName)
%ENTRYTEXT Registry entry text field with missing-field tolerance.

    if isfield(Entry, FieldName) && ischar(Entry.(FieldName))

        Text = Entry.(FieldName);

    else

        Text = '';

    end

end

function Value = entryNumber(Entry, FieldName)
%ENTRYNUMBER Registry entry numeric field with missing-field tolerance.

    if isfield(Entry, FieldName) && isnumeric(Entry.(FieldName)) && ...
            isscalar(Entry.(FieldName))

        Value = Entry.(FieldName);

    else

        Value = NaN;

    end

end

function Entry = excludedEntry( ...
    EmptyEntry, ...
    RunID, ...
    Root, ...
    Category, ...
    IssueText)
%EXCLUDEDENTRY Build an entry for an excluded location folder.

    Entry = EmptyEntry;
    Entry.RunID = RunID;
    Entry.Category = Category;
    Entry.RegistryStatus = 'NOT_APPLICABLE';
    Entry.RunDirectory = fullfile(Root, RunID);
    Entry.MetadataFile = fullfile(Entry.RunDirectory, 'RunMetadata.json');
    Entry.HasRunFolder = isfolder(Entry.RunDirectory);
    Entry.HasMetadataFile = isfile(Entry.MetadataFile);
    Entry.PathSource = 'ExcludedLocation';
    Entry.Eligibility = 'Ineligible';
    Entry.Issues{end + 1} = IssueText;

end

function [Eligibility, Issues, Warnings] = applyShallowSensorPolicy( ...
    Config, ...
    RunDirectory, ...
    HasRunFolder, ...
    Issues, ...
    Warnings)
%APPLYSHALLOWSENSORPOLICY CSV-presence check with the missing-sensor policy.
%
%   Returns '' when the shallow check leaves the earlier verdict intact.

    Eligibility = '';

    if ~HasRunFolder

        return;

    end

    Contracts = preprocessing.SensorDataContracts();

    if strcmp(char(Config.Source), 'IdealSensorTelemetry')

        SourceFolder = Contracts.IMU.Files.IdealCsvFolder;

    else

        SourceFolder = Contracts.IMU.Files.RealisticCsvFolder;

    end

    MissingSensors = {};

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};
        Stream = Contracts.(StreamName);

        if strcmp(char(Config.Source), 'IdealSensorTelemetry')

            CsvName = Stream.Files.IdealCsvFile;

        else

            CsvName = Stream.Files.RealisticCsvFile;

        end

        if ~isfile(fullfile(RunDirectory, SourceFolder, CsvName))

            MissingSensors{end + 1} = StreamName;

        end

    end

    RequiredSensors = Config.MissingSensors.RequiredSensors;
    MissingRequired = intersect(MissingSensors, RequiredSensors);

    if isempty(MissingSensors)

        return;

    end

    if ~isempty(MissingRequired)

        IssueText = sprintf('MissingRequiredSensor:%s', ...
            strjoin(MissingRequired, ','));

        if strcmpi(char(Config.MissingSensors.Policy), 'Strict')

            Issues{end + 1} = IssueText;
            Eligibility = 'Ineligible';

        else

            Warnings{end + 1} = [IssueText ' (Continue policy)'];
            Eligibility = 'ReviewRequired';

        end

    end

    MissingOptional = setdiff(MissingSensors, RequiredSensors);

    if ~isempty(MissingOptional)

        Warnings{end + 1} = sprintf('MissingSensor:%s', ...
            strjoin(MissingOptional, ','));

    end

end
