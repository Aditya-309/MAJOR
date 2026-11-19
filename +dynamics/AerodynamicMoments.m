function Aero = AerodynamicMoments(State,Controls,Environment,Aircraft)
% AERODYNAMICMOMENTS
%
% Computes aerodynamic moments acting on the aircraft body.
%
% Project:
%   Adaptive Flight State Reconstruction and
%   Trajectory Estimation using Sensor Fusion and AI
%
% Aircraft:
%   Cessna 172P
%
% MATLAB:
%   R2024b
%
% Inputs
% -------
% State
%   .VelocityBody
%   .AngularRatesBody
%
% Controls
%   .Aileron
%   .Elevator
%   .Rudder
%
% Environment
%   .AirDensity
%   .WindBody
%
% Aircraft
%   AircraftConfig structure
%
% Output
% ------
% Aero
%
%   .MomentBody
%   .DynamicPressure
%   .Airspeed
%   .AngleOfAttack
%   .Sideslip
%   .Coefficients
%
% Units
%
%   SI
%
% -------------------------------------------------------------------------

narginchk(4,4);

Aero = runAerodynamicMomentModel(...
    State,...
    Controls,...
    Environment,...
    Aircraft);

end

%==========================================================================
%% CORE EXECUTION PIPELINE
%==========================================================================

function Aero = runAerodynamicMomentModel(State,Controls,Environment,Aircraft)

validateMomentInputs(...
    State,...
    Controls,...
    Environment,...
    Aircraft);

validateMomentModel();

Aero = initializeMomentOutput();

Flow = computeAerodynamicAngles(...
    State.VelocityBody,...
    Environment.WindBody);

DynamicPressure = computeDynamicPressure(...
    Flow.Airspeed,...
    Environment.AirDensity);

b = Aircraft.Wingspan;
c = Aircraft.MeanAerodynamicChord;

Rates = State.AngularRatesBody(:);

Va = max(Flow.Airspeed,5.0);

pHat = Rates(1)*b/(2*Va);
qHat = Rates(2)*c/(2*Va);
rHat = Rates(3)*b/(2*Va);

Coeff = computeMomentCoefficients(...
    Flow.AngleOfAttack,...
    Flow.Sideslip,...
    pHat,...
    qHat,...
    rHat,...
    Controls.Aileron,...
    Controls.Elevator,...
    Controls.Rudder,...
    Aircraft);

Coeff = applyMomentLimits(...
    Coeff,...
    Flow.AngleOfAttack);

MomentBody = dimensionalizeMoments(...
    Coeff,...
    DynamicPressure,...
    Aircraft);

Aero.MomentBody      = MomentBody;
Aero.DynamicPressure = DynamicPressure.qBar;
Aero.Airspeed        = Flow.Airspeed;
Aero.AngleOfAttack   = Flow.AngleOfAttack;
Aero.Sideslip        = Flow.Sideslip;
Aero.Coefficients    = Coeff;

end

%==========================================================================
%% MOMENT COEFFICIENT MODEL
%==========================================================================

function Coeff = computeMomentCoefficients(...
    alpha,...
    beta,...
    pHat,...
    qHat,...
    rHat,...
    deltaA,...
    deltaE,...
    deltaR,...
    Aircraft)

Model = config.AircraftConfig.getAerodynamics();

%% Pitching Moment

Cm = ...
    Model.Cm0 + ...
    Model.Cm_alpha*alpha + ...
    Model.Cm_q*qHat + ...
    Model.Cm_elevator*deltaE;

%% Rolling Moment

Cl = ...
    Model.Cl_beta*beta + ...
    Model.Cl_p*pHat + ...
    Model.Cl_r*rHat + ...
    Model.Cl_aileron*deltaA + ...
    Model.Cl_rudder*deltaR;

%% Yawing Moment

Cn = ...
    Model.Cn_beta*beta + ...
    Model.Cn_p*pHat + ...
    Model.Cn_r*rHat + ...
    Model.Cn_aileron*deltaA + ...
    Model.Cn_rudder*deltaR;

Coeff = struct();

Coeff.Cl = Cl;
Coeff.Cm = Cm;
Coeff.Cn = Cn;

end
%==========================================================================
%% MOMENT LIMITING
%==========================================================================

function Coeff = applyMomentLimits(Coeff,alpha)

Model = config.AircraftConfig.getAerodynamics();

if isfield(Model,"Limits")
    Limits = Model.Limits;
else
    Limits = defaultMomentLimits();
end

alphaAbs = abs(alpha);

