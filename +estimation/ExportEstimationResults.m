function Export = ExportEstimationResults(RunID, EstimationID, Results, Report, Config, OutputRoot)
%EXPORTESTIMATIONRESULTS Transactional export of one estimation result.
%
%   Export = EXPORTESTIMATIONRESULTS(RunID, EstimationID, Results,
%   Report, Config, OutputRoot) publishes the estimation outputs to
%   <OutputRoot>/<RunID>/<EstimationID>/ following the established Block
%   9 export philosophy:
%
%       - unique EstimationID, never overwriting an existing output
%         (a non-empty target directory is a hard error);
%       - export order: EstimationResults.mat -> Review CSVs -> CSV
%         read-back validation -> transactional EstimationReport.json
%         (written to a .tmp name, decoded and EstimationID-verified in
%         place, then renamed to the final name as the success commit
%         point; nothing failure-prone runs after the rename and the
%         temp is removed on every failure path);
%       - explicit failure reporting: any failure leaves an
%         EstimationFailed.txt marker in the target directory and the
%         operation raises; no partially published result ever appears
%         successful (GetEstimationReport checks the marker first);
%       - complete source provenance inside both the MAT and the report.
%
%   Output layout (task document 16):
%       <RunID>/<EstimationID>/
%           EstimationResults.mat
%           EstimationReport.json
%           Review/
%               ForwardEKF.csv, ForwardUKF.csv,
%               SmoothedEKF.csv, SmoothedUKF.csv,
%               Diagnostics.csv, InvestigationEvents.csv
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: BuildEstimationReport, GetEstimationReport.

    TargetDirectory = fullfile(OutputRoot, RunID, EstimationID);

    if exist(TargetDirectory, 'dir')

        Listing = dir(TargetDirectory);
        Listing = Listing(~ismember({Listing.name}, {'.', '..'}));

        if ~isempty(Listing)

            error( ...
                'Estimation:ExportEstimationResults:OutputDirectoryExists', ...
                ['Output directory "%s" already exists and is not ', ...
                 'empty; outputs are never overwritten.'], ...
                TargetDirectory);

        end

    else

        [Created, Message] = mkdir(TargetDirectory);

        if ~Created

            error( ...
                'Estimation:ExportEstimationResults:OutputDirectoryFailure', ...
                'Could not create "%s": %s', TargetDirectory, Message);

        end

    end

    Export = struct();
    Export.EstimationID = EstimationID;
    Export.TargetDirectory = TargetDirectory;
    Export.Files = struct();
    Export.Validation = struct();

    try

        %% 1. MAT

        if Config.Output.WriteMat

            MatFile = fullfile(TargetDirectory, 'EstimationResults.mat');
            EstimationResults = Results;
            save(MatFile, 'EstimationResults', '-v7');

            % Read-back validation: section presence.
            Check = load(MatFile, 'EstimationResults');
            RequiredSections = {'RunInfo', 'SourceProvenance', ...
                'Configuration', 'Forward', 'Smoothed', ...
                'Diagnostics', 'Investigation', 'Evaluation', ...
                'ProcessingInfo'};

            for Index = 1:numel(RequiredSections)

                if ~isfield(Check.EstimationResults, RequiredSections{Index})

                    error( ...
                        'Estimation:ExportEstimationResults:MatReadBackFailure', ...
                        'MAT read-back is missing section "%s".', ...
                        RequiredSections{Index});

                end

            end

            Export.Files.EstimationResultsMat = MatFile;
            Export.Validation.MatReadBack = 'SectionsPresent';

        end

        %% 2. Review CSVs

        if Config.Output.WriteReviewCsv

            ReviewDir = fullfile(TargetDirectory, 'Review');

            if ~exist(ReviewDir, 'dir')
                mkdir(ReviewDir);
            end

            Export.Files.ForwardEKF = writeStateCsv( ...
                fullfile(ReviewDir, 'ForwardEKF.csv'), ...
                Results.Forward.EKF.Time_s, Results.Forward.EKF.State, ...
                Results.Forward.EKF.CovDiag, Results.Forward.EKF.Valid);
            Export.Files.ForwardUKF = writeStateCsv( ...
                fullfile(ReviewDir, 'ForwardUKF.csv'), ...
                Results.Forward.UKF.Time_s, Results.Forward.UKF.State, ...
                Results.Forward.UKF.CovDiag, Results.Forward.UKF.Valid);

            if strcmp(Results.Smoothed.EKF.Status, 'Smoothed')

                Export.Files.SmoothedEKF = writeStateCsv( ...
                    fullfile(ReviewDir, 'SmoothedEKF.csv'), ...
                    Results.Smoothed.EKF.Time_s, ...
                    Results.Smoothed.EKF.State, ...
                    Results.Smoothed.EKF.CovDiag, ...
                    true(size(Results.Smoothed.EKF.Time_s)));

            end

            if strcmp(Results.Smoothed.UKF.Status, 'Smoothed')

                Export.Files.SmoothedUKF = writeStateCsv( ...
                    fullfile(ReviewDir, 'SmoothedUKF.csv'), ...
                    Results.Smoothed.UKF.Time_s, ...
                    Results.Smoothed.UKF.State, ...
                    Results.Smoothed.UKF.CovDiag, ...
                    true(size(Results.Smoothed.UKF.Time_s)));

            end

            Export.Files.Diagnostics = writeDiagnosticsCsv( ...
                fullfile(ReviewDir, 'Diagnostics.csv'), ...
                Results.Diagnostics.Innovations);

            Export.Files.InvestigationEvents = writeEventsCsv( ...
                fullfile(ReviewDir, 'InvestigationEvents.csv'), ...
                Results.Investigation.Events);

            % CSV read-back validation: row counts.
            Export.Validation.CsvReadBack = struct( ...
                'ForwardEKFRows', countDataRows(Export.Files.ForwardEKF), ...
                'ForwardUKFRows', countDataRows(Export.Files.ForwardUKF), ...
                'DiagnosticsRows', countDataRows(Export.Files.Diagnostics), ...
                'EventRows', countDataRows(Export.Files.InvestigationEvents));

        end

        %% 3. Transactional JSON report

        if Config.Output.WriteReportJson

            JsonFile = fullfile(TargetDirectory, 'EstimationReport.json');
            TempFile = [JsonFile '.tmp'];

            CleanReport = sanitizeForJson(Report);
            Text = jsonencode(CleanReport, 'PrettyPrint', true);

            fid = fopen(TempFile, 'w');

            if fid < 0

                error( ...
                    'Estimation:ExportEstimationResults:JsonTempWrite', ...
                    'Could not open "%s" for writing.', TempFile);

            end

            fwrite(fid, Text, 'char');
            fclose(fid);

            % Decode and verify the embedded ID before publication.
            Back = fileread(TempFile);
            Decoded = jsondecode(Back);

            if ~isfield(Decoded, 'RunInfo') || ...
                    ~strcmp(Decoded.RunInfo.EstimationID, EstimationID)

                error( ...
                    'Estimation:ExportEstimationResults:JsonTempReadBack', ...
                    ['The temporary report does not carry the expected ', ...
                     'EstimationID "%s".'], EstimationID);

            end

            [Status, Message] = movefile(TempFile, JsonFile);

            if ~Status

                error( ...
                    'Estimation:ExportEstimationResults:JsonPublish', ...
                    'Could not publish the report: %s', Message);

            end

            Export.Files.EstimationReportJson = JsonFile;
            Export.Validation.JsonReadBack = 'EstimationIDVerified';

        end

        Export.Status = 'SUCCESS';

    catch Failure

        % Explicit failure record; no successful-looking partial output.
        MarkerFile = fullfile(TargetDirectory, 'EstimationFailed.txt');
        fid = fopen(MarkerFile, 'w');

        if fid > 0

            fprintf(fid, 'EstimationID: %s\n', EstimationID);
            fprintf(fid, 'FailedAt: %s\n', char(datetime('now', ...
                'Format', 'yyyy-MM-dd''T''HH:mm:ss')));
            fprintf(fid, 'Identifier: %s\n', Failure.identifier);
            fprintf(fid, 'Message: %s\n', Failure.message);
            fclose(fid);

        end

        % Remove any temp report.
        TempFile = fullfile(TargetDirectory, 'EstimationReport.json.tmp');

        if isfile(TempFile)
            delete(TempFile);
        end

        rethrow(Failure);

    end

