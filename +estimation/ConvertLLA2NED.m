function [North, East, Down] = ConvertLLA2NED(Latitude_rad, Longitude_rad, Altitude_m, Anchor)
%CONVERTLLA2NED Convert geodetic coordinates to local NED about an anchor.
%
%   [N,E,D] = CONVERTLLA2NED(Lat, Lon, Alt, Anchor) converts WGS-84
%   geodetic coordinates (rad, rad, m) to the local North-East-Down frame
%   referenced to the anchor geodetic point, using the frozen Block 2
%   transformations coordinates.LLA2ECEF and coordinates.ECEF2NED.
%
%   Anchor is a struct with fields Latitude_rad, Longitude_rad and
%   Altitude_m (the run navigation origin established by InitializeState
%   at the first eligible GNSS fix).
%
%   Vectorized over Lat/Lon/Alt (equal-sized arrays).
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: InitializeState, MeasurementModel, EvaluateAgainstGroundTruth.

    if ~(isstruct(Anchor) && isscalar(Anchor) && ...
            isfield(Anchor, 'Latitude_rad') && ...
            isfield(Anchor, 'Longitude_rad') && ...
            isfield(Anchor, 'Altitude_m'))

        error( ...
            'Estimation:ConvertLLA2NED:InvalidAnchor', ...
            ['Anchor must be a scalar structure with Latitude_rad, ', ...
             'Longitude_rad and Altitude_m fields.']);

    end

    [X, Y, Z] = coordinates.LLA2ECEF( ...
        Latitude_rad(:), Longitude_rad(:), Altitude_m(:));

    [North, East, Down] = coordinates.ECEF2NED( ...
        X, Y, Z, ...
        Anchor.Latitude_rad, ...
        Anchor.Longitude_rad, ...
        Anchor.Altitude_m);

    North = reshape(North, size(Latitude_rad));
    East = reshape(East, size(Latitude_rad));
    Down = reshape(Down, size(Latitude_rad));

end
