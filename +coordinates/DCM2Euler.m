function [roll,pitch,yaw] = DCM2Euler(DCM)
%DCM2EULER Convert Direction Cosine Matrix to Euler angles.
%
%   [roll,pitch,yaw] = DCM2Euler(DCM)
%
%   Input
%       DCM - 3x3 Body-to-NED Direction Cosine Matrix
%
%   Outputs
%       roll  - Roll angle (rad)
%       pitch - Pitch angle (rad)
%       yaw   - Yaw angle (rad)
%
%   Rotation Sequence
%       ZYX (Yaw-Pitch-Roll)
%
%   Requires Aerospace Toolbox.

if nargin==0
    help(mfilename);
    return;
end

narginchk(1,1);

validateattributes(DCM,{'numeric'},{'size',[3 3],'finite','real'});

eul = rotm2eul(DCM,"ZYX");

yaw   = eul(1);
pitch = eul(2);
roll  = eul(3);

end