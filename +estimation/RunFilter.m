function [Forward, RunLog] = RunFilter(Filter, FilterLabel, Timeline, Config, NoiseModels, InitInfo)
%RUNFILTER Causal forward state estimation over the event timeline.
%
%   [Forward, RunLog] = RUNFILTER(Filter, FilterLabel, Timeline, Config,
%   NoiseModels, InitInfo) drives one filter (created by CreateEKF or
%   CreateUKF) through the chronological event timeline and records the
%   forward estimates, measurement innovations and diagnostics.
%
%   Processing rules (task document 11.1):
%       1. Events are processed strictly in timeline order.
%       2. Between consecutive event times the state is propagated with
%          the held IMU input (piecewise-constant ZOH: the most recent
%          ELIGIBLE IMU sample at or before the interval start) over the
%          ACTUAL dt. ProcessNoise is refreshed to Q(x, dt) before every
%          predict.
%       3. Eligible measurements are applied at their own timestamps via
%          the toolbox correct operation with the documented per-type R;
%          innovation, innovation covariance and NIS are recorded from
%          the toolbox residual operation BEFORE the correction.
%       4. No future measurement can influence an earlier estimate:
%          nothing is read outside the current event.
%       5. Magnetometer measurements are applied as attitude updates when
%         Config.Magnetometer.EnableUpdates is true; otherwise they are
%         recorded diagnostic-only. AirData is always diagnostic-only
%         (true airspeed is never fused as ground velocity).
%
%   Validity policy: an update is applied only when the timeline marked
%   the event eligible (Block 9 validity flags plus the configured flag
%   policy), the optional chi-square innovation gate accepts it (if
%   enabled), and the current estimate is valid. Every skipped update is
%   recorded with its reason - never silently dropped.
%
%   Euler pitch singularity policy: after every propagation the pitch is
%   checked against Config.State thresholds. A warning event is recorded
%   at the warning threshold; at the hard-stop threshold valid
%   propagation stops and all subsequent estimates are marked invalid
%   (the state is carried forward unchanged and flagged).
%
%   Forward fields (columnar):
%       .Time_s (Sx1), .State (Sx15), .CovDiag (Sx15), .CovFull (Sx225),
%       .Valid (Sx1), .Degraded (Sx1), .PredictCount, .FirstTime_s,
%       .LastTime_s
%   CovFull is the row-major 15x15 covariance of each step (consumed by
%   the evaluation's full-covariance NEES; not exported to CSV). Valid is
%   false for hard-stopped or hold-invalid estimates; Degraded marks
%   estimates produced on a held IMU input beyond the degraded age limit.
%   RunLog fields:
%       .Updates   - per update-type event record (applied/gated/skipped,
%                    innovation, S diagonal, NIS, z, z-predicted,
%                    correction norm, covariance trace change, stream,
%                    source row, timestamp)
%       .AirData   - air-data consistency diagnostics
%       .Events    - estimator events (warnings, hard stop, holds)
%       .HoldRecords - intervals where the IMU input was held
%       .Summary   - counts
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: CreateEKF, CreateUKF, RunSmoothing, BuildMeasurementTimeline.

    Definition = estimation.StateDefinition( ...
        isfield(Config.State, 'EnableGNSSBiasStates') && ...
        Config.State.EnableGNSSBiasStates);
    Events = Timeline.Events;
    Codes = Timeline.EventCodes;

    t_init = InitInfo.t_init_s;

    MagParams = struct( ...
        'Anchor', InitInfo.Anchor, ...
        'ModelYear', Config.Magnetometer.ModelYear);

    % State-only measurement bindings (swapped per update type).
    Bindings = struct();
    Bindings.GNSSPosition = struct( ...
        'Meas', @(x) estimation.MeasurementModel(x, 'GNSSPosition', []), ...
        'Jacobian', @(x) estimation.MeasurementJacobian( ...
            x, 'GNSSPosition', []), ...
        'R', NoiseModels.R.GNSSPosition, ...
        'RField', 'GNSSPosition');
    Bindings.GNSSVelocity = struct( ...
        'Meas', @(x) estimation.MeasurementModel(x, 'GNSSVelocity', []), ...
        'Jacobian', @(x) estimation.MeasurementJacobian( ...
            x, 'GNSSVelocity', []), ...
        'R', NoiseModels.R.GNSSVelocity, ...
        'RField', 'GNSSVelocity');
    Bindings.MagneticField = struct( ...
        'Meas', @(x) estimation.MeasurementModel( ...
            x, 'MagneticField', MagParams), ...
        'Jacobian', @(x) estimation.MeasurementJacobian( ...
            x, 'MagneticField', MagParams), ...
        'R', NoiseModels.R.MagneticField, ...
        'RField', 'MagneticField', ...
        'MeasBuilder', @(state) fixedFieldMeas(state, MagParams, ...
            InitInfo.Anchor, Definition.Index));

    GateEnabled = Config.MeasurementPolicy.Gate.Enabled;

    if GateEnabled
        GateThreshold = estimation.ChiSquareQuantile( ...
            Config.MeasurementPolicy.Gate.Probability, 3);
    else
        GateThreshold = Inf;
    end

    %% Preallocate recording (upper bounds)

    TotalEvents = numel(Events.Time_s);
    MaxUpdates = sum(Events.Type == Codes.GNSSPosition | ...
        Events.Type == Codes.GNSSVelocity | ...
        Events.Type == Codes.MagneticField);
    MaxAirData = sum(Events.Type == Codes.AirDataDiagnostic);

    Time_s = zeros(TotalEvents + 1, 1);
    State = zeros(TotalEvents + 1, Definition.Count);
    CovDiag = zeros(TotalEvents + 1, Definition.Count);
    % Full covariance recording (reviewer finding F4): the evaluation's
    % NEES uses the complete covariance, not only its diagonal.
    CovFull = zeros(TotalEvents + 1, Definition.Count ^ 2);
    Valid = false(TotalEvents + 1, 1);
    Degraded = false(TotalEvents + 1, 1);
    StepCount = 0;

    % S8a: null-space variance protection. The confounded turn-on-bias
    % directions carry no information and must keep their no-information
    % variance; sequential updates leak it numerically (measured). P0 is
    % kept as the floor reference for the dynamic projection.
    ProtectionP0 = Filter.StateCovariance;

    U = struct();
    U.Time_s = zeros(MaxUpdates, 1);
    U.Type = zeros(MaxUpdates, 1);
    U.Stream = cell(MaxUpdates, 1);
    U.SourceRowIdx = zeros(MaxUpdates, 1);
    U.SegmentID = zeros(MaxUpdates, 1);
    U.Outcome = cell(MaxUpdates, 1);
    U.Z = zeros(MaxUpdates, 3);
    U.ZPredicted = zeros(MaxUpdates, 3);
    U.Innovation = zeros(MaxUpdates, 3);
    U.SDiag = zeros(MaxUpdates, 3);
    U.NIS = nan(MaxUpdates, 1);
    U.CorrectionNorm = nan(MaxUpdates, 1);
    U.TraceChange = nan(MaxUpdates, 1);
    U.StateBefore = zeros(MaxUpdates, Definition.Count);
    UpdateCount = 0;

    A = struct();
    A.Time_s = zeros(MaxAirData, 1);
    A.SourceRowIdx = zeros(MaxAirData, 1);
    A.TAS_mps = zeros(MaxAirData, 1);
    A.Qbar_Pa = zeros(MaxAirData, 1);
    A.GroundSpeedEst_mps = zeros(MaxAirData, 1);
    A.QbarFromTAS_Pa = zeros(MaxAirData, 1);
    A.Outcome = cell(MaxAirData, 1);
    AirDataCount = 0;

    RunEvents = struct('Time_s', {}, 'Kind', {}, 'Message', {}, ...
        'SourceRowIdx', {});
    HoldRecords = struct('Start_s', {}, 'End_s', {}, 'Reason', {});

    %% Loop over events

    t_prev = t_init;
    haveIMU = false;
    AccelHeld = zeros(3, 1);
    GyroHeld = zeros(3, 1);
    HeldSince = NaN;
    StateValid = true;

    % Reviewer finding F3: seed the held propagation input from the
    % initialization provenance (the most recent eligible IMU sample at
    % or before t_init), so the first propagation interval follows the
    % documented ZOH rule instead of being lost.
    HeldIMUTime_s = NaN;
    HeldIMUSegment = NaN;
    DegradedNow = false;
    DegradedEventRecorded = false;

    if isfield(InitInfo, 'InitialIMU') && ...
            ~isempty(InitInfo.InitialIMU.Accel_mps2)
        AccelHeld = InitInfo.InitialIMU.Accel_mps2(:);
        GyroHeld = InitInfo.InitialIMU.Gyro_radps(:);
        haveIMU = true;
        HeldIMUTime_s = InitInfo.InitialIMU.Time_s;
        HeldIMUSegment = InitInfo.InitialIMU.SegmentID;
    end

    % Reviewer findings F1/F2: held-input age policy and segment
    % continuity policy.
    HoldCfg = Config.MeasurementPolicy.IMUHold;
    WarnedPitch = false;
    HardStopped = false;
    PredictCount = 0;

    for k = 1:TotalEvents

        t_e = Events.Time_s(k);

        if t_e < t_init
            continue
        end

        if HardStopped
            % Carried, flagged invalid: nothing is processed anymore.
            break
        end

        dt = t_e - t_prev;

        % Reviewer finding F2: segment continuity. A held input belongs to
        % its source segment; a discontinuous segment (Block 9 breaks the
        % stream at data gaps) must not be bridged by stale input. The
        % input is dropped at the boundary and re-established by the first
        % eligible IMU sample of the new segment.
        if haveIMU && Events.SegmentID(k) ~= HeldIMUSegment
            haveIMU = false;
            HeldSince = NaN;
            DegradedNow = false;
            DegradedEventRecorded = false;
            RunEvents(end + 1) = struct( ...
                'Time_s', t_e, 'Kind', 'SegmentTransition', ...
                'Message', sprintf( [ ...
                    'Input segment changed from %d to %d at this event; ', ...
                    'the held IMU input was dropped at the discontinuity ', ...
                    'and propagation is unavailable until an eligible ', ...
                    'IMU sample of the new segment arrives.'], ...
                    HeldIMUSegment, Events.SegmentID(k)), ...
                'SourceRowIdx', Events.SourceRowIdx(k)); %#ok<AGROW>
        end

        if dt > 0

            if ~haveIMU

                RunEvents(end + 1) = struct( ...
                    'Time_s', t_e, 'Kind', 'PropagationUnavailable', ...
                    'Message', [ ...
                        'No eligible IMU input is available before this ', ...
                        'time; propagation skipped and the event is ', ...
                        'recorded without a state update.'], ...
                    'SourceRowIdx', Events.SourceRowIdx(k)); %#ok<AGROW>

            else

                % Reviewer finding F1: bounded held-input age. The age is
                % measured at the interval END (conservative: the ZOH
                % input ages across the interval).
                HoldAge_s = t_e - HeldIMUTime_s;

                if HoldAge_s > HoldCfg.MaxInvalid_s
                    % Stale input beyond the invalid limit: valid
                    % propagation stops (same policy as the pitch hard
                    % stop); the state is carried unchanged and flagged.
                    StateValid = false;
                    DegradedNow = true;
                    RunEvents(end + 1) = struct( ...
                        'Time_s', t_e, 'Kind', 'IMUHoldInvalid', ...
                        'Message', sprintf( [ ...
                            'The held IMU input is %.3f s old, beyond ', ...
                            'the invalid limit %.3f s; propagation ', ...
                            'stopped, the state is carried unchanged ', ...
                            'and affected estimates are marked invalid.'], ...
                            HoldAge_s, HoldCfg.MaxInvalid_s), ...
                        'SourceRowIdx', Events.SourceRowIdx(k)); %#ok<AGROW>

                else

                    if HoldAge_s > HoldCfg.MaxDegraded_s
                        DegradedNow = true;

                        if ~DegradedEventRecorded
                            DegradedEventRecorded = true;
                            RunEvents(end + 1) = struct( ...
                                'Time_s', t_e, 'Kind', 'IMUHoldDegraded', ...
                                'Message', sprintf( [ ...
                                    'The held IMU input is %.3f s old, ', ...
                                    'beyond the degraded limit %.3f s; ', ...
                                    'propagation continues on the held ', ...
                                    'input and estimates are flagged ', ...
                                    'Degraded until fresh IMU data ', ...
                                    'arrives.'], ...
                                    HoldAge_s, HoldCfg.MaxDegraded_s), ...
                                'SourceRowIdx', Events.SourceRowIdx(k)); %#ok<AGROW>
                        end

                    else
                        DegradedNow = false;
                        DegradedEventRecorded = false;
                    end

                    Filter.ProcessNoise = ...
                        NoiseModels.QHandle(Filter.State, dt);
                    predict(Filter, dt, AccelHeld, GyroHeld);
                    PredictCount = PredictCount + 1;

                % Pitch-singularity policy on the propagated attitude.
                pitch_deg = rad2deg(Filter.State(Definition.Index.pitch));

                if abs(pitch_deg) >= Config.State.PitchHardStop_deg

                    StateValid = false;
                    HardStopped = true;
                    RunEvents(end + 1) = struct( ...
                        'Time_s', t_e, 'Kind', 'PitchHardStop', ...
                        'Message', sprintf( [ ...
                            'Pitch magnitude %.2f deg reached the hard-', ...
                            'stop threshold %.2f deg; valid propagation ', ...
                            'stopped and subsequent estimates are ', ...
                            'marked invalid.'], ...
                            abs(pitch_deg), ...
                            Config.State.PitchHardStop_deg), ...
                        'SourceRowIdx', Events.SourceRowIdx(k)); %#ok<AGROW>

                elseif abs(pitch_deg) >= Config.State.PitchWarning_deg && ...
                        ~WarnedPitch

                    WarnedPitch = true;
                    RunEvents(end + 1) = struct( ...
                        'Time_s', t_e, 'Kind', 'PitchWarning', ...
                        'Message', sprintf( [ ...
                            'Pitch magnitude %.2f deg reached the ', ...
                            'warning threshold %.2f deg.'], ...
                            abs(pitch_deg), ...
                            Config.State.PitchWarning_deg), ...
                        'SourceRowIdx', Events.SourceRowIdx(k)); %#ok<AGROW>

                end

                end

            end

        end

        t_prev = t_e;

        %% Event handling

        switch Events.Type(k)

            case Codes.IMUPropagation

                if Events.Eligible(k)

                    AccelHeld = Events.Z(k, 1:3)';
                    GyroHeld = Events.Z(k, 4:6)';
                    HeldIMUTime_s = t_e;
                    HeldIMUSegment = Events.SegmentID(k);
                    DegradedNow = false;
                    DegradedEventRecorded = false;

                    if ~haveIMU
                        haveIMU = true;
                        RunEvents(end + 1) = struct( ...
                            'Time_s', t_e, 'Kind', 'InputReestablished', ...
                            'Message', [ ...
                                'An eligible IMU sample re-established ', ...
                                'the propagation input (source row and ', ...
                                'timestamp recorded in the event).'], ...
                            'SourceRowIdx', Events.SourceRowIdx(k)); %#ok<AGROW>
                    elseif ~isnan(HeldSince)
                        HoldRecords(end + 1) = struct( ...
                            'Start_s', HeldSince, 'End_s', t_e, ...
                            'Reason', ...
                            'PreviousEligibleIMUInputHeld'); %#ok<AGROW>
                        HeldSince = NaN;
                    end

                else

                    if isnan(HeldSince)
                        HeldSince = t_prev;
                    end

                end

            case {Codes.GNSSPosition, Codes.GNSSVelocity, ...
                    Codes.MagneticField}

                UpdateCount = UpdateCount + 1;
                U.Time_s(UpdateCount) = t_e;
                U.Type(UpdateCount) = Events.Type(k);
                U.Stream{UpdateCount} = Events.Stream{k};
                U.SourceRowIdx(UpdateCount) = Events.SourceRowIdx(k);
                U.SegmentID(UpdateCount) = Events.SegmentID(k);

                [BindingName, Outcome] = resolveBinding(Events.Type(k), ...
                    Codes);

                if ~Events.Eligible(k)
                    Outcome = ['Ineligible_' Events.ExclusionReason{k}];
                elseif ~StateValid
                    Outcome = 'InvalidState';
                end

                if strcmp(Outcome, 'Candidate')

                    Binding = Bindings.(BindingName);

                    % Measurement vector in model space.
                    switch BindingName

                        case 'GNSSPosition'
                            [n, e, d] = estimation.ConvertLLA2NED( ...
                                Events.Z(k, 1), Events.Z(k, 2), ...
                                Events.Z(k, 3), InitInfo.Anchor);
                            z = [n; e; d];

                        otherwise
                            z = Events.Z(k, 1:3)';

                    end

                    if isfield(Binding, 'MeasBuilder')
                        % SPEED addendum 4C: the geomagnetic reference is
                        % computed once per update at the predicted mean
                        % and held constant across the sigma points.
                        Filter.MeasurementFcn = Binding.MeasBuilder( ...
                            Filter.State);
                    else
                        Filter.MeasurementFcn = Binding.Meas;
                    end

                    if isprop(Filter, 'MeasurementJacobianFcn')
                        Filter.MeasurementJacobianFcn = Binding.Jacobian;
                    end
                    % Per-type R: the correct(filter, z, zcov) overload is
                    % not used because in R2024b the third positional
                    % argument is dispatched as measurement parameters.
                    % Setting the documented MeasurementNoise property is
                    % the supported equivalent and is identical for both
                    % filters.
                    Filter.MeasurementNoise = Binding.R;

                    zPredicted = Binding.Meas(Filter.State);
                    [Innovation, S] = residual(Filter, z);
                    NIS = Innovation' * (S \ Innovation);

                    U.Z(UpdateCount, :) = z';
                    U.ZPredicted(UpdateCount, :) = zPredicted';
                    U.Innovation(UpdateCount, :) = Innovation';
                    U.SDiag(UpdateCount, :) = diag(S)';
                    U.NIS(UpdateCount) = NIS;

                    IsDiagnosticOnly = ...
                        strcmp(BindingName, 'MagneticField') && ...
                        ~Config.Magnetometer.EnableUpdates;

                    if IsDiagnosticOnly

                        Outcome = 'DiagnosticOnly';

                    elseif NIS > GateThreshold

                        Outcome = 'Gated';

                    else

                        StateBefore = Filter.State;
                        TraceBefore = trace(Filter.StateCovariance);
                        correct(Filter, z);
                        Delta = Filter.State - StateBefore;

                        U.StateBefore(UpdateCount, :) = StateBefore';
                        U.CorrectionNorm(UpdateCount) = norm(Delta);
                        U.TraceChange(UpdateCount) = ...
                            TraceBefore - trace(Filter.StateCovariance);
                        Outcome = 'Applied';

                    end

                end

                U.Outcome{UpdateCount} = Outcome;

            case Codes.AirDataDiagnostic

                AirDataCount = AirDataCount + 1;
                A.Time_s(AirDataCount) = t_e;
                A.SourceRowIdx(AirDataCount) = Events.SourceRowIdx(k);

                if Events.Eligible(k) && StateValid

                    TAS = Events.Z(k, 1);
                    Qbar = Events.Z(k, 2);
                    v = Filter.State(Definition.Index.vN:Definition.Index.vD);
                    GroundSpeed = norm(v);

                    % Internal AirData consistency (same-stream channels):
                    % qbar vs the standard-atmosphere dynamic pressure of
                    % the measured TAS. Diagnostic only; no wind or
                    % aerodynamic attribution is made.
                    rho = config.AircraftConfig.SeaLevelDensity;
                    A.TAS_mps(AirDataCount) = TAS;
                    A.Qbar_Pa(AirDataCount) = Qbar;
                    A.GroundSpeedEst_mps(AirDataCount) = GroundSpeed;
                    A.QbarFromTAS_Pa(AirDataCount) = 0.5 * rho * TAS ^ 2;
                    A.Outcome{AirDataCount} = 'Diagnostic';

                else

                    A.Outcome{AirDataCount} = 'Skipped';

                end

        end

        %% End of a timestamp group: record the state snapshot

        if k == TotalEvents || Events.Time_s(k + 1) > t_e

            % S8a/S8c: no-information floors are fed back into the
            % tracker covariance (the consider semantics require the
            % gains and the reported covariance to agree; measured:
            % recorded-only floors leave the velocity block at its
            % uncorrected level). The growing floors are derived from
            % the declared priors. Flow safety does not depend on this:
            % the pitch-singularity guard keeps any state trajectory
            % runnable.
            Filter.StateCovariance = ...
                estimation.ProtectNullSpaceCovariance( ...
                Filter.StateCovariance, ProtectionP0, Definition, ...
                t_e - t_init);
            PRec = Filter.StateCovariance;
            StepCount = StepCount + 1;
            Time_s(StepCount) = t_e;
            State(StepCount, :) = Filter.State';
            CovDiag(StepCount, :) = diag(PRec)';
            CovFull(StepCount, :) = PRec(:)';
            Valid(StepCount) = StateValid;
            Degraded(StepCount) = DegradedNow;

        end

    end

    %% Final snapshot (if the loop ended on a carried invalid state)

    if StepCount == 0 || Time_s(StepCount) < t_prev

        Filter.StateCovariance = ...
            estimation.ProtectNullSpaceCovariance( ...
            Filter.StateCovariance, ProtectionP0, Definition, ...
            t_prev - t_init);
        PRec = Filter.StateCovariance;
        StepCount = StepCount + 1;
        Time_s(StepCount) = t_prev;
        State(StepCount, :) = Filter.State';
        CovDiag(StepCount, :) = diag(PRec)';
        CovFull(StepCount, :) = PRec(:)';
        Valid(StepCount) = StateValid;
        Degraded(StepCount) = DegradedNow;

    end

    %% Trim and assemble

    Forward = struct();
    Forward.Time_s = Time_s(1:StepCount);
    Forward.State = State(1:StepCount, :);
    Forward.CovDiag = CovDiag(1:StepCount, :);
    Forward.CovFull = CovFull(1:StepCount, :);
    Forward.Valid = Valid(1:StepCount);
    Forward.Degraded = Degraded(1:StepCount);
    Forward.PredictCount = PredictCount;
    Forward.FirstTime_s = t_init;
    Forward.LastTime_s = Time_s(StepCount);
    Forward.Label = FilterLabel;

    RunLog = struct();
    RunLog.Updates = trimStruct(U, UpdateCount);
    RunLog.AirData = trimStruct(A, AirDataCount);
    RunLog.Events = RunEvents;
    RunLog.HoldRecords = HoldRecords;
    RunLog.Summary = struct( ...
        'FilterLabel', FilterLabel, ...
        'StepCount', StepCount, ...
        'PredictCount', PredictCount, ...
        'UpdateEvents', UpdateCount, ...
        'UpdatesApplied', sum(strcmp(U.Outcome(1:UpdateCount), 'Applied')), ...
        'UpdatesGated', sum(strcmp(U.Outcome(1:UpdateCount), 'Gated')), ...
        'UpdatesDiagnosticOnly', sum(strcmp( ...
            U.Outcome(1:UpdateCount), 'DiagnosticOnly')), ...
        'UpdatesSkipped', UpdateCount - ...
            sum(ismember(U.Outcome(1:UpdateCount), ...
            {'Applied', 'Gated', 'DiagnosticOnly'})), ...
        'GateEnabled', GateEnabled, ...
        'GateThreshold', GateThreshold, ...
        'PreInitializationEvents', sum(Events.Time_s < t_init), ...
        'HardStopped', HardStopped, ...
        'WarningsPitch', WarnedPitch);

end

%% Local helpers

function [BindingName, Outcome] = resolveBinding(TypeCode, Codes)
    if TypeCode == Codes.GNSSPosition
        BindingName = 'GNSSPosition';
    elseif TypeCode == Codes.GNSSVelocity
        BindingName = 'GNSSVelocity';
    else
        BindingName = 'MagneticField';
    end

    Outcome = 'Candidate';
end

function S = trimStruct(S, Count)
    Fields = fieldnames(S);

    for Index = 1:numel(Fields)

        Value = S.(Fields{Index});

        if iscell(Value)
            S.(Fields{Index}) = Value(1:Count);
        elseif isnumeric(Value) || islogical(Value)
            S.(Fields{Index}) = Value(1:Count, :);
        end

    end
end

function Meas = fixedFieldMeas(State, MagParams, Anchor, Idx)
%FIXEDFIELDMEAS Magnetic model with the WMM reference held at the mean.
%
%   SPEED addendum 4C (user-approved): evaluates the geomagnetic
%   reference ONCE at the predicted mean position and returns a
%   measurement lambda that only rotates it per sigma point.

    [Lat, Lon, Alt] = estimation.ConvertNED2LLA( ...
        State(Idx.pN), State(Idx.pE), State(Idx.pD), Anchor);

    MP = MagParams;
    MP.B_NED_fixed = estimation.MagneticReferenceNED( ...
        Lat, Lon, Alt, MagParams.ModelYear);

    Meas = @(x) estimation.MeasurementModel(x, 'MagneticField', MP);
end
