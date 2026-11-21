function H = MeasurementJacobian(x, Type, Params)
%MEASUREMENTJACOBIAN Analytical Jacobian of the measurement models.
%
%   H = MEASUREMENTJACOBIAN(x, Type, Params) returns the 3x15
%   measurement Jacobian dh/dx of MeasurementModel for the given type:
%
%       'GNSSPosition'  - H = [I3, 0(3x12)]
%       'GNSSVelocity'  - H = [0(3x3), I3, 0(3x9)]
%       'MagneticField' - h = Cbn(eta)' * B_NED(p), so
%                         H = [Cbn' * dB/dp, dCbn'/deta * B, 0(3x6)]
%
%   For the magnetic model:
%       - the attitude part d(Cbn' B)/deta is analytical, using the
%         shared AttitudeKinematics partials with B held at its current
%         value;
%       - the position part Cbn' * dB_NED/dp is evaluated by central
%         finite differences of MagneticReferenceNED over the NED
%         position with a documented 10 m step (the WMM field varies by
%         only nT over such steps, far below the 120 nT measurement
%         noise; the gradient is included so the analytical-vs-numerical
%         Jacobian verification is exact for the implemented model).
%
%   The full analytical Jacobian is verified numerically against central
%   finite differences of MeasurementModel in the numerical test suite.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: MeasurementModel, StateTransitionJacobian,
%   AttitudeKinematics.

    Definition = estimation.StateDefinition();

    if ~(isnumeric(x) && isreal(x) && isequal(size(x), [15, 1]) && ...
            all(isfinite(x)))

        error( ...
            'Estimation:MeasurementJacobian:InvalidState', ...
            'x must be a finite real 15x1 state vector.');

    end

    if ~(ischar(Type) || (isstring(Type) && isscalar(Type)))

        error( ...
            'Estimation:MeasurementJacobian:InvalidType', ...
            'Type must be a character vector or scalar string.');

    end

    Type = char(Type);
    Idx = Definition.Index;
    H = zeros(3, 15);

    switch Type

        case 'GNSSPosition'

            H(:, Idx.pN:Idx.pD) = eye(3);

        case 'GNSSVelocity'

            H(:, Idx.vN:Idx.vD) = eye(3);

        case 'MagneticField'

            if nargin < 3 || ~isstruct(Params) || ...
                    ~isfield(Params, 'Anchor') || ...
                    ~isfield(Params, 'ModelYear')

                error( ...
                    'Estimation:MeasurementJacobian:MissingParams', ...
                    ['MagneticField measurements require Params with ', ...
                     'Anchor and ModelYear.']);

            end

            eta = x(Idx.roll:Idx.yaw);
            p = x(Idx.pN:Idx.pD);

            [Lat, Lon, Alt] = estimation.ConvertNED2LLA( ...
                p(1), p(2), p(3), Params.Anchor);
            B_NED = estimation.MagneticReferenceNED( ...
                Lat, Lon, Alt, Params.ModelYear);

            K = estimation.AttitudeKinematics(eta(1), eta(2), eta(3));

            % Attitude part (B held at its current value).
            H(:, Idx.roll) = K.dCbn_droll' * B_NED;
            H(:, Idx.pitch) = K.dCbn_dpitch' * B_NED;
            H(:, Idx.yaw) = K.dCbn_dyaw' * B_NED;

            % Position part: Cbn' * dB/dp via central finite differences
            % of the WMM reference over NED position (step 10 m).
            Step_m = 10;
            dBdp = zeros(3, 3);

            for Axis = 1:3

                Delta = zeros(3, 1);
                Delta(Axis) = Step_m;

                [LatP, LonP, AltP] = estimation.ConvertNED2LLA( ...
                    p(1) + Delta(1), p(2) + Delta(2), p(3) + Delta(3), ...
                    Params.Anchor);
                B_plus = estimation.MagneticReferenceNED( ...
                    LatP, LonP, AltP, Params.ModelYear);

                [LatM, LonM, AltM] = estimation.ConvertNED2LLA( ...
                    p(1) - Delta(1), p(2) - Delta(2), p(3) - Delta(3), ...
                    Params.Anchor);
                B_minus = estimation.MagneticReferenceNED( ...
                    LatM, LonM, AltM, Params.ModelYear);

                dBdp(:, Axis) = (B_plus - B_minus) / (2 * Step_m);

            end

            H(:, Idx.pN:Idx.pD) = K.Cbn' * dBdp;

        otherwise

            error( ...
                'Estimation:MeasurementJacobian:UnknownType', ...
                'Unknown measurement type "%s".', ...
                Type);

    end

end
