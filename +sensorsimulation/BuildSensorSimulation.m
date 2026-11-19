function RealisticSensorTelemetry = ...
    BuildSensorSimulation(NoisySensorTelemetry, Config)
%BUILDSENSORSIMULATION Build realistic sensor telemetry for Block 8.
%
%   RealisticSensorTelemetry = ...
%       sensorsimulation.BuildSensorSimulation( ...
%           NoisySensorTelemetry, Config)
%
%   Executes the Block 8 sensor-simulation pipeline:
%
%       Post-Block-5 Noisy Sensor Telemetry
%                    |
%                    v
%       ValidateSensorSimulationInput
%                    |
%                    v
%       ApplySensorSimulation
%                    |
%                    v
%       Realistic Sensor Telemetry
%
%   This function is the main execution entry point for Block 8.
%
%   Block 8 does NOT:
%       - generate stochastic sensor noise
%       - regenerate Block 5 noise
%       - modify GroundTruth
%       - generate flight scenarios
%       - perform aircraft dynamics
%       - perform state estimation
%       - perform sensor fusion
%       - implement a trust engine
%       - implement navigation solution
%       - implement persistence
%
%   Input:
%       NoisySensorTelemetry
%           Post-Block-5 sensor telemetry structure containing:
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
%       - Input telemetry is not modified.
%       - Configuration is not modified.
%       - Sensor timelines are not resampled.
%       - Sensor availability is not altered by corruption severity.
%       - All corruption is deterministic.

arguments
    NoisySensorTelemetry (1,1) struct
    Config (1,1) struct
end

%% ============================================================
%  Validate complete Block 8 input boundary
%  ============================================================

sensorsimulation.ValidateSensorSimulationInput( ...
    NoisySensorTelemetry, ...
    Config);

%% ============================================================
%  Apply frozen sensor-specific simulation functions
%  ============================================================

RealisticSensorTelemetry = ...
    sensorsimulation.ApplySensorSimulation( ...
        NoisySensorTelemetry, ...
        Config);

end