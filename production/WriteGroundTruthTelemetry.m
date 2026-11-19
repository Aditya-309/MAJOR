function OutputPaths = WriteGroundTruthTelemetry( ...
    GroundTruth, ...
    GroundTruthDirectory)
%WRITEGROUNDTRUTHTELEMETRY Persist canonical ASRTE GroundTruth telemetry.
%
%   OutputPaths = WriteGroundTruthTelemetry( ...
%       GroundTruth, GroundTruthDirectory)
%
%   Writes the already-generated canonical GroundTruth structure to:
%
%       GroundTruthTelemetry.mat
%       GroundTruthTelemetry.csv
%
%   No GroundTruth values are regenerated, transformed, or modified.
%
%   The CSV contains the canonical GroundTruth quantities in SI units:
%
%       Time_s
%       Latitude_rad
%       Longitude_rad
%       Altitude_m
%       VelocityBody_U_mps
%       VelocityBody_V_mps
%       VelocityBody_W_mps
%       AngularRateBody_P_radps
%       AngularRateBody_Q_radps
%       AngularRateBody_R_radps
%       Euler_Phi_rad
%       Euler_Theta_rad
%       Euler_Psi_rad
%       AirDensity_kgpm3

    %% ============================================================
    % INPUT VALIDATION
    % ============================================================

    if nargin ~= 2

        error( ...
            'Production:WriteGroundTruthTelemetry:InvalidInputCount', ...
            ['WriteGroundTruthTelemetry requires exactly two inputs: ' ...
             'GroundTruth and GroundTruthDirectory.']);

    end

    if ~isstruct(GroundTruth) || ~isscalar(GroundTruth)

        error( ...
            'Production:WriteGroundTruthTelemetry:InvalidGroundTruth', ...
            'GroundTruth must be a scalar structure.');

    end

    if ~(ischar(GroundTruthDirectory) || ...
            (isstring(GroundTruthDirectory) && ...
             isscalar(GroundTruthDirectory)))

        error( ...
            'Production:WriteGroundTruthTelemetry:InvalidDirectory', ...
            'GroundTruthDirectory must be a character vector or scalar string.');

    end

    GroundTruthDirectory = char(GroundTruthDirectory);

    %% ============================================================
    % REQUIRED CANONICAL FIELDS
    % =============================================================

    RequiredFields = { ...
        'SampleCount'
        'SampleTime_s'
        'Time_s'
        'Position'
        'VelocityBody_mps'
        'AngularRateBody_radps'
        'Euler_rad'
        'AirDensity_kgpm3'
        'SourceFile'
        };

    for Index = 1:numel(RequiredFields)

        FieldName = RequiredFields{Index};

        if ~isfield(GroundTruth, FieldName)

            error( ...
                'Production:WriteGroundTruthTelemetry:MissingField', ...
                'GroundTruth.%s is required.', ...
                FieldName);

        end

    end

    %% ============================================================
    % REQUIRED POSITION FIELDS
    % =============================================================

    PositionFields = { ...
        'Latitude_rad'
        'Longitude_rad'
        'Altitude_m'
        };

    if ~isstruct(GroundTruth.Position) || ...
            ~isscalar(GroundTruth.Position)

        error( ...
            'Production:WriteGroundTruthTelemetry:InvalidPosition', ...
            'GroundTruth.Position must be a scalar structure.');

    end

    for Index = 1:numel(PositionFields)

        FieldName = PositionFields{Index};

        if ~isfield(GroundTruth.Position, FieldName)

            error( ...
                'Production:WriteGroundTruthTelemetry:MissingPositionField', ...
                'GroundTruth.Position.%s is required.', ...
                FieldName);

        end

    end

    %% ============================================================
    % VALIDATE DIMENSIONS AGAINST SAMPLE COUNT
    % =============================================================

    SampleCount = GroundTruth.SampleCount;

    if ~isnumeric(SampleCount) || ...
            ~isscalar(SampleCount) || ...
            ~isfinite(SampleCount) || ...
            SampleCount < 1 || ...
            SampleCount ~= floor(SampleCount)

        error( ...
            'Production:WriteGroundTruthTelemetry:InvalidSampleCount', ...
            'GroundTruth.SampleCount must be a positive integer.');

    end

    SampleCount = double(SampleCount);

    Time_s = GroundTruth.Time_s(:);

    if numel(Time_s) ~= SampleCount

        error( ...
            'Production:WriteGroundTruthTelemetry:TimeCountMismatch', ...
            'GroundTruth.Time_s does not match SampleCount.');

    end

    VelocityBody_mps = GroundTruth.VelocityBody_mps;

    AngularRateBody_radps = GroundTruth.AngularRateBody_radps;

    Euler_rad = GroundTruth.Euler_rad;

    if ~isequal(size(VelocityBody_mps), [SampleCount 3])

        error( ...
            'Production:WriteGroundTruthTelemetry:VelocityDimensions', ...
            'GroundTruth.VelocityBody_mps must be SampleCount-by-3.');

    end

    if ~isequal(size(AngularRateBody_radps), [SampleCount 3])

        error( ...
            'Production:WriteGroundTruthTelemetry:AngularRateDimensions', ...
            'GroundTruth.AngularRateBody_radps must be SampleCount-by-3.');

    end

    if ~isequal(size(Euler_rad), [SampleCount 3])

        error( ...
            'Production:WriteGroundTruthTelemetry:EulerDimensions', ...
            'GroundTruth.Euler_rad must be SampleCount-by-3.');

    end

    %% ============================================================
    % POSITION VECTORS
    % =============================================================

    Latitude_rad = GroundTruth.Position.Latitude_rad(:);
    Longitude_rad = GroundTruth.Position.Longitude_rad(:);
    Altitude_m = GroundTruth.Position.Altitude_m(:);

    AirDensity_kgpm3 = GroundTruth.AirDensity_kgpm3(:);

    if numel(Latitude_rad) ~= SampleCount || ...
            numel(Longitude_rad) ~= SampleCount || ...
            numel(Altitude_m) ~= SampleCount

        error( ...
            'Production:WriteGroundTruthTelemetry:PositionCountMismatch', ...
            'GroundTruth position vectors must match SampleCount.');

    end

    if numel(AirDensity_kgpm3) ~= SampleCount

        error( ...
            'Production:WriteGroundTruthTelemetry:DensityCountMismatch', ...
            'GroundTruth.AirDensity_kgpm3 must match SampleCount.');

    end

    %% ============================================================
    % CREATE OUTPUT DIRECTORY
    % =============================================================

    if ~isfolder(GroundTruthDirectory)

        mkdir(GroundTruthDirectory);

    end

    %% ============================================================
    % MAT FILE
    % =============================================================

    MATFile = fullfile( ...
        GroundTruthDirectory, ...
        'GroundTruthTelemetry.mat');

    save( ...
        MATFile, ...
        'GroundTruth', ...
        '-v7');

    %% ============================================================
    % CSV TABLE
    % ============================================================

    GroundTruthTable = table( ...
        Time_s, ...
        Latitude_rad, ...
        Longitude_rad, ...
        Altitude_m, ...
        VelocityBody_mps(:,1), ...
        VelocityBody_mps(:,2), ...
        VelocityBody_mps(:,3), ...
        AngularRateBody_radps(:,1), ...
        AngularRateBody_radps(:,2), ...
        AngularRateBody_radps(:,3), ...
        Euler_rad(:,1), ...
        Euler_rad(:,2), ...
        Euler_rad(:,3), ...
        AirDensity_kgpm3, ...
        'VariableNames', { ...
        'Time_s'
        'Latitude_rad'
        'Longitude_rad'
        'Altitude_m'
        'VelocityBody_U_mps'
        'VelocityBody_V_mps'
        'VelocityBody_W_mps'
        'AngularRateBody_P_radps'
        'AngularRateBody_Q_radps'
        'AngularRateBody_R_radps'
        'Euler_Phi_rad'
        'Euler_Theta_rad'
        'Euler_Psi_rad'
        'AirDensity_kgpm3'
        });

    CSVFile = fullfile( ...
        GroundTruthDirectory, ...
        'GroundTruthTelemetry.csv');

    writetable( ...
        GroundTruthTable, ...
        CSVFile);

    %% ============================================================
    % FINAL FILE VALIDATION
    % =============================================================

    if ~isfile(MATFile)

        error( ...
            'Production:WriteGroundTruthTelemetry:MATWriteFailed', ...
            'GroundTruth MAT file was not created.');

    end

    if ~isfile(CSVFile)

        error( ...
            'Production:WriteGroundTruthTelemetry:CSVWriteFailed', ...
            'GroundTruth CSV file was not created.');

    end

    MATInfo = dir(MATFile);
    CSVInfo = dir(CSVFile);

    if MATInfo.bytes <= 0

        error( ...
            'Production:WriteGroundTruthTelemetry:EmptyMATFile', ...
            'GroundTruth MAT file is empty.');

    end

    if CSVInfo.bytes <= 0

        error( ...
            'Production:WriteGroundTruthTelemetry:EmptyCSVFile', ...
            'GroundTruth CSV file is empty.');

    end

    %% ============================================================
    % OUTPUT PATH STRUCTURE
    % =============================================================

    OutputPaths = struct();

    OutputPaths.GroundTruthMAT = MATFile;

    OutputPaths.GroundTruthCSV = CSVFile;

end