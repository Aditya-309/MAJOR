function StateDot = StateDerivatives(State, Controls, Environment, Aircraft)
% STATEDERIVATIVES Compute complete aircraft state derivatives.
%
% Computes the translational, rotational, attitude, and position
% derivatives for the rigid-body aircraft model.
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
%   StateDot
%       .VelocityBody
%       .AngularRatesBody
%       .Quaternion
%       .PositionNED
%       .Translation
%       .Rotation
%

    narginchk(4,4);

    StateDot = runStateDerivatives( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

end

% =========================================================================
%% CORE EXECUTION PIPELINE
% =========================================================================

function StateDot = runStateDerivatives( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% Validate Inputs

    validateStateDerivativeInputs( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Initialize Output

    StateDot = initializeStateDerivativeOutput();

    %% Translational Dynamics

    Translation = dynamics.TranslationalDynamics( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Rotational Dynamics

    Rotation = dynamics.RotationalDynamics( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Position Kinematics

    PositionDerivative = computePositionDerivative( ...
        State);

    %% Quaternion Kinematics

    QuaternionDerivative = computeQuaternionDerivative( ...
        State);

    %% Populate Outputs

    StateDot.VelocityBody = ...
        Translation.BodyAcceleration;

    StateDot.AngularRatesBody = ...
        Rotation.AngularAcceleration;

    StateDot.PositionNED = ...
        PositionDerivative;

    StateDot.Quaternion = ...
        QuaternionDerivative;

    StateDot.Translation = ...
        Translation;

    StateDot.Rotation = ...
        Rotation;

    %% Validate Outputs

    validateStateDerivativeOutput(StateDot);

end
% =========================================================================
%% POSITION KINEMATICS
% =========================================================================

function PositionDerivative = computePositionDerivative(State)

    %% Velocity

    VelocityBody = State.VelocityBody(:);

    %% Attitude

    Roll  = State.EulerAngles(1);
    Pitch = State.EulerAngles(2);
    Yaw   = State.EulerAngles(3);

    %% Body → NED Direction Cosine Matrix

    Cbn = coordinates.Euler2DCM( ...
        Roll,...
        Pitch,...
        Yaw);

    %% Position Rate

    PositionDerivative = ...
        Cbn * VelocityBody;

end

% =========================================================================
%% QUATERNION KINEMATICS
% =========================================================================

function QuaternionDerivative = computeQuaternionDerivative(State)

    %% Determine Quaternion Source

    if isfield(State,'Quaternion')

        Quaternion = State.Quaternion;

    else

        Roll  = State.EulerAngles(1);
        Pitch = State.EulerAngles(2);
        Yaw   = State.EulerAngles(3);

        Quaternion = coordinates.Euler2Quaternion( ...
            Roll,...
            Pitch,...
            Yaw);

    end

    %% Normalize Quaternion

    Quaternion = ...
        coordinates.NormalizeQuaternion(Quaternion);

    %% Angular Rates

    AngularRatesBody = ...
        State.AngularRatesBody(:);

    %% Quaternion Rate

    QuaternionDerivative = ...
        coordinates.QuaternionDerivative( ...
            Quaternion,...
            AngularRatesBody);

end

% =========================================================================
%% INITIALIZATION
% =========================================================================

function StateDot = initializeStateDerivativeOutput()

    StateDot = struct();

    StateDot.VelocityBody = zeros(3,1);

    StateDot.AngularRatesBody = zeros(3,1);

    StateDot.PositionNED = zeros(3,1);

    StateDot.Quaternion = zeros(4,1);

    StateDot.Translation = struct();

    StateDot.Rotation = struct();

end
% =========================================================================
%% INPUT VALIDATION
% =========================================================================

function validateStateDerivativeInputs( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% State

    if ~isstruct(State)

        error( ...
            'StateDerivatives:InvalidState', ...
            'State must be a structure.');

    end

    requiredState = { ...
        'VelocityBody',...
        'AngularRatesBody',...
        'EulerAngles'};

    for k = 1:numel(requiredState)

        if ~isfield(State,requiredState{k})

            error( ...
                'StateDerivatives:MissingStateField', ...
                'Missing State.%s.', ...
                requiredState{k});

        end

    end

    %% Controls

    if ~isstruct(Controls)

        error( ...
            'StateDerivatives:InvalidControls', ...
            'Controls must be a structure.');

    end

    %% Environment

    if ~isstruct(Environment)

        error( ...
            'StateDerivatives:InvalidEnvironment', ...
            'Environment must be a structure.');

    end

    %% Aircraft

    if ~(isa(Aircraft,'config.AircraftConfig') || isstruct(Aircraft))

        error( ...
            'StateDerivatives:InvalidAircraft', ...
            'Aircraft must be config.AircraftConfig or a compatible structure.');

    end

    %% Numerical Validation

    validateattributes( ...
        State.VelocityBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'VelocityBody');

    validateattributes( ...
        State.AngularRatesBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'AngularRatesBody');

    validateattributes( ...
        State.EulerAngles,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'EulerAngles');

end

% =========================================================================
%% OUTPUT VALIDATION
% =========================================================================

function validateStateDerivativeOutput(StateDot)

    requiredFields = { ...
        'VelocityBody',...
        'AngularRatesBody',...
        'PositionNED',...
        'Quaternion',...
        'Translation',...
        'Rotation'};

    for k = 1:numel(requiredFields)

        if ~isfield(StateDot,requiredFields{k})

            error( ...
                'StateDerivatives:MissingOutputField', ...
                'Missing StateDot.%s.', ...
                requiredFields{k});

        end

    end

    validateattributes( ...
        StateDot.VelocityBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'VelocityBody');

    validateattributes( ...
        StateDot.AngularRatesBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'AngularRatesBody');

    validateattributes( ...
        StateDot.PositionNED,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'PositionNED');

    validateattributes( ...
        StateDot.Quaternion,...
        {'numeric'},...
        {'real','finite','numel',4},...
        mfilename,...
        'Quaternion');

    if ~isstruct(StateDot.Translation)

        error( ...
            'StateDerivatives:InvalidTranslation', ...
            'StateDot.Translation must be a structure.');

    end

    if ~isstruct(StateDot.Rotation)

        error( ...
            'StateDerivatives:InvalidRotation', ...
            'StateDot.Rotation must be a structure.');

    end

end
