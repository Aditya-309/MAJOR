function Summary = RunMonteCarlo(ScenarioName, NSamples, Seed0, ...
        Duration_s, ValRoot)
%RUNMONTECARLO Seeded Monte-Carlo validation battery (change A2).
%
%   Summary = RUNMONTECARLO(ScenarioName, NSamples, Seed0, Duration_s,
%   ValRoot) generates NSamples independent noise realizations
%   (seeds Seed0+1 .. Seed0+NSamples), each through the full chain
%       truth (B1) -> sensors -> preprocessing -> estimation (18-state)
%   inside ValRoot, then computes trial-level NEES/NIS statistics and a
%   reproducible seed manifest. Nothing touches the production project.
%
%   Statistical use: per-run NEES means across the trials are compared
%   against the chi-square-derived distribution of run means (Bar-Shalom
%   consistency testing over independent trials).

    if nargin < 2 || isempty(NSamples)
        NSamples = 50;
    end

    if nargin < 3 || isempty(Seed0)
        Seed0 = 902100;
    end

    if nargin < 4 || isempty(Duration_s)
        Duration_s = 60;
    end

    if nargin < 5 || isempty(ValRoot)
        ValRoot = 'C:\Users\lalit\OneDrive\Documents\Aditya Docs\ENGINEERING\MAJOR_ValidationLab';
    end

    % Packages: frozen via ValRoot junctions, estimator from workspace.
    % A neutral working directory is mandatory: MATLAB searches pwd BEFORE
    % the path, so leaving cwd inside the real project root would shadow
    % the workspace estimator and the validation root.
    % Self-located project root (this file lives in <ProjectRoot>/ValidationLab).
    ProjectRoot = fileparts(fileparts(mfilename('fullpath')));
    cd(ValRoot);
    addpath(ProjectRoot);
    addpath(ValRoot);
    ProjectPaths = estimation.ProjectPaths(ValRoot);

    OutDir = fullfile(ValRoot, 'production', 'Estimation');

    PPCfg = preprocessing.PreprocessingConfig();
    EstCfg = estimation.EstimationConfig();
    EstCfg.State.EnableGNSSBiasStates = true;

    Results = struct('RunID', {}, 'Seed', {}, 'Scenario', {}, ...
        'PreprocessID', {}, 'EstimationID', {}, 'NEESForward', {}, ...
        'NEESSmoothed', {}, 'PosRMSE', {}, 'NISMean', {}, 'Status', {});

    t0 = tic;

    for i = 1:NSamples
        Seed = Seed0 + i;
        Stamp = datestr(now + i * (2 / 86400), 'yyyymmdd_HHMMSS');
        RunID = sprintf('Run_9%03d_%s', i, Stamp);
        fprintf('[%d/%d] %s seed=%d ... ', i, NSamples, RunID, Seed);

        Row = struct('RunID', RunID, 'Seed', Seed, ...
            'Scenario', ScenarioName, 'PreprocessID', '', ...
            'EstimationID', '', 'NEESForward', NaN, ...
            'NEESSmoothed', NaN, 'PosRMSE', NaN, 'NISMean', NaN, ...
            'NEESDoF', NaN, 'Status', 'OK');

        try
            BuildValidationRun(RunID, ScenarioName, Duration_s, ...
                Seed, ValRoot);

            RunDir = fullfile(ProjectPaths.RunsRoot, RunID);
            PP = preprocessing.PreprocessRun(RunID, PPCfg, struct( ...
                'RunDirectory', RunDir, 'ApproveUnregistered', true));
            Row.PreprocessID = PP.PreprocessID;

            % With a neutral working directory the junction root handles
            % output location; if the PP output appeared in the production
            % root anyway (pwd shadowing), relocate the PP subdir.
            SrcPP = fullfile(ProjectRoot, 'production', 'Preprocessed', ...
                RunID, PP.PreprocessID);
            DstPPDir = fullfile(ProjectPaths.PreprocessedRoot, RunID);

            if isfolder(SrcPP)

                if ~isfolder(DstPPDir)
                    mkdir(DstPPDir);
                end

                movefile(SrcPP, fullfile(DstPPDir, PP.PreprocessID));
            end

            E = estimation.RunStateReconstruction( ...
                RunID, PP.PreprocessID, EstCfg, struct( ...
                'ProjectRootOverride', ValRoot, ...
                'OutputRoot', OutDir, ...
                'WriteReviewCsv', false, 'Verbose', false));
            Row.EstimationID = E.EstimationID;

            Rep = estimation.GetEstimationReport(E.EstimationID, OutDir);
            R = Rep.Report;
            Row.NEESForward = R.Evaluation.ForwardEKF.NEESMean;
            Row.NEESSmoothed = R.Evaluation.SmoothedEKF.NEESMean;
            Row.PosRMSE = R.Evaluation.ForwardEKF.Position3DRMSE_m;

            S = load(fullfile(E.OutputDirectory, 'EstimationResults.mat'));
            Row.NEESDoF = size(S.EstimationResults.Forward.EKF.State, 2);
            Inn = S.EstimationResults.Diagnostics.Innovations.EKF;
            sel = isfinite(Inn.NIS);
            Row.NISMean = mean(Inn.NIS(sel));
            fprintf('NEES %.2f RMSE %.3f NIS %.3f (%.1f min)\n', ...
                Row.NEESForward, Row.PosRMSE, Row.NISMean, ...
                toc(t0) / 60);

        catch Err
            Row.Status = sprintf('%s: %s', Err.identifier, Err.message);
            fprintf('FAILED (%s)\n', Row.Status);
        end

        Results(end + 1) = Row; %#ok<AGROW>
    end

    %% Trial-level statistics
    OK = arrayfun(@(r) strcmp(r.Status, 'OK'), Results);
    Nees = [Results(OK).NEESForward];
    N = numel(Nees);
    Summary = struct();
    Summary.Scenario = ScenarioName;
    Summary.Seeds = Seed0 + (1:NSamples);
    Summary.Trials = N;
    Summary.NEESMean = mean(Nees);
    Summary.NEESStd = std(Nees);
    Summary.NEESMedian = median(Nees);
    Summary.RMSEMean = mean([Results(OK).PosRMSE]);
    Summary.NISMean = mean([Results(OK).NISMean]);
    % NEES expectation equals the ESTIMATED STATE DIMENSION (9 for the
    % nav-only model, 18 with GNSS bias states), taken from the runs.
    DoF = Results(find(OK, 1)).NEESDoF;
    Summary.ExpectedNEES = DoF;
    % Two-sided 95% band for the mean of N independent chi2_Dof trials.
    Half = 1.96 * sqrt(2 * DoF / max(N, 1));
    Summary.Consistent95 = Summary.NEESMean <= DoF + Half && ...
        Summary.NEESMean >= DoF - Half;
    Summary.Results = Results;

    %% Seed manifest (reproducibility)
    Manifest = struct('Scenario', ScenarioName, ...
        'Duration_s', Duration_s, 'BaseSeed', Seed0, ...
        'Seeds', Summary.Seeds, 'GeneratedAt', char(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss')), ...
        'Estimator', '18-state (EnableGNSSBiasStates=true)');
    ManifestFile = fullfile(ValRoot, sprintf( ...
        'SeedManifest_%s_%s.json', ScenarioName, ...
        datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(ManifestFile, 'w');
    fwrite(fid, jsonencode(Manifest, 'PrettyPrint', true), 'char');
    fclose(fid);
    Summary.ManifestFile = ManifestFile;

    SummaryFile = fullfile(ValRoot, sprintf( ...
        'MCSummary_%s_%s.csv', ScenarioName, datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(SummaryFile, 'w');
    fprintf(fid, 'RunID,Seed,Status,NEESForward,NEESSmoothed,PosRMSE,NISMean\n');

    for k = 1:numel(Results)
        fprintf(fid, '%s,%d,%s,%.6f,%.6f,%.6f,%.6f\n', ...
            Results(k).RunID, Results(k).Seed, ...
            ternary(Results(k).Status, 'OK', Results(k).Status), ...
            numOrNaN(Results(k), 'NEESForward'), ...
            numOrNaN(Results(k), 'NEESSmoothed'), ...
            numOrNaN(Results(k), 'PosRMSE'), ...
            numOrNaN(Results(k), 'NISMean'));
    end

    fclose(fid);
    Summary.SummaryFile = SummaryFile;

    fprintf('\n=== Monte Carlo summary (%s, N=%d) ===\n', ScenarioName, N);
    fprintf('NEES forward: mean %.2f median %.2f std %.2f (expected %d)\n', ...
        Summary.NEESMean, Summary.NEESMedian, Summary.NEESStd, DoF);
    fprintf('Pos RMSE mean %.4f m | NIS mean %.3f (expected 3)\n', ...
        Summary.RMSEMean, Summary.NISMean);
    fprintf('95%% consistency band for run-mean: [%.2f, %.2f] -> %s\n', ...
        DoF - Half, DoF + Half, ternary(Summary.Consistent95, ...
        'CONSISTENT', 'INCONSISTENT'));
    fprintf('Seed manifest: %s\n', ManifestFile);
end

function v = ternary(cond, a, b)

    if islogical(cond) && isscalar(cond) && cond
        v = a;
    elseif islogical(cond) && isscalar(cond)
        v = b;
    else
        v = b;
    end

end

function v = numOrNaN(S, Field)

    if isfield(S, Field) && isnumeric(S.(Field)) && ~isempty(S.(Field))
        v = S.(Field);
    else
        v = NaN;
    end

end
