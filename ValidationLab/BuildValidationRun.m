function RunInfo = BuildValidationRun(RunID, ScenarioName, Duration_s, ...
        Seed, ValRoot)
%BUILDVALIDATIONRUN Build one seeded validation run (B1 truth + A2 noise).
%
%   RunInfo = BUILDVALIDATIONRUN(RunID, ScenarioName, Duration_s, Seed,
%   ValRoot) generates:
%       1. analytic maneuvering ground truth   (GenerateAnalyticGroundTruth)
%       2. ideal sensors via FROZEN Block 5/8 generators
%       3. seeded noise via FROZEN noisemodels (Config.RandomSeed = Seed)
%       4. realistic telemetry = ideal + noise (additive error model)
%       5. a run folder under ValRoot/production/Runs/<RunID>/ ready for
%          preprocessing.PreprocessRun with Options.RunDirectory.
%
%   No frozen code is modified; all outputs stay under ValRoot.

    Rates = struct('IMU', 100, 'GNSS', 10, 'Magnetometer', 50, 'AirData', 50);

    %% 1. Ground truth (B1)
    Anchor = [deg2rad(28.6), deg2rad(77.2), 300];
    [GroundTruth, Scenario] = GenerateAnalyticGroundTruth( ...
        ScenarioName, Duration_s, Anchor);

    %% 2. Ideal sensors (frozen Block 5/8 generators)
    TL.IMU = sensormodels.BuildSensorTimeline(GroundTruth, Rates.IMU);
    TL.GNSS = sensormodels.BuildSensorTimeline(GroundTruth, Rates.GNSS);
    TL.Magnetometer = sensormodels.BuildSensorTimeline(GroundTruth, ...
        Rates.Magnetometer);
    TL.AirData = sensormodels.BuildSensorTimeline(GroundTruth, Rates.AirData);

    Ideal = struct();
    Ideal.IMU = sensormodels.GenerateIdealIMU(GroundTruth, TL.IMU);
    Ideal.GNSS = sensormodels.GenerateIdealGNSS(GroundTruth, TL.GNSS);
    Ideal.Magnetometer = sensormodels.GenerateIdealMagnetometer( ...
        GroundTruth, TL.Magnetometer);
    Ideal.AirData = sensormodels.GenerateIdealAirData( ...
        GroundTruth, TL.AirData, Scenario);

    %% 3. Seeded noise realization (A2: the seed IS the realization)
    NoiseConfig = noisemodels.SensorNoiseConfig();
    NoiseConfig.RandomSeed = Seed;

    SensorTimeline = struct( ...
        'IMU', struct('Time_s', TL.IMU.Time_s), ...
        'GNSS', struct('Time_s', TL.GNSS.Time_s), ...
        'Magnetometer', struct('Time_s', TL.Magnetometer.Time_s), ...
        'AirData', struct('Time_s', TL.AirData.Time_s));
    Noise = noisemodels.GenerateSensorNoise(SensorTimeline, NoiseConfig);

    %% 4. Realistic = (1 + scale)*ideal + bias + noise  (physical IMU model)
    Realistic = Ideal;

    IM = Noise.IMU.MeasurementNoise;
    IB = Noise.IMU.Bias;
    IS = Noise.IMU.ScaleFactor;
    Realistic.IMU.Accelerometer_mps2 = ...
        (1 + IS.AccelerometerScaleFactor) .* Ideal.IMU.Accelerometer_mps2 ...
        + IB.AccelerometerTotalBias_mps2 + IM.AccelerometerNoise_mps2;
    Realistic.IMU.Gyroscope_radps = ...
        (1 + IS.GyroscopeScaleFactor) .* Ideal.IMU.Gyroscope_radps ...
        + IB.GyroscopeTotalBias_radps + IM.GyroscopeNoise_radps;

    GN = Noise.GNSS.MeasurementNoise;
    GB = Noise.GNSS.Bias;
    Realistic.GNSS = addGeodeticNoise(Ideal.GNSS, GN, GB);

    Realistic.Magnetometer = addField(Ideal.Magnetometer, ...
        Noise.Magnetometer, ...
        {'MagneticFieldBody_uT', 'MagnetometerNoise_uT'});
    AirNoise = findAirNoise(Noise);
    Realistic.AirData = addField(Ideal.AirData, AirNoise, ...
        {'TrueAirspeed_mps', 'AirspeedNoise_mps'});

    %% 5. Run folder
    RunDir = fullfile(ValRoot, 'production', 'Runs', RunID);

    if exist(RunDir, 'dir')
        error('ValidationLab:BuildValidationRun:RunExists', ...
            'Run directory already exists: %s', RunDir);
    end

    mkdir(fullfile(RunDir, 'GroundTruth'));
    mkdir(fullfile(RunDir, 'IdealSensorTelemetry'));
    mkdir(fullfile(RunDir, 'RealisticSensorTelemetry'));

    save(fullfile(RunDir, 'GroundTruth', 'GroundTruthTelemetry.mat'), ...
        'GroundTruth');
    save(fullfile(RunDir, 'IdealSensorTelemetry', ...
        'IdealSensorTelemetry.mat'), 'Ideal');
    sensorsimulation.WriteSensorTelemetry(Realistic, ...
        fullfile(RunDir, 'RealisticSensorTelemetry'));

    Meta = struct('RunID', RunID, 'Scenario', ScenarioName, ...
        'Duration_s', Duration_s, 'RandomSeed', Seed, ...
        'Generator', 'ValidationLab/BuildValidationRun', ...
        'TruthType', 'AnalyticKinematic');
    writeJson(fullfile(RunDir, 'RunMetadata.json'), Meta);

    RunInfo = struct('RunID', RunID, 'RunDirectory', RunDir, ...
        'Scenario', ScenarioName, 'Seed', Seed, ...
        'Samples', struct('IMU', numel(TL.IMU.Time_s), ...
        'GNSS', numel(TL.GNSS.Time_s), ...
        'Magnetometer', numel(TL.Magnetometer.Time_s), ...
        'AirData', numel(TL.AirData.Time_s)));

