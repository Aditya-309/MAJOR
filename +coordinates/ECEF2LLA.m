
function [latitude, longitude, altitude] = ECEF2LLA(X, Y, Z)
%ECEF2LLA Convert Earth-Centered Earth-Fixed (ECEF) coordinates to
% geodetic Latitude, Longitude and Altitude using Bowring's iterative
% algorithm.
%
%   [LATITUDE, LONGITUDE, ALTITUDE] = ECEF2LLA(X,Y,Z)
%
%   Inputs
%   ------
%   X : ECEF X coordinate (m)
%   Y : ECEF Y coordinate (m)
%   Z : ECEF Z coordinate (m)
%
%   Outputs
%   -------
%   LATITUDE  : Geodetic latitude (rad)
%   LONGITUDE : Geodetic longitude (rad)
%   ALTITUDE  : Height above WGS-84 ellipsoid (m)
%
%   Earth Model
%   -----------
%   WGS-84
%
%   Units
%   -----
%   Position : metres
%   Angles   : radians
%
%   Coordinate Convention
%   --------------------
%   Input  : ECEF
%   Output : Geodetic LLA
%
%   Algorithm
%   ---------
%   Bowring's Iterative Method
%
%   Example
%   -------
%   [lat,lon,h] = ECEF2LLA(X,Y,Z);

    if nargin == 0
        help(mfilename);
        return;
    end

    narginchk(3,3);

    %% Input Validation

    validateattributes(X,...
        {'double'},...
        {'real','finite','nonnan'},...
        mfilename,'X',1);

    validateattributes(Y,...
        {'double'},...
        {'real','finite','nonnan'},...
        mfilename,'Y',2);

    validateattributes(Z,...
        {'double'},...
        {'real','finite','nonnan'},...
        mfilename,'Z',3);

    if ~(isequal(size(X),size(Y)) && isequal(size(X),size(Z)))

        error('ECEF2LLA:InputSizeMismatch',...
            'X, Y and Z must have identical dimensions.');

    end

    %% WGS-84 Constants

    wgs84 = coordinates.WGS84();

    a  = wgs84.SemiMajorAxis;
    b  = wgs84.SemiMinorAxis;
    e2 = wgs84.FirstEccentricitySquared;

    %% Longitude

    longitude = atan2(Y,X);

    %% Distance from Earth's Rotation Axis

    p = hypot(X,Y);

    %% Initial Latitude Estimate

    latitude = atan2(Z,p.*(1-e2));

    %% Iterative Bowring Algorithm

    tolerance = 1e-12;
    maxIterations = 20;

    altitude = zeros(size(X),'double');

    for k = 1:maxIterations

        % Radius of curvature
        sinLat = sin(latitude);

        N = a ./ sqrt(1 - e2.*sinLat.^2);

        % Latitude update
        latitudeNew = atan2( ...
            Z + e2.*N.*sinLat,...
            p);

        % Radius using updated latitude
        sinLat = sin(latitudeNew);

        N = a ./ sqrt(1 - e2.*sinLat.^2);

        % Altitude update
        altitudeNew = p ./ cos(latitudeNew) - N;

        % Convergence

        if max(abs(latitudeNew(:)-latitude(:))) < tolerance

            latitude = latitudeNew;
            altitude = altitudeNew;
            break;

        end

        latitude = latitudeNew;
        altitude = altitudeNew;

    end

    %% Convergence Warning

    if k == maxIterations

        warning('ECEF2LLA:NoConvergence',...
            'Bowring iteration reached the maximum number of iterations.');

    end

    %% Polar Handling

    poleMask = p < eps;

    if any(poleMask(:))

        latitude(poleMask) = sign(Z(poleMask)).*(pi/2);

        longitude(poleMask) = 0;

        altitude(poleMask) = abs(Z(poleMask)) - b;

    end

    %% Output Validation

    validateattributes(latitude,...
        {'double'},...
        {'real','finite'});

    validateattributes(longitude,...
        {'double'},...
        {'real','finite'});

    validateattributes(altitude,...
        {'double'},...
        {'real','finite'});

end

