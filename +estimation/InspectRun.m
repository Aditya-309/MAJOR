function Inspection = InspectRun(RunID, PreprocessID, Config, Paths)
%INSPECTRUN Inspect one explicit run and preprocessing revision.
%
%   Inspection = INSPECTRUN(RunID, PreprocessID, Config) resolves the
%   EXPLICIT preprocessing revision, validates its input contract and
%   reports what the estimator would consume: stream summaries, timeline
%   composition, eligibility counts and initialization feasibility. The
%   operation is strictly read-only.
%
%   Inspection = INSPECTRUN(RunID, PreprocessID, Config, Paths) uses an
%   already resolved estimation.ProjectPaths() structure.
%
%   Output fields:
%       .RunID, .PreprocessID, .InputInfo
%       .Validation          - contract validation result
%       .TimelineSummary     - event counts and exclusion reasons
%       .InitializationCheck - eligible GNSS position/velocity counts,
%                              magnetometer availability, verdict text
%       .Verdict             - 'Eligible', 'ReviewRequired' or
%                              'Ineligible' with Issues
%
%   Public Block 10 API entry point.
%
%   See also: DiscoverRuns, RunStateReconstruction, LoadPreprocessedRun.

    if nargin < 4 || isempty(Paths)
        Paths = estimation.ProjectPaths();
    end

    Issues = {};
    Warnings = {};

    [Data, InputInfo] = estimation.LoadPreprocessedRun( ...
        RunID, PreprocessID, Paths);
    Validation = estimation.ValidatePreprocessedRun(Data, Config);

    Issues = [Issues; Validation.Issues(:)];
    Warnings = [Warnings; Validation.Warnings(:)];

    TimelineSummary = struct();

    if Validation.Passed

        Timeline = estimation.BuildMeasurementTimeline(Data, Config);
        Events = Timeline.Events;
        Codes = Timeline.EventCodes;

        TimelineSummary = struct( ...
            'TotalEvents', Timeline.TotalEvents, ...
            'Streams', Timeline.Streams);

        PosEligible = sum(Events.Type == Codes.GNSSPosition & ...
            Events.Eligible);
        VelEligible = sum(Events.Type == Codes.GNSSVelocity & ...
            Events.Eligible);
        MagEligible = sum(Events.Type == Codes.MagneticField & ...
            Events.Eligible);

        InitCheck = struct( ...
            'EligibleGNSSPosition', PosEligible, ...
            'EligibleGNSSVelocity', VelEligible, ...
            'EligibleMagnetometer', MagEligible, ...
            'AttitudeSource', Config.Initialization.AttitudeSource, ...
            'MagnetometerUpdates', Config.Magnetometer.EnableUpdates);

        if PosEligible == 0
            Issues{end + 1} = ...
                'No eligible GNSS position measurement; initialization is impossible.';
        end

        if VelEligible == 0
            Issues{end + 1} = ...
                'No eligible GNSS velocity measurement; initialization is impossible.';
        end

        if Config.Magnetometer.EnableUpdates && MagEligible == 0 && ...
                strcmp(Config.Initialization.AttitudeSource, ...
                'AccelerometerMagnetometer')

            Issues{end + 1} = [ ...
                'Yaw initialization needs magnetometer measurements ', ...
                'but none are eligible and no attitude prior is set.'];

        end

        if PosEligible > 0 && VelEligible > 0 && ...
                ~(Config.Magnetometer.EnableUpdates && MagEligible == 0 && ...
                strcmp(Config.Initialization.AttitudeSource, ...
                'AccelerometerMagnetometer'))

            InitCheck.Verdict = 'Feasible';

        else

            InitCheck.Verdict = 'NotFeasible';

        end

    else

        InitCheck = struct('Verdict', 'NotAssessed', ...
            'Note', 'Input contract validation failed.');

    end

    if isempty(Issues) && Validation.Passed
        Verdict = 'Eligible';
    elseif ~Validation.Passed
        Verdict = 'Ineligible';
    else
        Verdict = 'ReviewRequired';
    end

    Inspection = struct();
    Inspection.RunID = RunID;
    Inspection.PreprocessID = PreprocessID;
    Inspection.InputInfo = InputInfo;
    Inspection.Validation = Validation;
    Inspection.TimelineSummary = TimelineSummary;
    Inspection.InitializationCheck = InitCheck;
    Inspection.Issues = Issues;
    Inspection.Warnings = Warnings;
    Inspection.Verdict = Verdict;

end
