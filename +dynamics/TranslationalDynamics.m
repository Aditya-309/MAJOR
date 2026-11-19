function Translation = TranslationalDynamics(State, Controls, Environment, Aircraft)
% TRANSLATIONALDYNAMICS Compute rigid-body translational dynamics.
%
% Computes body-axis translational accelerations using Newton's Second Law.
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
%   Translation
%       .BodyAcceleration
%       .LinearAcceleration
%       .CoriolisAcceleration
%       .Loads
%

    narginchk(4,4);

    Translation = runTranslationalDynamics( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

end

% =========================================================================
%% CORE EXECUTION PIPELINE
% =========================================================================

function Translation = runTranslationalDynamics( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% Validate Inputs

    validateTranslationalInputs( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Initialize Output

    Translation = initializeTranslationalOutput();

    %% External Loads

    Loads = dynamics.ForcesAndMoments( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    %% Aircraft Parameters

    Parameters = extractTranslationalParameters(Aircraft);

    %% Linear Acceleration

    LinearAcceleration = computeLinearAcceleration( ...
        Loads.TotalForceBody,...
        Parameters.ReferenceMass);

    %% Coriolis Acceleration

    CoriolisAcceleration = computeCoriolisAcceleration( ...
        State.VelocityBody,...
        State.AngularRatesBody);

    %% Total Body Acceleration

    BodyAcceleration = computeBodyAcceleration( ...
        LinearAcceleration,...
        CoriolisAcceleration);

    %% Populate Outputs

    Translation.BodyAcceleration      = BodyAcceleration;

    Translation.LinearAcceleration    = LinearAcceleration;

    Translation.CoriolisAcceleration  = CoriolisAcceleration;

    Translation.Loads                 = Loads;

    %% Validate Outputs

    validateTranslationalOutput(Translation);

end

% =========================================================================
%% PARAMETER EXTRACTION
% =========================================================================

function Parameters = extractTranslationalParameters(Aircraft)

    Parameters = struct();

    Parameters.ReferenceMass = Aircraft.ReferenceMass;

end

% =========================================================================
%% LINEAR ACCELERATION
% =========================================================================

function LinearAcceleration = computeLinearAcceleration( ...
    TotalForceBody,...
    ReferenceMass)

    ReferenceMass = max(ReferenceMass,eps);

    LinearAcceleration = ...
        TotalForceBody ./ ReferenceMass;

end
% =========================================================================
%% BODY ACCELERATION
% =========================================================================

function BodyAcceleration = computeBodyAcceleration( ...
    LinearAcceleration,...
    CoriolisAcceleration)

    BodyAcceleration = ...
        LinearAcceleration ...
      - CoriolisAcceleration;

end

% =========================================================================
%% CORIOLIS ACCELERATION
% =========================================================================

function CoriolisAcceleration = computeCoriolisAcceleration( ...
    VelocityBody,...
    AngularRatesBody)

    VelocityBody = VelocityBody(:);

    AngularRatesBody = AngularRatesBody(:);

    CoriolisAcceleration = ...
        cross(AngularRatesBody,VelocityBody);

end

% =========================================================================
%% INITIALIZATION
% =========================================================================

function Translation = initializeTranslationalOutput()

    Translation = struct();

    Translation.BodyAcceleration = zeros(3,1);

    Translation.LinearAcceleration = zeros(3,1);

    Translation.CoriolisAcceleration = zeros(3,1);

    Translation.Loads = struct();

end

% =========================================================================
%% INPUT VALIDATION
% =========================================================================

function validateTranslationalInputs( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% State

    if ~isstruct(State)

        error( ...
            'TranslationalDynamics:InvalidState', ...
            'State must be a structure.');

    end

    requiredState = { ...
        'VelocityBody',...
        'AngularRatesBody',...
        'EulerAngles'};

    for k = 1:numel(requiredState)

        if ~isfield(State,requiredState{k})

            error( ...
                'TranslationalDynamics:MissingStateField', ...
                'Missing State.%s.', ...
                requiredState{k});

        end

    end

    %% Controls

    if ~isstruct(Controls)

        error( ...
            'TranslationalDynamics:InvalidControls', ...
            'Controls must be a structure.');

    end

    %% Environment

    if ~isstruct(Environment)

        error( ...
            'TranslationalDynamics:InvalidEnvironment', ...
            'Environment must be a structure.');

    end

    %% Aircraft

    if ~(isa(Aircraft,'config.AircraftConfig') || isstruct(Aircraft))

        error( ...
            'TranslationalDynamics:InvalidAircraft', ...
            'Aircraft must be config.AircraftConfig or a compatible structure.');

    end

    %% Numerical Validation

    validateattributes( ...
        State.VelocityBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]});

    validateattributes( ...
        State.AngularRatesBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]});

end
% =========================================================================
%% OUTPUT VALIDATION
% =========================================================================

function validateTranslationalOutput(Translation)

    %% Required Fields

    requiredFields = { ...
        'BodyAcceleration',...
        'LinearAcceleration',...
        'CoriolisAcceleration',...
        'Loads'};

    for k = 1:numel(requiredFields)

        if ~isfield(Translation,requiredFields{k})

            error( ...
                'TranslationalDynamics:MissingOutputField', ...
                'Missing Translation.%s.', ...
                requiredFields{k});

        end

    end

    %% Body Acceleration

    validateattributes( ...
        Translation.BodyAcceleration,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'BodyAcceleration');

    %% Linear Acceleration

    validateattributes( ...
        Translation.LinearAcceleration,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'LinearAcceleration');

    %% Coriolis Acceleration

    validateattributes( ...
        Translation.CoriolisAcceleration,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'CoriolisAcceleration');

    %% Loads Structure

    if ~isstruct(Translation.Loads)

        error( ...
            'TranslationalDynamics:InvalidLoads', ...
            'Translation.Loads must be a structure.');

    end

end

% =========================================================================
%% UTILITY FUNCTIONS
% =========================================================================
