function InitFile = BuildJSBSimInitialization( ...
    RunConfig, ...
    Scenario)
%BUILDJSBSIMINITIALIZATION Build the JSBSim initialization XML file.
%
%   InitFile = BuildJSBSimInitialization(RunConfig, Scenario)
%
%   Generates the Block 7 JSBSim initialization artifact using the frozen
%   Block 6 initial-condition interface.
%
%   Frozen Block 6 inputs used:
%       Scenario.InitialCondition.Speed_mps
%       Scenario.InitialCondition.Altitude_m
%
%   JSBSim uses native imperial units in the generated initialization file.
%   SI-to-imperial conversion is performed explicitly here.

    %% Input Validation

    if nargin ~= 2
        error( ...
            'Block7:BuildJSBSimInitialization:InvalidInputCount', ...
            ['BuildJSBSimInitialization requires exactly two inputs: ' ...
             'RunConfig and Scenario.']);
    end

    if ~isstruct(RunConfig) || ~isscalar(RunConfig)
        error( ...
            'Block7:BuildJSBSimInitialization:InvalidRunConfig', ...
            'RunConfig must be a scalar structure.');
    end

    if ~isstruct(Scenario) || ~isscalar(Scenario)
        error( ...
            'Block7:BuildJSBSimInitialization:InvalidScenario', ...
            'Scenario must be a scalar structure.');
    end

    if ~isfield(RunConfig, 'InitFile') || ...
            isempty(RunConfig.InitFile)

        error( ...
            'Block7:BuildJSBSimInitialization:MissingInitFile', ...
            'RunConfig.InitFile is required.');
    end

    if ~isfield(Scenario, 'InitialCondition') || ...
            ~isstruct(Scenario.InitialCondition) || ...
            ~isscalar(Scenario.InitialCondition)

        error( ...
            'Block7:BuildJSBSimInitialization:MissingInitialCondition', ...
            'Scenario.InitialCondition must be a scalar structure.');
    end

    InitialCondition = Scenario.InitialCondition;

    if ~isfield(InitialCondition, 'Speed_mps') || ...
            ~isscalar(InitialCondition.Speed_mps) || ...
            ~isfinite(InitialCondition.Speed_mps) || ...
            InitialCondition.Speed_mps < 0

        error( ...
            'Block7:BuildJSBSimInitialization:InvalidSpeed', ...
            ['Scenario.InitialCondition.Speed_mps must be a finite ' ...
             'non-negative scalar.']);
    end

    if ~isfield(InitialCondition, 'Altitude_m') || ...
            ~isscalar(InitialCondition.Altitude_m) || ...
            ~isfinite(InitialCondition.Altitude_m)

        error( ...
            'Block7:BuildJSBSimInitialization:InvalidAltitude', ...
            ['Scenario.InitialCondition.Altitude_m must be a finite ' ...
             'scalar.']);
    end

    %% Resolve Output Path

    InitFile = char(RunConfig.InitFile);

    [InitDirectory, ~, ~] = fileparts(InitFile);

    if isempty(InitDirectory)
        error( ...
            'Block7:BuildJSBSimInitialization:InvalidInitPath', ...
            'RunConfig.InitFile must include a valid directory path.');
    end

    if ~isfolder(InitDirectory)
        mkdir(InitDirectory);
    end

    %% Unit Conversion

    MeterToFoot = 3.280839895013123;
    MeterPerSecondToFootPerSecond = MeterToFoot;

    Altitude_ft = ...
        InitialCondition.Altitude_m * MeterToFoot;

    Speed_fps = ...
        InitialCondition.Speed_mps * ...
        MeterPerSecondToFootPerSecond;

    %% Build JSBSim Initialization XML

    XMLLines = {
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<initialize name="Block7InitialCondition">'
        '  <description>'
        '    Block 7 generated initialization condition.'
        '  </description>'
        ''
        sprintf('  <property value="%.15g">ic/h-sl-ft</property>', ...
            Altitude_ft)
        sprintf('  <property value="%.15g">ic/vt-fps</property>', ...
            Speed_fps)
        ''
        '</initialize>'
        };

    %% Write File

    FileID = fopen( ...
        InitFile, ...
        'w');

    if FileID == -1
        error( ...
            'Block7:BuildJSBSimInitialization:FileOpenFailed', ...
            'Unable to open initialization file for writing: %s', ...
            InitFile);
    end

    CleanupObject = onCleanup(@() fclose(FileID));

    for LineIndex = 1:numel(XMLLines)

        fprintf( ...
            FileID, ...
            '%s\n', ...
            XMLLines{LineIndex});

    end

    clear CleanupObject;

    %% Final Verification

    if ~isfile(InitFile)
        error( ...
            'Block7:BuildJSBSimInitialization:FileCreationFailed', ...
            'Initialization file was not created successfully.');
    end

end