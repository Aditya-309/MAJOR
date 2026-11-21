function Result = RunStateReconstruction(RunID, PreprocessID, Config, Options)
%RUNSTATERECONSTRUCTION Complete Block 10 state reconstruction workflow.
%
%   Result = RUNSTATERECONSTRUCTION(RunID, PreprocessID, Config) runs the
%   complete estimation workflow for one EXPLICIT preprocessing revision:
%
%       1. configuration validation
%       2. input loading and contract validation (read-only)
%       3. input provenance and native-rate event timeline
%       4. defensible initialization (alignment-search policy)
%       5. EKF and UKF forward estimation (identical assumptions)
%       6. full-flight backward smoothing for both filters
%       7. diagnostics: confidence, sensor contribution, integrity,
%          model mismatch, evidence-linked investigation events
%       8. POST-ESTIMATION ground-truth evaluation and fair comparison
%          (only when enabled; strictly after step 5-6 complete)
%       9. report generation and transactional export
%
%   Result = RUNSTATERECONSTRUCTION(RunID, PreprocessID, Config, Options)
%   accepts options:
%       .ProjectRootOverride - explicit project root (isolated
%                              development tests only)
%       .OutputRoot          - explicit output root (tests use the
%                              external workspace; empty means
%                              Config.Output.EstimationRoot or
%                              production/Estimation)
%       .EnableExport        - default true
%
%   Output: Result struct with EstimationID, OutputDirectory, export and
%   validation records, the summary metrics and the diagnostics event
%   count. The full EstimationResults hierarchy is exported to
%   <OutputRoot>/<RunID>/<EstimationID>/ per the documented layout.
%
%   Public Block 10 API entry point.
%
%   See also: EstimationConfig, DiscoverRuns, InspectRun,
%   GetEstimationReport.

    if nargin < 3 || isempty(Config)
        Config = estimation.EstimationConfig();
    end

    Config = estimation.ValidateEstimationConfig(Config);

    if nargin < 4
        Options = struct();
    end

    Options = applyOptionDefaults(Options);

    %% Paths

    if ~isempty(Options.ProjectRootOverride)
        Paths = estimation.ProjectPaths(Options.ProjectRootOverride);
    else
        Paths = estimation.ProjectPaths();
    end

    if ~isempty(Options.OutputRoot)
        OutputRoot = char(Options.OutputRoot);
    elseif ~isempty(Config.Output.EstimationRoot)
        OutputRoot = char(Config.Output.EstimationRoot);
    else
        OutputRoot = Paths.EstimationRoot;
    end

    %% 2-3. Input, provenance, timeline

    [Data, InputInfo] = estimation.LoadPreprocessedRun( ...
        RunID, PreprocessID, Paths);
    Validation = estimation.ValidatePreprocessedRun(Data, Config);

    if ~Validation.Passed

        error( ...
            'Estimation:RunStateReconstruction:InputContractFailed', ...
            'Input contract validation failed: %s', ...
            strjoin(Validation.Issues, ' | '));

    end

    SourceProvenance = estimation.BuildInputProvenance(Data, InputInfo);
    Timeline = estimation.BuildMeasurementTimeline(Data, Config);

    %% 4. Initialization

    [x0, P0, InitInfo] = estimation.InitializeState( ...
        Data, Timeline, Config);

    %% Noise models and smoothing preflight

    NoiseModels = estimation.BuildNoiseModels(Config);

    MaxSmoothingSteps = Timeline.TotalEvents;
    MemoryEstimate_MB = MaxSmoothingSteps * 17e-3;
    EffectiveConfig = Config;
    SmoothingLimitation = '';

    if Config.Smoothing.FullFlight && ...
            MemoryEstimate_MB > Config.Smoothing.MemoryLimit_MB

        EffectiveConfig.Smoothing.FullFlight = false;
        SmoothingLimitation = sprintf( [ ...
            'Resource preflight estimated %.0f MB of smoothing history ', ...
            'for %d steps, exceeding the configured limit of %.0f MB. ', ...
            'Full-flight smoothing was not run and no shorter window ', ...
            'was substituted.'], ...
            MemoryEstimate_MB, MaxSmoothingSteps, ...
            Config.Smoothing.MemoryLimit_MB);

    end

    %% 5. Forward estimation (identical assumptions for both filters)

    MemBefore_MB = memoryInUseMB();
    tStart = tic;

    FilterEKF = estimation.CreateEKF(x0, P0, EffectiveConfig, ...
        NoiseModels, MaxSmoothingSteps);
    [ForwardEKF, RunLogEKF] = estimation.RunFilter(FilterEKF, 'EKF', ...
        Timeline, EffectiveConfig, NoiseModels, InitInfo);

    FilterUKF = estimation.CreateUKF(x0, P0, EffectiveConfig, ...
        NoiseModels, MaxSmoothingSteps);
    [ForwardUKF, RunLogUKF] = estimation.RunFilter(FilterUKF, 'UKF', ...
        Timeline, EffectiveConfig, NoiseModels, InitInfo);

    ForwardTime_s = toc(tStart);

    %% 6. Smoothing

    tStart = tic;
    SmoothingEKF = estimation.RunSmoothing(FilterEKF, 'EKF', ...
        EffectiveConfig, ForwardEKF);
    SmoothingUKF = estimation.RunSmoothing(FilterUKF, 'UKF', ...
        EffectiveConfig, ForwardUKF);
    SmoothingTime_s = toc(tStart);

    MemAfter_MB = memoryInUseMB();

    if ~isempty(SmoothingLimitation)
        SmoothingEKF.Limitation = SmoothingLimitation;
        SmoothingEKF.Status = 'ResourceLimited';
        SmoothingUKF.Limitation = SmoothingLimitation;
        SmoothingUKF.Status = 'ResourceLimited';
    end

    %% 7. Diagnostics

    Diagnostics = estimation.BuildDiagnostics( ...
        ForwardEKF, ForwardUKF, SmoothingEKF, SmoothingUKF, ...
        RunLogEKF, RunLogUKF, Timeline, InitInfo, EffectiveConfig);

    %% 8. Post-estimation ground-truth evaluation

    Evaluation = struct('Status', 'Disabled', ...
        'Note', 'Ground-truth evaluation disabled in configuration.');
    Comparison = struct('Status', 'NotAvailable');

    if Config.Evaluation.EnableGroundTruthEvaluation

        Evaluation = estimation.EvaluateAgainstGroundTruth( ...
            RunID, InputInfo, InitInfo, ForwardEKF, ForwardUKF, ...
            SmoothingEKF, SmoothingUKF, Config, Paths);

        FairnessEvidence = struct( ...
            'RunID', RunID, ...
            'PreprocessID', PreprocessID, ...
            'SharedInitialState', true, ...
            'SharedInitialCovariance', true, ...
            'SharedProcessModel', ...
                'estimation.StateTransitionModel (single implementation)', ...
            'SharedMeasurementModels', ...
                'estimation.MeasurementModel (single implementation)', ...
            'SharedInputs', true, ...
            'SharedTimestamps', true, ...
            'SharedNoiseAssumptions', true, ...
            'SharedPolicies', ...
                'same eligibility, gating and validity code path', ...
            'ConfigVersion', Config.Version);

        Comparison = estimation.CompareEstimators( ...
            Evaluation, FairnessEvidence);

    end

    %% Processing information

    ProcessingInfo = struct();
    ProcessingInfo.Environment = struct( ...
        'MATLABVersion', version, ...
        'MATLABRelease', version('-release'), ...
        'FilterImplementation', ...
            'Sensor Fusion and Tracking Toolbox trackingEKF/trackingUKF', ...
        'ImplementationVersion', Config.ImplementationVersion, ...
        'Timestamp', char(datetime('now', ...
            'Format', 'yyyy-MM-dd''T''HH:mm:ss')));
    ProcessingInfo.Timing = struct( ...
        'ForwardEstimation_s', ForwardTime_s, ...
        'Smoothing_s', SmoothingTime_s);
    ProcessingInfo.Memory = struct( ...
        'Before_MB', MemBefore_MB, ...
        'After_MB', MemAfter_MB, ...
        'SmoothingPreflightEstimate_MB', MemoryEstimate_MB, ...
        'SmoothingStepCap', MaxSmoothingSteps);
    ProcessingInfo.SmoothingLimitation = SmoothingLimitation;
    ProcessingInfo.InputValidation = Validation;

    %% Assemble results

    Results = struct();
    Results.RunInfo = struct( ...
        'RunID', RunID, ...
        'PreprocessID', PreprocessID, ...
        'Status', 'SUCCESS');
    Results.SourceProvenance = SourceProvenance;
    Results.Configuration = struct( ...
        'Config', EffectiveConfig, ...
        'RequestedConfig', Config, ...
        'Anchor', InitInfo.Anchor);
    Results.Forward = struct('EKF', ForwardEKF, 'UKF', ForwardUKF);
    Results.Smoothed = struct('EKF', SmoothingEKF, 'UKF', SmoothingUKF);
    Results.Diagnostics = Diagnostics;
    Results.Investigation = Diagnostics.Investigation;
    Results.Evaluation = Evaluation;
    Results.ProcessingInfo = ProcessingInfo;

    %% 9. Export

    EstimationID = '';
    Export = struct('Status', 'NotRequested');

    if Options.EnableExport

        EstimationID = allocateEstimationID(RunID, OutputRoot);
        Results.RunInfo.EstimationID = EstimationID;

        Report = estimation.BuildEstimationReport( ...
            RunID, PreprocessID, EstimationID, Config, InputInfo, ...
            InitInfo, Timeline, NoiseModels, ForwardEKF, ForwardUKF, ...
            SmoothingEKF, SmoothingUKF, Diagnostics, Evaluation, ...
            Comparison, ProcessingInfo);

        Export = estimation.ExportEstimationResults( ...
            RunID, EstimationID, Results, Report, Config, OutputRoot);

    end

    %% Result summary

    Result = struct();
    Result.RunID = RunID;
    Result.PreprocessID = PreprocessID;
    Result.EstimationID = EstimationID;
    Result.OutputDirectory = Export.TargetDirectory;
    Result.Export = Export;
    Result.InitInfo = InitInfo;
    Result.Summary = struct( ...
        'ForwardEKFSteps', numel(ForwardEKF.Time_s), ...
        'ForwardUKFSteps', numel(ForwardUKF.Time_s), ...
        'SmoothingEKFStatus', SmoothingEKF.Status, ...
        'SmoothingUKFStatus', SmoothingUKF.Status, ...
        'InvestigationEventCount', Diagnostics.Investigation.EventCount, ...
        'EvaluationStatus', getStatusOr(Evaluation, 'Completed'), ...
        'ForwardTime_s', ForwardTime_s, ...
        'SmoothingTime_s', SmoothingTime_s);

