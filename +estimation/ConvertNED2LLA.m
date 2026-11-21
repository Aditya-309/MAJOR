function [Latitude_rad, Longitude_rad, Altitude_m] = ConvertNED2LLA(North, East, Down, Anchor)
%CONVERTNED2LLA Convert local NED coordinates back to geodetic LLA.
%
%   [Lat, Lon, Alt] = CONVERTNED2LLA(N, E, D, Anchor) is the inverse of
%   ConvertLLA2NED relative to the same anchor: local NED (m) to WGS-84
%   geodetic (rad, rad, m), via the frozen Block 2 transformations
%   coordinates.NED2ECEF and coordinates.ECEF2LLA. Vectorized.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: ConvertLLA2NED, MeasurementModel.

    if ~(isstruct(Anchor) && isscalar(Anchor) && ...
            isfield(Anchor, 'Latitude_rad') && ...
            isfield(Anchor, 'Longitude_rad') && ...
            isfield(Anchor, 'Altitude_m'))

        error( ...
            'Estimation:ConvertNED2LLA:InvalidAnchor', ...
            ['Anchor must be a scalar structure with Latitude_rad, ', ...
             'Longitude_rad and Altitude_m fields.']);

    end

    [X, Y, Z] = coordinates.NED2ECEF( ...
        North(:), East(:), Down(:), ...
        Anchor.Latitude_rad, ...
        Anchor.Longitude_rad, ...
        Anchor.Altitude_m);

    [Latitude_rad, Longitude_rad, Altitude_m] = ...
        coordinates.ECEF2LLA(X, Y, Z);

    Latitude_rad = reshape(Latitude_rad, size(North));
    Longitude_rad = reshape(Longitude_rad, size(North));
    Altitude_m = reshape(Altitude_m, size(North));

end
