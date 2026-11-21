function [Data, InputInfo] = LoadPreprocessedRun(RunID, PreprocessID, Paths)
%LOADPREPROCESSEDRUN Load one Block 9 preprocessed run (read-only).
%
%   [Data, InputInfo] = LOADPREPROCESSEDRUN(RunID, PreprocessID) resolves
%   the explicit preprocessing revision to
%   production/Preprocessed/<RunID>/<PreprocessID>/ and loads
%   PreprocessedData.mat. The revision is always explicit; this function
%   never selects a different or latest revision.
%
%   [Data, InputInfo] = LOADPREPROCESSEDRUN(RunID, PreprocessID, Paths)
%   uses an already resolved estimation.ProjectPaths() structure instead
%   of resolving paths again (used by the orchestrator and by the
%   isolated development tests).
%
%   Resolution (fail closed, no silent substitution):
%       1. PreprocessID must match the Block 9 grammar
%          <RunID>__PP_<yyyymmdd_HHMMSS>_<nn> and its RunID prefix must
%          equal the requested RunID.
%       2. Exactly one matching output directory must exist.
%       3. A ProcessingFailed.txt marker (if present) takes precedence:
%          a failed output is never loaded as a successful one.
%       4. PreprocessingReport.json must exist and its embedded
%          RunInfo.PreprocessID must equal the requested ID.
%       5. PreprocessedData.mat must exist and contain the preprocessed
%          structure (variable name resolved by inspection, not by
%          assumption; the name actually used is recorded in
%          InputInfo.MatVariable).
%
%   Output:
%       Data       - the loaded PreprocessedData structure
%       InputInfo  - resolution metadata:
%           .RunID, .PreprocessID, .PreprocessedDirectory, .MatFile,
%           .MatVariable, .ReportFile, .ReportRunInfo, .LoadedAt
%
%   This function reads ONLY the preprocessing output of the requested
%   revision. It never reads ground truth, run folders or sensor
%   simulation outputs.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: ValidatePreprocessedRun, BuildInputProvenance, ProjectPaths.

    %% Validate Identifiers

    if ~(ischar(RunID) || (isstring(RunID) && isscalar(RunID)))

        error( ...
            'Estimation:LoadPreprocessedRun:InvalidRunID', ...
            'RunID must be a character vector or scalar string.');

    end

    RunID = char(RunID);

    if isempty(regexp(RunID, '^Run_[0-9]+_[0-9]{8}_[0-9]{6}$', 'once'))

        error( ...
            'Estimation:LoadPreprocessedRun:InvalidRunID', ...
            'RunID "%s" does not match the required RunID grammar.', ...
            RunID);

    end

    if ~(ischar(PreprocessID) || ...
            (isstring(PreprocessID) && isscalar(PreprocessID)))

        error( ...
            'Estimation:LoadPreprocessedRun:InvalidPreprocessID', ...
            'PreprocessID must be a character vector or scalar string.');

    end

    PreprocessID = char(PreprocessID);

    Pattern = [ ...
        '^Run_[0-9]+_[0-9]{8}_[0-9]{6}', ...
        '__PP_[0-9]{8}_[0-9]{6}_[0-9]{2}$'];

    if isempty(regexp(PreprocessID, Pattern, 'once'))

        error( ...
            'Estimation:LoadPreprocessedRun:InvalidPreprocessID', ...
            ['PreprocessID "%s" does not match the required grammar ', ...
             '<RunID>__PP_<yyyymmdd_HHMMSS>_<nn>.'], ...
            PreprocessID);

    end

    Separator = strfind(PreprocessID, '__PP_');
    PrefixRunID = PreprocessID(1:Separator(1) - 1);

    if ~strcmp(PrefixRunID, RunID)

        error( ...
            'Estimation:LoadPreprocessedRun:RunIDMismatch', ...
            ['PreprocessID "%s" belongs to RunID "%s", not to the ', ...
             'requested RunID "%s".'], ...
            PreprocessID, PrefixRunID, RunID);

    end

    %% Resolve Output Directory

    if nargin >= 3 && isstruct(Paths) && isfield(Paths, 'PreprocessedRoot')
        % Paths supplied by the caller.
    else
        Paths = estimation.ProjectPaths();
    end

    PreprocessedDirectory = fullfile( ...
        Paths.PreprocessedRoot, RunID, PreprocessID);

    Listing = dir(fullfile(Paths.PreprocessedRoot, RunID));
    Matching = {};

    for Index = 1:numel(Listing)

        if Listing(Index).isdir && ...
                strcmp(Listing(Index).name, PreprocessID)

            Matching{end + 1} = Listing(Index).name; %#ok<AGROW>

        end

    end

    if isempty(Matching)

        error( ...
            'Estimation:LoadPreprocessedRun:PreprocessIDNotFound', ...
            ['No preprocessing output directory exists for ', ...
             'PreprocessID "%s" under "%s".'], ...
            PreprocessID, fullfile(Paths.PreprocessedRoot, RunID));

    end

    if numel(Matching) > 1

        error( ...
            'Estimation:LoadPreprocessedRun:AmbiguousPreprocessID', ...
            ['Multiple preprocessing output directories match ', ...
             'PreprocessID "%s": %s.'], ...
            PreprocessID, strjoin(Matching, ', '));

    end

    %% Marker Precedence

    FailureMarker = fullfile(PreprocessedDirectory, 'ProcessingFailed.txt');

    if isfile(FailureMarker)

        error( ...
            'Estimation:LoadPreprocessedRun:ProcessingFailedMarker', ...
            ['Preprocessing output "%s" carries a ProcessingFailed.txt ', ...
             'marker and is never loaded as a successful result.'], ...
            PreprocessID);

    end

    %% Verify Report Identity

    ReportFile = fullfile(PreprocessedDirectory, 'PreprocessingReport.json');

    if ~isfile(ReportFile)

        error( ...
            'Estimation:LoadPreprocessedRun:ReportFileMissing', ...
            'PreprocessingReport.json is missing for "%s".', ...
            PreprocessID);

    end

    ReportText = fileread(ReportFile);

    try
        ReportRunInfo = jsondecode(ReportText);
    catch
        error( ...
            'Estimation:LoadPreprocessedRun:ReportDecodeFailure', ...
            'PreprocessingReport.json for "%s" does not decode.', ...
            PreprocessID);
    end

    if ~isfield(ReportRunInfo, 'RunInfo') || ...
            ~isfield(ReportRunInfo.RunInfo, 'PreprocessID') || ...
            ~strcmp(ReportRunInfo.RunInfo.PreprocessID, PreprocessID)

        error( ...
            'Estimation:LoadPreprocessedRun:PreprocessIDMismatch', ...
            ['The embedded RunInfo.PreprocessID of the report does not ', ...
             'equal the requested PreprocessID "%s".'], ...
            PreprocessID);

    end

    %% Load MAT (variable resolved by inspection)

    MatFile = fullfile(PreprocessedDirectory, 'PreprocessedData.mat');

    if ~isfile(MatFile)

        error( ...
            'Estimation:LoadPreprocessedRun:MatFileMissing', ...
            'PreprocessedData.mat is missing for "%s".', ...
            PreprocessID);

    end

    Contents = whos('-file', MatFile);
    MatVariable = '';

    for Index = 1:numel(Contents)

        if strcmp(Contents(Index).name, 'PreprocessedData') && ...
                strcmp(Contents(Index).class, 'struct')

            MatVariable = 'PreprocessedData';
            break

        end

    end

    if isempty(MatVariable)

        for Index = 1:numel(Contents)

            if strcmp(Contents(Index).class, 'struct') && ...
                    isscalar(Contents(Index).size)

                Candidate = load(MatFile, Contents(Index).name);
                Value = Candidate.(Contents(Index).name);

                if isstruct(Value) && isscalar(Value) && ...
                        isfield(Value, 'NativeRate')

                    MatVariable = Contents(Index).name;
                    break

                end

            end

        end

    end

    if isempty(MatVariable)

        error( ...
            'Estimation:LoadPreprocessedRun:MatVariableNotFound', ...
            ['No scalar structure containing NativeRate was found in ', ...
             '"%s".'], ...
            MatFile);

    end

    Loaded = load(MatFile, MatVariable);
    Data = Loaded.(MatVariable);

    %% Build Input Info

    InputInfo = struct();
    InputInfo.RunID = RunID;
    InputInfo.PreprocessID = PreprocessID;
    InputInfo.PreprocessedDirectory = PreprocessedDirectory;
    InputInfo.MatFile = MatFile;
    InputInfo.MatVariable = MatVariable;
    InputInfo.ReportFile = ReportFile;
    InputInfo.ReportRunInfo = ReportRunInfo.RunInfo;
    InputInfo.LoadedAt = char(datetime('now', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss'));

end
