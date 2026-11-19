function [north, east, down] = ECEF2NED(X, Y, Z, refLatitude, refLongitude, refAltitude)
%ECEF2NED Convert ECEF coordinates to Local NED coordinates.
%
%   [NORTH, EAST, DOWN] = ECEF2NED(X,Y,Z,REFLATITUDE,REFLONGITUDE,REFALTITUDE)
%
%   Converts Earth-Centered Earth-Fixed (ECEF) coordinates into the
%   local North-East-Down (NED) frame referenced to a geodetic
%   latitude, longitude and altitude.
%
%   Inputs
%   ------
%   X, Y, Z          : ECEF coordinates (m)
%   refLatitude      : Reference latitude (rad)
%   refLongitude     : Reference longitude (rad)
%   refAltitude      : Reference altitude above WGS-84 ellipsoid (m)
%
%   Outputs
%   -------
%   north            : North coordinate (m)
%   east             : East coordinate (m)
%   down             : Down coordinate (m)
%
%   Reference Frame
%   ----------------
%   WGS-84
%
%   Requirements
%   ------------
%   Aerospace Toolbox
%
%   Example
%   -------
%   [n,e,d] = ECEF2NED(X,Y,Z,lat0,lon0,h0);

arguments
    X (:,1) double
    Y (:,1) double
    Z (:,1) double
    refLatitude (1,1) double
    refLongitude (1,1) double
    refAltitude (1,1) double
end

if ~(isequal(size(X),size(Y),size(Z)))
    error('ECEF2NED:InputSizeMismatch', ...
        'X, Y and Z must have identical dimensions.');
end

wgs84 = wgs84Ellipsoid("meter");

[north,east,down] = ecef2ned( ...
    X,...
    Y,...
    Z,...
    rad2deg(refLatitude),...
    rad2deg(refLongitude),...
    refAltitude,...
    wgs84);

end