function [roll,pitch,yaw] = Quaternion2Euler(q)
%QUATERNION2EULER Convert quaternion to Euler angles.
%
%   [roll,pitch,yaw] = Quaternion2Euler(q)
%
%   Input
%       q - Quaternion [w x y z]
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

validateattributes(q,{'numeric'},{'real','finite','numel',4});

q = reshape(q,1,4);

eul = quat2eul(q,"ZYX");

yaw   = eul(1);
pitch = eul(2);
roll  = eul(3);

end