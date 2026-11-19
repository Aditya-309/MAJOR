function OutputFile = BuildJSBSimOutput(RunConfig)
%BUILDJSBSIMOUTPUT Build the JSBSim ground-truth telemetry output XML.
%
%   OutputFile = BuildJSBSimOutput(RunConfig)

    %% Input Validation

    if nargin ~= 1
        error( ...
            'Block7:BuildJSBSimOutput:InvalidInputCount', ...
            'BuildJSBSimOutput requires exactly one input: RunConfig.');
    end

    if ~isstruct(RunConfig) || ~isscalar(RunConfig)
        error( ...
            'Block7:BuildJSBSimOutput:InvalidRunConfig', ...
            'RunConfig must be a scalar structure.');
    end

    RequiredFields = { ...
        'OutputFile', ...
        'TelemetryFile', ...
        'SampleTime_s'};

    for FieldIndex = 1:numel(RequiredFields)

        FieldName = RequiredFields{FieldIndex};

        if ~isfield(RunConfig, FieldName) || ...
                isempty(RunConfig.(FieldName))

            error( ...
                'Block7:BuildJSBSimOutput:MissingRunConfigField', ...
                'RunConfig.%s is required.', ...
                FieldName);
        end

    end

    if ~isscalar(RunConfig.SampleTime_s) || ...
            ~isnumeric(RunConfig.SampleTime_s) || ...
            ~isfinite(RunConfig.SampleTime_s) || ...
            RunConfig.SampleTime_s <= 0

        error( ...
            'Block7:BuildJSBSimOutput:InvalidSampleTime', ...
            'RunConfig.SampleTime_s must be a positive finite scalar.');
    end

    %% Resolve Paths

    OutputFile = char(RunConfig.OutputFile);
    TelemetryFile = char(RunConfig.TelemetryFile);

    [OutputDirectory, ~, ~] = ...
        fileparts(OutputFile);

    if isempty(OutputDirectory)
        error( ...
            'Block7:BuildJSBSimOutput:InvalidOutputPath', ...
            'RunConfig.OutputFile must include a directory path.');
    end

    if ~isfolder(OutputDirectory)
        mkdir(OutputDirectory);
    end

    [TelemetryDirectory, ...
     TelemetryName, ...
     TelemetryExtension] = ...
        fileparts(TelemetryFile);

    if isempty(TelemetryDirectory)
        error( ...
            'Block7:BuildJSBSimOutput:InvalidTelemetryPath', ...
            'RunConfig.TelemetryFile must include a directory path.');
    end

    if ~strcmpi(TelemetryExtension, '.csv')
        error( ...
            'Block7:BuildJSBSimOutput:InvalidTelemetryExtension', ...
            'RunConfig.TelemetryFile must use the .csv extension.');
    end

    if ~isfolder(TelemetryDirectory)
        mkdir(TelemetryDirectory);
    end

    %% Use Filename Only

    TelemetryReference = ...
        [TelemetryName TelemetryExtension];

    %% Output Rate

    OutputRate_Hz = ...
        1 / RunConfig.SampleTime_s;

    if ~isfinite(OutputRate_Hz) || ...
            OutputRate_Hz <= 0

        error( ...
            'Block7:BuildJSBSimOutput:InvalidOutputRate', ...
            'Derived JSBSim output rate must be positive and finite.');
    end

    %% Property List

    PropertyList = { ...
        'simulation/sim-time-sec'
        'position/lat-geod-deg'
        'position/long-gc-deg'
        'position/h-sl-ft'
        'velocities/u-fps'
        'velocities/v-fps'
        'velocities/w-fps'
        'velocities/p-rad_sec'
        'velocities/q-rad_sec'
        'velocities/r-rad_sec'
        'attitude/phi-rad'
        'attitude/theta-rad'
        'attitude/psi-rad'
        'atmosphere/rho-slugs_ft3'
        };

    %% Build XML

    XMLLines = {
        '<?xml version="1.0" encoding="UTF-8"?>'
        sprintf( ...
            '<output name="%s" type="CSV" rate="%.15g">', ...
            TelemetryReference, ...
            OutputRate_Hz)
        '  <description>'
        '    Block 7 generated raw ground-truth telemetry output.'
        '  </description>'
        };

    for PropertyIndex = 1:numel(PropertyList)

        XMLLines{end + 1, 1} = ...
            sprintf( ...
                '  <property>%s</property>', ...
                PropertyList{PropertyIndex});

    end

    XMLLines{end + 1, 1} = ...
        '</output>';

    %% Write XML

    FileID = fopen(OutputFile, 'w');

    if FileID == -1
        error( ...
            'Block7:BuildJSBSimOutput:FileOpenFailed', ...
            'Unable to open output file for writing: %s', ...
            OutputFile);
    end

    CleanupObject = ...
        onCleanup(@() fclose(FileID));

    for LineIndex = 1:numel(XMLLines)

        fprintf( ...
            FileID, ...
            '%s\n', ...
            XMLLines{LineIndex});

    end

    clear CleanupObject;

    %% Verify

    if ~isfile(OutputFile)

        error( ...
            'Block7:BuildJSBSimOutput:FileCreationFailed', ...
            'JSBSim output definition file was not created successfully.');

    end

end