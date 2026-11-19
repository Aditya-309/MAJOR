function Loads = ForcesAndMoments(State, Controls, Environment, Aircraft)
% FORCESANDMOMENTS Assemble total aircraft body forces and moments.
%
% Combines all external force and moment producing subsystems into a
% unified body-axis load vector suitable for 6-DOF rigid-body dynamics.
%
% Project:
%   Adaptive Flight State Reconstruction and Trajectory Estimation
%
% MATLAB Version:
%   R2024b
%
% INPUTS:
%   State
%       Aircraft state structure
%
%   Controls
%       Aircraft control input structure
%
%   Environment
%       Atmospheric/environment structure
%
%   Aircraft
%       AircraftConfig object or compatible structure
%
% OUTPUT:
%   Loads
%       .TotalForceBody
%       .TotalMomentBody
%       .Gravity
%       .Aerodynamic
%       .Propulsion
%

    narginchk(4,4);

    Loads = runForcesAndMoments( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

end

% =========================================================================
%% CORE EXECUTION PIPELINE
% =========================================================================

function Loads = runForcesAndMoments( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% Validate Inputs

    validateForcesAndMomentsInputs( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Initialize Output

    Loads = initializeForcesAndMomentsOutput();

    %% Gravity

Roll  = State.EulerAngles(1);
Pitch = State.EulerAngles(2);
Yaw   = State.EulerAngles(3);

DCM = coordinates.Euler2DCM( ...
    Roll,...
    Pitch,...
    Yaw);

Quaternion = coordinates.DCM2Quaternion(DCM);

Gravity = struct();

Gravity.GravityVector = dynamics.GravityModel( ...
    "BODY",...
    Quaternion);

Gravity.ForceBody = ...
    Aircraft.ReferenceMass * Gravity.GravityVector;

Gravity.MomentBody = zeros(3,1);

    %% Aerodynamic Forces

    Aerodynamic = dynamics.AerodynamicForces( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Aerodynamic Moments

    AeroMoments = dynamics.AerodynamicMoments( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Propulsion

    Propulsion = dynamics.PropulsionModel( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Assemble Total Loads

    Loads = assembleForcesAndMoments( ...
        Loads,...
        Gravity,...
        Aerodynamic,...
        AeroMoments,...
        Propulsion);

    %% Validate Outputs

    validateForcesAndMomentsOutput(Loads);

end

% =========================================================================
%% LOAD ASSEMBLY
% =========================================================================

function Loads = assembleForcesAndMoments( ...
    Loads,...
    Gravity,...
    Aerodynamic,...
    AeroMoments,...
    Propulsion)

    %% Total Forces

    Loads.TotalForceBody = ...
          Gravity.ForceBody ...
        + Aerodynamic.ForceBody ...
        + Propulsion.ForceBody;

    %% Total Moments

    Loads.TotalMomentBody = ...
          AeroMoments.MomentBody ...
        + Propulsion.MomentBody;

    %% Store Individual Contributions

    Loads.Gravity = Gravity;

    Loads.Aerodynamic = Aerodynamic;

    Loads.AerodynamicMoments = AeroMoments;

    Loads.Propulsion = Propulsion;

end
% =========================================================================
%% INITIALIZATION
% =========================================================================

function Loads = initializeForcesAndMomentsOutput()

    Loads = struct();

    Loads.TotalForceBody = zeros(3,1);

    Loads.TotalMomentBody = zeros(3,1);

    Loads.Gravity = struct();

    Loads.Aerodynamic = struct();

    Loads.AerodynamicMoments = struct();

    Loads.Propulsion = struct();

end

% =========================================================================
%% INPUT VALIDATION
% =========================================================================

function validateForcesAndMomentsInputs( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% State Structure

    if ~isstruct(State)

        error( ...
            'ForcesAndMoments:InvalidState', ...
            'State must be a structure.');

    end

    %% Controls Structure

    if ~isstruct(Controls)

        error( ...
            'ForcesAndMoments:InvalidControls', ...
            'Controls must be a structure.');

    end

    %% Environment Structure

    if ~isstruct(Environment)

        error( ...
            'ForcesAndMoments:InvalidEnvironment', ...
            'Environment must be a structure.');

    end

    %% Aircraft Object

    if ~(isstruct(Aircraft) || isa(Aircraft,'config.AircraftConfig'))

        error( ...
            'ForcesAndMoments:InvalidAircraft', ...
            'Aircraft must be a config.AircraftConfig object or compatible structure.');

    end

    %% Required State Fields

    requiredState = { ...
        'VelocityBody',...
        'AngularRatesBody',...
        'EulerAngles'};

    for k = 1:numel(requiredState)

        if ~isfield(State,requiredState{k})

            error( ...
                'ForcesAndMoments:MissingStateField', ...
                'Missing State.%s.', ...
                requiredState{k});

        end

    end

    %% Required Control Fields

    requiredControls = { ...
        'Throttle',...
        'Aileron',...
        'Elevator',...
        'Rudder'};

    for k = 1:numel(requiredControls)

        if ~isfield(Controls,requiredControls{k})

            error( ...
                'ForcesAndMoments:MissingControlField', ...
                'Missing Controls.%s.', ...
                requiredControls{k});

        end

    end

    %% Required Environment Fields

    requiredEnvironment = { ...
        'AirDensity',...
        'WindBody'};

    for k = 1:numel(requiredEnvironment)

        if ~isfield(Environment,requiredEnvironment{k})

            error( ...
                'ForcesAndMoments:MissingEnvironmentField', ...
                'Missing Environment.%s.', ...
                requiredEnvironment{k});

        end

    end

end
% =========================================================================
%% OUTPUT VALIDATION
% =========================================================================

function validateForcesAndMomentsOutput(Loads)

    %% Force Vector

    if ~isfield(Loads,'TotalForceBody')

        error( ...
            'ForcesAndMoments:MissingForceBody', ...
            'TotalForceBody was not generated.');

    end

    if numel(Loads.TotalForceBody) ~= 3

        error( ...
            'ForcesAndMoments:InvalidForceBody', ...
            'TotalForceBody must be a 3-element vector.');

    end

    if any(~isfinite(Loads.TotalForceBody))

        error( ...
            'ForcesAndMoments:NonFiniteForceBody', ...
            'TotalForceBody contains NaN or Inf.');

    end

    %% Moment Vector

    if ~isfield(Loads,'TotalMomentBody')

        error( ...
            'ForcesAndMoments:MissingMomentBody', ...
            'TotalMomentBody was not generated.');

    end

    if numel(Loads.TotalMomentBody) ~= 3

        error( ...
            'ForcesAndMoments:InvalidMomentBody', ...
            'TotalMomentBody must be a 3-element vector.');

    end

    if any(~isfinite(Loads.TotalMomentBody))

        error( ...
            'ForcesAndMoments:NonFiniteMomentBody', ...
            'TotalMomentBody contains NaN or Inf.');

    end

    %% Required Structures

    requiredStructures = { ...
        'Gravity',...
        'Aerodynamic',...
        'AerodynamicMoments',...
        'Propulsion'};

    for k = 1:numel(requiredStructures)

        if ~isfield(Loads,requiredStructures{k})

            error( ...
                'ForcesAndMoments:MissingStructure', ...
                'Loads.%s was not generated.', ...
                requiredStructures{k});

        end

    end

end

% =========================================================================
%% UTILITY FUNCTIONS
% =========================================================================

