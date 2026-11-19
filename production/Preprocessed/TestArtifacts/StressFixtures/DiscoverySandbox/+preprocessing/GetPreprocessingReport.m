function Report = GetPreprocessingReport(PreprocessID)
%GETPREPROCESSINGREPORT Retrieve one preprocessing report by PreprocessID.
%
%   Report = GETPREPROCESSINGREPORT(PreprocessID) resolves the approved
%   PreprocessID grammar
%
%       <RunID>__PP_<yyyymmdd_HHMMSS>_<nn>
%
%   (RunID grammar: Run_<digits>_<yyyymmdd>_<hhmmss>) to the output
%   directory production/Preprocessed/<RunID>/<PreprocessID>/ and returns
%   the decoded PreprocessingReport.json together with resolution
%   metadata. The operation is strictly read-only.
%
%   Resolution and verification (no silent substitution):
%       1. The PreprocessID must match the grammar exactly
%          -> 'Preprocessing:GetPreprocessingReport:InvalidPreprocessID'
%       2. Exactly one matching output directory must exist
%          -> 'Preprocessing:GetPreprocessingReport:PreprocessIDNotFound'
%          -> 'Preprocessing:GetPreprocessingReport:AmbiguousPreprocessID'
%       3. The directory must not carry a ProcessingFailed.txt marker
%          (a failed output is never returned as a successful result)
%          -> 'Preprocessing:GetPreprocessingReport:ProcessingFailedMarker'
%       4. PreprocessingReport.json must exist
%          -> 'Preprocessing:GetPreprocessingReport:ReportFileMissing'
%       5. The JSON must decode and its embedded RunInfo.PreprocessID
%          must equal the requested ID
%          -> 'Preprocessing:GetPreprocessingReport:ReportDecodeFailure'
%          -> 'Preprocessing:GetPreprocessingReport:PreprocessIDMismatch'
%
%   Output fields:
%       Report.PreprocessID, .RunID, .OutputDirectory, .ReportFile,
%       .Report (decoded JSON structure)
%
%   Public Block 9 API entry point (together with DiscoverRuns, InspectRun
%   and PreprocessRun).
%
%   See also: PreprocessRun, ExportPreprocessedData, ProjectPaths.

    %% Validate Identifier Grammar

    if ~(ischar(PreprocessID) || ...
            (isstring(PreprocessID) && isscalar(PreprocessID)))

        error( ...
            'Preprocessing:GetPreprocessingReport:InvalidPreprocessID', ...
            'PreprocessID must be a character vector or scalar string.');

    end

    PreprocessID = char(PreprocessID);
    Pattern = [ ...
        '^Run_[0-9]+_[0-9]{8}_[0-9]{6}', ...
        '__PP_[0-9]{8}_[0-9]{6}_[0-9]{2}$'];

    if isempty(regexp(PreprocessID, Pattern, 'once'))

        error( ...
            'Preprocessing:GetPreprocessingReport:InvalidPreprocessID', ...
            ['PreprocessID "%s" does not match the required grammar ', ...
             '<RunID>__PP_<yyyymmdd_HHMMSS>_<nn>.'], ...
            PreprocessID);

    end

    Separator = strfind(PreprocessID, '__PP_');
    RunID = PreprocessID(1:Separator(1) - 1);

    %% Resolve Output Directory

    Paths = preprocessing.ProjectPaths();
    OutputDirectory = fullfile( ...
        Paths.PreprocessedRoot, RunID, PreprocessID);

    Listing = dir(fullfile(Paths.PreprocessedRoot, RunID));
    Matching = {};

    for Index = 1:numel(Listing)

        if Listing(Index).isdir && ...
                strcmp(Listing(Index).name, PreprocessID)

            Matching{end + 1} = Listing(Index).name;

        end

    end

    if isempty(Matching)

        error( ...
            'Preprocessing:GetPreprocessingReport:PreprocessIDNotFound', ...
            'No preprocessing output exists for "%s".', ...
            PreprocessID);

    end

    if numel(Matching) > 1

        error( ...
            ['Preprocessing:GetPreprocessingReport:', ...
             'AmbiguousPreprocessID'], ...
            ['Multiple output directories match "%s": %s.'], ...
            PreprocessID, ...
            strjoin(Matching, ', '));

    end

    %% Failed-Output Marker Precedence
    % A directory carrying ProcessingFailed.txt must never be returned as
    % a successful result, regardless of which artifacts are present.
    MarkerFile = fullfile(OutputDirectory, 'ProcessingFailed.txt');

    if isfile(MarkerFile)

        error( ...
            ['Preprocessing:GetPreprocessingReport:', ...
             'ProcessingFailedMarker'], ...
            ['Preprocessing output "%s" carries a ', ...
             'ProcessingFailed.txt marker and must not be treated as ', ...
             'a successful result.'], ...
            OutputDirectory);

    end

    ReportFile = fullfile(OutputDirectory, 'PreprocessingReport.json');

    if ~isfile(ReportFile)

        error( ...
            'Preprocessing:GetPreprocessingReport:ReportFileMissing', ...
            'Report file "%s" does not exist.', ...
            ReportFile);

    end

    %% Decode And Verify

    try

        Decoded = jsondecode(fileread(ReportFile));

    catch DecodeFailure

        error( ...
            'Preprocessing:GetPreprocessingReport:ReportDecodeFailure', ...
            'Report file "%s" could not be decoded: %s', ...
            ReportFile, ...
            DecodeFailure.message);

    end

    if ~isstruct(Decoded) || ~isfield(Decoded, 'RunInfo') || ...
            ~isfield(Decoded.RunInfo, 'PreprocessID')

        error( ...
            'Preprocessing:GetPreprocessingReport:ReportDecodeFailure', ...
            ['Report file "%s" does not contain ', ...
             'RunInfo.PreprocessID.'], ...
            ReportFile);

    end

    if ~strcmp(Decoded.RunInfo.PreprocessID, PreprocessID)

        error( ...
            'Preprocessing:GetPreprocessingReport:PreprocessIDMismatch', ...
            ['Report at "%s" embeds PreprocessID "%s" but "%s" was ', ...
             'requested.'], ...
            ReportFile, ...
            Decoded.RunInfo.PreprocessID, ...
            PreprocessID);

    end

    %% Build Output

    Report = struct();
    Report.PreprocessID = PreprocessID;
    Report.RunID = RunID;
    Report.OutputDirectory = OutputDirectory;
    Report.ReportFile = ReportFile;
    Report.Report = Decoded;

end
