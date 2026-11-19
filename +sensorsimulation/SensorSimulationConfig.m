function Config = SensorSimulationConfig(varargin)
%SENSORSIMULATIONCONFIG Create the Block 8 sensor-simulation configuration.
%
%   Config = sensorsimulation.SensorSimulationConfig()
%   creates the default Block 8 configuration.
%
%   Config = sensorsimulation.SensorSimulationConfig(Name,Value,...)
%   allows the approved sensor-corruption severity values to be overridden.
%
%   Block 8 owns deterministic sensor-simulation/corruption severity.
%
%   This configuration intentionally does NOT contain:
%       - stochastic noise parameters
%       - stochastic bias parameters
%       - IMU scale-factor parameters
%       - random seeds
%       - sensor-noise realizations
%       - sensor availability/outage state
%       - estimator or trust parameters
%
%   Those responsibilities belong to other project layers.
%
%   Approved Name-Value parameters:
%
%       'GNSSCorruption'
%       'IMUCorruption'
%       'AirspeedCorruption'
%       'MagnetometerCorruption'
%
%   Corruption severity is expressed as a percentage:
%
%       0   = no additional Block 8 corruption
%       100 = maximum configured corruption severity
%
%   Corruption severity does not control the Available field.

    %% Default configuration

    Config = struct();

    Config.Corruption = struct();

    Config.Corruption.GNSS = 0;
    Config.Corruption.IMU = 0;
    Config.Corruption.Airspeed = 0;
    Config.Corruption.Magnetometer = 0;

    %% Apply approved optional overrides

    if mod(nargin, 2) ~= 0

        error( ...
            'ASRTE:SensorSimulationConfig:InvalidNameValueArguments', ...
            'Name-value arguments must be supplied in pairs.');

    end

    for k = 1:2:nargin

        Name = varargin{k};
        Value = varargin{k + 1};

        if ~(ischar(Name) || ...
                (isstring(Name) && isscalar(Name)))

            error( ...
                'ASRTE:SensorSimulationConfig:InvalidParameterName', ...
                ['Parameter names must be character vectors or ', ...
                 'scalar strings.']);

        end

        Name = char(Name);

        switch lower(Name)

            case 'gnsscorruption'

                Config.Corruption.GNSS = Value;

            case 'imucorruption'

                Config.Corruption.IMU = Value;

            case 'airspeedcorruption'

                Config.Corruption.Airspeed = Value;

            case 'magnetometercorruption'

                Config.Corruption.Magnetometer = Value;

            otherwise

                error( ...
                    'ASRTE:SensorSimulationConfig:UnknownParameter', ...
                    'Unknown configuration parameter "%s".', ...
                    Name);

        end

    end

    %% Validate corruption severity

    CorruptionNames = ...
        {'GNSS', 'IMU', 'Airspeed', 'Magnetometer'};

    for k = 1:numel(CorruptionNames)

        SensorName = CorruptionNames{k};

        CorruptionValue = ...
            Config.Corruption.(SensorName);

        if ~isnumeric(CorruptionValue) || ...
                ~isreal(CorruptionValue) || ...
                ~isscalar(CorruptionValue) || ...
                ~isfinite(CorruptionValue) || ...
                CorruptionValue < 0 || ...
                CorruptionValue > 100

            error( ...
                'ASRTE:SensorSimulationConfig:InvalidCorruptionSeverity', ...
                ['%s corruption severity must be a finite ', ...
                 'real scalar in the range 0 to 100 percent.'], ...
                SensorName);

        end

    end

end
