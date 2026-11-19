function RunOnePreprocessing()
%RUNONEPREPROCESSING Select and preprocess one existing registered run.
%
% Save this file in the project root (beside +preprocessing and production),
% then run from the MATLAB Command Window:
%
%   RunOnePreprocessing
%
% The script lists registered runs that pass discovery, lets you select
% one by number, performs the full InspectRun check, asks for confirmation,
% and calls the public preprocessing.PreprocessRun API.
%
% It then displays the generated MAT/JSON/CSV paths and previews their
% contents in the MATLAB Command Window. It does not modify source runs.

    fprintf('\n============================================================\n');
    fprintf(' BLOCK 9 - PROCESS ONE EXISTING RUN\n');
    fprintf('============================================================\n');

    %% Resolve project root from this script location

    ScriptPath = mfilename('fullpath');
    ProjectRoot = fileparts(ScriptPath);

    if isempty(ProjectRoot)
        ProjectRoot = pwd;
    end

    if ~isfolder(fullfile(ProjectRoot, '+preprocessing')) || ...
            ~isfolder(fullfile(ProjectRoot, 'production'))

        error('Preprocessing:RunOnePreprocessing:InvalidProjectRoot', ...
            ['Save RunOnePreprocessing.m in the project root, beside ', ...
             '+preprocessing and production. Resolved root: %s'], ...
            ProjectRoot);
    end

    addpath(ProjectRoot);

    %% Default configuration

    Config = preprocessing.PreprocessingConfig();

    fprintf('\nProject root:\n  %s\n', ProjectRoot);
    fprintf('\nConfiguration:\n');
    fprintf('  Source:                  %s\n', char(Config.Source));
    fprintf('  Missing sensor policy:   %s\n', ...
        char(Config.MissingSensors.Policy));
    fprintf('  Alignment enabled:       %s\n', ...
        logicalText(Config.Alignment.Enabled));
    fprintf('  Timestamp gap absolute:  %.4g s\n', ...
        Config.Timestamps.GapAbsolute_s);
    fprintf('  Timestamp gap relative:  %.4g\n', ...
        Config.Timestamps.GapRelative);

    %% Discover registered eligible runs

    fprintf('\nDiscovering registered runs...\n');
    RunList = preprocessing.DiscoverRuns(Config);

    Registered = RunList.Registered;

    if isempty(Registered)
        fprintf(2, '\nNo registered runs were found.\n');
        return;
    end

    EligibleMask = strcmp({Registered.Eligibility}, 'Eligible');
    Candidates = Registered(EligibleMask);

    fprintf('\nDiscovery summary:\n');
    fprintf('  Registered runs:   %d\n', RunList.Summary.RegisteredCount);
    fprintf('  Eligible runs:     %d\n', RunList.Summary.EligibleCount);
    fprintf('  Unregistered:      %d (not selectable by this script)\n', ...
        RunList.Summary.UnregisteredCount);
    fprintf('  Working runs:      %d (excluded)\n', ...
        RunList.Summary.WorkingRunCount);
    fprintf('  Failed runs:       %d (excluded)\n', ...
        RunList.Summary.FailedRunCount);

    if isempty(Candidates)
        fprintf(2, ['\nThere are no registered runs with discovery ', ...
            'eligibility = Eligible.\n']);
        fprintf('Use InspectRun on a run requiring review; this script does not\n');
        fprintf('automatically approve unregistered or ineligible runs.\n');
        return;
    end

    %% Display candidates

    fprintf('\nSelectable registered runs:\n');
    fprintf(' No.  %-34s %-18s %-22s\n', ...
        'RunID', 'Registry status', 'Finalized at');
    fprintf('%s\n', repmat('-', 1, 82));

    for k = 1:numel(Candidates)
        fprintf(' %3d  %-34s %-18s %-22s\n', ...
            k, ...
            truncateText(Candidates(k).RunID, 34), ...
            truncateText(Candidates(k).RegistryStatus, 18), ...
            truncateText(Candidates(k).FinalizedAt, 22));
    end

    %% Ask user to select one run

    SelectionText = input( ...
        '\nEnter the number of the run to preprocess (0 to cancel): ', ...
        's');
    Selection = str2double(strtrim(SelectionText));

    if isempty(SelectionText) || ~isfinite(Selection) || ...
            Selection ~= floor(Selection) || ...
            Selection < 0 || Selection > numel(Candidates)

        fprintf(2, '\nInvalid selection. No run was processed.\n');
        return;
    end

    if Selection == 0
        fprintf('\nCancelled. No run was processed.\n');
        return;
    end

    Selected = Candidates(Selection);
    RunID = Selected.RunID;

    %% Full read-only inspection before processing

    fprintf('\nInspecting selected run: %s\n', RunID);
    Inspection = preprocessing.InspectRun(RunID, Config);

    fprintf('\nInspection result:\n');
    fprintf('  Category:          %s\n', Inspection.Category);
    fprintf('  Eligibility:       %s\n', Inspection.Eligibility);
    fprintf('  Run directory:    %s\n', Inspection.RunDirectory);
    fprintf('  Required files:   %d / %d present\n', ...
        Inspection.Summary.RequiredPresent, ...
        Inspection.Summary.RequiredCount);
    fprintf('  Artifact checks:  %d passed, %d failed\n', ...
        Inspection.Summary.ChecksPassed, ...
        Inspection.Summary.ChecksFailed);

    if ~isempty(Inspection.MissingSensors)
        fprintf('  Missing sensors:  %s\n', ...
            strjoin(Inspection.MissingSensors, ', '));
    end

    printTextList('Inspection issues', Inspection.Issues);
    printTextList('Inspection warnings', Inspection.Warnings);

    if ~strcmp(Inspection.Eligibility, 'Eligible')
        fprintf(2, ['\nSTOPPED: full inspection did not return Eligible. ', ...
            'No preprocessing was started.\n']);
        return;
    end

    %% Explicit confirmation

    fprintf('\nThe selected run will be read and new outputs will be written to:\n');
    fprintf('  production/Preprocessed/%s/<new PreprocessID>/\n', RunID);
    fprintf('Existing outputs will not be overwritten.\n');

    Confirm = input('Continue? Enter Y to process, anything else to cancel: ', ...
        's');

    if ~strcmpi(strtrim(Confirm), 'Y')
        fprintf('\nCancelled. No run was processed.\n');
        return;
    end

    %% Execute Block 9 preprocessing

    fprintf('\n------------------------------------------------------------\n');
    fprintf('Processing run: %s\n', RunID);
    fprintf('------------------------------------------------------------\n');

    StartedAt = datetime('now');
    Result = preprocessing.PreprocessRun(RunID, Config);
    FinishedAt = datetime('now');

    fprintf('\nPreprocessing result:\n');
    fprintf('  RunID:             %s\n', Result.RunID);
    fprintf('  PreprocessID:      %s\n', Result.PreprocessID);
    fprintf('  Status:            %s\n', Result.Status);
    fprintf('  Eligibility:       %s\n', Result.Eligibility);
    fprintf('  Started:           %s\n', char(StartedAt));
    fprintf('  Finished:          %s\n', char(FinishedAt));
    fprintf('  Output directory:  %s\n', Result.OutputDirectory);

    printTextList('Processing warnings', Result.Warnings);
    printTextList('Processing errors', Result.Errors);

    if strcmp(Result.Status, 'FAILED')
        fprintf(2, '\nProcessing FAILED. Do not treat this output as valid.\n');
        fprintf(2, 'Check ProcessingFailed.txt in the output directory.\n');
        return;
    end

    %% Retrieve the published report

    fprintf('\nRetrieving and validating the exported report...\n');
    Retrieved = preprocessing.GetPreprocessingReport(Result.PreprocessID);
    Report = Retrieved.Report;

    fprintf('\nPublished report summary:\n');
    if isfield(Report, 'Status')
        fprintf('  Report status:     %s\n', textValue(Report.Status));
    end
    if isfield(Report, 'RunInfo') && isfield(Report.RunInfo, 'PreprocessID')
        fprintf('  Report ID:         %s\n', ...
            textValue(Report.RunInfo.PreprocessID));
    end
    if isfield(Report, 'Warnings')
        fprintf('  Report warnings:   %d\n', numel(Report.Warnings));
    end
    if isfield(Report, 'Errors')
        fprintf('  Report errors:     %d\n', numel(Report.Errors));
    end

    %% Display generated files and previews in the Command Window

    fprintf('\n============================================================\n');
    fprintf(' GENERATED FILES\n');
    fprintf('============================================================\n');

    fprintf('\nMAT file:\n  %s\n', Result.MatFile);
    if isfile(Result.MatFile)
        fprintf('  Variables stored in MAT file:\n');
        try
            MatContents = whos('-file', Result.MatFile);
            for k = 1:numel(MatContents)
                fprintf('    %-32s %-12s %s\n', ...
                    MatContents(k).name, ...
                    MatContents(k).class, ...
                    mat2str(MatContents(k).size));
            end
        catch MatListError
            fprintf(2, '  Could not inspect MAT file: %s\n', ...
                MatListError.message);
        end
    end

    fprintf('\nJSON report:\n  %s\n', Result.JsonFile);
    if isfile(Result.JsonFile)
        fprintf('  Report contents (decoded summary):\n');
        disp(Report);
    end

    ReviewNames = fieldnames(Result.ReviewFiles);
    fprintf('\nReview CSV files: %d\n', numel(ReviewNames));

    for k = 1:numel(ReviewNames)
        StreamName = ReviewNames{k};
        CsvPath = Result.ReviewFiles.(StreamName);

        fprintf('\n  %s CSV:\n    %s\n', StreamName, CsvPath);

        if isfile(CsvPath)
            try
                Preview = readtable(CsvPath);
                fprintf('    Rows: %d | Columns: %d\n', ...
                    height(Preview), width(Preview));
                fprintf('    First up to 8 rows:\n');
                disp(Preview(1:min(8, height(Preview)), :));
            catch CsvReadError
                fprintf(2, '    Could not preview CSV: %s\n', ...
                    CsvReadError.message);
            end
        else
            fprintf(2, '    File listed in result but not found on disk.\n');
        end
    end

    %% Final output inventory

    fprintf('\nAll files in this preprocessing output folder:\n');
    listFilesRecursive(Result.OutputDirectory);

    fprintf('\n============================================================\n');
    fprintf(' FINISHED: %s\n', Result.Status);
    fprintf(' PreprocessID: %s\n', Result.PreprocessID);
    fprintf(' Output folder: %s\n', Result.OutputDirectory);
    fprintf('============================================================\n');

    fprintf('\nThe original run data was not modified. New outputs are in the\n');
    fprintf('Preprocessed folder shown above.\n');
