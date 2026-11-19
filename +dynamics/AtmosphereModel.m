function [T,P,rho,a] = AtmosphereModel(altitude)
%ATMOSPHEREMODEL International Standard Atmosphere (ISA 1976)
%
%   [T,P,rho,a] = dynamics.AtmosphereModel(altitude)
%
%   Description
%   -----------
%   Computes the standard atmospheric properties using the
%   International Standard Atmosphere (ISA 1976) model for the
%   troposphere (0–11 km).
%
%   Inputs
%   ------
%   altitude
%       Geometric altitude above Mean Sea Level (m)
%
%   Outputs
%   -------
%   T
%       Temperature (K)
%
%   P
%       Pressure (Pa)
%
%   rho
%       Air Density (kg/m^3)
%
%   a
%       Speed of Sound (m/s)
%
%   Assumptions
%   -----------
%   Valid for:
%       0 <= altitude <= 11000 m
%
%   Aircraft
%   --------
%   Cessna 172P
%
%   Earth Model
%   -----------
%   WGS-84
%
%   Units
%   -----
%   SI Units
%
%   Examples
%   --------
%   [T,P,rho,a] = dynamics.AtmosphereModel(0);
%
%   [T,P,rho,a] = dynamics.AtmosphereModel(2500);
%
%   altitude = [0 1000 2000 3000];
%   [T,P,rho,a] = dynamics.AtmosphereModel(altitude);

if nargin==0
    help(mfilename);
    return;
end

narginchk(1,1);

validateattributes(altitude,...
    {'numeric'},...
    {'real','finite','nonnegative'},...
    mfilename,...
    'altitude',1);

if any(altitude(:)>11000)
    error('AtmosphereModel:AltitudeOutOfRange',...
        'ISA troposphere model is valid only for altitudes between 0 and 11000 meters.');
end

altitude = double(altitude);

%% ISA Constants

T0 = 288.15;          % K
P0 = 101325.0;        % Pa
L  = 0.0065;          % K/m
R  = 287.05287;       % J/(kg·K)
gamma = 1.4;

g = config.AircraftConfig.Gravity;

%% Temperature

T = T0 - L.*altitude;

%% Pressure

P = P0.*(T./T0).^(g/(R*L));

%% Density

rho = P./(R.*T);

%% Speed of Sound

a = sqrt(gamma.*R.*T);

%% Output Validation

validateattributes(T,...
    {'double'},...
    {'real','finite','positive'});

validateattributes(P,...
    {'double'},...
    {'real','finite','positive'});

validateattributes(rho,...
    {'double'},...
    {'real','finite','positive'});

validateattributes(a,...
    {'double'},...
    {'real','finite','positive'});

end