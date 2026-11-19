function S = SkewSymmetric(v)
%SKEWSYMMETRIC Construct a skew-symmetric matrix from a 3-element vector.
%
%   S = SkewSymmetric(v)
%
%   Input
%       v - 3x1 or 1x3 vector
%
%   Output
%       S - 3x3 skew-symmetric matrix
%
%   Such that:
%       cross(v,a) = S*a

if nargin==0
    help(mfilename);
    return;
end

narginchk(1,1);

validateattributes(v,{'numeric'},{'real','finite','numel',3});

v = v(:);

S = [   0    -v(3)  v(2);
      v(3)    0    -v(1);
     -v(2)  v(1)    0 ];

end