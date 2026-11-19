function RunConfig = BuildJSBSimRun(Scenario, Timeline)
%BUILDJSBSIMRUN Build deterministic Block 7 JSBSim run configuration.

    if nargin ~= 2
        error('Block7:BuildJSBSimRun:InvalidInputCount', ...
            'BuildJSBSimRun requires Scenario and Timeline.');
    end

    if ~isstruct(Scenario) || ~isscalar(Scenario)
        error('Block7:BuildJSBSimRun:InvalidScenario', ...
            'Scenario must be a scalar structure.');
    end

    if ~isstruct(Timeline) || ~isscalar(Timeline)
        error('Block7:BuildJSBSimRun:InvalidTimeline', ...
            'Timeline must be a scalar structure.');
    end

    if ~isfield(Timeline, 'Time_s') || isempty(Timeline.Time_s)
        error('Block7:BuildJSBSimRun:MissingTimelineTime', ...
            'Timeline.Time_s is required.');
    end

    Time_s = Timeline.Time_s(:);

    if any(~isfinite(Time_s)) || any(diff(Time_s) <= 0)
        error('Block7:BuildJSBSimRun:InvalidTimelineTime', ...
            'Timeline.Time_s must be finite and strictly increasing.');
    end

    if ~isfield(Timeline, 'SampleTime_s') || ...
            ~isscalar(Timeline.SampleTime_s) || ...
            ~isfinite(Timeline.SampleTime_s) || ...
            Timeline.SampleTime_s <= 0
        error('Block7:BuildJSBSimRun:InvalidSampleTime', ...
            'Timeline.SampleTime_s must be a positive finite scalar.');
    end

    ProjectRoot = fileparts(fileparts(mfilename('fullpath')));
    Block7Root   = fileparts(mfilename('fullpath'));

    RunsRoot = fullfile(Block7Root, 'Runs');

    if ~isfolder(RunsRoot)
        mkdir(RunsRoot);
    end

    if isfield(Scenario, 'ScenarioID') && ...
            ~(isempty(Scenario.ScenarioID))
        ScenarioID = string(Scenario.ScenarioID);
    else
        ScenarioID = "Scenario";
    end

    ScenarioID = regexprep(ScenarioID, '[^\w\-]', '_');

    RunDirectory = fullfile(RunsRoot, char(ScenarioID));

    if ~isfolder(RunDirectory)
        mkdir(RunDirectory);
    end

    Duration_s = Time_s(end) - Time_s(1);

    RunConfig = struct();

    RunConfig.ProjectRoot = ProjectRoot;
    RunConfig.Block7Root = Block7Root;
    RunConfig.RunsRoot = RunsRoot;
    RunConfig.RunDirectory = RunDirectory;

    RunConfig.ScenarioID = char(ScenarioID);

    RunConfig.Aircraft = 'c172p';

    RunConfig.StartTime_s = Time_s(1);
    RunConfig.Duration_s = Duration_s;

    RunConfig.SampleTime_s = 0.005;
    RunConfig.SampleRate_Hz = 200;

    RunConfig.TimelineSampleTime_s = Timeline.SampleTime_s;
    RunConfig.TimelineTime_s = Time_s;

    RunConfig.InitFile = fullfile( ...
        RunDirectory, ...
        'Init.xml');

    RunConfig.ScriptFile = fullfile( ...
        RunDirectory, ...
        'Script.xml');

    RunConfig.OutputFile = fullfile( ...
        RunDirectory, ...
        'Output.xml');

    RunConfig.TelemetryFile = fullfile( ...
        RunDirectory, ...
        'Telemetry.csv');

end