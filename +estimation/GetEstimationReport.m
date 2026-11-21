function Report = GetEstimationReport(EstimationID, OutputRoot)
%GETESTIMATIONREPORT Retrieve one estimation report by EstimationID.
%
%   Report = GETESTIMATIONREPORT(EstimationID) resolves the documented
%   EstimationID grammar
%
%       <RunID>__ES_<yyyymmdd_HHMMSS>_<nn>
%
%   to production/Estimation/<RunID>/<EstimationID>/ and returns the
%   decoded EstimationReport.json together with resolution metadata. The
%   operation is strictly read-only.
%
%   Report = GETESTIMATIONREPORT(EstimationID, OutputRoot) resolves under
%   the given output root instead (used by the isolated development
%   tests and by any documented non-production output root).
%
%   Resolution and verification (no silent substitution):
%       1. EstimationID must match the grammar exactly.
%       2. The output directory must exist.
%       3. A EstimationFailed.txt marker (if present) takes precedence:
%          a failed output is NEVER returned as a successful result.
%       4. EstimationReport.json must exist, decode, and its embedded
%          RunInfo.EstimationID must equal the requested ID.
%
%   Output fields:
%       Report.EstimationID, .RunID, .OutputDirectory, .ReportFile,
%       .Report (decoded JSON structure)
%
%   Public Block 10 API entry point (together with EstimationConfig,
%   DiscoverRuns, InspectRun and RunStateReconstruction).
%
%   See also: RunStateReconstruction, ExportEstimationResults.

    %% Validate Identifier Grammar

    if ~(ischar(EstimationID) || ...
            (isstring(EstimationID) && isscalar(EstimationID)))

        error( ...
            'Estimation:GetEstimationReport:InvalidEstimationID', ...
            'EstimationID must be a character vector or scalar string.');

    end

    EstimationID = char(EstimationID);
    Pattern = [ ...
        '^Run_[0-9]+_[0-9]{8}_[0-9]{6}', ...
        '__ES_[0-9]{8}_[0-9]{6}_[0-9]{2}$'];

    if isempty(regexp(EstimationID, Pattern, 'once'))

        error( ...
            'Estimation:GetEstimationReport:InvalidEstimationID', ...
            ['EstimationID "%s" does not match the required grammar ', ...
             '<RunID>__ES_<yyyymmdd_HHMMSS>_<nn>.'], EstimationID);

    end

    Separator = strfind(EstimationID, '__ES_');
    RunID = EstimationID(1:Separator(1) - 1);

    %% Resolve Output Directory

    if nargin >= 2 && ~isempty(OutputRoot)

        if ~(ischar(OutputRoot) || ...
                (isstring(OutputRoot) && isscalar(OutputRoot)))

            error( ...
                'Estimation:GetEstimationReport:InvalidOutputRoot', ...
                'OutputRoot must be a character vector or scalar string.');

        end

        Root = char(OutputRoot);

    else

        Paths = estimation.ProjectPaths();
        Root = Paths.EstimationRoot;

    end

    OutputDirectory = fullfile(Root, RunID, EstimationID);

    if ~isfolder(OutputDirectory)

        error( ...
            'Estimation:GetEstimationReport:EstimationIDNotFound', ...
            'No estimation output directory exists for "%s".', ...
            EstimationID);

    end

    %% Marker Precedence

    FailureMarker = fullfile(OutputDirectory, 'EstimationFailed.txt');

    if isfile(FailureMarker)

        error( ...
            'Estimation:GetEstimationReport:EstimationFailedMarker', ...
            ['Estimation output "%s" carries an EstimationFailed.txt ', ...
             'marker and is never returned as a successful result.'], ...
            EstimationID);

    end

    %% Decode and verify

    ReportFile = fullfile(OutputDirectory, 'EstimationReport.json');

    if ~isfile(ReportFile)

        error( ...
            'Estimation:GetEstimationReport:ReportFileMissing', ...
            'EstimationReport.json is missing for "%s".', EstimationID);

    end

    Text = fileread(ReportFile);

    try
        Decoded = jsondecode(Text);
    catch
        error( ...
            'Estimation:GetEstimationReport:ReportDecodeFailure', ...
            'EstimationReport.json for "%s" does not decode.', ...
            EstimationID);
    end

    if ~isfield(Decoded, 'RunInfo') || ...
            ~isfield(Decoded.RunInfo, 'EstimationID') || ...
            ~strcmp(Decoded.RunInfo.EstimationID, EstimationID)

        error( ...
            'Estimation:GetEstimationReport:EstimationIDMismatch', ...
            ['The embedded RunInfo.EstimationID of the report does not ', ...
             'equal the requested EstimationID "%s".'], EstimationID);

    end

    Report = struct();
    Report.EstimationID = EstimationID;
    Report.RunID = RunID;
    Report.OutputDirectory = OutputDirectory;
    Report.ReportFile = ReportFile;
    Report.Report = Decoded;

end
