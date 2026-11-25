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

% Cached: the WGS-84 ellipsoid is a mathematical constant. Building it
% per call dominated estimation runtime (1.36M constructions per run);
% the cached object is bitwise identical to a fresh one (user-approved
% frozen edit, GuardrailUpdateProposal_S8a.md addendum 4).
persistent wgs84Cache
if isempty(wgs84Cache)
    wgs84Cache = wgs84Ellipsoid("meter");
end
wgs84 = wgs84Cache;

[X,Y,Z] = ned2ecef( ...
    north,...
    east,...
    down,...
    rad2deg(refLatitude),...
    rad2deg(refLongitude),...
    refAltitude,...
    wgs84);

end