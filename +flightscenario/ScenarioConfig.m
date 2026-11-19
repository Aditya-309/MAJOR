function Scenario = ScenarioConfig(ScenarioSelector)
%SCENARIOCONFIG Define canonical deterministic flight scenarios for C172P.
%
%   Scenario = ScenarioConfig(ScenarioSelector)
%
%   Creates and returns the static configuration for one of the six
%   deterministic Block 6 flight scenarios. The returned structure is
%   intentionally independent of JSBSim property names and contains only
%   scenario-definition information required by later Block 6 functions.
%
%   INPUT
%       ScenarioSelector : Scenario identifier. Accepted forms:
%           Numeric scalar:
%               1 - Straight and Level Cruise
%               2 - Controlled Climb
%               3 - Coordinated Turn
%               4 - Combined Maneuver
%               5 - Wind Disturbance
%               6 - GPS Outage Reference Scenario
%
%           Character vector or string scalar:
%               "StraightAndLevelCruise"
%               "ControlledClimb"
%               "CoordinatedTurn"
%               "CombinedManeuver"
%               "WindDisturbance"
%               "GPSOutageReference"
%
%   OUTPUT
%       Scenario : Canonical scenario definition structure containing:
%
%           Metadata
%           Name
%           ID
%
%           Time
%           SampleRate_Hz
%           SampleTime_s
%           Duration_s
%
%           InitialCondition
%               Latitude_rad
%               Longitude_rad
%               Altitude_m
%               Roll_rad
%               Pitch_rad
%               Heading_rad
%               Speed_mps
%
%           Controls
%               Definitions required by BuildScenarioTimeline.m
%
%           Wind
%               Deterministic wind-definition parameters
%
%           Events
%               GPSOutage
%               WindDisturbance
%               Maneuver
%
%   DEPENDENCIES
%       AircraftConfig.m
%
%   NOTES
%       - All quantities use SI units internally.
%       - Angles are expressed in radians.
%       - Wind definitions use the NED frame.
%       - This function defines scenario parameters only.
%       - No time-indexed profiles, control commands, wind histories, or
%         event masks are generated here.
%
%   MATLAB Version
%       MATLAB R2024b compatible.

    %% Input Validation

    if nargin ~= 1
        error( ...
            'ScenarioConfig:InvalidNumberOfInputs', ...
            'Exactly one scenario selector input is required.');
    end

    ScenarioID = localParseScenarioSelector(ScenarioSelector);

    %% Global Scenario Constants

    SampleRate_Hz = 100;
    SampleTime_s = 1 / SampleRate_Hz;

    if ~isscalar(SampleRate_Hz) || ...
            ~isnumeric(SampleRate_Hz) || ...
            ~isfinite(SampleRate_Hz) || ...
            SampleRate_Hz <= 0

        error( ...
            'ScenarioConfig:InvalidSampleRate', ...
            'SampleRate_Hz must be a positive finite scalar.');
    end

    %% Aircraft Configuration

    try
        Aircraft = config.AircraftConfig();
    catch ME
        throwAsCaller(MException( ...
            'ScenarioConfig:AircraftConfigFailure', ...
            'Failed to obtain aircraft configuration from AircraftConfig.m: %s', ...
            ME.message));
    end

    NominalSpeed_mps = localExtractNominalSpeed(Aircraft);

    %% Base Scenario Structure

    Scenario = struct();

    Scenario.Metadata = struct();
    Scenario.Metadata.Block = 6;
    Scenario.Metadata.BlockName = 'Flight Scenario';
    Scenario.Metadata.Aircraft = 'C172P';
    Scenario.Metadata.Description = ...
        'Deterministic flight scenario definition for flight-state reconstruction and trajectory estimation.';
    Scenario.Metadata.Version = '1.0';

    Scenario.Name = '';
    Scenario.ID = ScenarioID;

    Scenario.Time = [];
    Scenario.SampleRate_Hz = SampleRate_Hz;
    Scenario.SampleTime_s = SampleTime_s;
    Scenario.Duration_s = [];

    Scenario.InitialCondition = struct();
    Scenario.InitialCondition.Latitude_rad = 0;
    Scenario.InitialCondition.Longitude_rad = 0;
    Scenario.InitialCondition.Altitude_m = [];
    Scenario.InitialCondition.Roll_rad = 0;
    Scenario.InitialCondition.Pitch_rad = 0;
    Scenario.InitialCondition.Heading_rad = 0;
    Scenario.InitialCondition.Speed_mps = NominalSpeed_mps;

    Scenario.Controls = localDefaultControlDefinition();

    Scenario.Wind = localCalmWindDefinition();

    Scenario.Events = struct();

    Scenario.Events.GPSOutage = struct( ...
        'Enabled', false, ...
        'StartTime_s', NaN, ...
        'EndTime_s', NaN);

    Scenario.Events.WindDisturbance = struct( ...
        'Enabled', false, ...
        'StartTime_s', NaN, ...
        'EndTime_s', NaN);

    Scenario.Events.Maneuver = struct( ...
        'Enabled', false, ...
        'Type', 'None', ...
        'StartTime_s', NaN, ...
        'EndTime_s', NaN);

    %% Scenario-Specific Configuration

    switch ScenarioID

        case 1
            Scenario.Name = 'StraightAndLevelCruise';
            Scenario.Metadata.Description = ...
                'Straight-and-level C172P cruise scenario for baseline trim, stability, navigation, and future EKF validation.';

            Scenario.Duration_s = 300;

            Scenario.InitialCondition.Altitude_m = 1500;

            Scenario.Controls = localDefaultControlDefinition();
            Scenario.Controls.Stabilization = localTimeWindow(0, 30);
            Scenario.Controls.Cruise = localTimeWindow(30, 300);

            Scenario.Events.Maneuver = struct( ...
                'Enabled', true, ...
                'Type', 'StraightAndLevel', ...
                'StartTime_s', 0, ...
                'EndTime_s', 300);


        case 2
            Scenario.Name = 'ControlledClimb';
            Scenario.Metadata.Description = ...
                'Smooth controlled climb followed by transition to level flight and stabilization.';

            Scenario.Duration_s = 240;

            Scenario.InitialCondition.Altitude_m = 1000;

            Scenario.Controls = localDefaultControlDefinition();

            Scenario.Controls.TargetAltitude_m = 2000;

            Scenario.Controls.Stabilization = localTimeWindow(0, 30);

            Scenario.Controls.Climb = struct();
            Scenario.Controls.Climb.StartTime_s = 30;
            Scenario.Controls.Climb.EndTime_s = 150;
            Scenario.Controls.Climb.TargetAltitude_m = 2000;

            Scenario.Controls.LevelTransition = localTimeWindow(150, 180);
            Scenario.Controls.LevelStabilization = localTimeWindow(180, 240);

            Scenario.Events.Maneuver = struct( ...
                'Enabled', true, ...
                'Type', 'ControlledClimb', ...
                'StartTime_s', 30, ...
                'EndTime_s', 180);


        case 3
            Scenario.Name = 'CoordinatedTurn';
            Scenario.Metadata.Description = ...
                'Coordinated turn with smooth roll-in, sustained turning segment, smooth roll-out, and recovery.';

            Scenario.Duration_s = 180;

            Scenario.InitialCondition.Altitude_m = 1500;

            Scenario.Controls = localDefaultControlDefinition();

            Scenario.Controls.Stabilization = localTimeWindow(0, 30);
            Scenario.Controls.RollIn = localTimeWindow(30, 45);
            Scenario.Controls.SustainedTurn = localTimeWindow(45, 105);
            Scenario.Controls.RollOut = localTimeWindow(105, 120);
            Scenario.Controls.FinalStabilization = localTimeWindow(120, 180);

            Scenario.Controls.Turn = struct();
            Scenario.Controls.Turn.Coordinated = true;
            Scenario.Controls.Turn.Direction = 'Right';

            Scenario.Events.Maneuver = struct( ...
                'Enabled', true, ...
                'Type', 'CoordinatedTurn', ...
                'StartTime_s', 30, ...
                'EndTime_s', 120);


        case 4
            Scenario.Name = 'CombinedManeuver';
            Scenario.Metadata.Description = ...
                'Combined climb and coordinated-turn maneuver for coupled dynamics excitation and future estimator stress testing.';

            Scenario.Duration_s = 300;

            Scenario.InitialCondition.Altitude_m = 1500;

            Scenario.Controls = localDefaultControlDefinition();

            Scenario.Controls.Stabilization = localTimeWindow(0, 30);

            Scenario.Controls.Climb = localTimeWindow(30, 100);
            Scenario.Controls.RollIn = localTimeWindow(100, 115);
            Scenario.Controls.CoordinatedTurn = localTimeWindow(115, 180);
            Scenario.Controls.RollOutAndRecovery = localTimeWindow(180, 210);
            Scenario.Controls.StraightLevelRecovery = localTimeWindow(210, 300);

            Scenario.Controls.Turn = struct();
            Scenario.Controls.Turn.Coordinated = true;
            Scenario.Controls.Turn.Direction = 'Right';

            Scenario.Events.Maneuver = struct( ...
                'Enabled', true, ...
                'Type', 'CombinedManeuver', ...
                'StartTime_s', 30, ...
                'EndTime_s', 210);


        case 5
            Scenario.Name = 'WindDisturbance';
            Scenario.Metadata.Description = ...
                'Straight-and-level flight with deterministic NED-frame wind disturbance and deterministic gust transition.';

            Scenario.Duration_s = 240;

            Scenario.InitialCondition.Altitude_m = 1500;

            Scenario.Controls = localDefaultControlDefinition();

            Scenario.Controls.CalmBaseline = localTimeWindow(0, 60);
            Scenario.Controls.ConstantWind = localTimeWindow(60, 180);
            Scenario.Controls.GustTransition = localTimeWindow(180, 210);
            Scenario.Controls.Recovery = localTimeWindow(210, 240);

            Scenario.Wind = localWindDisturbanceDefinition();

            Scenario.Events.WindDisturbance = struct( ...
                'Enabled', true, ...
                'StartTime_s', 60, ...
                'EndTime_s', 210);

            Scenario.Events.Maneuver = struct( ...
                'Enabled', true, ...
                'Type', 'StraightAndLevel', ...
                'StartTime_s', 0, ...
                'EndTime_s', 240);


        case 6
            Scenario.Name = 'GPSOutageReference';
            Scenario.Metadata.Description = ...
                'Straight-and-level reference trajectory with deterministic GPS outage event metadata and uninterrupted ground truth.';

            Scenario.Duration_s = 300;

            Scenario.InitialCondition.Altitude_m = 1500;

            Scenario.Controls = localDefaultControlDefinition();

            Scenario.Controls.NormalReference = localTimeWindow(0, 60);
            Scenario.Controls.GPSOutageReference = localTimeWindow(60, 240);
            Scenario.Controls.RecoveryReference = localTimeWindow(240, 300);

            Scenario.Events.GPSOutage = struct( ...
                'Enabled', true, ...
                'StartTime_s', 60, ...
                'EndTime_s', 240);

            Scenario.Events.Maneuver = struct( ...
                'Enabled', true, ...
                'Type', 'StraightAndLevel', ...
                'StartTime_s', 0, ...
                'EndTime_s', 300);


        otherwise
            error( ...
                'ScenarioConfig:UnsupportedScenarioID', ...
                'Scenario ID %d is not supported.', ...
                ScenarioID);
    end

    %% Final Structural Validation

    localValidateScenarioDefinition(Scenario);

