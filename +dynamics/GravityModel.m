function gVector = GravityModel(frame, quaternion)
%GRAVITYMODEL Return gravity vector in the requested reference frame.
%
%   gVector = GravityModel(frame)
%   gVector = GravityModel(frame, quaternion)
%
%   Description
%   -----------
%   Returns the gravity vector expressed in the requested coordinate frame.
%
%   Supported Frames
%   ----------------
%   "NED"  - North-East-Down frame
%   "BODY" - Aircraft Body frame
%
%   Inputs
%   ------
%   frame
%       Coordinate frame ("NED" or "BODY")
%
%   quaternion
%       Aircraft attitude quaternion [w x y z]
%       Required only when frame = "BODY"
%
%   Output
%   ------
%   gVector
%       3×1 gravity vector (m/s^2)
%
%   Units
%   -----
%   SI Units
%
%   Coordinate Convention
%   ---------------------
%   WGS-84
%   NED Navigation Frame
%   Quaternion format:
%       [w x y z]
%
%   Gravity
%   -------
%   Standard Gravity
%       g = 9.80665 m/s^2
%
%   Examples
%   --------
%   g = GravityModel("NED");
%
%   q = coordinates.Euler2Quaternion(0,0,0);
%   g = dynamics.GravityModel("BODY",q);
%
%   See also:
%       NormalizeQuaternion
%       Quaternion2DCM

    if nargin == 0
        help(mfilename);
        return;
    end

    narginchk(1,2);

    if ~(ischar(frame) || isstring(frame))
        error('GravityModel:InvalidFrame',...
            'Frame must be a character vector or string.');
    end

    frame = upper(string(frame));

    g = config.AircraftConfig.Gravity;

    switch frame

        case "NED"

            gVector = [0;0;g];

        case "BODY"

            if nargin ~= 2
                error('GravityModel:MissingQuaternion',...
                    'Quaternion must be supplied for BODY frame.');
            end

            validateattributes(quaternion,...
                {'numeric'},...
                {'real','finite','numel',4},...
                mfilename,...
                'quaternion',2);

            quaternion = coordinates.NormalizeQuaternion(quaternion);

            Cbn = coordinates.Quaternion2DCM(quaternion);

            gVector = Cbn.' * [0;0;g];

        otherwise

            error('GravityModel:UnknownFrame',...
                'Supported frames are "NED" and "BODY".');

    end

    validateattributes(gVector,...
        {'double'},...
        {'size',[3 1],'real','finite'},...
        mfilename,...
        'gVector');

end