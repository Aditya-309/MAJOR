function Trim = TrimState(Target, Aircraft)
% TRIMSTATE
% Compute steady-state aircraft trim using MATLAB Optimization Toolbox.
%
% Project
%   Adaptive Flight State Reconstruction and Trajectory Estimation using
%   Sensor Fusion and AI
%
% MATLAB Version
%   R2024b
%
% Required Toolboxes
%   • Optimization Toolbox
%   • Parallel Computing Toolbox (optional)
%
% Supported Trim Modes
%
%   "StraightLevel"
%   "Climb"
%   "Descent"
%   "CoordinatedTurn"
%   "Custom"
%
% Supported Solvers
%
%   "lsqnonlin"   (Default)
%   "fsolve"
%   "fmincon"
%
% INPUT
%
%   Target
%
%       .Mode
%       .Solver
%
%       .Airspeed
%       .Altitude
%       .Heading
%       .FlightPathAngle
%       .TurnRate
%
%       .AirDensity
%       .WindBody
%
%       .UseParallel
%
%
%   Aircraft
%
%       config.AircraftConfig
%
%
% OUTPUT
%
%   Trim
%
%       .State
%       .Controls
%
%       .Residual
%       .ResidualNorm
%       .Cost
%
%       .Converged
%       .ExitFlag
%
%       .Output
%       .Optimizer
%
%       .Jacobian
%
%       .ExecutionTime
%
%       .Diagnostics
%

    narginchk(2,2);

    Trim = runTrimSolver( ...
        Target,...
        Aircraft);

end

% =========================================================================
%% MAIN EXECUTION PIPELINE
% =========================================================================

function Trim = runTrimSolver( ...
    Target,...
    Aircraft)

    %% Validate Inputs

    validateTrimInputs( ...
        Target,...
        Aircraft);

    %% Initialize Output

    Trim = initializeTrimOutput();

    %% Build Optimization Problem

    Problem = buildTrimProblem( ...
        Target,...
        Aircraft);

    %% Build Solver Options

    Optimizer = buildOptimizationOptions( ...
        Target);

    %% Start Timer

    Timer = tic;

    %% Solve Trim

    SolverResult = solveTrimProblem( ...
        Problem,...
        Optimizer,...
        Target);

    %% Decode Solution

    [State,...
 Controls] = decodeTrimSolution( ...
    SolverResult.Solution,...
    Target);

    %% Diagnostics

    Diagnostics = computeTrimDiagnostics( ...
        SolverResult,...
        Problem);

    %% Populate Outputs

    Trim.State = State;

    Trim.Controls = Controls;

    Trim.Residual = SolverResult.Residual;

    Trim.ResidualNorm = norm(SolverResult.Residual);

    Trim.Cost = SolverResult.Cost;

    Trim.Converged = SolverResult.Converged;

    Trim.ExitFlag = SolverResult.ExitFlag;

    Trim.Output = SolverResult.Output;

    Trim.Optimizer = Optimizer;

    Trim.Jacobian = SolverResult.Jacobian;

    Trim.ExecutionTime = toc(Timer);

    Trim.Diagnostics = Diagnostics;

    %% Validate Outputs

    validateTrimOutput(Trim);

end
% =========================================================================
%% BUILD TRIM PROBLEM
% =========================================================================

function Problem = buildTrimProblem( ...
    Target,...
    Aircraft)

    %% Initial Guess

    Problem.InitialGuess = ...
        buildInitialGuess( ...
            Target,...
            Aircraft);

    %% Variable Bounds

    [Problem.LowerBounds,...
     Problem.UpperBounds] = ...
        buildOptimizationBounds( ...
            Target,...
            Aircraft);

    %% Residual Function

    Problem.Objective = ...
        @(x)trimResidual( ...
            x,...
            Target,...
            Aircraft);

end

% =========================================================================
%% BUILD OPTIMIZATION OPTIONS
% =========================================================================