end


function ScenarioID = localParseScenarioSelector(ScenarioSelector)

    ScenarioNames = [ ...
        "StraightAndLevelCruise"
        "ControlledClimb"
        "CoordinatedTurn"
        "CombinedManeuver"
        "WindDisturbance"
        "GPSOutageReference"];

    if isnumeric(ScenarioSelector)

        if ~isscalar(ScenarioSelector) || ...
                ~isreal(ScenarioSelector) || ...
                ~isfinite(ScenarioSelector) || ...
                ScenarioSelector ~= floor(ScenarioSelector)

            error( ...
                'ScenarioConfig:InvalidScenarioID', ...
                'Numeric scenario selector must be a finite integer scalar from 1 to 6.');
        end

        ScenarioID = double(ScenarioSelector);

        if ScenarioID < 1 || ScenarioID > 6
            error( ...
                'ScenarioConfig:ScenarioIDOutOfRange', ...
                'Scenario ID must be an integer from 1 to 6.');
        end

        return
    end

    if ~(ischar(ScenarioSelector) || ...
            (isstring(ScenarioSelector) && isscalar(ScenarioSelector)))

        error( ...
            'ScenarioConfig:InvalidScenarioSelector', ...
            ['Scenario selector must be an integer from 1 to 6 or one of: ' ...
             '%s.'], ...
            strjoin(ScenarioNames, ', '));
    end

    ScenarioName = string(ScenarioSelector);

    MatchIndex = find(strcmpi(ScenarioName, ScenarioNames), 1);

    if isempty(MatchIndex)
        error( ...
            'ScenarioConfig:UnknownScenarioName', ...
            ['Unknown scenario "%s". Valid scenario names are: %s.'], ...
            ScenarioName, ...
            strjoin(ScenarioNames, ', '));
    end

    ScenarioID = MatchIndex;

