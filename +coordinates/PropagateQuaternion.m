function qNext = PropagateQuaternion(q,omega,dt)
%PROPAGATEQUATERNION Propagate quaternion using exact quaternion increment.
%
%   qNext = PropagateQuaternion(q,omega,dt)
%
%   Inputs
%       q     - Quaternion [w x y z]
%       omega - Body angular rate [wx wy wz] (rad/s)
%       dt    - Sample time (s)
%
%   Output
%       qNext - Propagated unit quaternion
%
%   Quaternion Convention
%       [w x y z]
%
%   Uses exact axis-angle quaternion propagation.

if nargin==0
    help(mfilename);
    return;
end

narginchk(3,3);

validateattributes(q,{'numeric'},...
    {'real','finite','numel',4});

validateattributes(omega,{'numeric'},...
    {'real','finite','numel',3});

validateattributes(dt,{'numeric'},...
    {'real','scalar','finite','positive'});

q = NormalizeQuaternion(q);

omega = omega(:);

theta = norm(omega)*dt;

if theta < 1e-12

    dq = [1 0 0 0];

else

    axis = omega./norm(omega);

    dq = [ cos(theta/2), ...
           axis(1)*sin(theta/2), ...
           axis(2)*sin(theta/2), ...
           axis(3)*sin(theta/2)];

end

qNext = quatmultiply(q,dq);

qNext = NormalizeQuaternion(qNext);

end