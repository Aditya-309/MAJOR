function Rotation = RotationalDynamics(State, Controls, Environment, Aircraft)
% ROTATIONALDYNAMICS Compute rigid-body rotational dynamics.
%
% Computes body-axis angular accelerations using Euler's rotational
% equations of motion.
%
% Project:
%   Adaptive Flight State Reconstruction and Trajectory Estimation
%
% MATLAB Version:
%   R2024b
%
% INPUTS
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
% OUTPUT
%   Rotation
%       .AngularAcceleration
%       .GyroscopicMoment
%       .AppliedMoment
%       .Loads
%

    narginchk(4,4);

    Rotation = runRotationalDynamics( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

end

% =========================================================================
%% CORE EXECUTION PIPELINE
% =========================================================================

function Rotation = runRotationalDynamics( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% Validate Inputs

    validateRotationalInputs( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Initialize Output

    Rotation = initializeRotationalOutput();

    %% External Loads

    Loads = dynamics.ForcesAndMoments( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Aircraft Inertia

    Parameters = extractRotationalParameters(Aircraft);

    %% Gyroscopic Moment

    GyroscopicMoment = computeGyroscopicMoment( ...
        State.AngularRatesBody,...
        Parameters.InertiaMatrix);

    %% Angular Acceleration

    AngularAcceleration = computeAngularAcceleration( ...
        Loads.TotalMomentBody,...
        GyroscopicMoment,...
        Parameters.InertiaMatrix);

    %% Populate Outputs

    Rotation.AngularAcceleration = AngularAcceleration;

    Rotation.GyroscopicMoment = GyroscopicMoment;

    Rotation.AppliedMoment = Loads.TotalMomentBody;

    Rotation.Loads = Loads;

    %% Validate Outputs

    validateRotationalOutput(Rotation);

end

% =========================================================================
%% PARAMETER EXTRACTION
% =========================================================================

function Parameters = extractRotationalParameters(Aircraft)

    Parameters = struct();

    Parameters.InertiaMatrix = ...
        [
            Aircraft.Ix   0            -Aircraft.Ixz
            0             Aircraft.Iy   0
           -Aircraft.Ixz  0             Aircraft.Iz
        ];

end
% =========================================================================
%% GYROSCOPIC MOMENT
% =========================================================================

function GyroscopicMoment = computeGyroscopicMoment( ...
    AngularRatesBody,...
    InertiaMatrix)

    %% Ensure Column Vector

    AngularRatesBody = AngularRatesBody(:);

    %% Angular Momentum

    AngularMomentum = ...
        InertiaMatrix * AngularRatesBody;

    %% Gyroscopic Coupling

    GyroscopicMoment = ...
        cross(AngularRatesBody,...
              AngularMomentum);

end

% =========================================================================
%% ANGULAR ACCELERATION
% =========================================================================

function AngularAcceleration = computeAngularAcceleration( ...
    AppliedMoment,...
    GyroscopicMoment,...
    InertiaMatrix)

    %% Effective Moment

    NetMoment = ...
        AppliedMoment ...
      - GyroscopicMoment;

    %% Euler's Rotational Equation

    AngularAcceleration = ...
        InertiaMatrix \ NetMoment;

end

% =========================================================================
%% INITIALIZATION
% =========================================================================

function Rotation = initializeRotationalOutput()

    Rotation = struct();

    Rotation.AngularAcceleration = zeros(3,1);

    Rotation.GyroscopicMoment = zeros(3,1);

    Rotation.AppliedMoment = zeros(3,1);

    Rotation.Loads = struct();

end
% =========================================================================
%% INPUT VALIDATION
% =========================================================================

function validateRotationalInputs( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% State

    if ~isstruct(State)

        error( ...
            'RotationalDynamics:InvalidState', ...
            'State must be a structure.');

    end

    requiredState = { ...
        'AngularRatesBody',...
        'VelocityBody',...
        'EulerAngles'};

    for k = 1:numel(requiredState)

        if ~isfield(State,requiredState{k})

            error( ...
                'RotationalDynamics:MissingStateField', ...
                'Missing State.%s.', ...
                requiredState{k});

        end

    end

    %% Controls

    if ~isstruct(Controls)

        error( ...
            'RotationalDynamics:InvalidControls', ...
            'Controls must be a structure.');

    end

    %% Environment

    if ~isstruct(Environment)

        error( ...
            'RotationalDynamics:InvalidEnvironment', ...
            'Environment must be a structure.');

    end

    %% Aircraft

    if ~(isa(Aircraft,'config.AircraftConfig') || isstruct(Aircraft))

        error( ...
            'RotationalDynamics:InvalidAircraft', ...
            'Aircraft must be config.AircraftConfig or a compatible structure.');

    end

    %% Numerical Validation

    validateattributes( ...
        State.AngularRatesBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'AngularRatesBody');

    validateattributes( ...
        State.VelocityBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'VelocityBody');

end

% =========================================================================
%% OUTPUT VALIDATION
% =========================================================================

function validateRotationalOutput(Rotation)

    requiredFields = { ...
        'AngularAcceleration',...
        'GyroscopicMoment',...
        'AppliedMoment',...
        'Loads'};

    for k = 1:numel(requiredFields)

        if ~isfield(Rotation,requiredFields{k})

            error( ...
                'RotationalDynamics:MissingOutputField', ...
                'Missing Rotation.%s.', ...
                requiredFields{k});

        end

    end

    validateattributes( ...
        Rotation.AngularAcceleration,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'AngularAcceleration');

    validateattributes( ...
        Rotation.GyroscopicMoment,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'GyroscopicMoment');

    validateattributes( ...
        Rotation.AppliedMoment,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'AppliedMoment');

    if ~isstruct(Rotation.Loads)

        error( ...
            'RotationalDynamics:InvalidLoads', ...
            'Rotation.Loads must be a structure.');

    end

end