end


function NominalSpeed_mps = localExtractNominalSpeed(Aircraft)

    if ~isobject(Aircraft)
        error( ...
            'ScenarioConfig:InvalidAircraftConfig', ...
            'AircraftConfig must return a valid aircraft configuration object.');
    end

    if ~isprop(Aircraft, 'CruiseSpeed')
        error( ...
            'ScenarioConfig:MissingAircraftCruiseSpeed', ...
            ['AircraftConfig does not contain the required CruiseSpeed ' ...
             'property.']);
    end

    NominalSpeed_mps = Aircraft.CruiseSpeed;

    if ~isnumeric(NominalSpeed_mps) || ...
            ~isreal(NominalSpeed_mps) || ...
            ~isscalar(NominalSpeed_mps) || ...
            ~isfinite(NominalSpeed_mps) || ...
            NominalSpeed_mps <= 0

        error( ...
            'ScenarioConfig:InvalidAircraftCruiseSpeed', ...
            ['AircraftConfig.CruiseSpeed must be a positive finite ' ...
             'real scalar in m/s.']);
    end

    NominalSpeed_mps = double(NominalSpeed_mps);

end


function Value = localGetNestedField(S, FieldPath)

    Value = [];

    CurrentValue = S;

    for k = 1:numel(FieldPath)

        FieldName = FieldPath{k};

        if ~isstruct(CurrentValue) || ...
                ~isfield(CurrentValue, FieldName)

            return
        end

        CurrentValue = CurrentValue.(FieldName);
    end

    Value = CurrentValue;

