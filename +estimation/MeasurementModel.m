function [zPredicted, Extra] = MeasurementModel(x, Type, Params)
%MEASUREMENTMODEL State-only measurement models for Block 10.
%
%   z = MEASUREMENTMODEL(x, Type, Params) returns the predicted
%   measurement vector of the given type for state x (15x1).
%
%   Types (exact strings):
%       'GNSSPosition'  - z = [pN; pE; pD] (m, local NED)
%       'GNSSVelocity'  - z = [vN; vE; vD] (m/s, local NED)
%       'MagneticField' - z = Cbn(eta)' * B_NED(p) (T, body axes)
%
%   Params is required for 'MagneticField' and supplies:
%       .Anchor     - run navigation origin (see ConvertLLA2NED)
%       .ModelYear  - WMM model epoch (2024; matches the simulator)
%   For the GNSS types Params may be empty.
%
%   [z, Extra] = MEASUREMENTMODEL(...) additionally returns
%   Extra.B_NED_T (the WMM reference vector in NED, T) for diagnostics.
%
%   The magnetic measurement model evaluates the WMM reference field at
%   the ESTIMATED position carried in the state (so the model is a
%   function of the state alone, which the filter's residual operation
%   requires) using MagneticReferenceNED - the same model, epoch and
%   call convention as the frozen simulator
%   (+sensormodels/GenerateIdealMagnetometer.m). The measured vector is
%   in the canonical Block 9 unit T.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: MeasurementJacobian, StateTransitionModel,
%   MagneticReferenceNED.

    Definition = estimation.StateDefinition();

    if ~(isnumeric(x) && isreal(x) && isequal(size(x), [15, 1]) && ...
            all(isfinite(x)))

        error( ...
            'Estimation:MeasurementModel:InvalidState', ...
            'x must be a finite real 15x1 state vector.');

    end

    if ~(ischar(Type) || (isstring(Type) && isscalar(Type)))

        error( ...
            'Estimation:MeasurementModel:InvalidType', ...
            'Type must be a character vector or scalar string.');

    end

    Type = char(Type);
    Idx = Definition.Index;
    Extra = struct('B_NED_T', []);

    switch Type

        case 'GNSSPosition'

            zPredicted = x(Idx.pN:Idx.pD);

        case 'GNSSVelocity'

            zPredicted = x(Idx.vN:Idx.vD);

        case 'MagneticField'

            if nargin < 3 || ~isstruct(Params) || ...
                    ~isfield(Params, 'Anchor') || ...
                    ~isfield(Params, 'ModelYear')

                error( ...
                    'Estimation:MeasurementModel:MissingParams', ...
                    ['MagneticField measurements require Params with ', ...
                     'Anchor and ModelYear.']);

            end

            eta = x(Idx.roll:Idx.yaw);
            p = x(Idx.pN:Idx.pD);

            [Lat, Lon, Alt] = estimation.ConvertNED2LLA( ...
                p(1), p(2), p(3), Params.Anchor);

            B_NED = estimation.MagneticReferenceNED( ...
                Lat, Lon, Alt, Params.ModelYear);

            Cbn = coordinates.Euler2DCM(eta(1), eta(2), eta(3));
            zPredicted = Cbn' * B_NED;
            Extra.B_NED_T = B_NED;

        otherwise

            error( ...
                'Estimation:MeasurementModel:UnknownType', ...
                'Unknown measurement type "%s".', ...
                Type);

    end

end
