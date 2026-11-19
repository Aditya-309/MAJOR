function DCM = Euler2DCM(roll,pitch,yaw)
%EULER2DCM Convert Euler angles to Direction Cosine Matrix.
%
%   DCM = Euler2DCM(roll,pitch,yaw)
%
%   Inputs
%       roll  - Roll angle (rad)
%       pitch - Pitch angle (rad)
%       yaw   - Yaw angle (rad)
%
%   Output
%       DCM   - Body-to-NED Direction Cosine Matrix
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

DCM = eul2rotm([yaw pitch roll],"ZYX");

end