end


function Controls = localDefaultControlDefinition()

    Controls = struct();

    Controls.TargetAltitude_m = NaN;

    Controls.Stabilization = localEmptyTimeWindow();
    Controls.Cruise = localEmptyTimeWindow();

    Controls.Climb = localEmptyTimeWindow();
    Controls.LevelTransition = localEmptyTimeWindow();
    Controls.LevelStabilization = localEmptyTimeWindow();

    Controls.RollIn = localEmptyTimeWindow();
    Controls.SustainedTurn = localEmptyTimeWindow();
    Controls.RollOut = localEmptyTimeWindow();
    Controls.FinalStabilization = localEmptyTimeWindow();

    Controls.CoordinatedTurn = localEmptyTimeWindow();
    Controls.RollOutAndRecovery = localEmptyTimeWindow();
    Controls.StraightLevelRecovery = localEmptyTimeWindow();

    Controls.CalmBaseline = localEmptyTimeWindow();
    Controls.ConstantWind = localEmptyTimeWindow();
    Controls.GustTransition = localEmptyTimeWindow();
    Controls.Recovery = localEmptyTimeWindow();

    Controls.NormalReference = localEmptyTimeWindow();
    Controls.GPSOutageReference = localEmptyTimeWindow();
    Controls.RecoveryReference = localEmptyTimeWindow();

    Controls.Turn = struct();
    Controls.Turn.Coordinated = false;
    Controls.Turn.Direction = 'None';

end


function Window = localEmptyTimeWindow()

    Window = struct( ...
        'StartTime_s', NaN, ...
        'EndTime_s', NaN);

end


