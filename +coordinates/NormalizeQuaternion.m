function q = NormalizeQuaternion(q)
%NORMALIZEQUATERNION Normalize a quaternion.
%
%   q = NormalizeQuaternion(q)
%
%   Input
%       q - Quaternion [w x y z]
%
%   Output
%       q - Unit quaternion

if nargin==0
    help(mfilename);
    return;
end

narginchk(1,1);

validateattributes(q,{'numeric'},{'real','finite','numel',4});

q = reshape(q,1,4);

n = norm(q);

if n <= eps
    error('NormalizeQuaternion:ZeroNorm', ...
        'Quaternion norm must be greater than zero.');
end

q = q./n;

end