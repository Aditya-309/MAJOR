function [X, Y, Z] = NED2ECEF(north, east, down, refLatitude, refLongitude, refAltitude)
%NED2ECEF Convert Local NED coordinates to ECEF coordinates.
%
%   [X,Y,Z] = NED2ECEF(NORTH,EAST,DOWN,REFLATITUDE,REFLONGITUDE,REFALTITUDE)
%
%   Converts Local North-East-Down coordinates into Earth-Centered
%   Earth-Fixed (ECEF) coordinates referenced to a geodetic latitude,
%   longitude and altitude.
%
%   Inputs
%   ------
%   north            : North coordinate (m)
%   east             : East coordinate (m)
%   down             : Down coordinate (m)
%   refLatitude      : Reference latitude (rad)
%   refLongitude     : Reference longitude (rad)
%   refAltitude      : Reference altitude (m)
%
%   Outputs
%   -------
%   X, Y, Z          : ECEF coordinates (m)
%
%   Requirements
%   ------------
%   Aerospace Toolbox
%
%   Example
%   -------
%   [X,Y,Z] = NED2ECEF(n,e,d,lat0,lon0,h0);

arguments
    north (:,1) double
    east (:,1) double
    down (:,1) double
    refLatitude (1,1) double
    refLongitude (1,1) double
    refAltitude (1,1) double
end

if ~(isequal(size(north),size(east),size(down)))
    error('NED2ECEF:InputSizeMismatch', ...
        'North, East and Down must have identical dimensions.');
end

wgs84 = wgs84Ellipsoid("meter");

[X,Y,Z] = ned2ecef( ...
    north,...
    east,...
    down,...
    rad2deg(refLatitude),...
    rad2deg(refLongitude),...
    refAltitude,...
    wgs84);

end