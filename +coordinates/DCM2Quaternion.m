function q = DCM2Quaternion(DCM)
%DCM2QUATERNION Convert Direction Cosine Matrix to quaternion.
%
%   q = DCM2Quaternion(DCM)
%
%   Input
%       DCM - 3x3 Body-to-NED Direction Cosine Matrix
%
%   Output
%       q   - Quaternion [w x y z]
%
%   Requires Aerospace Toolbox.

if nargin==0
    help(mfilename);
    return;
end

narginchk(1,1);

validateattributes(DCM,{'numeric'},{'size',[3 3],'real','finite'});

q = rotm2quat(DCM);

end