end

function printTextList(Heading, Items)
    fprintf('\n%s:\n', Heading);
    if isempty(Items)
        fprintf('  None\n');
        return;
    end
    for k = 1:numel(Items)
        fprintf('  - %s\n', textValue(Items{k}));
    end
end

function Text = logicalText(Value)
    if Value
        Text = 'true';
    else
        Text = 'false';
    end
end

function Text = truncateText(Value, MaxLength)
    Text = textValue(Value);
    if numel(Text) > MaxLength
        Text = [Text(1:MaxLength-3) '...'];
    end
end

function Text = textValue(Value)
    if ischar(Value)
        Text = Value;
    elseif isstring(Value) && isscalar(Value)
        Text = char(Value);
    elseif isnumeric(Value) && isscalar(Value)
        Text = num2str(Value);
    else
        Text = '<non-text value>';
    end
end

function listFilesRecursive(RootDirectory)
    Entries = dir(fullfile(RootDirectory, '**', '*'));
    Entries = Entries(~[Entries.isdir]);

    if isempty(Entries)
        fprintf('  (No files found.)\n');
        return;
    end

    for k = 1:numel(Entries)
        fprintf('  %-10s %s\n', ...
            formatBytes(Entries(k).bytes), ...
            fullfile(Entries(k).folder, Entries(k).name));
    end
end

function Text = formatBytes(NumberOfBytes)
    Units = {'B', 'KB', 'MB', 'GB'};
    Value = double(NumberOfBytes);
    UnitIndex = 1;

    while Value >= 1024 && UnitIndex < numel(Units)
        Value = Value / 1024;
        UnitIndex = UnitIndex + 1;
    end

    Text = sprintf('%.2f %s', Value, Units{UnitIndex});
end
