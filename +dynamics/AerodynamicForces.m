    function Aero = AerodynamicForces(State, Controls, Environment, Aircraft)
    % AERODYNAMICFORCES Top-level aerodynamic interface for flight simulation.
    %
    % Computes aerodynamic forces and moments for the aircraft using a
    % modular coefficient-based formulation. Supports both struct and 
    % AircraftConfig class object inputs.
    %
    % Project:
    %   Adaptive Flight State Reconstruction and Trajectory Estimation
    %
    % MATLAB Version:
    %   R2024b
    %
    % INPUTS:
    %   State        - Struct containing:
    %                     .VelocityBody      [3x1] (m/s)
    %                     .AngularRatesBody  [3x1] (rad/s)
    %                     .EulerAngles       [3x1] (rad)
    %   Controls     - Struct containing:
    %                     .Aileron           (rad)
    %                     .Elevator          (rad)
    %                     .Rudder            (rad)
    %                     .Throttle          (0-1)
    %   Environment  - Struct containing:
    %                     .AirDensity        (kg/m^3)
    %                     .WindBody          [3x1] (m/s)
    %   Aircraft     - Struct or AircraftConfig object containing:
    %                     .WingArea
    %                     .Wingspan
    %                     .MeanAerodynamicChord
    %                     .Aerodynamics (Struct containing aero derivatives)
    %
    % OUTPUT:
    %   Aero         - Struct containing:
    %                     .ForceBody         [3x1] (N)
    %                     .MomentBody        [3x1] (N*m)
    %                     .DynamicPressure   (Pa)
    %                     .Airspeed          (m/s)
    %                     .AngleOfAttack     (rad)
    %                     .Sideslip          (rad)
    %                     .Coefficients      (Struct of nondimensional coeffs)
    
        narginchk(4, 4);
    
        % Delegate computation to the core engine workflow
        Aero = runAerodynamicModel(State, Controls, Environment, Aircraft);
    end
    
    % =========================================================================
    %% CORE EXECUTION PIPELINE
    % =========================================================================
    
    function Aero = runAerodynamicModel(State, Controls, Environment, Aircraft)
        % Orchestrates the complete aerodynamic evaluation sequence.
        
        % 1. Validate Inputs & Model Configurations
        validateAerodynamicInputs(State, Controls, Environment, Aircraft);
        Aircraft = validateAerodynamicModel(Aircraft);
    
        % 2. Initialize Output Payload
        Aero = initializeAerodynamicOutput();
    
        % 3. Calculate Relative Flow Properties
        Flow = computeAerodynamicAngles(State.VelocityBody, Environment.WindBody);
    
        % 4. Compute Dynamic Pressure
        DynamicPressure = computeDynamicPressure(Flow.Airspeed, Environment.AirDensity);
    
        % 5. Non-Dimensional Angular Rates (Updated property name to Wingspan)
        b = Aircraft.Wingspan;
        c = Aircraft.MeanAerodynamicChord;
        Rates = State.AngularRatesBody(:);
        Va = max(Flow.Airspeed, 5.0);
    
        pHat = Rates(1) * b / (2 * Va);
        qHat = Rates(2) * c / (2 * Va);
        rHat = Rates(3) * b / (2 * Va);
    
        % 6. Compute Raw Aerodynamic Coefficients
        Coeff = computeAerodynamicCoefficients( ...
            Flow.AngleOfAttack, ...
            Flow.Sideslip, ...
            pHat, qHat, rHat, ...
            Controls.Aileron, ...
            Controls.Elevator, ...
            Controls.Rudder, ...
            Aircraft);
    
        % 7. Apply Post-Stall Blending and Bounds Limits
        Coeff = applyAerodynamicLimits(Coeff, Flow.AngleOfAttack, Aircraft);
    
        % 8. Assemble Body Forces & Moments
        Loads = assembleAerodynamicLoads(Coeff, DynamicPressure, Aircraft);
    
        % 9. Populate Final Output Structure
        Aero.ForceBody       = Loads.ForceBody;
        Aero.MomentBody      = Loads.MomentBody;
        Aero.DynamicPressure = DynamicPressure.qBar;
        Aero.Airspeed        = Flow.Airspeed;
        Aero.AngleOfAttack   = Flow.AngleOfAttack;
        Aero.Sideslip        = Flow.Sideslip;
        Aero.Coefficients    = Coeff;
    end
    
    % =========================================================================
    %% AERODYNAMIC MODEL & COEFFICIENT CALCULATIONS
    % =========================================================================
    
    function Coeff = computeAerodynamicCoefficients( ...
        alpha, beta, pHat, qHat, rHat, deltaA, deltaE, deltaR, Aircraft)
        % Computes non-dimensional aerodynamic coefficients from model derivatives.
        Model = config.AircraftConfig.getAerodynamics();
    
        %% Longitudinal Coefficients
        CL = Model.CL0 ...
           + Model.CL_alpha * alpha ...
           + Model.CL_q * qHat ...
           + Model.CL_elevator * deltaE;
    
        % Induced drag model
    
    k = Model.CD_alpha2;
    
    CD = Model.CD0 ...
       + k * (CL^2) ...
       + Model.CD_q * abs(qHat);
    
        Cm = Model.Cm0 ...
           + Model.Cm_alpha * alpha ...
           + Model.Cm_q * qHat ...
           + Model.Cm_elevator * deltaE;
    
        %% Lateral / Directional Coefficients
        CY = Model.CY_beta * beta ...
           + Model.CY_p * pHat ...
           + Model.CY_r * rHat ...
           + Model.CY_rudder * deltaR;
    
        Cl = Model.Cl_beta * beta ...
           + Model.Cl_p * pHat ...
           + Model.Cl_r * rHat ...
           + Model.Cl_aileron * deltaA ...
           + Model.Cl_rudder * deltaR;
    
        Cn = Model.Cn_beta * beta ...
           + Model.Cn_p * pHat ...
           + Model.Cn_r * rHat ...
           + Model.Cn_aileron * deltaA ...
           + Model.Cn_rudder * deltaR;
    
        %% Lift/Drag to Body Axes Transformation (X and Z)
        ca = cos(alpha);
        sa = sin(alpha);
        CX = -CD * ca + CL * sa;
        CZ = -CD * sa - CL * ca;
    
        %% Package Output Structure
        Coeff = struct();
        Coeff.CL = CL;
        Coeff.CD = CD;
        Coeff.CX = CX;
        Coeff.CY = CY;
        Coeff.CZ = CZ;
        Coeff.Cl = Cl;
        Coeff.Cm = Cm;
        Coeff.Cn = Cn;
    end
    
    function Coeff = applyAerodynamicLimits(Coeff, alpha, Aircraft)
        % Applies smooth coefficient limiting near stall and constrains bounds.
    Model = config.AircraftConfig.getAerodynamics();
    
    if isfield(Model,'Limits')
        Limits = Model.Limits;
    else
        Limits = defaultAerodynamicLimits();
    end
    
        %% Stall Blending
        alphaAbs = abs(alpha);
        if alphaAbs <= Limits.StallStart
            blend = 1.0;
        elseif alphaAbs >= Limits.StallEnd
            blend = Limits.PostStallLiftFactor;
        else
            t = (alphaAbs - Limits.StallStart) / (Limits.StallEnd - Limits.StallStart);
            blend = (1 - t) + t * Limits.PostStallLiftFactor;
        end
    
        Coeff.CL = Coeff.CL * blend;
        Coeff.Cm = Coeff.Cm * blend;
    
        %% Recompute Body-Axis Force Coefficients Post-Blend
        ca = cos(alpha);
        sa = sin(alpha);
        Coeff.CX = -Coeff.CD * ca + Coeff.CL * sa;
        Coeff.CZ = -Coeff.CD * sa - Coeff.CL * ca;
    
        %% Saturation / Clamp
        Coeff.CL = clamp(Coeff.CL, Limits.CL);
        Coeff.CD = clamp(Coeff.CD, Limits.CD);
        Coeff.CX = clamp(Coeff.CX, Limits.CX);
        Coeff.CY = clamp(Coeff.CY, Limits.CY);
        Coeff.CZ = clamp(Coeff.CZ, Limits.CZ);
        Coeff.Cl = clamp(Coeff.Cl, Limits.Cl);
        Coeff.Cm = clamp(Coeff.Cm, Limits.Cm);
        Coeff.Cn = clamp(Coeff.Cn, Limits.Cn);
    end
    
    % =========================================================================
    %% ATMOSPHERIC & KINEMATIC HELPERS
    % =========================================================================
    
    function AlphaBeta = computeAerodynamicAngles(VelocityBody, WindBody)
        % Computes relative velocity, airspeed, angle of attack, and sideslip.
    
        Vrel = VelocityBody(:) - WindBody(:);
        u = Vrel(1);
        v = Vrel(2);
        w = Vrel(3);
    
        V = norm(Vrel);
        if V < 1e-3
            V = 1e-3; % Prevent divide-by-zero
        end
    
        alpha = atan2(w, u);
        beta  = asin(min(max(v / V, -1.0), 1.0));
    
        AlphaBeta = struct();
        AlphaBeta.RelativeVelocity = Vrel;
        AlphaBeta.Airspeed         = V;
        AlphaBeta.AngleOfAttack    = alpha;
        AlphaBeta.Sideslip         = beta;
    end
    
    function DynamicPressure = computeDynamicPressure(Airspeed, AirDensity)
        % Computes aerodynamic dynamic pressure (qbar).
    
        V   = max(Airspeed, 0.0);
        rho = max(AirDensity, 0.0);
    
        V2   = V * V;
        qBar = 0.5 * rho * V2;
    
        DynamicPressure = struct();
        DynamicPressure.qBar            = qBar;
        DynamicPressure.VelocitySquared = V2;
    end
    
    function ForceMoment = assembleAerodynamicLoads(Coeff, DynamicPressure, Aircraft)
        % Dimensionalizes non-dimensional coefficients into body forces and moments.
    
        S    = Aircraft.WingArea;
        b    = Aircraft.Wingspan; % Fixed capitalization from WingSpan -> Wingspan
        c    = Aircraft.MeanAerodynamicChord;
        qBar = DynamicPressure.qBar;
    
        %% Forces
        Fx = qBar * S * Coeff.CX;
        Fy = qBar * S * Coeff.CY;
        Fz = qBar * S * Coeff.CZ;
    
        %% Moments
        L = qBar * S * b * Coeff.Cl;
        M = qBar * S * c * Coeff.Cm;
        N = qBar * S * b * Coeff.Cn;
    
        ForceMoment = struct();
        ForceMoment.ForceBody  = [Fx; Fy; Fz];
        ForceMoment.MomentBody = [L; M; N];
    end
    
    % =========================================================================
    %% VALIDATION & INITIALIZATION HELPERS
    % =========================================================================
    
    function validateAerodynamicInputs(State, Controls, Environment, Aircraft)
        % Input verification for state, control, environment, and geometry inputs.
    
        % State Verification
        reqState = {'VelocityBody', 'AngularRatesBody'};
        for k = 1:numel(reqState)
            if ~isfield(State, reqState{k})
                error('AerodynamicForces:MissingStateField', 'Missing State.%s.', reqState{k});
            end
        end
    
        % Controls Verification
        reqControls = {'Aileron', 'Elevator', 'Rudder'};
        for k = 1:numel(reqControls)
            if ~isfield(Controls, reqControls{k})
                error('AerodynamicForces:MissingControlField', 'Missing Controls.%s.', reqControls{k});
            end
        end
    
        % Environment Verification
        reqEnv = {'AirDensity', 'WindBody'};
        for k = 1:numel(reqEnv)
            if ~isfield(Environment, reqEnv{k})
                error('AerodynamicForces:MissingEnvironmentField', 'Missing Environment.%s.', reqEnv{k});
            end
        end
    
        % Aircraft Verification (Supports both class objects and structs)
        reqAir = {'WingArea', 'Wingspan', 'MeanAerodynamicChord'};
        for k = 1:numel(reqAir)
            if ~isMemberOrField(Aircraft, reqAir{k})
                error('AerodynamicForces:MissingAircraftField', 'Missing Aircraft.%s.', reqAir{k});
            end
        end
    
        % Bounds & Constraints Validation
        if Aircraft.WingArea <= 0 || Aircraft.Wingspan <= 0 || Aircraft.MeanAerodynamicChord <= 0
            error('AerodynamicForces:InvalidGeometry', 'Aircraft dimensions must be positive values.');
        end
    
        if numel(State.VelocityBody) ~= 3 || numel(State.AngularRatesBody) ~= 3 || numel(Environment.WindBody) ~= 3
            error('AerodynamicForces:VectorSizeMismatch', 'State and Environment vectors must have 3 elements.');
        end
    
        if any(~isfinite(State.VelocityBody)) || any(~isfinite(State.AngularRatesBody)) || any(~isfinite(Environment.WindBody))
            error('AerodynamicForces:NonFiniteInput', 'State or Environment contains NaN/Inf values.');
        end
    
        if ~isfinite(Environment.AirDensity) || Environment.AirDensity < 0
            error('AerodynamicForces:InvalidDensity', 'AirDensity must be finite and non-negative.');
        end
    end
    
    function Aircraft = validateAerodynamicModel(Aircraft)
    % Ensures all required aerodynamic coefficients exist.
    
    Model = config.AircraftConfig.getAerodynamics();
    
    requiredFields = { ...
        'CL0','CL_alpha','CL_q','CL_elevator', ...
        'CD0','CD_alpha2','CD_q', ...
        'Cm0','Cm_alpha','Cm_q','Cm_elevator', ...
        'CY_beta','CY_p','CY_r','CY_rudder', ...
        'Cl_beta','Cl_p','Cl_r','Cl_aileron','Cl_rudder', ...
        'Cn_beta','Cn_p','Cn_r','Cn_aileron','Cn_rudder'};
    
    for k = 1:numel(requiredFields)
    
        fn = requiredFields{k};
    
        if ~isfield(Model,fn)
            error('AerodynamicForces:MissingCoefficient', ...
                'Missing aerodynamic coefficient "%s".',fn);
        end
    
    end
    
    end
    
    function Aero = initializeAerodynamicOutput()
        % Constructs a cleanly typed template for the output structure.
        Aero = struct();
        Aero.ForceBody       = zeros(3, 1);
        Aero.MomentBody      = zeros(3, 1);
        Aero.DynamicPressure = 0.0;
        Aero.Airspeed        = 0.0;
        Aero.AngleOfAttack   = 0.0;
        Aero.Sideslip        = 0.0;
        Aero.Coefficients    = struct('CL',0,'CD',0,'CX',0,'CY',0,'CZ',0,'Cl',0,'Cm',0,'Cn',0);
    end
    
    % =========================================================================
    %% UTILITY FUNCTIONS
    % =========================================================================
    
    function tf = isMemberOrField(obj, name)
        % Checks for a field (if struct) or property (if object).
        if isstruct(obj)
            tf = isfield(obj, name);
        else
            tf = isprop(obj, name);
        end
    end
    
    function value = clamp(value, bounds)
        % Clamps a numerical value within specified lower and upper bounds.
        value = min(max(value, bounds(1)), bounds(2));
    end
    
    function Limits = defaultAerodynamicLimits()
        % Default saturation and stall parameter limits.
        Limits.StallStart          = deg2rad(12);
        Limits.StallEnd            = deg2rad(20);
        Limits.PostStallLiftFactor = 0.40;
        Limits.CL                  = [-2.5,  2.5];
        Limits.CD                  = [ 0.0,  4.0];
        Limits.CX                  = [-3.0,  3.0];
        Limits.CY                  = [-2.0,  2.0];
        Limits.CZ                  = [-4.0,  4.0];
        Limits.Cl                  = [-1.5,  1.5];
        Limits.Cm                  = [-2.0,  2.0];
        Limits.Cn                  = [-1.5,  1.5];
    end