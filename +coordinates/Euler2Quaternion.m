function q = Euler2Quaternion(roll,pitch,yaw)
%EULER2QUATERNION Convert Euler angles to quaternion.
%
%   q = Euler2Quaternion(roll,pitch,yaw)
%
%   Inputs
%       roll  - Roll angle (rad)
%       pitch - Pitch angle (rad)
%       yaw   - Yaw angle (rad)
%
%   Output
%       q     - Quaternion [w x y z]
%
%   Rotation Sequence
%       ZYX (Yaw-Pitch-Roll)
%
%   Requires Aerospace Toolbox.

if nargin==0
    help(mfilename);
    return;
end

narginchk(3,3);

validateattributes(roll,{'numeric'},{'real','scalar','finite'});
validateattributes(pitch,{'numeric'},{'real','scalar','finite'});
validateattributes(yaw,{'numeric'},{'real','scalar','finite'});

q = eul2quat([yaw pitch roll],"ZYX");

end