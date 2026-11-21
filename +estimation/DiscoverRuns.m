function RunList = DiscoverRuns(Config, Paths)
%DISCOVERRUNS List runs eligible for Block 10 state reconstruction.
%
%   RunList = DISCOVERRUNS(Config) inspects the run registry and the
%   preprocessing output tree and returns the inventory of runs that can
%   be fed to RunStateReconstruction. Discovery is strictly read-only.
%
%   RunList = DISCOVERRUNS(Config, Paths) uses an already resolved
%   estimation.ProjectPaths() structure (isolated development tests).
%
%   Output fields:
%       .GeneratedAt        - generation timestamp
%       .RegistryFile       - registry used
%       .Entries            - struct array: RunID, Category,
%                             PreprocessIDs (cellstr of explicit
%                             revisions), Registered, HasPreprocessedData,
%                             Eligibility ('Eligible'/'ReviewRequired'/
%                             'Ineligible'), Issues
%       .EligibleRunIDs     - cellstr of run IDs with at least one
%                             preprocessed revision
%       .Summary            - counts
%
%   The estimator NEVER silently selects a preprocessing revision: the
%   revisions are listed here and the caller passes the explicit
%   PreprocessID to InspectRun/RunStateReconstruction.
%
%   Public Block 10 API entry point (together with EstimationConfig,
%   InspectRun, RunStateReconstruction and GetEstimationReport).
%
%   See also: InspectRun, RunStateReconstruction, LoadPreprocessedRun.

    if nargin < 2 || isempty(Paths)
        Paths = estimation.ProjectPaths();
    end

    %% Registered runs (from the frozen registry, read-only)

    Registered = {};

    if isfile(Paths.RegistryFile)

        RegistryText = fileread(Paths.RegistryFile);
        Registry = jsondecode(RegistryText);

        if isfield(Registry, 'Runs')

            for Index = 1:numel(Registry.Runs)

                Registered{end + 1} = ...
                    char(Registry.Runs(Index).RunID); %#ok<AGROW>

            end

        end

    end

    %% Preprocessed output tree

    Entries = struct('RunID', {}, 'Category', {}, 'PreprocessIDs', {}, ...
        'Registered', {}, 'HasPreprocessedData', {}, ...
        'Eligibility', {}, 'Issues', {});

    if isfolder(Paths.PreprocessedRoot)

        Listing = dir(Paths.PreprocessedRoot);
        Listing = Listing([Listing.isdir] & ...
            ~startsWith({Listing.name}, '.'));

        for Index = 1:numel(Listing)

            RunID = Listing(Index).name;
            SubListing = dir(fullfile(Paths.PreprocessedRoot, RunID));
            SubListing = SubListing([SubListing.isdir] & ...
                ~startsWith({SubListing.name}, '.'));

            PreprocessIDs = {};

            for SubIndex = 1:numel(SubListing)

                Candidate = fullfile(Paths.PreprocessedRoot, RunID, ...
                    SubListing(SubIndex).name, 'PreprocessedData.mat');

                if isfile(Candidate)

                    PreprocessIDs{end + 1} = ...
                        SubListing(SubIndex).name; %#ok<AGROW>

                end

            end

            IsRegistered = any(strcmp(Registered, RunID));
            Entry = struct();
            Entry.RunID = RunID;

            if IsRegistered
                Entry.Category = 'Registered';
            else
                Entry.Category = 'Unregistered';
            end

            Entry.PreprocessIDs = sort(PreprocessIDs);
            Entry.Registered = IsRegistered;
            Entry.HasPreprocessedData = ~isempty(PreprocessIDs);
            Entry.Issues = {};

            if ~IsRegistered

                Entry.Issues{end + 1} = ...
                    'Run is not in RunRegistry.json.';

            end

            if isempty(PreprocessIDs)

                Entry.Issues{end + 1} = ...
                    'No Block 9 preprocessing revision is available.';

            end

            if Entry.HasPreprocessedData && IsRegistered
                Entry.Eligibility = 'Eligible';
            elseif Entry.HasPreprocessedData
                Entry.Eligibility = 'ReviewRequired';
            else
                Entry.Eligibility = 'Ineligible';
            end

            Entries(end + 1) = Entry; %#ok<AGROW>

        end

    end

    RunList = struct();
    RunList.GeneratedAt = char(datetime('now', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
    RunList.RegistryFile = Paths.RegistryFile;
    RunList.Configuration = struct('Name', Config.Name, ...
        'Version', Config.Version);
    RunList.Entries = Entries;
    RunList.EligibleRunIDs = { ...
        Entries(arrayfun(@(e) strcmp(e.Eligibility, 'Eligible'), ...
        Entries)).RunID};
    RunList.Summary = struct( ...
        'TotalRuns', numel(Entries), ...
        'Eligible', sum(strcmp({Entries.Eligibility}, 'Eligible')), ...
        'ReviewRequired', sum(strcmp( ...
            {Entries.Eligibility}, 'ReviewRequired')), ...
        'Ineligible', sum(strcmp({Entries.Eligibility}, 'Ineligible')));

end