if alphaAbs <= Limits.StallStart

    blend = 1.0;

elseif alphaAbs >= Limits.StallEnd

    blend = Limits.PostStallLiftFactor;
else

    t = (alphaAbs - Limits.StallStart) / ...
        (Limits.StallEnd - Limits.StallStart);

    blend = (1-t) + t*Limits.PostStallLiftFactor;

end

Coeff.Cl = Coeff.Cl * blend;
Coeff.Cm = Coeff.Cm * blend;
Coeff.Cn = Coeff.Cn * blend;

Coeff.Cl = clamp(Coeff.Cl,Limits.Cl);
Coeff.Cm = clamp(Coeff.Cm,Limits.Cm);
Coeff.Cn = clamp(Coeff.Cn,Limits.Cn);

end

%==========================================================================
%% MOMENT DIMENSIONALIZATION
%==========================================================================

function MomentBody = dimensionalizeMoments( ...
                                Coeff,...
                                DynamicPressure,...
                                Aircraft)

S    = Aircraft.WingArea;
b    = Aircraft.Wingspan;
cbar = Aircraft.MeanAerodynamicChord;

qBar = DynamicPressure.qBar;

L = qBar*S*b*Coeff.Cl;
M = qBar*S*cbar*Coeff.Cm;
N = qBar*S*b*Coeff.Cn;

MomentBody = [L;M;N];

end

%==========================================================================
%% FLOW PROPERTIES
%==========================================================================

function Flow = computeAerodynamicAngles( ...
                                VelocityBody,...
                                WindBody)

Vrel = VelocityBody(:) - WindBody(:);

u = Vrel(1);
v = Vrel(2);
w = Vrel(3);

V = norm(Vrel);

if V < 1e-3
    V = 1e-3;
end

alpha = atan2(w,u);

beta = asin(min(max(v/V,-1),1));

Flow = struct();

Flow.RelativeVelocity = Vrel;
Flow.Airspeed         = V;
Flow.AngleOfAttack    = alpha;
Flow.Sideslip         = beta;

end

%==========================================================================
%% DYNAMIC PRESSURE
%==========================================================================

function DynamicPressure = computeDynamicPressure( ...
                                    Airspeed,...
                                    AirDensity)

V = max(Airspeed,0);
rho = max(AirDensity,0);

qBar = 0.5*rho*V^2;

DynamicPressure = struct();

DynamicPressure.qBar            = qBar;
DynamicPressure.VelocitySquared = V^2;

end

%==========================================================================
%% OUTPUT INITIALIZATION
%==========================================================================

function Aero = initializeMomentOutput()

Aero = struct();

Aero.MomentBody      = zeros(3,1);
Aero.DynamicPressure = 0;
Aero.Airspeed        = 0;
Aero.AngleOfAttack   = 0;
Aero.Sideslip        = 0;

Aero.Coefficients = struct( ...
    'Cl',0,...
    'Cm',0,...
    'Cn',0);

end
%==========================================================================
%% INPUT VALIDATION
%==========================================================================

function validateMomentInputs(State,Controls,Environment,Aircraft)

%%---------------------- State -------------------------------------------

requiredState = { ...
    'VelocityBody',...
    'AngularRatesBody'};

for k = 1:numel(requiredState)

    if ~isfield(State,requiredState{k})

        error('AerodynamicMoments:MissingStateField',...
            'Missing State.%s.',requiredState{k});

    end

end

%%---------------------- Controls ----------------------------------------

requiredControls = { ...
    'Aileron',...
    'Elevator',...
    'Rudder'};

for k = 1:numel(requiredControls)

    if ~isfield(Controls,requiredControls{k})

        error('AerodynamicMoments:MissingControlField',...
            'Missing Controls.%s.',requiredControls{k});

    end

end

%%---------------------- Environment -------------------------------------

requiredEnvironment = { ...
    'AirDensity',...
    'WindBody'};

for k = 1:numel(requiredEnvironment)

    if ~isfield(Environment,requiredEnvironment{k})

        error('AerodynamicMoments:MissingEnvironmentField',...
            'Missing Environment.%s.',requiredEnvironment{k});

    end

end

%%---------------------- Aircraft ----------------------------------------

requiredAircraft = { ...
    'WingArea',...
    'Wingspan',...
    'MeanAerodynamicChord'};

for k = 1:numel(requiredAircraft)

    if ~isMemberOrField(Aircraft,requiredAircraft{k})

        error('AerodynamicMoments:MissingAircraftField',...
            'Missing Aircraft.%s.',requiredAircraft{k});

    end