function Optimizer = buildOptimizationOptions(Target)

    %% Parallel Computing

    UseParallel = false;

    if isfield(Target,'UseParallel')

        UseParallel = logical(Target.UseParallel);

    end

    %% Solver Selection

    Solver = lower(string(Target.Solver));

    switch Solver

        case "lsqnonlin"

            Options = optimoptions( ...
                'lsqnonlin',...
                'Algorithm','levenberg-marquardt',...
                'Display','iter-detailed',...
                'UseParallel',UseParallel,...
                'FiniteDifferenceType','central',...
                'FiniteDifferenceStepSize',1e-6,...
                'FunctionTolerance',1e-10,...
                'StepTolerance',1e-10,...
                'OptimalityTolerance',1e-10,...
                'MaxIterations',500,...
                'MaxFunctionEvaluations',10000);

        case "fsolve"

            Options = optimoptions( ...
                'fsolve',...
                'Algorithm','trust-region-dogleg',...
                'Display','iter-detailed',...
                'UseParallel',UseParallel,...
                'FiniteDifferenceType','central',...
                'FiniteDifferenceStepSize',1e-6,...
                'FunctionTolerance',1e-10,...
                'StepTolerance',1e-10,...
                'OptimalityTolerance',1e-10,...
                'MaxIterations',500,...
                'MaxFunctionEvaluations',10000);

        case "fmincon"

            Options = optimoptions( ...
                'fmincon',...
                'Algorithm','interior-point',...
                'Display','iter-detailed',...
                'UseParallel',UseParallel,...
                'FiniteDifferenceType','central',...
                'FiniteDifferenceStepSize',1e-6,...
                'OptimalityTolerance',1e-10,...
                'ConstraintTolerance',1e-10,...
                'StepTolerance',1e-10,...
                'MaxIterations',500,...
                'MaxFunctionEvaluations',10000);

        otherwise

            error( ...
                'TrimState:UnknownSolver',...
                'Unsupported optimization solver "%s".',...
                Target.Solver);

    end

    Optimizer.Solver = Solver;

    Optimizer.Options = Options;

end

% =========================================================================
%% SOLVE TRIM PROBLEM
% =========================================================================

function SolverResult = solveTrimProblem( ...
    Problem,...
    Optimizer,...
    Target)

    SolverResult = struct();

    switch Optimizer.Solver

        case "lsqnonlin"

            [x,...
             resnorm,...
             residual,...
             exitflag,...
             output,...
             lambda,...
             jacobian] = ...
                lsqnonlin( ...
                    Problem.Objective,...
                    Problem.InitialGuess,...
                    Problem.LowerBounds,...
                    Problem.UpperBounds,...
                    Optimizer.Options);

            SolverResult.Cost = resnorm;

        case "fsolve"

            [x,...
             residual,...
             exitflag,...
             output,...
             jacobian] = ...
                fsolve( ...
                    Problem.Objective,...
                    Problem.InitialGuess,...
                    Optimizer.Options);

            SolverResult.Cost = norm(residual)^2;

            lambda = [];

        case "fmincon"

            Objective = @(x)sum(Problem.Objective(x).^2);

            [x,...
             cost,...
             exitflag,...
             output,...
             lambda,...
             ~,...
             ~,...
             ~] = ...
                fmincon( ...
                    Objective,...
                    Problem.InitialGuess,...
                    [],[],[],[],...
                    Problem.LowerBounds,...
                    Problem.UpperBounds,...
                    [],...
                    Optimizer.Options);

            residual = Problem.Objective(x);

            jacobian = [];

            SolverResult.Cost = cost;

    end

    SolverResult.Solution = x;

    SolverResult.Residual = residual;

    SolverResult.ExitFlag = exitflag;

    SolverResult.Output = output;

    SolverResult.Jacobian = jacobian;

    SolverResult.Lambda = lambda;

    SolverResult.Converged = exitflag > 0;

end
% =========================================================================
%% BUILD INITIAL GUESS
% =========================================================================

function InitialGuess = buildInitialGuess( ...
    Target,...
    Aircraft)

    %#ok<INUSD>

    %% Airspeed

    V = Target.Airspeed;

    %% Flight Path

    Gamma = Target.FlightPathAngle;

    %% Default Initial Attitude

    Roll  = 0.0;
    Pitch = deg2rad(2);
    Yaw   = Target.Heading;
    %% Default Body Velocity

    u = V;
    v = 0.0;
    w = 0.0;

    %% Default Body Rates

    p = 0.0;
    q = 0.0;
    r = 0.0;

    %% Default Controls

    Elevator = deg2rad(2);

    Aileron = 0.0;

    Rudder = 0.0;

    Throttle = 0.60;
    %% Mode Specific Initial Guess

Mode = lower(string(Target.Mode));