end

%% Local helpers

function Options = applyOptionDefaults(Options)
    if ~isstruct(Options) || ~isscalar(Options)

        error( ...
            'Estimation:RunStateReconstruction:InvalidOptions', ...
            'Options must be a scalar structure.');

    end

    Defaults = struct( ...
        'ProjectRootOverride', '', ...
        'OutputRoot', '', ...
        'EnableExport', true);
    Names = fieldnames(Defaults);

    for Index = 1:numel(Names)

        if ~isfield(Options, Names{Index})
            Options.(Names{Index}) = Defaults.(Names{Index});
        end

    end
end

function EstimationID = allocateEstimationID(RunID, OutputRoot)
    % Unique ID: <RunID>__ES_<yyyymmdd_HHMMSS>_<nn>. The sequential
    % suffix handles same-second collisions; the export itself re-verifies
    % that the target directory is empty (never overwriting).
    Stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));

    for Suffix = 1:99

        EstimationID = sprintf('%s__ES_%s_%02d', RunID, Stamp, Suffix);
        Candidate = fullfile(OutputRoot, RunID, EstimationID);

        if ~exist(Candidate, 'dir')
            return
        end

    end

    error( ...
        'Estimation:RunStateReconstruction:EstimationIDExhausted', ...
        'Could not allocate a unique EstimationID for this second.');

end

function Status = getStatusOr(S, Default)
    if isstruct(S) && isfield(S, 'Status')
        Status = S.Status;
    else
        Status = Default;
    end
end

function MB = memoryInUseMB()
    try
        Info = memory;
        MB = Info.MemUsedMATLAB / 2^20;
    catch
        MB = NaN;
    end
end
