function B_NED_T = MagneticReferenceNED(Latitude_rad, Longitude_rad, Altitude_m, ModelYear)
%MAGNETICREFERENCENED World Magnetic Model reference field in NED (tesla).
%
%   B_NED_T = MAGNETICREFERENCENED(Lat_rad, Lon_rad, Alt_m, ModelYear)
%   evaluates the Aerospace Toolbox World Magnetic Model (wrldmagm) at
%   the given WGS-84 geodetic position and returns the magnetic field
%   vector in North-East-Down coordinates in TESLA (3x1).
%
%   Call convention mirrors the frozen simulator exactly
%   (+sensormodels/GenerateIdealMagnetometer.m):
%       wrldmagm(Altitude_m/1000, rad2deg(Lat), rad2deg(Lon), ModelYear)
%   with the model epoch fixed at the configured year (the simulator uses
%   2024). wrldmagm returns XYZ in NED coordinates in nT; the result is
%   converted to T here (the Block 9 canonical unit).
%
%   Vectorized over equal-sized Lat/Lon/Alt arrays: output is 3xN.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: MeasurementModel, InitializeState.

    if ~(isnumeric(ModelYear) && isscalar(ModelYear) && ...
            isfinite(ModelYear) && ModelYear == floor(ModelYear))

        error( ...
            'Estimation:MagneticReferenceNED:InvalidModelYear', ...
            'ModelYear must be an integer scalar.');

    end

    Lat_deg = rad2deg(Latitude_rad(:));
    Lon_deg = rad2deg(Longitude_rad(:));
    Alt_km = Altitude_m(:) / 1000;

    Count = numel(Lat_deg);
    B_NED_T = zeros(3, Count);

    for Index = 1:Count

        B_nT = wrldmagm(Alt_km(Index), Lat_deg(Index), ...
            Lon_deg(Index), ModelYear);
        B_nT = B_nT(:);

        if numel(B_nT) ~= 3

            error( ...
                'Estimation:MagneticReferenceNED:InvalidModelOutput', ...
                'wrldmagm did not return a three-component magnetic field.');

        end

        B_NED_T(:, Index) = B_nT * 1e-9;

    end

end
