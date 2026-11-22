function [x0, P0, InitInfo] = InitializeState(Data, Timeline, Config)
%INITIALSTATE Build the defensible initial state and covariance.
%
%   [x0, P0, InitInfo] = INITIALIZESTATE(Data, Timeline, Config) forms
%   the 15-state initial estimate strictly from sensor measurements and
%   documented configuration. Ground truth is never read. The simulator's
%   realized sensor biases are never read.
%
%   Navigation origin (task document 9.1)
%   --------------------------------------
%   The local NED anchor is the FIRST ELIGIBLE GNSS position measurement
%   (OriginPolicy = 'FirstEligibleGNSSFix'). Position is expressed
%   relative to that fix for the whole reconstruction.
%
%   Initialization time and alignment search
%   ---------------------------------------
%   The startup of this corpus contains a simulator transient and, in
%   several runs, a short maneuver, so accelerometer leveling is only
%   permitted in a window where LOW-DYNAMIC CONDITIONS ARE VERIFIED. The
%   alignment search therefore scans consecutive non-overlapping windows
%   of Initialization.Window_s forward from the anchor time and selects
%   the FIRST window that verifies. t_init is the END of that window, so
%   every sample used by the initialization lies at or before t_init
%   (strict forward causality for everything the filter produces).
%
%   Low-dynamic verification (robust, bias-aware):
%       - specific force magnitude: |median(f)| within tolerance of
%         standard gravity (confirms negligible non-gravitational
%         acceleration);
%       - specific force DIRECTION: the largest angular deviation of any
%         window sample from the median direction must stay within the
%         tolerance (genuine roll/pitch rotation turns the specific
%         force even when the gyroscope carries a constant bias);
%       - gyroscope: the maximum deviation of any sample in the window
%         from the window median must stay within the tolerance
%         (rate variation; a constant sensor bias is not rotation and is
%         deliberately NOT rejected here);
%       - magnetic field direction (when the window holds eligible
%         magnetometer samples): the largest angular deviation of the
%         field direction must stay within its tolerance (pure yaw
%         rotation leaves the gravity direction untouched and is only
%         visible in the magnetic direction).
%   All tolerances are derived from the Block 5 noise parameters
%   (5 sigma; accel: turn-on bias plus discrete white noise; gyro:
%   discrete white noise; mag: noise over field magnitude) and are
%   recorded with their derivation. Rejected windows and their failing
%   statistics are recorded in InitInfo.
%
%   Position and velocity at t_init (task document 9.1)
%   ---------------------------------------------------
%   The initial position is the NED position of the most recent eligible
%   GNSS position measurement at or before t_init and the initial
%   velocity is the most recent eligible GNSS NED velocity measurement
%   at or before t_init. No value is ever invented; the exact source rows
%   are recorded. (Whenever the alignment window contains no later fix,
%   these are exactly the first eligible measurements.)
%
%   Attitude (task document 9.2)
%   ----------------------------
%   AttitudeSource='AccelerometerMagnetometer' (default):
%       roll and pitch from accelerometer leveling over the verified
%       window (medians, robust), yaw from magnetometer heading against
%       the WMM reference field at the initial position (the validated
%       reference model shared with the measurement model,
%       MagneticReferenceNED; same model, epoch and conventions as the
%       frozen simulator).
%   AttitudeSource='Prior': the configured prior angles and standard
%   deviations are used and their Provenance text is recorded.
%   When neither path is available, initialization stops with an explicit
%   error; zero attitude is never assumed to be a measurement.
%
%   Config.Initialization.AlignmentWindow = 'Trailing' restricts the
%   search to the single window ending at the anchor time (strictly
%   causal relative to the anchor; usually unusable when a run starts
%   with a transient). 'Forward' (default) searches forward from the
%   anchor and places t_init at the verified window end.
%
%   Biases (task document 9.3)
%   --------------------------
%   Initial biases are zero-mean. Their covariance diagonal comes from
%   the Block 5 turn-on bias sigmas. The realized simulator bias is never
%   used. Where realized biases exceed the configured prior, the
%   estimation report exposes the resulting consistency evidence instead
%   of hiding it.
%
%   Outputs:
%       x0       - 15x1 initial state
%       P0       - 15x15 initial covariance (block structured)
%       InitInfo - evidence record: anchor, t_init, source rows used,
%                  alignment search evidence, low-dynamic verification
%                  results and derived tolerances, attitude sigmas and
%                  their derivation, bias priors, warnings
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: BuildMeasurementTimeline, StateDefinition, ConvertLLA2NED.

    Definition = estimation.StateDefinition( ...
        isfield(Config.State, 'EnableGNSSBiasStates') && ...
        Config.State.EnableGNSSBiasStates);
    Warnings = {};

    Events = Timeline.Events;
    Codes = Timeline.EventCodes;

    % Integrity cross-check: the timeline must belong to this input.
    if ~isfield(Timeline, 'BuiltFrom') || ...
            ~strcmp(Timeline.BuiltFrom.PreprocessID, ...
            Data.RunInfo.PreprocessID)

        error( ...
            'Estimation:InitializeState:TimelineInputMismatch', ...
            ['The supplied timeline was not built from the supplied ', ...
             'preprocessed run.']);

    end

    %% First eligible GNSS position fix (navigation origin)

    PosRows = find(Events.Type == Codes.GNSSPosition & Events.Eligible);

    if isempty(PosRows)

        error( ...
            'Estimation:InitializeState:NoEligibleGNSSPosition', ...
            ['No eligible GNSS position measurement exists; the ', ...
             'initialization policy forbids inventing an initial ', ...
             'position.']);

    end

    AnchorEvent = PosRows(1);
    t_anchor = Events.Time_s(AnchorEvent);

    Anchor = struct();
    Anchor.Latitude_rad = Events.Z(AnchorEvent, 1);
    Anchor.Longitude_rad = Events.Z(AnchorEvent, 2);
    Anchor.Altitude_m = Events.Z(AnchorEvent, 3);
    Anchor.SourceRowIdx = Events.SourceRowIdx(AnchorEvent);
    Anchor.Time_s = t_anchor;
    Anchor.Policy = Config.Initialization.OriginPolicy;

    %% Noise-derived tolerances (Block 5 provenance)

    NoiseIMU = Config.Noise.IMU;
    NoiseMag = Config.Noise.Magnetometer;

    IMURows = find(Events.Type == Codes.IMUPropagation & Events.Eligible);

    if numel(IMURows) >= 2
        dt_med = median(diff(Events.Time_s(IMURows)));
    else
        dt_med = 0.01;
        Warnings{end + 1} = [ ...
            'Too few eligible IMU samples to measure the sample ', ...
            'interval; the 0.01 s code default was used for the noise ', ...
            'derivation and is recorded as a code default.'];
    end

    AccelDiscreteSigma = sqrt( ...
        NoiseIMU.AccelTurnOnBiasSigma_mps2 ^ 2 + ...
        (NoiseIMU.AccelVRW_mps2SqrtHz ^ 2) / dt_med);
    GyroDiscreteSigma = ...
        (NoiseIMU.GyroARW_radpsSqrtHz) / sqrt(dt_med);

    AccelTolerance_mps2 = 5 * AccelDiscreteSigma;
    GyroDeviationTolerance_radps = 5 * GyroDiscreteSigma;

    g = dynamics.GravityModel("NED");
    g = norm(g);

    %% Alignment search

    Window_s = Config.Initialization.Window_s;
    MaxSearchWindows = 200;

    SearchEvidence = struct( ...
        'Mode', Config.Initialization.AlignmentWindow, ...
        'Window_s', Window_s, ...
        'Windows', struct('Start_s', {}, 'End_s', {}, 'Verified', {}, ...
            'AccelDeviation_mps2', {}, 'GyroDeviation_radps', {}, ...
            'AccelDirectionDeviation_rad', {}, ...
            'MagDirectionDeviation_rad', {}, 'SampleCount', {}), ...
        'Tolerances', struct( ...
            'AccelTolerance_mps2', AccelTolerance_mps2, ...
            'GyroDeviationTolerance_radps', ...
                GyroDeviationTolerance_radps, ...
            'AccelDirectionTolerance_rad', ...
                5 * AccelDiscreteSigma / g, ...
            'MagDirectionTolerance', [ ...
                '5 * Magnetometer.Sigma_T / |B_median| (small-angle ', ...
                'form); applied when the window holds >= 2 eligible ', ...
                'magnetometer samples.'], ...
            'Derivation', [ ...
                '5 sigma of Block 5 discrete white noise (gyro ', ...
                'ARW/sqrt(dt), deviation-based so a constant bias is ', ...
                'not treated as rotation) and of turn-on bias plus ', ...
                'discrete white noise (accel); dt measured over ', ...
                'eligible IMU samples.']));

    VerifiedWindow = [];
    WindowIndex = 0;

    while WindowIndex < MaxSearchWindows

        switch Config.Initialization.AlignmentWindow

            case 'Forward'
                WindowStart = t_anchor + WindowIndex * Window_s;
                WindowEnd = WindowStart + Window_s;

            case 'Trailing'
                WindowStart = t_anchor - Window_s;
                WindowEnd = t_anchor;

            otherwise

                error( ...
                    'Estimation:InitializeState:InvalidAlignmentWindow', ...
                    ['Initialization.AlignmentWindow must be ', ...
                     '''Forward'' or ''Trailing''.']);

        end

        InWindow = Events.Time_s >= WindowStart & ...
            Events.Time_s <= WindowEnd;
        WindowRows = find(InWindow & ...
            Events.Type == Codes.IMUPropagation & Events.Eligible);

        WindowIndex = WindowIndex + 1;
        Entry = struct();
        Entry.Start_s = WindowStart;
        Entry.End_s = WindowEnd;
        Entry.SampleCount = numel(WindowRows);
        Entry.Verified = false;
        Entry.AccelDeviation_mps2 = NaN;
        Entry.GyroDeviation_radps = NaN;
        Entry.AccelDirectionDeviation_rad = NaN;
        Entry.MagDirectionDeviation_rad = NaN;

        MinStabilitySamples = Config.Initialization.MinStabilitySamples;

        if numel(WindowRows) >= MinStabilitySamples

            AccelWindow = Events.Z(WindowRows, 1:3);
            GyroWindow = Events.Z(WindowRows, 4:6);

            AccelMedian = median(AccelWindow, 1);
            GyroMedian = median(GyroWindow, 1);

            AccelDeviation = abs(norm(AccelMedian) - g);
            GyroDeviation = max(abs(GyroWindow - ...
                repmat(GyroMedian, numel(WindowRows), 1)), [], 'all');

            % Specific-force DIRECTION stability: genuine rotation turns
            % the specific-force direction even when the gyroscope
            % carries a constant bias (which the variation check
            % deliberately tolerates). Threshold: 5 sigma of the
            % accelerometer noise expressed as an angle (sigma_a / g).
            AccelDirectionDeviation = 0;
            UnitMedian = AccelMedian / max(norm(AccelMedian), realmin);

            for Sample = 1:numel(WindowRows)

                Unit = AccelWindow(Sample, :) / ...
                    max(norm(AccelWindow(Sample, :)), realmin);
                Angle = atan2(norm(cross(UnitMedian, Unit)), ...
                    dot(UnitMedian, Unit));
                AccelDirectionDeviation = max( ...
                    AccelDirectionDeviation, Angle);

            end

            AccelDirectionTolerance_rad = ...
                5 * AccelDiscreteSigma / g;

            % Magnetic-direction stability: pure yaw rotation leaves the
            % gravity direction untouched but turns the magnetic
            % direction, so heading alignment needs its own criterion.
            % Threshold: 5 sigma of the magnetometer noise over the
            % median field magnitude (small-angle form).
            MagWindowRows = find(InWindow & ...
                Events.Type == Codes.MagneticField & Events.Eligible);
            MagDirectionDeviation = NaN;
            % Reviewer finding F8: stability is NOT demonstrated vacuously.
            % With fewer than MinStabilitySamples eligible magnetometer
            % samples the window fails the heading-stability criterion.
            MagDirectionStable = false;

            if numel(MagWindowRows) >= MinStabilitySamples

                MagW = Events.Z(MagWindowRows, 1:3);
                MagMed = median(MagW, 1);
                UnitMed = MagMed / max(norm(MagMed), realmin);
                MagDirectionDeviation = 0;

                for Sample = 1:size(MagW, 1)

                    Unit = MagW(Sample, :) / ...
                        max(norm(MagW(Sample, :)), realmin);
                    Angle = atan2(norm(cross(UnitMed, Unit)), ...
                        dot(UnitMed, Unit));
                    MagDirectionDeviation = max( ...
                        MagDirectionDeviation, Angle);

                end

                MagTolerance = 5 * NoiseMag.Sigma_T / ...
                    max(norm(MagMed), realmin);
                MagDirectionStable = ...
                    MagDirectionDeviation <= MagTolerance;

            end

            Entry.AccelDeviation_mps2 = AccelDeviation;
            Entry.GyroDeviation_radps = GyroDeviation;
            Entry.AccelDirectionDeviation_rad = AccelDirectionDeviation;
            Entry.MagDirectionDeviation_rad = MagDirectionDeviation;
            Entry.Verified = ...
                AccelDeviation <= AccelTolerance_mps2 && ...
                GyroDeviation <= GyroDeviationTolerance_radps && ...
                AccelDirectionDeviation <= ...
                AccelDirectionTolerance_rad && ...
                MagDirectionStable;

        end

        SearchEvidence.Windows(end + 1) = Entry;

        if Entry.Verified
            VerifiedWindow = Entry;
            break
        end

        if strcmp(Config.Initialization.AlignmentWindow, 'Trailing')
            break
        end

    end

    if isempty(VerifiedWindow)

        error( ...
            'Estimation:InitializeState:LowDynamicNotVerified', ...
            ['No alignment window verified low-dynamic conditions ', ...
             'within %d searched windows (window %.3f s, mode %s). ', ...
             'Accelerometer leveling is not permitted; supply an ', ...
             'independent attitude prior to continue.'], ...
            numel(SearchEvidence.Windows), Window_s, ...
            Config.Initialization.AlignmentWindow);

    end

    t_init = VerifiedWindow.End_s;
    WindowStart = VerifiedWindow.Start_s;
    WindowEnd = VerifiedWindow.End_s;

    AlignmentEvidence = SearchEvidence;
    AlignmentEvidence.SelectedWindow = VerifiedWindow;
    AlignmentEvidence.CausalityNote = [ ...
        't_init is the end of the verified alignment window, so every ', ...
        'sample used by the initialization lies at or before t_init. ', ...
        'Forward filter outputs never use measurements beyond their ', ...
        'own timestamps.'];

    %% Position and velocity at t_init (most recent eligible at or before)

    PosBefore = PosRows(Events.Time_s(PosRows) <= t_init);

    if isempty(PosBefore)

        error( ...
            'Estimation:InitializeState:NoGNSSPositionBeforeInit', ...
            ['No eligible GNSS position measurement exists at or ', ...
             'before t_init; the policy forbids inventing one.']);

    end

    PosEvent = PosBefore(end);

    [North, East, Down] = estimation.ConvertLLA2NED( ...
        Events.Z(PosEvent, 1), Events.Z(PosEvent, 2), ...
        Events.Z(PosEvent, 3), Anchor);

    x0 = zeros(Definition.Count, 1);
    x0(Definition.Index.pN:Definition.Index.pD) = [North; East; Down];

    VelRows = find(Events.Type == Codes.GNSSVelocity & Events.Eligible);
    VelBefore = VelRows(Events.Time_s(VelRows) <= t_init);

    if isempty(VelBefore)

        error( ...
            'Estimation:InitializeState:NoGNSSVelocityBeforeInit', ...
            ['No eligible GNSS velocity measurement exists at or ', ...
             'before t_init; the policy forbids inventing one.']);

    end

    VelEvent = VelBefore(end);
    x0(Definition.Index.vN:Definition.Index.vD) = ...
        Events.Z(VelEvent, 1:3)';

    %% Attitude determination

    AttitudeSource = Config.Initialization.AttitudeSource;
    AttitudeEvidence = struct();
    AttitudeEvidence.Source = AttitudeSource;

    InWindow = Events.Time_s >= WindowStart & ...
        Events.Time_s <= WindowEnd;
    WindowIMURows = find(InWindow & ...
        Events.Type == Codes.IMUPropagation & Events.Eligible);
    WindowMagRows = find(InWindow & ...
        Events.Type == Codes.MagneticField & Events.Eligible);

    % Statistical audit S1: the leveling tilt error and the zero-mean
    % accel-bias prior share the same unknown turn-on bias, so they are
    % jointly distributed (not independent). The joint-prior quantities
    % are computed in the leveling branch and applied to P0 below.
    LevelingJ = zeros(2, 3);
    AttCov2 = zeros(2, 2);
    AttBiasCross = zeros(2, 3);

    if strcmp(AttitudeSource, 'Prior')

        Prior = Config.Initialization.PriorAttitude;

        x0(Definition.Index.roll) = Prior.roll_rad;
        x0(Definition.Index.pitch) = Prior.pitch_rad;
        x0(Definition.Index.yaw) = Prior.yaw_rad;

        AttitudeSigma_rad = Prior.sigma_rad(:);
        AttitudeEvidence.PriorProvenance = Prior.Provenance;
        AttitudeEvidence.Roll_rad = Prior.roll_rad;
        AttitudeEvidence.Pitch_rad = Prior.pitch_rad;
        AttitudeEvidence.Yaw_rad = Prior.yaw_rad;

    else

        % Median accelerometer over the verified window.
        AccelMedian = median(Events.Z(WindowIMURows, 1:3), 1);
        AccelNorm = norm(AccelMedian);

        % Leveling: f = g*[sin(theta); -sin(phi)cos(theta);
        %                  -cos(phi)cos(theta)] (specific-force
        % convention f = a - g, body X-fwd Y-right Z-down; see
        % StateTransitionModel).
        roll0 = atan2(-AccelMedian(2), -AccelMedian(3));
        pitch0 = asin(max(-1, min(1, AccelMedian(1) / AccelNorm)));

        x0(Definition.Index.roll) = roll0;
        x0(Definition.Index.pitch) = pitch0;

        AttitudeEvidence.Roll_rad = roll0;
        AttitudeEvidence.Pitch_rad = pitch0;
        AttitudeEvidence.SourceRowsIMU = ...
            Events.SourceRowIdx(WindowIMURows);
        AttitudeEvidence.LowDynamic = VerifiedWindow;

        % Leveling uncertainty: noise on the median over N samples;
        % turn-on bias does not average out.
        NSamples = numel(WindowIMURows);
        AccelMedianSigma = sqrt( ...
            NoiseIMU.AccelTurnOnBiasSigma_mps2 ^ 2 + ...
            (NoiseIMU.AccelVRW_mps2SqrtHz ^ 2) / dt_med / NSamples);
        RollPitchSigma = AccelMedianSigma / g;

        % Statistical audit S1: exact leveling map Jacobian and joint
        % attitude/bias prior. With a zero-mean bias prior the leveling
        % error is delta_theta = J_level * b_a and the bias-state error is
        % delta_b = -b_a, hence
        %   Var(delta_theta)      = J*(Sigma_a + Sigma_n)*J'
        %   Cov(delta_theta,db)   = -J*Sigma_a
        % (Sigma_a = turn-on bias variance, Sigma_n = median noise
        % variance above). All terms are derived from the Block 5 noise
        % model; none is tuned. The joint block is positive semidefinite
        % by construction.
        LevelingJ = levelingJacobian(AccelMedian);
        SigmaA = NoiseIMU.AccelTurnOnBiasSigma_mps2 ^ 2;
        SigmaN = (NoiseIMU.AccelVRW_mps2SqrtHz ^ 2) / dt_med / NSamples;
        AttCov2 = (SigmaA + SigmaN) * (LevelingJ * LevelingJ');
        AttBiasCross = -LevelingJ * (SigmaA * eye(3));

        % Yaw from magnetometer heading against the WMM reference.
        % Reviewer finding F8: require sufficient eligible samples AND
        % the demonstrated directional stability of the verified window
        % (a single sample can neither demonstrate stability nor support
        % a robust median heading).
        MinStabilitySamples = Config.Initialization.MinStabilitySamples;
        MagStabilityDemonstrated = ...
            isfield(VerifiedWindow, 'MagDirectionDeviation_rad') && ...
            isfinite(VerifiedWindow.MagDirectionDeviation_rad);

        if Config.Magnetometer.EnableUpdates && ...
                numel(WindowMagRows) >= MinStabilitySamples && ...
                MagStabilityDemonstrated

            MagMedian = median(Events.Z(WindowMagRows, 1:3), 1)';

            PosLLA = [Events.Z(PosEvent, 1), Events.Z(PosEvent, 2), ...
                Events.Z(PosEvent, 3)];
            B_NED = estimation.MagneticReferenceNED( ...
                PosLLA(1), PosLLA(2), PosLLA(3), ...
                Config.Magnetometer.ModelYear);

            % Level-frame vector: since B_body = Rx(-phi)*Ry(-theta)*
            % Rz(-psi)*B_NED, the heading is isolated by applying the
            % attitude rotations with POSITIVE angles:
            %   B_level = Ry(theta)*Rx(roll)*B_body = Rz(-psi)*B_NED.
            RxPlus = [1, 0, 0; ...
                0, cos(roll0), -sin(roll0); ...
                0, sin(roll0), cos(roll0)];
            RyPlus = [cos(pitch0), 0, sin(pitch0); ...
                0, 1, 0; ...
                -sin(pitch0), 0, cos(pitch0)];
            B_level = RyPlus * RxPlus * MagMedian;

            GammaField = atan2(B_NED(2), B_NED(1));
            DeltaBody = atan2(B_level(2), B_level(1));
            yaw0 = estimation.WrapAngle(GammaField - DeltaBody);

            x0(Definition.Index.yaw) = yaw0;
            AttitudeEvidence.Yaw_rad = yaw0;
            AttitudeEvidence.YawSource = 'MagnetometerHeading';
            AttitudeEvidence.SourceRowsMag = ...
                Events.SourceRowIdx(WindowMagRows);
            AttitudeEvidence.MagMedianBody_T = MagMedian;
            AttitudeEvidence.MagReferenceNED_T = B_NED;
            AttitudeEvidence.MagSampleCount = numel(WindowMagRows);
            AttitudeEvidence.MagReferencePosition = PosLLA;

            HorizontalField = norm(B_NED(1:2));

            if HorizontalField <= 0

                error( ...
                    'Estimation:InitializeState:UnusableMagneticReference', ...
                    ['The WMM reference has zero horizontal component ', ...
                     'at the initial position; magnetic heading is ', ...
                     'undefined.']);

            end

            MagMedianSigma = ...
                NoiseMag.Sigma_T / sqrt(numel(WindowMagRows));
            YawSigma = MagMedianSigma / HorizontalField;

        else

            error( ...
                'Estimation:InitializeState:YawUnresolvable', ...
                ['Yaw cannot be initialized: no eligible magnetometer ', ...
                 'measurement exists in the verified alignment window ', ...
                 '(or magnetometer updates are disabled) and no ', ...
                 'independent attitude prior is configured.']);

        end

        AttitudeSigma_rad = [RollPitchSigma; RollPitchSigma; YawSigma];
        if any(AttCov2(:))
            AttitudeSigma_rad(1:2) = sqrt(diag(AttCov2));
        end
        AttitudeEvidence.SigmaDerivation = [ ...
            'Roll/pitch: (turn-on bias plus averaged VRW noise) / g; ', ...
            'yaw: averaged magnetometer noise over the WMM horizontal ', ...
            'field magnitude.'];

    end

    %% Pitch-singularity proximity check on the initial attitude

    pitch_deg = rad2deg(abs(x0(Definition.Index.pitch)));

    if pitch_deg >= Config.State.PitchWarning_deg

        Warnings{end + 1} = sprintf( ...
            ['Initial pitch magnitude %.2f deg is at or beyond the ', ...
             'Euler pitch-singularity warning threshold %.2f deg.'], ...
            pitch_deg, Config.State.PitchWarning_deg);

    end

    %% Initial covariance

    P0 = zeros(Definition.Count);

    NoiseGNSS = Config.Noise.GNSS;

    if NoiseGNSS.IncludeBiasInR

        PosVar = [ ...
            NoiseGNSS.HorizontalSigma_m ^ 2 + ...
                NoiseGNSS.BiasSigmaHorizontal_m ^ 2; ...
            NoiseGNSS.HorizontalSigma_m ^ 2 + ...
                NoiseGNSS.BiasSigmaHorizontal_m ^ 2; ...
            NoiseGNSS.VerticalSigma_m ^ 2 + ...
                NoiseGNSS.BiasSigmaVertical_m ^ 2];

    else

        PosVar = [ ...
            NoiseGNSS.HorizontalSigma_m ^ 2; ...
            NoiseGNSS.HorizontalSigma_m ^ 2; ...
            NoiseGNSS.VerticalSigma_m ^ 2];

    end

    VelVar = repmat(NoiseGNSS.VelocitySigma_mps ^ 2, 3, 1);

    P0(Definition.Index.pN:Definition.Index.pD, ...
        Definition.Index.pN:Definition.Index.pD) = diag(PosVar);
    P0(Definition.Index.vN:Definition.Index.vD, ...
        Definition.Index.vN:Definition.Index.vD) = diag(VelVar);
    P0(Definition.Index.roll:Definition.Index.yaw, ...
        Definition.Index.roll:Definition.Index.yaw) = ...
        diag(AttitudeSigma_rad .^ 2);
    P0(Definition.Index.bax:Definition.Index.baz, ...
        Definition.Index.bax:Definition.Index.baz) = ...
        eye(3) * NoiseIMU.AccelTurnOnBiasSigma_mps2 ^ 2;
    P0(Definition.Index.bgx:Definition.Index.bgz, ...
        Definition.Index.bgx:Definition.Index.bgz) = ...
        eye(3) * NoiseIMU.GyroTurnOnBiasSigma_radps ^ 2;

    % Statistical audit S1: apply the joint leveling/bias prior derived in
    % the leveling branch (zero elsewhere). The cross block is what keeps
    % the unobservable attitude/bias direction from being over-shrunk by
    % updates that constrain only their combination.
    if any(AttCov2(:))
        AttSpan = Definition.Index.roll:Definition.Index.pitch;
        BiasSpan = Definition.Index.bax:Definition.Index.baz;
        P0(AttSpan, AttSpan) = AttCov2;
        P0(AttSpan, BiasSpan) = AttBiasCross;
        P0(BiasSpan, AttSpan) = AttBiasCross';
    end

    % GNSS position-bias states (augmentation A1): zero-mean prior with
    % Block 5 bias sigmas; the joint position/bias prior carries the
    % exact cross term Cov(delta_p, delta_b) = -Sigma_b (first fix
    % z = p + b + n, x0(p) = z, x0(b) = 0) - the same honest-joint-prior
    % treatment as the leveling/bias block above.
    if Definition.EnableGNSSBiasStates
        PSpan = Definition.Index.pN:Definition.Index.pD;
        GSpan = Definition.Index.bgn:Definition.Index.bgd;
        BiasVar = [ ...
            NoiseGNSS.BiasSigmaHorizontal_m ^ 2; ...
            NoiseGNSS.BiasSigmaHorizontal_m ^ 2; ...
            NoiseGNSS.BiasSigmaVertical_m ^ 2];
        P0(GSpan, GSpan) = diag(BiasVar);
        P0(PSpan, GSpan) = -diag(BiasVar);
        P0(GSpan, PSpan) = -diag(BiasVar);
    end

    %% Init info

    InitInfo = struct();
    InitInfo.LevelingJacobian = LevelingJ;
    InitInfo.AttBiasCrossCovariance = AttBiasCross;
    % Reviewer finding F3: the initial propagation input. The documented
    % ZOH rule is "the most recent eligible IMU sample at or before the
    % interval start"; the first interval [t_init, first event] therefore
    % needs the sample at or before t_init - the last eligible IMU row of
    % the verified alignment window. Provenance (source row, timestamp,
    % segment) is recorded; RunFilter seeds the held input from it.
    if ~isempty(WindowIMURows)
        LastIMURow = WindowIMURows(end);
        InitInfo.InitialIMU = struct( ...
            'Accel_mps2', Events.Z(LastIMURow, 1:3)', ...
            'Gyro_radps', Events.Z(LastIMURow, 4:6)', ...
            'Time_s', Events.Time_s(LastIMURow), ...
            'SourceRowIdx', Events.SourceRowIdx(LastIMURow), ...
            'SegmentID', Events.SegmentID(LastIMURow), ...
            'Provenance', [ ...
                'Last eligible IMU sample of the verified alignment ', ...
                'window (at or before t_init).']);
    else
        InitInfo.InitialIMU = struct( ...
            'Accel_mps2', [], 'Gyro_radps', [], 'Time_s', NaN, ...
            'SourceRowIdx', NaN, 'SegmentID', NaN, ...
            'Provenance', ...
            'No eligible IMU sample existed in the alignment window.');
    end

    InitInfo.t_anchor_s = t_anchor;
    InitInfo.t_init_s = t_init;
    InitInfo.Anchor = Anchor;
    InitInfo.Attitude = AttitudeEvidence;
    InitInfo.Alignment = AlignmentEvidence;
    InitInfo.PositionSourceRowIdx = Events.SourceRowIdx(PosEvent);
    InitInfo.PositionSourceTime_s = Events.Time_s(PosEvent);
    InitInfo.GNSSVelocitySourceRowIdx = Events.SourceRowIdx(VelEvent);
    InitInfo.GNSSVelocityTime_s = Events.Time_s(VelEvent);
    InitInfo.BiasPrior = struct( ...
        'Mean_mps2', zeros(3, 1), ...
        'Mean_radps', zeros(3, 1), ...
        'AccelSigma_mps2', NoiseIMU.AccelTurnOnBiasSigma_mps2, ...
        'GyroSigma_radps', NoiseIMU.GyroTurnOnBiasSigma_radps, ...
        'Provenance', [ ...
            'Zero mean; covariance from Block 5 turn-on bias sigmas. ', ...
            'The simulator bias realization is never used.']);
    InitInfo.Warnings = Warnings(:);
    InitInfo.PreInitializationEventCount = ...
        sum(Events.Time_s < t_init);

end

function J = levelingJacobian(A)
%LEVELINGJACOBIAN d(roll,pitch)/d(accel) of the leveling map at A.
%   Mirrors the leveling formulas above exactly (central differences -
%   deterministic geometry, not statistics).

    J = zeros(2, 3);

    for i = 1:3
        h = max(1e-6, 1e-4 * abs(A(i)));
        Ap = A(:);
        Am = A(:);
        Ap(i) = Ap(i) + h;
        Am(i) = Am(i) - h;
        J(:, i) = (levelingMap(Ap) - levelingMap(Am)) / (2 * h);
    end

end

function rp = levelingMap(A)
%LEVELINGMAP Roll/pitch from the accelerometer median (rest solution).

    rp = [atan2(-A(2), -A(3)); ...
        asin(max(-1, min(1, A(1) / norm(A))))];

end
