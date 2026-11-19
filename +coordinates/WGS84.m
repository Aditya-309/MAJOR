classdef WGS84
    %WGS84 WGS-84 Earth Model Constants
    %
    % Static utility class containing immutable WGS-84 constants and
    % helper methods for geodetic calculations.
    %
    % All units are SI.
    %
    % Example:
    %   a = WGS84.SemiMajorAxis;
    %   e2 = WGS84.FirstEccentricitySquared;
    %   N = WGS84.primeVerticalRadius(deg2rad(45));

    properties (Constant)

        %% WGS-84 Ellipsoid
        SemiMajorAxis (1,1) double = 6378137.0                % m
        Flattening (1,1) double = 1/298.257223563
        SemiMinorAxis (1,1) double = 6356752.314245           % m

        %% Eccentricities
        FirstEccentricitySquared (1,1) double = 6.69437999014e-3
        FirstEccentricity (1,1) double = sqrt(6.69437999014e-3)

        SecondEccentricitySquared (1,1) double = 6.73949674228e-3
        SecondEccentricity (1,1) double = sqrt(6.73949674228e-3)

        %% Earth Constants
        EarthRotationRate (1,1) double = 7.292115e-5          % rad/s
        StandardGravity (1,1) double = 9.80665                % m/s^2
        SeaLevelDensity (1,1) double = 1.225                  % kg/m^3

    end

    methods (Static)

        function N = primeVerticalRadius(latitude)
            %PRIMEVERTICALRADIUS Prime vertical radius of curvature.
            %
            % Input:
            %   latitude (rad)
            %
            % Output:
            %   N (m)

            validateattributes(latitude,...
                {'double'},...
                {'real','finite','nonnan'});

            s = sin(latitude);

            N = WGS84.SemiMajorAxis ./ ...
                sqrt(1 - WGS84.FirstEccentricitySquared .* s.^2);

        end

        function M = meridianRadius(latitude)
            %MERIDIANRADIUS Meridian radius of curvature.
            %
            % Input:
            %   latitude (rad)
            %
            % Output:
            %   M (m)

            validateattributes(latitude,...
                {'double'},...
                {'real','finite','nonnan'});

            s = sin(latitude);

            denom = 1 - WGS84.FirstEccentricitySquared .* s.^2;

            M = WGS84.SemiMajorAxis .* ...
                (1 - WGS84.FirstEccentricitySquared) ./ ...
                (denom.^(3/2));

        end

    end

end