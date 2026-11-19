function GroundTruth = ConvertGroundTruthState(TelemetryFile)
%CONVERTGROUNDTRUTHSTATE Convert raw JSBSim telemetry to canonical SI state.

    %% Input Validation

    if nargin ~= 1

        error( ...
            'Block7:ConvertGroundTruthState:InvalidInputCount', ...
            'ConvertGroundTruthState requires exactly one input: TelemetryFile.');

    end

    if ~(ischar(TelemetryFile) || ...
            (isstring(TelemetryFile) && isscalar(TelemetryFile)))

        error( ...
            'Block7:ConvertGroundTruthState:InvalidTelemetryFile', ...
            'TelemetryFile must be a character vector or scalar string.');

    end

    TelemetryFile = char(TelemetryFile);

    if ~isfile(TelemetryFile)

        error( ...
            'Block7:ConvertGroundTruthState:TelemetryFileNotFound', ...
            'Telemetry file does not exist: %s', ...
            TelemetryFile);

    end

    [~, ~, Extension] = fileparts(TelemetryFile);

    if ~strcmpi(Extension, '.csv')

        error( ...
            'Block7:ConvertGroundTruthState:InvalidTelemetryExtension', ...
            'TelemetryFile must use the .csv extension.');

    end

    FileInfo = dir(TelemetryFile);

    if FileInfo.bytes <= 0

        error( ...
            'Block7:ConvertGroundTruthState:EmptyTelemetryFile', ...
            'Telemetry file is empty: %s', ...
            TelemetryFile);

    end

    %% Read CSV Header Directly

    FileID = fopen(TelemetryFile, 'r');

    if FileID == -1

        error( ...
            'Block7:ConvertGroundTruthState:FileOpenFailed', ...
            'Unable to open telemetry file: %s', ...
            TelemetryFile);

    end

    CleanupObject = ...
        onCleanup(@() fclose(FileID));

    HeaderLine = fgetl(FileID);

    clear CleanupObject;

    if ~ischar(HeaderLine) || isempty(strtrim(HeaderLine))

        error( ...
            'Block7:ConvertGroundTruthState:InvalidTelemetryHeader', ...
            'Telemetry CSV file does not contain a valid header.');

    end

    HeaderNames = strsplit(HeaderLine, ',');

    for HeaderIndex = 1:numel(HeaderNames)

        HeaderNames{HeaderIndex} = ...
            strtrim(HeaderNames{HeaderIndex});

        HeaderNames{HeaderIndex} = ...
            strrep(HeaderNames{HeaderIndex}, '"', '');

    end

    %% Read Numeric Data

    try

        RawMatrix = readmatrix( ...
            TelemetryFile, ...
            'NumHeaderLines', ...
            1);

    catch ME

        error( ...
            'Block7:ConvertGroundTruthState:TelemetryReadFailed', ...
            'Unable to read telemetry file "%s": %s', ...
            TelemetryFile, ...
            ME.message);

    end

    if isempty(RawMatrix) || ...
            size(RawMatrix, 1) == 0

        error( ...
            'Block7:ConvertGroundTruthState:NoTelemetrySamples', ...
            'Telemetry file contains no data samples.');

    end

    if size(RawMatrix, 2) ~= numel(HeaderNames)

        error( ...
            'Block7:ConvertGroundTruthState:HeaderDataMismatch', ...
            ['Number of CSV headers does not match the number of ' ...
             'numeric data columns.']);

    end

    if any(~isfinite(RawMatrix), 'all')

        error( ...
            'Block7:ConvertGroundTruthState:NonFiniteTelemetryData', ...
            'Telemetry file contains NaN or Inf values.');

    end

    %% Required JSBSim Properties

    RequiredProperties = { ...
        'simulation/sim-time-sec'
        'position/lat-geod-deg'
        'position/long-gc-deg'
        'position/h-sl-ft'
        'velocities/u-fps'
        'velocities/v-fps'
        'velocities/w-fps'
        'velocities/p-rad_sec'
        'velocities/q-rad_sec'
        'velocities/r-rad_sec'
        'attitude/phi-rad'
        'attitude/theta-rad'
        'attitude/psi-rad'
        'atmosphere/rho-slugs_ft3'
        };

    RawData = struct();

    for PropertyIndex = 1:numel(RequiredProperties)

        PropertyName = ...
            RequiredProperties{PropertyIndex};

        ColumnIndex = find( ...
    strcmp(HeaderNames, PropertyName), ...
    1);

    if isempty(ColumnIndex)

        JSBSimPropertyName = ...
            ['/fdm/jsbsim/' PropertyName];

         ColumnIndex = find( ...
        strcmp(HeaderNames, JSBSimPropertyName), ...
        1);

    end

        if isempty(ColumnIndex)

            error( ...
                'Block7:ConvertGroundTruthState:MissingTelemetryProperty', ...
                ['Required JSBSim telemetry property "%s" was not ' ...
                 'found in the CSV file.'], ...
                PropertyName);

        end

        Values = ...
            RawMatrix(:, ColumnIndex);

        if any(~isfinite(Values))

            error( ...
                'Block7:ConvertGroundTruthState:NonFiniteTelemetryData', ...
                ['Telemetry property "%s" contains NaN or Inf ' ...
                 'values.'], ...
                PropertyName);

        end

        FieldName = ...
            matlab.lang.makeValidName(PropertyName);

        RawData.(FieldName) = ...
            Values(:);

    end

    %% Extract Raw Values

    Time_s = ...
        RawData.simulation_sim_time_sec;

    Latitude_deg = ...
        RawData.position_lat_geod_deg;

    Longitude_deg = ...
        RawData.position_long_gc_deg;

    Altitude_ft = ...
        RawData.position_h_sl_ft;

    U_fps = ...
        RawData.velocities_u_fps;

    V_fps = ...
        RawData.velocities_v_fps;

    W_fps = ...
        RawData.velocities_w_fps;

    P_radps = ...
        RawData.velocities_p_rad_sec;

    Q_radps = ...
        RawData.velocities_q_rad_sec;

    R_radps = ...
        RawData.velocities_r_rad_sec;

    Phi_rad = ...
        RawData.attitude_phi_rad;

    Theta_rad = ...
        RawData.attitude_theta_rad;

    Psi_rad = ...
        RawData.attitude_psi_rad;

    Density_slugft3 = ...
        RawData.atmosphere_rho_slugs_ft3;

    %% Validate Time History

    if numel(Time_s) < 2

        error( ...
            'Block7:ConvertGroundTruthState:InsufficientSamples', ...
            'Telemetry must contain at least two samples.');

    end

    TimeDifference_s = ...
        diff(Time_s);

    if any(TimeDifference_s <= 0)

        error( ...
            'Block7:ConvertGroundTruthState:InvalidTimeHistory', ...
            ['Telemetry time must be strictly increasing with no ' ...
             'duplicate or reversed samples.']);

    end

    %% Unit Conversion

    FeetToMetres = ...
        0.3048;

    SlugPerCubicFootToKgPerCubicMetre = ...
        515.378818;

    Latitude_rad = ...
        deg2rad(Latitude_deg);

    Longitude_rad = ...
        deg2rad(Longitude_deg);

    Altitude_m = ...
        Altitude_ft .* FeetToMetres;

    VelocityBody_mps = [ ...
        U_fps .* FeetToMetres, ...
        V_fps .* FeetToMetres, ...
        W_fps .* FeetToMetres ...
        ];

    AngularRateBody_radps = [ ...
        P_radps, ...
        Q_radps, ...
        R_radps ...
        ];

    Euler_rad = [ ...
        Phi_rad, ...
        Theta_rad, ...
        Psi_rad ...
        ];

    AirDensity_kgpm3 = ...
        Density_slugft3 .* ...
        SlugPerCubicFootToKgPerCubicMetre;

    %% Final Validation

    if any(~isfinite(Latitude_rad)) || ...
            any(~isfinite(Longitude_rad)) || ...
            any(~isfinite(Altitude_m))

        error( ...
            'Block7:ConvertGroundTruthState:InvalidPosition', ...
            'Converted position contains non-finite values.');

    end

    if any(~isfinite(VelocityBody_mps), 'all')

        error( ...
            'Block7:ConvertGroundTruthState:InvalidVelocity', ...
            'Converted body velocity contains non-finite values.');

    end

    if any(~isfinite(AngularRateBody_radps), 'all')

        error( ...
            'Block7:ConvertGroundTruthState:InvalidAngularRate', ...
            'Converted angular rate contains non-finite values.');

    end

    if any(~isfinite(Euler_rad), 'all')

        error( ...
            'Block7:ConvertGroundTruthState:InvalidAttitude', ...
            'Converted Euler attitude contains non-finite values.');

    end

    if any(~isfinite(AirDensity_kgpm3)) || ...
            any(AirDensity_kgpm3 <= 0)

        error( ...
            'Block7:ConvertGroundTruthState:InvalidAirDensity', ...
            'Converted air density must be positive and finite.');

    end

    %% Assemble Output

    GroundTruth = struct();

    GroundTruth.Time_s = ...
        Time_s;

    GroundTruth.Position = struct();

    GroundTruth.Position.Latitude_rad = ...
        Latitude_rad;

    GroundTruth.Position.Longitude_rad = ...
        Longitude_rad;

    GroundTruth.Position.Altitude_m = ...
        Altitude_m;

    GroundTruth.VelocityBody_mps = ...
        VelocityBody_mps;

    GroundTruth.AngularRateBody_radps = ...
        AngularRateBody_radps;

    GroundTruth.Euler_rad = ...
        Euler_rad;

    GroundTruth.AirDensity_kgpm3 = ...
        AirDensity_kgpm3;

    GroundTruth.SampleTime_s = ...
        median(TimeDifference_s);

    GroundTruth.SampleCount = ...
        numel(Time_s);

    GroundTruth.SourceFile = ...
        TelemetryFile;

end