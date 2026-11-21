function Comparison = CompareEstimators(Evaluation, FairnessEvidence)
%COMPAREESTIMATORS Fair EKF-versus-UKF performance comparison.
%
%   Comparison = COMPAREESTIMATORS(Evaluation, Config, FairnessEvidence)
%   places the EKF and UKF metrics side by side under the fair-comparison
%   conditions of task document 13: identical run and preprocessing
%   revision, initial conditions, initial covariance, process and
%   measurement models, sensor data, timestamps, noise assumptions and
%   availability/gating policies.
%
%   The comparison REPORTS measured quantities and their ratios. It does
%   NOT declare one filter superior: conclusions require the documented
%   metrics across the available scenarios and runs, and one favourable
%   run is explicitly not sufficient evidence.
%
%   Output fields:
%       .Metrics       - side-by-side tables (forward and smoothed)
%       .Ratios        - EKF/UKF ratios of the headline metrics
%       .Fairness      - the recorded fairness evidence (inputs, config
%                        hash, model identities)
%       .InterpretationNotes - documented limits on interpretation
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: EvaluateAgainstGroundTruth, CalculateEstimationMetrics.

    Metrics = struct();
    Names = {'ForwardEKF', 'ForwardUKF', 'SmoothedEKF', 'SmoothedUKF'};

    for Index = 1:numel(Names)

        Name = Names{Index};

        if isfield(Evaluation, Name) && ...
                isfield(Evaluation.(Name), 'Status') && ...
                strcmp(Evaluation.(Name).Status, 'Evaluated')

            M = Evaluation.(Name);
            Metrics.(Name) = struct( ...
                'Position3DRMSE_m', M.Position3DRMSE_m, ...
                'PositionRMSE_m', M.PositionRMSE_m, ...
                'VelocityRMSE_mps', M.VelocityRMSE_mps, ...
                'AttitudeAngularRMSE_rad', M.AttitudeAngularRMSE_rad, ...
                'AttitudeAngularMax_rad', M.AttitudeAngularMax_rad, ...
                'NEESMean', M.NEESMean, ...
                'Coverage', M.Coverage);

        else

            Metrics.(Name) = struct('Status', 'NotAvailable');

        end

    end

    % Ratios (EKF / UKF) of headline metrics where both exist.
    Ratios = struct();
    Pairs = {{'ForwardEKF', 'ForwardUKF'}, {'SmoothedEKF', 'SmoothedUKF'}};

    for Index = 1:numel(Pairs)

        A = Pairs{Index}{1};
        B = Pairs{Index}{2};
        PairName = [A '_vs_' B];

        if isfield(Metrics.(A), 'Position3DRMSE_m') && ...
                isfield(Metrics.(B), 'Position3DRMSE_m')

            Ratios.(PairName) = struct( ...
                'Position3DRMSE', ...
                    Metrics.(A).Position3DRMSE_m / ...
                    Metrics.(B).Position3DRMSE_m, ...
                'VelocityRMSE', ...
                    norm(Metrics.(A).VelocityRMSE_mps) / ...
                    norm(Metrics.(B).VelocityRMSE_mps), ...
                'AttitudeAngularRMSE', ...
                    Metrics.(A).AttitudeAngularRMSE_rad / ...
                    Metrics.(B).AttitudeAngularRMSE_rad, ...
                'NEESMean', ...
                    Metrics.(A).NEESMean / Metrics.(B).NEESMean);

        else

            Ratios.(PairName) = struct('Status', 'NotAvailable');

        end

    end

    Comparison = struct();
    Comparison.Metrics = Metrics;
    Comparison.Ratios = Ratios;
    Comparison.Fairness = FairnessEvidence;
    Comparison.InterpretationNotes = { ...
        'Both filters consumed identical inputs, models, initial conditions, noise assumptions and policies (see Fairness).'; ...
        'Reported quantities are measured on this run; no filter is declared superior from one run.'; ...
        'Ratios above 1 mean the EKF metric is larger (worse for error metrics) on this run.'; ...
        'NEES values are consistency indicators against the chi-square expectation, not error magnitudes.'};

end