end

%% Local helpers

function Path = writeStateCsv(Path, Time_s, State, CovDiag, Valid)
    Definition = estimation.StateDefinition(size(State, 2) > 15);
    Names = Definition.Names;

    fid = fopen(Path, 'w');

    if fid < 0

        error( ...
            'Estimation:ExportEstimationResults:CsvWriteFailure', ...
            'Could not open "%s" for writing.', Path);

    end

    fprintf(fid, 'Time_s');

    for Index = 1:numel(Names)
        fprintf(fid, ',%s', Names{Index});
    end

    for Index = 1:numel(Names)
        fprintf(fid, ',Sigma_%s', Names{Index});
    end

    fprintf(fid, ',Valid\n');

    for Row = 1:numel(Time_s)

        fprintf(fid, '%.9f', Time_s(Row));

        for Col = 1:numel(Names)
            fprintf(fid, ',%.12g', State(Row, Col));
        end

        for Col = 1:numel(Names)
            fprintf(fid, ',%.12g', sqrt(CovDiag(Row, Col)));
        end

        fprintf(fid, ',%d\n', Valid(Row));

    end

    fclose(fid);
end

function Path = writeDiagnosticsCsv(Path, Innovations)
    fid = fopen(Path, 'w');

    if fid < 0

        error( ...
            'Estimation:ExportEstimationResults:CsvWriteFailure', ...
            'Could not open "%s" for writing.', Path);

    end

    fprintf(fid, ['Filter,Time_s,Type,Stream,SourceRowIdx,SegmentID,', ...
        'Outcome,Z1,Z2,Z3,ZPred1,ZPred2,ZPred3,', ...
        'Innov1,Innov2,Innov3,Sdiag1,Sdiag2,Sdiag3,NIS,', ...
        'CorrectionNorm,TraceChange\n']);

    Filters = {'EKF', 'UKF'};

    for f = 1:numel(Filters)

        U = Innovations.(Filters{f});

        for Row = 1:numel(U.Time_s)

            fprintf(fid, '%s,%.9f,%d,%s,%d,%d,%s', ...
                Filters{f}, U.Time_s(Row), U.Type(Row), ...
                U.Stream{Row}, U.SourceRowIdx(Row), U.SegmentID(Row), ...
                U.Outcome{Row});

            fprintf(fid, ',%.12g', U.Z(Row, :));
            fprintf(fid, ',%.12g', U.ZPredicted(Row, :));
            fprintf(fid, ',%.12g', U.Innovation(Row, :));
            fprintf(fid, ',%.12g', U.SDiag(Row, :));
            fprintf(fid, ',%.12g', U.NIS(Row));
            fprintf(fid, ',%.12g', U.CorrectionNorm(Row));
            fprintf(fid, ',%.12g\n', U.TraceChange(Row));

        end

    end

    fclose(fid);