function Window = localTimeWindow(StartTime_s, EndTime_s)

    if ~isscalar(StartTime_s) || ...
            ~isscalar(EndTime_s) || ...
            ~isnumeric(StartTime_s) || ...
            ~isnumeric(EndTime_s) || ...
            ~isfinite(StartTime_s) || ...
            ~isfinite(EndTime_s) || ...
            StartTime_s < 0 || ...
            EndTime_s <= StartTime_s

        error( ...
            'ScenarioConfig:InvalidTimeWindow', ...
            'Time windows must satisfy 0 <= StartTime_s < EndTime_s.');
    end

    Window = struct( ...
        'StartTime_s', double(StartTime_s), ...
        'EndTime_s', double(EndTime_s));

end


function Wind = localCalmWindDefinition()

    Wind = struct();

    Wind.Mode = 'Calm';
    Wind.Frame = 'NED';
    Wind.Units = 'm/s';

    Wind.ConstantNED_mps = [0; 0; 0];

    Wind.Gust = struct();
    Wind.Gust.Enabled = false;
    Wind.Gust.StartTime_s = NaN;
    Wind.Gust.EndTime_s = NaN;
    Wind.Gust.PeakNED_mps = [0; 0; 0];

end


function Wind = localWindDisturbanceDefinition()

    Wind = struct();

    Wind.Mode = 'DeterministicDisturbance';
    Wind.Frame = 'NED';
    Wind.Units = 'm/s';

    % Central deterministic disturbance definition.
    Wind.ConstantNED_mps = [8; 3; 0];

    Wind.Gust = struct();
    Wind.Gust.Enabled = true;
    Wind.Gust.StartTime_s = 180;
    Wind.Gust.EndTime_s = 210;
    Wind.Gust.PeakNED_mps = [12; -4; 1.5];

end


