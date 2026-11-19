function qDot = QuaternionDerivative(q,omega)
%QUATERNIONDERIVATIVE Quaternion derivative from body angular rates.
%
%   qDot = QuaternionDerivative(q,omega)
%
%   Inputs
%       q     - Quaternion [w x y z]
%       omega - Body angular rate [wx wy wz] (rad/s)
%
%   Output
%       qDot  - Quaternion derivative

if nargin==0
    help(mfilename);
    return;
end

narginchk(2,2);

validateattributes(q,{'numeric'},{'real','finite','numel',4});
validateattributes(omega,{'numeric'},{'real','finite','numel',3});

q = reshape(q,4,1);
omega = reshape(omega,3,1);

Omega = [ 0         -omega';
          omega   -coordinates.SkewSymmetric(omega)];

qDot = 0.5*Omega*q;

qDot = qDot.';

end