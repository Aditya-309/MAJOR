function RegistryEntry = RegisterProductionRun( ...
    ProductionConfig, ...
    FinalizedRun)
% RegisterProductionRun
%
% Registers a successfully finalized production run in
% production/RunRegistry.json.
%
% Inputs:
%   ProductionConfig - Frozen production configuration
%   FinalizedRun     - Finalized production run context
%
% Output:
%   RegistryEntry    - Registry entry written for the run
%
% This function:
%   - requires a FINALIZED run
%   - verifies the finalized run directory
%   - reads the existing registry if present
%   - prevents duplicate RunID registration
%   - appends one registry entry
%   - writes the updated registry
%   - verifies the resulting registry
%
% This function does not:
%   - generate telemetry
%   - modify telemetry
%   - move run directories
%   - modify Block 1-8
%   - finalize runs
%   - alter scientific data

%% Validate input count

if nargin ~= 2
    error('RegisterProductionRun:InputCount', ...
        'Exactly two inputs are required.');
end

%% Validate ProductionConfig

if ~isstruct(ProductionConfig) || ...
        ~isscalar(ProductionConfig)
    error('RegisterProductionRun:InvalidProductionConfig', ...
        'ProductionConfig must be a scalar structure.');
end

RequiredProductionFields = { ...
    'RegistryFile', ...
    'RunsRoot', ...
    'ScenarioSelector', ...
    'ScenarioID', ...
    'ScenarioName'};

for k = 1:numel(RequiredProductionFields)

    FieldName = RequiredProductionFields{k};

    if ~isfield(ProductionConfig, FieldName)
        error('RegisterProductionRun:MissingProductionField', ...
            'ProductionConfig.%s is missing.', FieldName);
    end
end

%% Validate FinalizedRun

if ~isstruct(FinalizedRun) || ...
        ~isscalar(FinalizedRun)
    error('RegisterProductionRun:InvalidFinalizedRun', ...
        'FinalizedRun must be a scalar structure.');
end

RequiredRunFields = { ...
    'RunID', ...
    'Status', ...
    'CreatedAt', ...
    'FinalizedAt', ...
    'FinalRunDirectory', ...
    'ScenarioSelector', ...
    'ScenarioID', ...
    'ScenarioName'};

for k = 1:numel(RequiredRunFields)

    FieldName = RequiredRunFields{k};

    if ~isfield(FinalizedRun, FieldName)
        error('RegisterProductionRun:MissingRunField', ...
            'FinalizedRun.%s is missing.', FieldName);
    end
end

if ~strcmp(FinalizedRun.Status, 'FINALIZED')
    error('RegisterProductionRun:InvalidRunStatus', ...
        'FinalizedRun.Status must be FINALIZED.');
end

%% Cross-check identity

if ~isequaln( ...
        FinalizedRun.ScenarioSelector, ...
        ProductionConfig.ScenarioSelector)
    error('RegisterProductionRun:ScenarioSelectorMismatch', ...
        'FinalizedRun scenario selector does not match ProductionConfig.');
end

if ~isequaln( ...
        FinalizedRun.ScenarioID, ...
        ProductionConfig.ScenarioID)
    error('RegisterProductionRun:ScenarioIDMismatch', ...
        'FinalizedRun scenario ID does not match ProductionConfig.');
end

if ~strcmp( ...
        FinalizedRun.ScenarioName, ...
        ProductionConfig.ScenarioName)
    error('RegisterProductionRun:ScenarioNameMismatch', ...
        'FinalizedRun scenario name does not match ProductionConfig.');
end

%% Validate finalized directory

if ~isfolder(FinalizedRun.FinalRunDirectory)
    error('RegisterProductionRun:MissingFinalDirectory', ...
        'Finalized run directory does not exist.');
end

%% Validate metadata

MetadataPath = fullfile( ...
    FinalizedRun.FinalRunDirectory, ...
    'RunMetadata.json');

if ~isfile(MetadataPath)
    error('RegisterProductionRun:MissingMetadata', ...
        'RunMetadata.json is missing from finalized run.');
end

MetadataText = fileread(MetadataPath);

if isempty(MetadataText)
    error('RegisterProductionRun:EmptyMetadata', ...
        'RunMetadata.json is empty.');
end

try
    Metadata = jsondecode(MetadataText);
catch ME
    error('RegisterProductionRun:InvalidMetadataJSON', ...
        'RunMetadata.json is not valid JSON: %s', ...
        ME.message);
end

if ~isfield(Metadata, 'Run') || ...
        ~isfield(Metadata.Run, 'RunID')
    error('RegisterProductionRun:InvalidMetadataStructure', ...
        'RunMetadata.json does not contain Run.RunID.');
end

if ~strcmp(Metadata.Run.RunID, FinalizedRun.RunID)
    error('RegisterProductionRun:MetadataRunIDMismatch', ...
        'RunMetadata RunID does not match FinalizedRun.');
end

%% Ensure registry directory exists

RegistryDirectory = fileparts(ProductionConfig.RegistryFile);

if ~isempty(RegistryDirectory) && ...
        ~isfolder(RegistryDirectory)

    mkdir(RegistryDirectory);
end

%% Read existing registry

if isfile(ProductionConfig.RegistryFile)

    RegistryText = fileread(ProductionConfig.RegistryFile);

    if isempty(strtrim(RegistryText))
        Registry = struct();
    else
        try
            Registry = jsondecode(RegistryText);
        catch ME
            error('RegisterProductionRun:InvalidRegistryJSON', ...
                'Existing RunRegistry.json is not valid JSON: %s', ...
                ME.message);
        end
    end

else
    Registry = struct();
end

