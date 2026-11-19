function DCM = Quaternion2DCM(q)
%QUATERNION2DCM Convert quaternion to Direction Cosine Matrix.
%
%   DCM = Quaternion2DCM(q)
%
%   Input
%       q - Quaternion [w x y z]
%
%   Output
%       DCM - Body-to-NED Direction Cosine Matrix
%
%   Requires Aerospace Toolbox.

if nargin==0
    help(mfilename);
    return;
end

narginchk(1,1);

validateattributes(q,{'numeric'},{'real','finite','numel',4});

q = reshape(q,1,4);

DCM = quat2rotm(q);

end