switch Mode

    case "straightlevel"

        Pitch = deg2rad(2);

    case "climb"

        Gamma = Target.FlightPathAngle;

        Pitch = Gamma + deg2rad(2);

        u = V*cos(Gamma);

        w = V*sin(Gamma);

        Elevator = deg2rad(3);

        Throttle = 0.75;

    case "descent"

        Gamma = Target.FlightPathAngle;

        Pitch = Gamma + deg2rad(2);

        u = V*cos(Gamma);

        w = V*sin(Gamma);

        Elevator = deg2rad(1);

        Throttle = 0.40;

    case "coordinatedturn"

        g = config.AircraftConfig.Gravity;

        BankAngle = atan( ...
            V*Target.TurnRate/g);

        Roll = BankAngle;

        Pitch = deg2rad(2);

        r = Target.TurnRate;

        Aileron = deg2rad(1);

        Rudder = deg2rad(0.5);

    case "custom"

        % Leave default guess unchanged

end

    %% Optimization Vector

    InitialGuess = ...
        [
            u
            v
            w

            p
            q
            r

            Roll
            Pitch
            Yaw

            Elevator
            Aileron
            Rudder
            Throttle
        ];

end

% =========================================================================
%% BUILD OPTIMIZATION BOUNDS
% =========================================================================

function [LowerBounds,UpperBounds] = ...
    buildOptimizationBounds( ...
    Target,...
    Aircraft)

    %#ok<INUSD>

    Config = Aircraft.getStruct();

    %% Velocity Bounds

    VelocityLower = ...
        [
            5
           -25
           -25
        ];

    VelocityUpper = ...
        [
            120
             25
             25
        ];

    %% Angular Rate Bounds

    RateLower = deg2rad( ...
        [
        -90
        -90
        -90
        ]);

    RateUpper = deg2rad( ...
        [
         90
         90
         90
        ]);

    %% Euler Bounds

    EulerLower = deg2rad( ...
        [
        -180
         -45
        -180
        ]);

    EulerUpper = deg2rad( ...
        [
         180
          45
         180
        ]);

    %% Control Bounds

    ControlLower = ...
        [
            Config.ElevatorMin
            Config.AileronMin
            Config.RudderMin
            Config.MinimumThrottle
        ];

    ControlUpper = ...
        [
            Config.ElevatorMax
            Config.AileronMax
            Config.RudderMax
            Config.MaximumThrottle
        ];

    %% Assemble

    LowerBounds = ...
        [
            VelocityLower
            RateLower
            EulerLower
            ControlLower
        ];

    UpperBounds = ...
        [
            VelocityUpper
            RateUpper
            EulerUpper
            ControlUpper
        ];

end

% =========================================================================
%% TRIM RESIDUAL
% =========================================================================

function Residual = trimResidual( ...
    X,...
    Target,...
    Aircraft)

    %% Decode Optimization Variables

    [State,...
     Controls] = ...
        decodeTrimSolution( ...
            X,...
            Target);

    %% Environment

    Environment = struct();

    Environment.AirDensity = Target.AirDensity;

    Environment.WindBody = Target.WindBody;

    %% Aircraft Dynamics

    StateDot = ...
        dynamics.AircraftDynamics6DOF( ...
            State,...
            Controls,...
            Environment,...
            Aircraft);

    %% Residual Weighting

    W = getResidualWeights(Target);

    %% Build Residual Vector

    VelocityResidual = ...
        W.Velocity ...
        .* StateDot.VelocityBody;

    AngularResidual = ...
        W.Angular ...
        .* StateDot.AngularRatesBody;

   QuaternionResidual = ...
    W.Quaternion(:) ...
    .* StateDot.Quaternion(2:4).';

QuaternionResidual = QuaternionResidual(:);

    ConstraintResidual = ...
        computeTrimConstraintResidual( ...
            State,...
            Controls,...
            Target);
 
        %% Complete Residual

    %% Force Column Vectors

    VelocityResidual   = VelocityResidual(:);

    AngularResidual    = AngularResidual(:);

    QuaternionResidual = QuaternionResidual(:);

    ConstraintResidual = ConstraintResidual(:);

    %% Residual Scaling
    %
    % Scale residuals so each group has a comparable numerical magnitude.
    % This improves optimizer conditioning and convergence.

    VelocityResidual   = VelocityResidual   ./ 100.0;   % ~100 m/s
    AngularResidual    = AngularResidual    ./ 10.0;    % ~10 rad/s
    QuaternionResidual = QuaternionResidual ./ 1.0;     % Unitless
    ConstraintResidual = ConstraintResidual ./ 1.0;     % Unitless

    %% Assemble Residual Vector

    Residual = [
        VelocityResidual
        AngularResidual
        QuaternionResidual
        ConstraintResidual
    ];

