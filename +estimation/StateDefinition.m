function Definition = StateDefinition()
%STATEDEFINITION Canonical Block 10 state-vector definition.
%
%   Definition = STATEDEFINITION() returns the approved 15-state ZYX
%   Euler state definition used by the Block 10 estimators.
%
%   State vector (column, 15x1):
%       x = [pN; pE; pD; vN; vE; vD; roll; pitch; yaw; ...
%            bax; bay; baz; bgx; bgy; bgz]
%
%   Indices and units:
%       1-3   NED position (m), local NED frame anchored at the run
%             navigation origin (see InitializeState)
%       4-6   NED velocity (m/s)
%       7-9   Roll, pitch, yaw (rad), ZYX (yaw-pitch-roll) order
%       10-12 Accelerometer bias (m/s^2), body axes
%       13-15 Gyroscope bias (rad/s), body axes
%
%   Attitude conventions follow the frozen Block 2 package:
%       - ZYX Euler angles, body-to-NED DCM
%       - quaternion export is scalar-first [w x y z]
%       - roll and yaw are carried continuous/unwrapped internally;
%         angular quantities are wrapped only for presentation and for
%         measurement residuals
%
%   Output fields:
%       .Count        - 15
%       .Index        - struct of named 1-based indices
%       .Names        - 15x1 cellstr of state names
%       .Units        - 15x1 cellstr of SI units
%       .AttitudeOrder - 'ZYX'
%       .QuaternionOrder - 'wxyz'
%
%   INTERNAL function. Not part of the public Block 10 API. The public
%   API is EstimationConfig, DiscoverRuns, InspectRun,
%   RunStateReconstruction and GetEstimationReport.
%
%   See also: InitializeState, StateTransitionModel, MeasurementModel.

    Definition = struct();
    Definition.Count = 15;
    Definition.AttitudeOrder = 'ZYX';
    Definition.QuaternionOrder = 'wxyz';

    Definition.Index = struct( ...
        'pN', 1, 'pE', 2, 'pD', 3, ...
        'vN', 4, 'vE', 5, 'vD', 6, ...
        'roll', 7, 'pitch', 8, 'yaw', 9, ...
        'bax', 10, 'bay', 11, 'baz', 12, ...
        'bgx', 13, 'bgy', 14, 'bgz', 15);

    Definition.Names = { ...
        'pN_m'; 'pE_m'; 'pD_m'; ...
        'vN_mps'; 'vE_mps'; 'vD_mps'; ...
        'roll_rad'; 'pitch_rad'; 'yaw_rad'; ...
        'bax_mps2'; 'bay_mps2'; 'baz_mps2'; ...
        'bgx_radps'; 'bgy_radps'; 'bgz_radps'};

    Definition.Units = { ...
        'm'; 'm'; 'm'; ...
        'm/s'; 'm/s'; 'm/s'; ...
        'rad'; 'rad'; 'rad'; ...
        'm/s^2'; 'm/s^2'; 'm/s^2'; ...
        'rad/s'; 'rad/s'; 'rad/s'};

    Definition.Names = Definition.Names(:);
    Definition.Units = Definition.Units(:);

    % Group spans for metric aggregation.
    Definition.Span = struct( ...
        'Position', 1:3, ...
        'Velocity', 4:6, ...
        'Attitude', 7:9, ...
        'AccelBias', 10:12, ...
        'GyroBias', 13:15);

end
