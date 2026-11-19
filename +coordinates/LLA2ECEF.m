
function [X, Y, Z] = LLA2ECEF(latitude, longitude, altitude)
%LLA2ECEF Convert geodetic coordinates to Earth-Centered Earth-Fixed (ECEF).
%
%   [X,Y,Z] = LLA2ECEF(LATITUDE,LONGITUDE,ALTITUDE)
%
%   Converts geodetic latitude, longitude and altitude referenced to the
%   WGS-84 ellipsoid into Earth-Centered Earth-Fixed (ECEF) Cartesian
%   coordinates.
%
%   Inputs
%   ------
%   latitude   : Geodetic latitude (rad)
%   longitude  : Geodetic longitude (rad)
%   altitude   : Height above WGS-84 ellipsoid (m)
%
%   Outputs
%   -------
%   X : ECEF X coordinate (m)
%   Y : ECEF Y coordinate (m)
%   Z : ECEF Z coordinate (m)
%
%   Coordinate Convention
%   ---------------------
%   Earth Model : WGS-84
%   Frame       : ECEF
%   Units       : SI
%   Angles      : Radians
%
%   Example
%   -------
%   lat = deg2rad(28.6139);
%   lon = deg2rad(77.2090);
%   h   = 216.0;
%
%   [X,Y,Z] = LLA2ECEF(lat,lon,h);

    narginchk(3,3);

    validateattributes(latitude, ...
        {'double'}, ...
        {'real','finite','nonnan'}, ...
        mfilename,'latitude',1);

    validateattributes(longitude, ...
        {'double'}, ...
        {'real','finite','nonnan'}, ...
        mfilename,'longitude',2);

    validateattributes(altitude, ...
        {'double'}, ...
        {'real','finite','nonnan'}, ...
        mfilename,'altitude',3);

    if ~(isequal(size(latitude),size(longitude)) && ...
         isequal(size(latitude),size(altitude)))

        error('LLA2ECEF:InputSizeMismatch', ...
            'Latitude, longitude and altitude must have identical dimensions.');

    end

    %% WGS-84 Constants

    wgs84 = coordinates.WGS84();

    a  = wgs84.SemiMajorAxis;
    e2 = wgs84.FirstEccentricitySquared;

    %% ECEF Conversion

    sinLat = sin(latitude);
    cosLat = cos(latitude);

    sinLon = sin(longitude);
    cosLon = cos(longitude);

    N = a ./ sqrt(1.0 - e2 .* sinLat.^2);

    X = (N + altitude) .* cosLat .* cosLon;
    Y = (N + altitude) .* cosLat .* sinLon;
    Z = (N .* (1.0 - e2) + altitude) .* sinLat;

    %% Output Validation

    validateattributes(X,{'double'},{'real','finite'});
    validateattributes(Y,{'double'},{'real','finite'});
    validateattributes(Z,{'double'},{'real','finite'});

end