function localValidateScenarioDefinition(Scenario)

    RequiredTopLevelFields = { ...
        'Metadata'
        'Name'
        'ID'
        'Time'
        'SampleRate_Hz'
        'SampleTime_s'
        'Duration_s'
        'InitialCondition'
        'Controls'
        'Wind'
        'Events'};

    for k = 1:numel(RequiredTopLevelFields)

        if ~isfield(Scenario, RequiredTopLevelFields{k})

            error( ...
                'ScenarioConfig:InvalidScenarioStructure', ...
                'Required Scenario field "%s" is missing.', ...
                RequiredTopLevelFields{k});
        end
    end

    if ~isscalar(Scenario.SampleRate_Hz) || ...
            ~isfinite(Scenario.SampleRate_Hz) || ...
            Scenario.SampleRate_Hz <= 0

        error( ...
            'ScenarioConfig:InvalidScenarioSampleRate', ...
            'Scenario.SampleRate_Hz must be a positive finite scalar.');
    end

    ExpectedSampleTime_s = 1 / Scenario.SampleRate_Hz;

    if abs(Scenario.SampleTime_s - ExpectedSampleTime_s) > eps(ExpectedSampleTime_s)

        error( ...
            'ScenarioConfig:SampleTimeMismatch', ...
            ['Scenario.SampleTime_s must equal the reciprocal of ' ...
             'Scenario.SampleRate_Hz.']);
    end

    if ~isscalar(Scenario.Duration_s) || ...
            ~isfinite(Scenario.Duration_s) || ...
            Scenario.Duration_s <= 0

        error( ...
            'ScenarioConfig:InvalidDuration', ...
            'Scenario.Duration_s must be a positive finite scalar.');
    end

    if abs(Scenario.Duration_s / Scenario.SampleTime_s - ...
            round(Scenario.Duration_s / Scenario.SampleTime_s)) > 1e-10

        error( ...
            'ScenarioConfig:DurationSampleTimeMismatch', ...
            ['Scenario duration must be an integer multiple of the ' ...
             'scenario sample time.']);
    end

    InitialCondition = Scenario.InitialCondition;

    RequiredInitialFields = { ...
        'Latitude_rad'
        'Longitude_rad'
        'Altitude_m'
        'Roll_rad'
        'Pitch_rad'
        'Heading_rad'
        'Speed_mps'};

    for k = 1:numel(RequiredInitialFields)

        FieldName = RequiredInitialFields{k};

        if ~isfield(InitialCondition, FieldName)

            error( ...
                'ScenarioConfig:MissingInitialConditionField', ...
                'Initial condition field "%s" is missing.', ...
                FieldName);
        end

        Value = InitialCondition.(FieldName);

        if ~isscalar(Value) || ...
                ~isnumeric(Value) || ...
                ~isreal(Value) || ...
                ~isfinite(Value)

            error( ...
                'ScenarioConfig:InvalidInitialCondition', ...
                'Initial condition field "%s" must be a finite real scalar.', ...
                FieldName);
        end
    end

    if InitialCondition.Altitude_m < 0

        error( ...
            'ScenarioConfig:InvalidInitialAltitude', ...
            'Initial altitude must be greater than or equal to zero.');
    end

    if InitialCondition.Speed_mps <= 0

        error( ...
            'ScenarioConfig:InvalidInitialSpeed', ...
            'Initial speed must be positive.');
    end

    if ~isfield(Scenario.Wind, 'Frame') || ...
            ~strcmp(Scenario.Wind.Frame, 'NED')

        error( ...
            'ScenarioConfig:InvalidWindFrame', ...
            'Scenario wind must explicitly use the NED frame.');
    end

    if ~isfield(Scenario.Wind, 'Units') || ...
            ~strcmp(Scenario.Wind.Units, 'm/s')

        error( ...
            'ScenarioConfig:InvalidWindUnits', ...
            'Scenario wind units must be m/s.');
    end

    if ~isfield(Scenario.Wind, 'ConstantNED_mps') || ...
            ~isnumeric(Scenario.Wind.ConstantNED_mps) || ...
            ~isreal(Scenario.Wind.ConstantNED_mps) || ...
            ~isequal(size(Scenario.Wind.ConstantNED_mps), [3, 1]) || ...
            any(~isfinite(Scenario.Wind.ConstantNED_mps))

        error( ...
            'ScenarioConfig:InvalidWindVector', ...
            'Wind.ConstantNED_mps must be a finite 3-by-1 NED vector in m/s.');
    end

    localValidateEvent( ...
        Scenario.Events.GPSOutage, ...
        Scenario.Duration_s, ...
        'GPSOutage');

    localValidateEvent( ...
        Scenario.Events.WindDisturbance, ...
        Scenario.Duration_s, ...
        'WindDisturbance');

    localValidateEvent( ...
        Scenario.Events.Maneuver, ...
        Scenario.Duration_s, ...
        'Maneuver');

end


function localValidateEvent(Event, Duration_s, EventName)

    RequiredFields = { ...
        'Enabled'
        'StartTime_s'
        'EndTime_s'};

    for k = 1:numel(RequiredFields)

        if ~isfield(Event, RequiredFields{k})

            error( ...
                'ScenarioConfig:InvalidEventStructure', ...
                'Event "%s" is missing required field "%s".', ...
                EventName, ...
                RequiredFields{k});
        end
    end

    if ~(islogical(Event.Enabled) && isscalar(Event.Enabled))

        error( ...
            'ScenarioConfig:InvalidEventEnabledFlag', ...
            'Event "%s" Enabled flag must be a logical scalar.', ...
            EventName);
    end

    if ~Event.Enabled
        return
    end

    if ~isscalar(Event.StartTime_s) || ...
            ~isscalar(Event.EndTime_s) || ...
            ~isnumeric(Event.StartTime_s) || ...
            ~isnumeric(Event.EndTime_s) || ...
            ~isfinite(Event.StartTime_s) || ...
            ~isfinite(Event.EndTime_s)

        error( ...
            'ScenarioConfig:InvalidEventTiming', ...
            'Event "%s" timing values must be finite numeric scalars.', ...
            EventName);
    end

    if Event.StartTime_s < 0 || ...
            Event.EndTime_s <= Event.StartTime_s || ...
            Event.EndTime_s > Duration_s

        error( ...
            'ScenarioConfig:EventTimingOutOfRange', ...
            ['Event "%s" must satisfy 0 <= StartTime_s < EndTime_s ' ...
             '<= Scenario.Duration_s.'], ...
            EventName);
    end

end