end
% =========================================================================
%% DECODE TRIM SOLUTION
% =========================================================================

function [State,Controls] = decodeTrimSolution( ...
    X,...
    Target)

    %#ok<INUSD>

    %% State

    State = struct();

    State.VelocityBody = X(1:3);

    State.AngularRatesBody = X(4:6);

    State.EulerAngles = X(7:9);

    State.Quaternion = ...
        coordinates.Euler2Quaternion( ...
            X(7),...
            X(8),...
            X(9));

    %% Controls

    Controls = struct();

    Controls.Elevator = X(10);

    Controls.Aileron = X(11);

    Controls.Rudder = X(12);

    Controls.Throttle = X(13);

end

% =========================================================================
%% COMPUTE TRIM CONSTRAINT RESIDUAL
% =========================================================================

function ConstraintResidual = ...
    computeTrimConstraintResidual( ...
    State,...
    Controls,...
    Target)

    %#ok<INUSD>

    Mode = lower(string(Target.Mode));

    switch Mode

        %--------------------------------------------------------------
        case "straightlevel"

            ConstraintResidual = ...
                [
                    State.EulerAngles(1)
                    State.AngularRatesBody(3)
                ];

        %--------------------------------------------------------------
        case "climb"

            FlightPath = ...
                atan2( ...
                State.VelocityBody(3),...
                State.VelocityBody(1));

            ConstraintResidual = ...
                [
                    FlightPath ...
                    - Target.FlightPathAngle
                ];

        %--------------------------------------------------------------
        case "descent"

            FlightPath = ...
                atan2( ...
                State.VelocityBody(3),...
                State.VelocityBody(1));

            ConstraintResidual = ...
                [
                    FlightPath ...
                    - Target.FlightPathAngle
                ];

        %--------------------------------------------------------------
        case "coordinatedturn"

            ConstraintResidual = ...
                [
                    State.AngularRatesBody(3) ...
                    - Target.TurnRate

                    State.VelocityBody(2)
                ];

        %--------------------------------------------------------------
        case "custom"

            ConstraintResidual = zeros(0,1);

        %--------------------------------------------------------------
        otherwise

            error( ...
                'TrimState:UnknownTrimMode',...
                'Unsupported trim mode "%s".',...
                Target.Mode);

    end

end

% =========================================================================
%% RESIDUAL WEIGHTS
% =========================================================================

function W = getResidualWeights(Target)

    %#ok<INUSD>

    W = struct();

    %% Translational Dynamics

    W.Velocity = ...
        [
        10
        10
        10
        ];

    %% Rotational Dynamics

    W.Angular = ...
        [
        50
        50
        50
        ];

    %% Quaternion Dynamics

    W.Quaternion = ...
        [
        20
        20
        20
        ];

end

% =========================================================================
%% COMPUTE TRIM DIAGNOSTICS
% =========================================================================

function Diagnostics = ...
    computeTrimDiagnostics( ...
    SolverResult,...
    Problem)

    Diagnostics = struct();

    Diagnostics.ResidualNorm = ...
        norm(SolverResult.Residual);

    Diagnostics.MaximumResidual = ...
        max(abs(SolverResult.Residual));

    Diagnostics.NumberOfVariables = ...
        numel(Problem.InitialGuess);

    Diagnostics.NumberOfResiduals = ...
        numel(SolverResult.Residual);

    Diagnostics.Iterations = ...
        SolverResult.Output.iterations;

    Diagnostics.FunctionEvaluations = ...
        SolverResult.Output.funcCount;

    Diagnostics.FirstOrderOptimality = [];

    if isfield(SolverResult.Output,...
            'firstorderopt')

        Diagnostics.FirstOrderOptimality = ...
            SolverResult.Output.firstorderopt;

    end

    Diagnostics.Solver = [];

    if isfield(SolverResult.Output,...
            'algorithm')

        Diagnostics.Solver = ...
            SolverResult.Output.algorithm;

    end

    Diagnostics.Success = ...
        SolverResult.Converged;

end
% =========================================================================
%% INITIALIZE OUTPUT
% =========================================================================

function Trim = initializeTrimOutput()

    Trim = struct();

    %% Solution

    Trim.State = struct();

    Trim.Controls = struct();

    %% Optimization Results
    
    Trim.Residual = [];

    Trim.ResidualNorm = NaN;

    Trim.Cost = NaN;

    Trim.Converged = false;

    Trim.ExitFlag = 0;

    Trim.Output = struct();

    Trim.Optimizer = struct();

    Trim.Jacobian = [];

    Trim.ExecutionTime = NaN;

    Trim.Diagnostics = struct();