%% Initialize registry structure

if isempty(fieldnames(Registry))

    Registry = struct();

end

if ~isfield(Registry, 'Version')
    Registry.Version = 1;
end

if ~isfield(Registry, 'Runs')
    Registry.Runs = struct([]);
end

%% Validate registry Runs representation

if ~isempty(Registry.Runs) && ...
        ~isstruct(Registry.Runs)

    error('RegisterProductionRun:InvalidRunsRegistry', ...
        'Registry.Runs must be a structure array.');
end

%% Prevent duplicate RunID registration

ExistingCount = numel(Registry.Runs);

for k = 1:ExistingCount

    if isfield(Registry.Runs(k), 'RunID') && ...
            strcmp(Registry.Runs(k).RunID, FinalizedRun.RunID)

        error('RegisterProductionRun:DuplicateRunID', ...
            'RunID %s is already registered.', ...
            FinalizedRun.RunID);
    end
end

%% Build registry entry

RegistryEntry = struct();

RegistryEntry.RunID = FinalizedRun.RunID;
RegistryEntry.Status = 'REGISTERED';
RegistryEntry.CreatedAt = char(FinalizedRun.CreatedAt);
RegistryEntry.FinalizedAt = char(FinalizedRun.FinalizedAt);
RegistryEntry.RegisteredAt = char(datetime( ...
    'now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS'));

RegistryEntry.ScenarioSelector = ...
    FinalizedRun.ScenarioSelector;

RegistryEntry.ScenarioID = ...
    FinalizedRun.ScenarioID;

RegistryEntry.ScenarioName = ...
    FinalizedRun.ScenarioName;

RegistryEntry.FinalRunDirectory = ...
    FinalizedRun.FinalRunDirectory;

RegistryEntry.MetadataFile = ...
    MetadataPath;

%% Append entry

if isempty(Registry.Runs)

    Registry.Runs = RegistryEntry;

else

    Registry.Runs(end+1) = RegistryEntry;

end

%% Encode registry

try
    RegistryJSON = jsonencode( ...
        Registry, ...
        'PrettyPrint', true);
catch ME
    error('RegisterProductionRun:JSONEncodeFailure', ...
        'Failed to encode RunRegistry.json: %s', ...
        ME.message);
end

%% Write registry

FileID = fopen( ...
    ProductionConfig.RegistryFile, ...
    'w');

if FileID == -1
    error('RegisterProductionRun:FileOpenFailure', ...
        'Could not open RunRegistry.json for writing.');
end

CleanupObject = onCleanup(@() fclose(FileID));

Count = fwrite(FileID, RegistryJSON, 'char');

if Count ~= numel(RegistryJSON)
    error('RegisterProductionRun:WriteFailure', ...
        'RunRegistry.json was not completely written.');
end

clear CleanupObject;

%% Verify registry file

if ~isfile(ProductionConfig.RegistryFile)
    error('RegisterProductionRun:MissingRegistry', ...
        'RunRegistry.json was not created.');
end

RegistryInfo = dir(ProductionConfig.RegistryFile);

if isempty(RegistryInfo) || RegistryInfo.bytes <= 0
    error('RegisterProductionRun:EmptyRegistry', ...
        'RunRegistry.json is empty.');
end

%% Re-read registry for final verification

FinalRegistryText = fileread( ...
    ProductionConfig.RegistryFile);

try
    FinalRegistry = jsondecode(FinalRegistryText);
catch ME
    error('RegisterProductionRun:FinalRegistryInvalidJSON', ...
        'Final RunRegistry.json is invalid JSON: %s', ...
        ME.message);
end

if ~isfield(FinalRegistry, 'Runs') || ...
        ~isstruct(FinalRegistry.Runs)

    error('RegisterProductionRun:FinalRegistryInvalidRuns', ...
        'Final RunRegistry.json has an invalid Runs section.');
end

%% Locate registered run

RegisteredIndex = [];

for k = 1:numel(FinalRegistry.Runs)

    if isfield(FinalRegistry.Runs(k), 'RunID') && ...
            strcmp(FinalRegistry.Runs(k).RunID, ...
                   FinalizedRun.RunID)

        RegisteredIndex = k;
        break;

    end
end

if isempty(RegisteredIndex)
    error('RegisterProductionRun:RegistrationVerificationFailure', ...
        'Final RunRegistry.json does not contain the registered RunID.');
end

RegisteredRecord = ...
    FinalRegistry.Runs(RegisteredIndex);

%% Verify registered record

if ~strcmp( ...
        RegisteredRecord.Status, ...
        'REGISTERED')
    error('RegisterProductionRun:RegistrationStatusFailure', ...
        'Registered run status is incorrect.');
end

if ~strcmp( ...
        RegisteredRecord.RunID, ...
        FinalizedRun.RunID)
    error('RegisterProductionRun:RegistrationRunIDFailure', ...
        'Registered RunID is incorrect.');
end

if ~isequaln( ...
        RegisteredRecord.ScenarioID, ...
        FinalizedRun.ScenarioID)
    error('RegisterProductionRun:RegistrationScenarioIDFailure', ...
        'Registered scenario ID is incorrect.');
end

if ~strcmp( ...
        RegisteredRecord.ScenarioName, ...
        FinalizedRun.ScenarioName)
    error('RegisterProductionRun:RegistrationScenarioNameFailure', ...
        'Registered scenario name is incorrect.');
end

if ~strcmp( ...
        RegisteredRecord.FinalRunDirectory, ...
        FinalizedRun.FinalRunDirectory)
    error('RegisterProductionRun:RegistrationPathFailure', ...
        'Registered final run directory is incorrect.');
end

end