end

function Path = writeEventsCsv(Path, Events)
    fid = fopen(Path, 'w');

    if fid < 0

        error( ...
            'Estimation:ExportEstimationResults:CsvWriteFailure', ...
            'Could not open "%s" for writing.', Path);

    end

    fprintf(fid, 'Index,Type,Severity,StartTime_s,EndTime_s,Message\n');

    for Row = 1:numel(Events)

        Message = strrep(Events(Row).Message, '"', '''');
        Message = strrep(Message, newline, ' ');
        fprintf(fid, '%d,%s,%s,%.9f,%.9f,"%s"\n', ...
            Row, Events(Row).Type, Events(Row).Severity, ...
            Events(Row).StartTime_s, Events(Row).EndTime_s, Message);

    end

    fclose(fid);
end

function Count = countDataRows(Path)
    fid = fopen(Path, 'r');

    if fid < 0
        Count = -1;
        return
    end

    Count = 0;

    while ~feof(fid)

        Line = fgetl(fid);

        if ischar(Line) && ~isempty(Line)
            Count = Count + 1;
        end

    end

    fclose(fid);
    Count = Count - 1;   % header

end

function Clean = sanitizeForJson(Value)
    if isstruct(Value) && ~isscalar(Value)

        % Struct arrays: sanitize element-wise, preserving the array.
        Clean = Value;

        for Index = 1:numel(Value)
            Clean(Index) = sanitizeForJson(Value(Index));
        end

    elseif isstruct(Value)

        Clean = Value;
        Fields = fieldnames(Value);

        for Index = 1:numel(Fields)

            Clean.(Fields{Index}) = sanitizeForJson(Value.(Fields{Index}));

        end

    elseif iscell(Value)

        Clean = cell(size(Value));

        for Index = 1:numel(Value)
            Clean{Index} = sanitizeForJson(Value{Index});
        end

    elseif isnumeric(Value) && ~isreal(Value)

        Clean = 'ComplexValueRemoved';

    elseif isnumeric(Value)

        if isscalar(Value) && ~isfinite(Value)

            % Non-finite scalars become explicit strings (Block 9
            % export convention); the native numeric stays in the MAT.
            if isnan(Value)
                Clean = 'NaN';
            elseif Value > 0
                Clean = 'Inf';
            else
                Clean = '-Inf';
            end

        elseif any(~isfinite(Value(:)))

            % Non-finite array entries become explicit strings inside a
            % cell array; they are never silently zeroed or dropped.
            Clean = num2cell(Value);

            for Index = 1:numel(Clean)

                Entry = Clean{Index};

                if isnan(Entry)
                    Clean{Index} = 'NaN';
                elseif isinf(Entry) && Entry > 0
                    Clean{Index} = 'Inf';
                elseif isinf(Entry)
                    Clean{Index} = '-Inf';
                end

            end

        else

            Clean = Value;

        end

    elseif islogical(Value) || ischar(Value) || isstring(Value)

        Clean = Value;

    else

        Clean = class(Value);

    end

end