end

% =========================================================================
%% INPUT VALIDATION
% =========================================================================

function validateTrimInputs( ...
    Target,...
    Aircraft)

    %% Target

    if ~isstruct(Target)

        error( ...
            'TrimState:InvalidTarget',...
            'Target must be a structure.');

    end

    RequiredFields = ...
        {
        'Mode'
        'Solver'
        'Airspeed'
        'Altitude'
        'Heading'
        'FlightPathAngle'
        'TurnRate'
        'AirDensity'
        'WindBody'
        };

    for k = 1:numel(RequiredFields)

        if ~isfield(Target,RequiredFields{k})

            error( ...
                'TrimState:MissingField',...
                'Target.%s is required.',...
                RequiredFields{k});

        end

    end

    %% Aircraft

    if ~( ...
            isa(Aircraft,'config.AircraftConfig') || ...
            isstruct(Aircraft))

        error( ...
            'TrimState:InvalidAircraft',...
            'Aircraft must be config.AircraftConfig or a compatible structure.');

    end

    %% Numerical Validation

    validateattributes( ...
        Target.Airspeed,...
        {'numeric'},...
        {'real','finite','scalar','positive'},...
        mfilename,...
        'Target.Airspeed');

    validateattributes( ...
        Target.Altitude,...
        {'numeric'},...
        {'real','finite','scalar'},...
        mfilename,...
        'Target.Altitude');

    validateattributes( ...
        Target.Heading,...
        {'numeric'},...
        {'real','finite','scalar'},...
        mfilename,...
        'Target.Heading');

    validateattributes( ...
        Target.FlightPathAngle,...
        {'numeric'},...
        {'real','finite','scalar'},...
        mfilename,...
        'Target.FlightPathAngle');

    validateattributes( ...
        Target.TurnRate,...
        {'numeric'},...
        {'real','finite','scalar'},...
        mfilename,...
        'Target.TurnRate');

    validateattributes( ...
        Target.AirDensity,...
        {'numeric'},...
        {'real','finite','positive','scalar'},...
        mfilename,...
        'Target.AirDensity');

    validateattributes( ...
        Target.WindBody,...
        {'numeric'},...
        {'real','finite','size',[3 1]},...
        mfilename,...
        'Target.WindBody');

    %% Mode Validation

    SupportedModes = ...
        [
        "StraightLevel"
        "Climb"
        "Descent"
        "CoordinatedTurn"
        "Custom"
        ];

    if ~any(strcmpi(Target.Mode,SupportedModes))

        error( ...
            'TrimState:UnsupportedMode',...
            'Unsupported trim mode.');

    end

    %% Solver Validation

    SupportedSolvers = ...
        [
        "lsqnonlin"
        "fsolve"
        "fmincon"
        ];

    if ~any(strcmpi(Target.Solver,SupportedSolvers))

        error( ...
            'TrimState:UnsupportedSolver',...
            'Unsupported optimization solver.');

    end

end

% =========================================================================
%% OUTPUT VALIDATION
% =========================================================================

function validateTrimOutput(Trim)

    RequiredFields = ...
        {
        'State'
        'Controls'
        'Residual'
        'ResidualNorm'
        'Cost'
        'Converged'
        'ExitFlag'
        'Output'
        'Optimizer'
        'Jacobian'
        'ExecutionTime'
        'Diagnostics'
        };

    for k = 1:numel(RequiredFields)

        if ~isfield(Trim,RequiredFields{k})

            error( ...
                'TrimState:InvalidOutput',...
                'Trim.%s missing.',...
                RequiredFields{k});

        end

    end

    if ~isstruct(Trim.State)

        error( ...
            'TrimState:InvalidState',...
            'Trim.State must be a structure.');

    end

    if ~isstruct(Trim.Controls)

        error( ...
            'TrimState:InvalidControls',...
            'Trim.Controls must be a structure.');

    end

    validateattributes( ...
        Trim.ResidualNorm,...
        {'numeric'},...
        {'real','finite','scalar'},...
        mfilename,...
        'ResidualNorm');

    validateattributes( ...
        Trim.Cost,...
        {'numeric'},...
        {'real','finite','scalar'},...
        mfilename,...
        'Cost');

    validateattributes( ...
        Trim.ExecutionTime,...
        {'numeric'},...
        {'real','finite','scalar','nonnegative'},...
        mfilename,...
        'ExecutionTime');

end