end

%% ------------------------------------------------------------------ helpers

function S = addField(IdealS, NoiseS, Pairs)
    S = IdealS;

    for k = 1:size(Pairs, 1)
        [iOk, nOk] = checkPair(IdealS, NoiseS, Pairs{k, 1}, Pairs{k, 2});

        if ~iOk || ~nOk
            error('ValidationLab:BuildValidationRun:FieldMismatch', ...
                ['Missing field for pair (%s, %s).\nIdeal fields: %s\n', ...
                'Noise fields: %s'], Pairs{k, 1}, Pairs{k, 2}, ...
                strjoin(fieldnames(IdealS), ','), ...
                strjoin(fieldnames(NoiseS), ','));
        end

        S.(Pairs{k, 1}) = IdealS.(Pairs{k, 1}) + NoiseS.(Pairs{k, 2});
    end

end

function [iOk, nOk] = checkPair(IdealS, NoiseS, iName, nName)
    iOk = isfield(IdealS, iName);
    nOk = isfield(NoiseS, nName);
end

function S = addGeodeticNoise(IdealS, NoiseS, BiasS)
    % GNSS position error enters in NED metres (GM bias + noise); the ideal
    % fields are geodetic. Convert and add; velocity noise adds in NED.
    S = IdealS;
    Lat = IdealS.Latitude_rad;
    Lon = IdealS.Longitude_rad;
    Alt = IdealS.Altitude_m;
    R = 6378137;
    n = BiasS.PositionBias_m + NoiseS.PositionNoise_m;
    S.Latitude_rad = Lat + n(:, 1) ./ (R + Alt);
    S.Longitude_rad = Lon + n(:, 2) ./ ((R + Alt) .* max(cos(Lat), 1e-6));
    S.Altitude_m = Alt - n(:, 3);
    S.Velocity_NED_mps = IdealS.Velocity_NED_mps + NoiseS.VelocityNoise_mps;
end

function AirNoise = findAirNoise(Noise)
    Candidates = {'Airspeed', 'AirData'};
    AirNoise = [];

    for k = 1:numel(Candidates)

        if isfield(Noise, Candidates{k})
            AirNoise = Noise.(Candidates{k});
            return
        end

    end

    % fall back: a flat struct holding an AirspeedNoise field
    F = fieldnames(Noise);

    for k = 1:numel(F)
        Sub = Noise.(F{k});

        if isstruct(Sub) && isfield(Sub, 'AirspeedNoise_mps')
            AirNoise = Sub;
            return
        end

    end

    error('ValidationLab:BuildValidationRun:AirNoiseMissing', ...
        'Could not locate airspeed noise in Noise (fields: %s).', ...
        strjoin(F, ','));
end

function writeJson(Path, S)
    txt = jsonencode(S, 'PrettyPrint', true);
    fid = fopen(Path, 'w');

    if fid < 0
        error('ValidationLab:BuildValidationRun:JsonWrite', ...
            'Cannot write %s', Path);
    end

    fwrite(fid, txt, 'char');
    fclose(fid);
end