end

%%---------------------- Geometry ----------------------------------------

if Aircraft.WingArea <= 0
    error('AerodynamicMoments:InvalidWingArea',...
        'WingArea must be positive.');
end

if Aircraft.Wingspan <= 0
    error('AerodynamicMoments:InvalidWingspan',...
        'Wingspan must be positive.');
end

if Aircraft.MeanAerodynamicChord <= 0
    error('AerodynamicMoments:InvalidMAC',...
        'MeanAerodynamicChord must be positive.');
end

%%---------------------- Vector Sizes ------------------------------------

if numel(State.VelocityBody) ~= 3

    error('AerodynamicMoments:VelocitySize',...
        'VelocityBody must contain 3 elements.');

end

if numel(State.AngularRatesBody) ~= 3

    error('AerodynamicMoments:AngularRateSize',...
        'AngularRatesBody must contain 3 elements.');

end

if numel(Environment.WindBody) ~= 3

    error('AerodynamicMoments:WindSize',...
        'WindBody must contain 3 elements.');

end

%%---------------------- Finite Values -----------------------------------

if any(~isfinite(State.VelocityBody))

    error('AerodynamicMoments:VelocityFinite',...
        'VelocityBody contains NaN or Inf.');

end

if any(~isfinite(State.AngularRatesBody))

    error('AerodynamicMoments:RateFinite',...
        'AngularRatesBody contains NaN or Inf.');

end

if any(~isfinite(Environment.WindBody))

    error('AerodynamicMoments:WindFinite',...
        'WindBody contains NaN or Inf.');

end

if ~isfinite(Environment.AirDensity)

    error('AerodynamicMoments:DensityFinite',...
        'AirDensity must be finite.');

end

if Environment.AirDensity < 0

    error('AerodynamicMoments:DensityNegative',...
        'AirDensity cannot be negative.');

end

end

%==========================================================================
%% MODEL VALIDATION
%==========================================================================

function validateMomentModel()

Model = config.AircraftConfig.getAerodynamics();

required = { ...
    'Cm0',...
    'Cm_alpha',...
    'Cm_q',...
    'Cm_elevator',...
    'Cl_beta',...
    'Cl_p',...
    'Cl_r',...
    'Cl_aileron',...
    'Cl_rudder',...
    'Cn_beta',...
    'Cn_p',...
    'Cn_r',...
    'Cn_aileron',...
    'Cn_rudder'};

for k = 1:numel(required)

    if ~isfield(Model,required{k})

        error('AerodynamicMoments:MissingCoefficient',...
            'Missing coefficient "%s".',required{k});

    end

end

end
%==========================================================================
%% UTILITY FUNCTIONS
%==========================================================================

function tf = isMemberOrField(obj,name)
% Supports both MATLAB structs and class objects.

if isstruct(obj)

    tf = isfield(obj,name);

else

    tf = isprop(obj,name);

end

end

%--------------------------------------------------------------------------

function value = clamp(value,bounds)
% Saturates a scalar between lower and upper bounds.

value = min(max(value,bounds(1)),bounds(2));

end

%--------------------------------------------------------------------------

function Limits = defaultMomentLimits()
% Default aerodynamic moment limits.
%
% Used only if AircraftConfig does not define
% Model.Limits.

Limits.StallStart = deg2rad(12);

Limits.StallEnd = deg2rad(20);

Limits.PostStallMomentFactor = 0.45;

Limits.Cl = [-1.5 1.5];

Limits.Cm = [-2.0 2.0];

Limits.Cn = [-1.5 1.5];

end

%==========================================================================
%% SELF TEST
%==========================================================================

function selfTest()
% Internal verification routine.

Aircraft = config.AircraftConfig.getStruct();

State.VelocityBody = [60;0;2];

State.AngularRatesBody = [0.05;0.02;-0.04];

Controls.Aileron = deg2rad(5);

Controls.Elevator = deg2rad(-2);

Controls.Rudder = deg2rad(3);

Controls.Throttle = 0.6;

Environment.AirDensity = 1.225;

Environment.WindBody = [0;0;0];

Aero = AerodynamicMoments( ...
    State,...
    Controls,...
    Environment,...
    Aircraft);

assert(all(isfinite(Aero.MomentBody)));

assert(numel(Aero.MomentBody)==3);

assert(isfinite(Aero.DynamicPressure));

assert(isfinite(Aero.Airspeed));

disp("AerodynamicMoments self-test PASSED")

end

%==========================================================================
%% END OF FILE
%==========================================================================