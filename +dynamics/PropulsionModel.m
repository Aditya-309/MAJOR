function Propulsion = PropulsionModel(State, Controls, Environment, Aircraft)
% PROPULSIONMODEL Compute propulsion forces and moments for the Cessna 172P.
%
% Computes engine power, propeller operating state, thrust, torque,
% body-axis propulsion forces, and propulsion moments using a modular
% engineering model suitable for real-time simulation.
%
% Project:
%   Adaptive Flight State Reconstruction and Trajectory Estimation
%
% MATLAB Version:
%   R2024b
%
% INPUTS:
%   State
%       .VelocityBody         [3x1] m/s
%
%   Controls
%       .Throttle             [0-1]
%
%   Environment
%       .AirDensity           kg/m^3
%
%   Aircraft
%       AircraftConfig object
%       or compatible structure
%
% OUTPUT:
%   Propulsion
%       .ForceBody
%       .MomentBody
%       .Thrust
%       .EngineRPM
%       .PropellerRPM
%       .ShaftPower
%       .PropellerTorque
%       .AdvanceRatio
%       .PropellerEfficiency
%       .Structures
%

    narginchk(4,4);

    Propulsion = runPropulsionModel( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

end

% =========================================================================
%% CORE EXECUTION PIPELINE
% =========================================================================

function Propulsion = runPropulsionModel( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% Validate Inputs

    validatePropulsionInputs( ...
        State,...
        Controls,...
        Environment,...
        Aircraft);

    Aircraft = validatePropulsionConfiguration(Aircraft);

    %% Initialize Output

    Propulsion = initializePropulsionOutput();

    %% Aircraft Parameters

    Parameters = extractPropulsionParameters(Aircraft);

    %% Airspeed

    Airspeed = computeAirspeed(State);

    %% Engine Operating Point

    Engine = computeEngineState( ...
        Controls.Throttle,...
        Parameters);

    %% Propeller Operating Point

    Propeller = computePropellerState( ...
        Airspeed,...
        Engine,...
        Environment,...
        Parameters);

    %% Force and Moment Generation

    Loads = computePropulsionLoads( ...
        Propeller,...
        Parameters);
    validatePropulsionOutput(struct( ...
    'ForceBody',Loads.ForceBody,...
    'MomentBody',Loads.MomentBody,...
    'Thrust',Propeller.Thrust,...
    'EngineRPM',Engine.EngineRPM,...
    'PropellerRPM',Engine.PropellerRPM,...
    'ShaftPower',Engine.ShaftPower,...
    'PropellerTorque',Propeller.PropellerTorque,...
    'AdvanceRatio',Propeller.AdvanceRatio,...
    'PropellerEfficiency',Propeller.PropellerEfficiency));

    %% Populate Outputs

    Propulsion.ForceBody           = Loads.ForceBody;
    Propulsion.MomentBody          = Loads.MomentBody;

    Propulsion.Thrust              = Propeller.Thrust;

    Propulsion.EngineRPM           = Engine.EngineRPM;
    Propulsion.PropellerRPM        = Engine.PropellerRPM;

    Propulsion.ShaftPower          = Engine.ShaftPower;
    Propulsion.PropellerTorque     = Propeller.PropellerTorque;

    Propulsion.AdvanceRatio        = Propeller.AdvanceRatio;
    Propulsion.PropellerEfficiency = Propeller.PropellerEfficiency;

    Propulsion.Structures.Engine      = Engine;
    Propulsion.Structures.Propeller   = Propeller;
    Propulsion.Structures.Parameters  = Parameters;

end

% =========================================================================
%% PARAMETER EXTRACTION
% =========================================================================

function Parameters = extractPropulsionParameters(Aircraft)

    Parameters.EnginePower       = Aircraft.EnginePower;
    Parameters.IdleRPM           = Aircraft.IdleRPM;
    Parameters.MaximumRPM        = Aircraft.MaximumRPM;

    Parameters.MinimumThrottle   = Aircraft.MinimumThrottle;
    Parameters.MaximumThrottle   = Aircraft.MaximumThrottle;

    Parameters.PropellerDiameter = Aircraft.PropellerDiameter;
    Parameters.PropellerRadius   = Aircraft.PropellerDiameter / 2;

    Parameters.PropellerInertia  = Aircraft.PropellerInertia;
    Parameters.NumberOfBlades    = Aircraft.NumberOfBlades;

    Parameters.Gravity           = Aircraft.Gravity;

end

function Airspeed = computeAirspeed(State)

    Velocity = State.VelocityBody(:);

    Airspeed = norm(Velocity);

    Airspeed = max(Airspeed,1.0);

end
% =========================================================================
%% ENGINE MODEL
% =========================================================================

function Engine = computeEngineState(Throttle, Parameters)

    %% Throttle Saturation

    Throttle = min(max( ...
        Throttle,...
        Parameters.MinimumThrottle),...
        Parameters.MaximumThrottle);

    %% Engine Speed

    EngineRPM = interpolateEngineRPM( ...
        Throttle,...
        Parameters);

    %% Shaft Power

    ShaftPower = interpolateEnginePower( ...
        Throttle,...
        EngineRPM,...
        Parameters);

    %% Propeller Speed
    % Direct-drive piston engine

    PropellerRPM = EngineRPM;

    AngularVelocity = ...
        (2*pi/60) * PropellerRPM;

    %% Package Output

    Engine = struct();

    Engine.Throttle        = Throttle;

    Engine.EngineRPM       = EngineRPM;
    Engine.PropellerRPM    = PropellerRPM;

    Engine.AngularVelocity = AngularVelocity;

    Engine.ShaftPower      = ShaftPower;

end

function EngineRPM = interpolateEngineRPM( ...
    Throttle,...
    Parameters)

    throttleRange = ...
        Parameters.MaximumThrottle ...
      - Parameters.MinimumThrottle;

    throttleFraction = ...
        (Throttle - Parameters.MinimumThrottle) ...
        / max(throttleRange,eps);

    throttleFraction = ...
        min(max(throttleFraction,0.0),1.0);

    EngineRPM = ...
        Parameters.IdleRPM ...
      + throttleFraction * ...
        (Parameters.MaximumRPM ...
      - Parameters.IdleRPM);

end

function ShaftPower = interpolateEnginePower( ...
    Throttle,...
    EngineRPM,...
    Parameters)

    rpmFraction = ...
        EngineRPM / ...
        max(Parameters.MaximumRPM,1);

    rpmFraction = ...
        min(max(rpmFraction,0.0),1.0);

    throttleFraction = ...
        (Throttle - Parameters.MinimumThrottle) ...
      / (Parameters.MaximumThrottle ...
       - Parameters.MinimumThrottle);

    throttleFraction = ...
        min(max(throttleFraction,0.0),1.0);

    powerFraction = ...
        throttleFraction .* rpmFraction;

    ShaftPower = ...
        Parameters.EnginePower ...
      * powerFraction;

    ShaftPower = max(ShaftPower,0.0);

end

% =========================================================================
%% PROPELLER MODEL
% =========================================================================

function Propeller = computePropellerState( ...
    Airspeed,...
    Engine,...
    Environment,...
    Parameters)

    %% Propeller Speed

    n = Engine.PropellerRPM / 60.0;

    Omega = Engine.AngularVelocity;

    %% Advance Ratio

    AdvanceRatio = computeAdvanceRatio( ...
        Airspeed,...
        n,...
        Parameters.PropellerDiameter);

    %% Propeller Efficiency

    Efficiency = computePropellerEfficiency( ...
        AdvanceRatio);

    %% Thrust

   Thrust = computePropellerThrust( ...
    Engine.ShaftPower,...
    Efficiency,...
    Airspeed,...
    Environment.AirDensity,...
    n,...
    Parameters.PropellerDiameter,...
    AdvanceRatio);

    %% Torque

    PropellerTorque = computePropellerTorque( ...
        Engine.ShaftPower,...
        Omega);

    %% Output Structure

    Propeller = struct();

    Propeller.PropellerSpeed      = n;
    Propeller.AngularVelocity     = Omega;

    Propeller.AdvanceRatio        = AdvanceRatio;
    Propeller.PropellerEfficiency = Efficiency;

    Propeller.Thrust              = Thrust;
    Propeller.PropellerTorque     = PropellerTorque;

    Propeller.AirDensity          = Environment.AirDensity;

end
% =========================================================================
%% PROPELLER PERFORMANCE MODELS
% =========================================================================

function AdvanceRatio = computeAdvanceRatio( ...
    Airspeed,...
    PropellerSpeed,...
    Diameter)

    denominator = max(PropellerSpeed * Diameter,1e-6);

    AdvanceRatio = Airspeed / denominator;

    AdvanceRatio = max(AdvanceRatio,0.0);

end

function Efficiency = computePropellerEfficiency(AdvanceRatio)

    % Smooth analytical efficiency model.
    %
    % Peak efficiency occurs near J ≈ 0.8 with gradual roll-off
    % toward static thrust and windmilling conditions.

    J = AdvanceRatio;

    Efficiency = ...
        0.88 ...
      - 0.65 * (J - 0.80).^2;

    Efficiency = ...
        min(max(Efficiency,0.15),0.90);

end

function Thrust = computePropellerThrust( ...
    ShaftPower,...
    Efficiency,...
    Airspeed,...
    AirDensity,...
    PropellerSpeed,...
    Diameter,...
    AdvanceRatio)

    %% Static Thrust Model

    Ct = computeThrustCoefficient(AdvanceRatio);

    StaticThrust = ...
        Ct ...
      * AirDensity ...
      * (PropellerSpeed^2) ...
      * (Diameter^4);

    %% Cruise Thrust Model

    EffectiveVelocity = max(Airspeed,10.0);

    CruiseThrust = ...
        (Efficiency * ShaftPower) ...
        / EffectiveVelocity;

    %% Smooth Transition

    TransitionSpeed = 15.0;

    Blend = min(max(Airspeed / TransitionSpeed,0.0),1.0);

    Thrust = ...
        (1.0 - Blend) * StaticThrust ...
      + Blend * CruiseThrust;

    Thrust = max(Thrust,0.0);

end
function Ct = computeThrustCoefficient(AdvanceRatio)

    Ct = 0.12 * max(1.0 - 0.8 * AdvanceRatio,0.20);

end


function PropellerTorque = computePropellerTorque( ...
    ShaftPower,...
    AngularVelocity)

    omega = max(AngularVelocity,1e-3);

    PropellerTorque = ShaftPower / omega;

    PropellerTorque = max(PropellerTorque,0.0);

end

% =========================================================================
%% FORCE AND MOMENT ASSEMBLY
% =========================================================================

function Loads = computePropulsionLoads( ...
    Propeller,...
    Parameters)

    %% Body Forces

    ForceBody = [ ...
        Propeller.Thrust;
        0.0;
        0.0];

    %% Propeller Reaction Torque
    %
    % Assumes a tractor configuration with engine torque acting
    % primarily about the body X-axis.

    RollMoment = ...
        -Propeller.PropellerTorque;

    PitchMoment = 0.0;

    YawMoment = 0.0;

    MomentBody = [ ...
        RollMoment;
        PitchMoment;
        YawMoment];

    %% Output

    Loads = struct();

    Loads.ForceBody = ForceBody;
    Loads.MomentBody = MomentBody;

end
% =========================================================================
%% VALIDATION & INITIALIZATION
% =========================================================================

function validatePropulsionInputs( ...
    State,...
    Controls,...
    Environment,...
    Aircraft)

    %% Required State Fields

    requiredState = { ...
        'VelocityBody'};

    for k = 1:numel(requiredState)

        if ~isfield(State,requiredState{k})

            error( ...
                'PropulsionModel:MissingStateField', ...
                'Missing State.%s.', ...
                requiredState{k});

        end

    end

    %% Required Control Fields

    requiredControls = { ...
        'Throttle'};

    for k = 1:numel(requiredControls)

        if ~isfield(Controls,requiredControls{k})

            error( ...
                'PropulsionModel:MissingControlField', ...
                'Missing Controls.%s.', ...
                requiredControls{k});

        end

    end

    %% Required Environment Fields

    requiredEnvironment = { ...
        'AirDensity'};

    for k = 1:numel(requiredEnvironment)

        if ~isfield(Environment,requiredEnvironment{k})

            error( ...
                'PropulsionModel:MissingEnvironmentField', ...
                'Missing Environment.%s.', ...
                requiredEnvironment{k});

        end

    end

    %% Aircraft Geometry

    requiredAircraft = { ...
        'EnginePower',...
        'IdleRPM',...
        'MaximumRPM',...
        'MinimumThrottle',...
        'MaximumThrottle',...
        'PropellerDiameter',...
        'PropellerInertia',...
        'NumberOfBlades'};

    for k = 1:numel(requiredAircraft)

        if ~isMemberOrField(Aircraft,requiredAircraft{k})

            error( ...
                'PropulsionModel:MissingAircraftField', ...
                'Missing Aircraft.%s.', ...
                requiredAircraft{k});

        end

    end

    %% Numerical Checks

    if numel(State.VelocityBody) ~= 3

        error( ...
            'PropulsionModel:VelocityDimension', ...
            'VelocityBody must be a 3-element vector.');

    end

    if any(~isfinite(State.VelocityBody))

        error( ...
            'PropulsionModel:InvalidVelocity', ...
            'VelocityBody contains NaN or Inf.');

    end

    if ~isfinite(Controls.Throttle)

        error( ...
            'PropulsionModel:InvalidThrottle', ...
            'Throttle must be finite.');

    end

    if ~isfinite(Environment.AirDensity)

        error( ...
            'PropulsionModel:InvalidDensity', ...
            'AirDensity must be finite.');

    end

end

function Aircraft = validatePropulsionConfiguration(Aircraft)

    requiredPositive = { ...
        'EnginePower',...
        'IdleRPM',...
        'MaximumRPM',...
        'PropellerDiameter',...
        'PropellerInertia',...
        'NumberOfBlades'};

    for k = 1:numel(requiredPositive)

        value = Aircraft.(requiredPositive{k});

        if ~isfinite(value) || value <= 0

            error( ...
                'PropulsionModel:InvalidAircraftParameter', ...
                'Aircraft.%s must be positive.', ...
                requiredPositive{k});

        end

    end

end

function Propulsion = initializePropulsionOutput()

    Propulsion = struct();

    Propulsion.ForceBody = zeros(3,1);

    Propulsion.MomentBody = zeros(3,1);

    Propulsion.Thrust = 0.0;

    Propulsion.EngineRPM = 0.0;

    Propulsion.PropellerRPM = 0.0;

    Propulsion.ShaftPower = 0.0;

    Propulsion.PropellerTorque = 0.0;

    Propulsion.AdvanceRatio = 0.0;

    Propulsion.PropellerEfficiency = 0.0;

    Propulsion.Structures = struct();

end

% =========================================================================
%% UTILITY FUNCTIONS
% =========================================================================

function tf = isMemberOrField(Object,FieldName)

    if isstruct(Object)

        tf = isfield(Object,FieldName);

    else

        tf = isprop(Object,FieldName);

    end

end
function validatePropulsionOutput(Propulsion)

    %% Force Vector

    if numel(Propulsion.ForceBody) ~= 3

        error( ...
            'PropulsionModel:InvalidForceVector', ...
            'ForceBody must be a 3-element vector.');

    end

    %% Moment Vector

    if numel(Propulsion.MomentBody) ~= 3

        error( ...
            'PropulsionModel:InvalidMomentVector', ...
            'MomentBody must be a 3-element vector.');

    end

    %% Finite Values

    if any(~isfinite(Propulsion.ForceBody))

        error( ...
            'PropulsionModel:NonFiniteForce', ...
            'ForceBody contains NaN or Inf.');

    end

    if any(~isfinite(Propulsion.MomentBody))

        error( ...
            'PropulsionModel:NonFiniteMoment', ...
            'MomentBody contains NaN or Inf.');

    end

    scalarFields = { ...
        'Thrust',...
        'EngineRPM',...
        'PropellerRPM',...
        'ShaftPower',...
        'PropellerTorque',...
        'AdvanceRatio',...
        'PropellerEfficiency'};

    for k = 1:numel(scalarFields)

        value = Propulsion.(scalarFields{k});

        if ~isfinite(value)

            error( ...
                'PropulsionModel:InvalidOutput', ...
                '%s contains NaN or Inf.', ...
                scalarFields{k});

        end

    end

end