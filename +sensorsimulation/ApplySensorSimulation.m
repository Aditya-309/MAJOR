function RealisticSensorTelemetry = ...
    ApplySensorSimulation(NoisySensorTelemetry, Config)
%APPLYSENSORSIMULATION Apply Block 8 sensor simulation to all sensors.
%
%   RealisticSensorTelemetry = ...
%       sensorsimulation.ApplySensorSimulation( ...
%           NoisySensorTelemetry, Config)
%
%   Applies the frozen Block 8 sensor-specific simulation functions:
%
%       SimulateGNSS
%       SimulateIMU
%       SimulateAirspeed
%       SimulateMagnetometer
%
%   to the corresponding post-Block-5 sensor telemetry branches.
%
%   This function is an orchestration layer only. It does not:
%       - generate stochastic noise
%       - regenerate Block 5 noise
%       - modify GroundTruth
%       - generate scenarios
%       - perform state estimation
%       - perform sensor fusion
%       - implement sensor trust
%       - implement outages or dropouts
%
%   Input:
%       NoisySensorTelemetry
%           Structure containing:
%               GNSS
%               IMU
%               AirData
%               Magnetometer
%
%       Config
%           Scalar structure returned by
%           sensorsimulation.SensorSimulationConfig.
%
%   Output:
%       RealisticSensorTelemetry
%           Structure containing:
%               GNSS
%               IMU
%               AirData
%               Magnetometer
%
%   Notes:
%       - Corruption severity is read only from Config.Corruption.
%       - Each sensor branch is processed independently.
%       - Input telemetry is not modified.

arguments
    NoisySensorTelemetry (1,1) struct
    Config (1,1) struct
end

%% Validate required top-level telemetry branches

RequiredBranches = { ...
    'GNSS', ...
    'IMU', ...
    'AirData', ...
    'Magnetometer'};

for k = 1:numel(RequiredBranches)

    BranchName = RequiredBranches{k};

    if ~isfield(NoisySensorTelemetry, BranchName)
        error( ...
            "sensorsimulation:MissingTelemetryBranch", ...
            "NoisySensorTelemetry is missing required branch '%s'.", ...
            BranchName);
    end

    if ~isstruct(NoisySensorTelemetry.(BranchName))
        error( ...
            "sensorsimulation:InvalidTelemetryBranch", ...
            "Telemetry branch '%s' must be a structure.", ...
            BranchName);
    end
end

%% Validate required corruption configuration

if ~isfield(Config,'Corruption')
    error( ...
        "sensorsimulation:MissingCorruptionConfig", ...
        "Config is missing the required 'Corruption' field.");
end

if ~isstruct(Config.Corruption)
    error( ...
        "sensorsimulation:InvalidCorruptionConfig", ...
        "Config.Corruption must be a structure.");
end

RequiredCorruptionFields = { ...
    'GNSS', ...
    'IMU', ...
    'Airspeed', ...
    'Magnetometer'};

for k = 1:numel(RequiredCorruptionFields)

    SensorName = RequiredCorruptionFields{k};

    if ~isfield(Config.Corruption,SensorName)
        error( ...
            "sensorsimulation:MissingCorruptionSeverity", ...
            "Config.Corruption is missing '%s'.", ...
            SensorName);
    end

    Severity = Config.Corruption.(SensorName);

    if ~isnumeric(Severity) || ...
            ~isscalar(Severity) || ...
            ~isreal(Severity) || ...
            ~isfinite(Severity) || ...
            Severity < 0 || ...
            Severity > 100

        error( ...
            "sensorsimulation:InvalidCorruptionSeverity", ...
            "Config.Corruption.%s must be a finite real scalar in [0,100].", ...
            SensorName);
    end
end

%% Read corruption configuration

GNSSSeverity = Config.Corruption.GNSS;
IMUSeverity = Config.Corruption.IMU;
AirspeedSeverity = Config.Corruption.Airspeed;
MagnetometerSeverity = Config.Corruption.Magnetometer;

%% Apply sensor-specific deterministic simulation

RealisticSensorTelemetry = struct();

RealisticSensorTelemetry.GNSS = ...
    sensorsimulation.SimulateGNSS( ...
        NoisySensorTelemetry.GNSS, ...
        GNSSSeverity);

RealisticSensorTelemetry.IMU = ...
    sensorsimulation.SimulateIMU( ...
        NoisySensorTelemetry.IMU, ...
        IMUSeverity);

RealisticSensorTelemetry.AirData = ...
    sensorsimulation.SimulateAirspeed( ...
        NoisySensorTelemetry.AirData, ...
        AirspeedSeverity);

RealisticSensorTelemetry.Magnetometer = ...
    sensorsimulation.SimulateMagnetometer( ...
        NoisySensorTelemetry.Magnetometer, ...
        MagnetometerSeverity);

end