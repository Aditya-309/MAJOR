function Report = BuildPreprocessingReport( ...
    Config, Data, ProcessedStreams, Aligned, RunInfo)
%BUILDPREPROCESSINGREPORT Build the auditable Block 9 preprocessing report.
%
%   Report = BUILDPREPROCESSINGREPORT(Config, Data, ProcessedStreams,
%   Aligned, RunInfo) assembles the complete preprocessing report.
%
%   Inputs:
%       Config           - validated preprocessing configuration
%       Data             - LoadSensorData output
%       ProcessedStreams - Phase-4 processed streams (per stream name)
%       Aligned          - BuildAlignedSensorData output
%       RunInfo          - scalar struct with fields: RunID, PreprocessID,
%                          RunDirectory, OutputDirectory, Eligibility,
%                          Category, Status, Warnings, Errors,
%                          ApprovalUsed
%
%   Provenance categories are kept strictly separate:
%       Report.RunRecorded        - values explicitly recorded in
%                                   RunMetadata.json or source artifacts
%                                   ('NotRecorded' where absent; nothing
%                                   is inferred).
%       Report.CurrentCodeDefaults - current preprocessing code defaults
%                                   (NOT historical run settings).
%       Report.MeasuredStatistics - values measured from the loaded data
%                                   ('NotMeasured' where a stream is not
%                                   loaded).
%
%   Report sections: RunInfo, Configuration, ConfigurationProvenance,
%   RunRecorded, CurrentCodeDefaults, MeasuredStatistics, MissingSensors,
%   Units, CoordinateConventions, Alignment, Warnings, Errors, Outputs,
%   Status.
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: ExportPreprocessedData, BuildAlignedSensorData, PreprocessRun.

    %% Validate Inputs

    preprocessing.ValidatePreprocessingConfig(Config);

    RequiredRunInfo = { ...
        'RunID', 'PreprocessID', 'RunDirectory', 'OutputDirectory', ...
        'Eligibility', 'Category', 'Status', 'Warnings', 'Errors', ...
        'ApprovalUsed'};

    if ~isstruct(RunInfo) || ~isscalar(RunInfo) || ...
            ~all(isfield(RunInfo, RequiredRunInfo))

        error( ...
            'Preprocessing:BuildPreprocessingReport:InvalidRunInfo', ...
            'RunInfo is missing required fields: %s.', ...
            strjoin(RequiredRunInfo(~isfield( ...
                RunInfo, RequiredRunInfo)), ', '));

    end

    Contracts = preprocessing.SensorDataContracts();

    %% Run Info And Configuration

    Report = struct();
    Report.RunInfo = struct( ...
        'RunID', RunInfo.RunID, ...
        'PreprocessID', RunInfo.PreprocessID, ...
        'Eligibility', RunInfo.Eligibility, ...
        'Category', RunInfo.Category, ...
        'RunDirectory', RunInfo.RunDirectory, ...
        'OutputDirectory', RunInfo.OutputDirectory, ...
        'ProcessingTimestamp', char(datetime( ...
            'now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss')), ...
        'MATLABRelease', version('-release'), ...
        'MATLABVersion', version(), ...
        'ApprovalUsed', RunInfo.ApprovalUsed, ...
        'Status', RunInfo.Status);

    Report.Configuration = Config;
    Report.ConfigurationProvenance = [ ...
        'Current preprocessing code defaults as configured for this ', ...
        'run; not historical run settings.'];

    %% Run-Recorded Settings

    RunRecorded = struct();
    RunRecorded.Source = 'RunMetadata.json';
    RunRecorded.Status = 'NotRecorded';
    RunRecorded.DecodeError = 'NotApplicable';
    RunRecorded.Run = 'NotRecorded';
    RunRecorded.Scenario = 'NotRecorded';
    RunRecorded.ConfigurationPath = 'NotRecorded';
    RunRecorded.RecordedSampleCounts = 'NotRecorded';
    RunRecorded.SensorSampleRates_Hz = 'NotRecorded';
    RunRecorded.SensorSampleRatesSource = 'NotRecorded';
    MetadataWarning = '';

    MetadataFile = fullfile(RunInfo.RunDirectory, 'RunMetadata.json');

    if ~isempty(RunInfo.RunDirectory) && isfile(MetadataFile)

        try

            Metadata = jsondecode(fileread(MetadataFile));
            RunRecorded.Status = 'Recorded';

            if isfield(Metadata, 'Run')
                RunRecorded.Run = Metadata.Run;
            end

            if isfield(Metadata, 'Scenario')
                RunRecorded.Scenario = Metadata.Scenario;
            end

            if isfield(Metadata, 'Configuration') && ...
                    isfield(Metadata.Configuration, 'ScenarioConfigPath')
                RunRecorded.ConfigurationPath = ...
                    Metadata.Configuration.ScenarioConfigPath;
            end

            if isfield(Metadata, 'Telemetry')
                RunRecorded.RecordedSampleCounts = Metadata.Telemetry;
            end

        catch DecodeFailure

            % F-05: an existing but unreadable/undecodable metadata file
            % is never reported as missing. The distinction is preserved
            % explicitly and surfaced as a structured warning.
            RunRecorded.Status = 'DecodeFailed';
            RunRecorded.DecodeError = DecodeFailure.message;
            MetadataWarning = sprintf( ...
                ['Preprocessing:BuildPreprocessingReport:', ...
                 'MetadataDecodeFailure: RunMetadata.json exists but ', ...
                 'could not be read or decoded (%s); recorded settings ', ...
                 'are reported as DecodeFailed, not as missing.'], ...
                DecodeFailure.message);

        end

    end

    RecordedRates = struct();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if isfield(Data.Streams, StreamName) && ...
                isfield(Data.Streams.(StreamName), 'SourceSampleRate_Hz') && ...
                isfinite(Data.Streams.(StreamName).SourceSampleRate_Hz)

            RecordedRates.(StreamName) = ...
                Data.Streams.(StreamName).SourceSampleRate_Hz;

        else

            RecordedRates.(StreamName) = 'NotRecorded';

        end

    end

    RunRecorded.SensorSampleRates_Hz = RecordedRates;
    RunRecorded.SensorSampleRatesSource = ...
        'MAT artifact field SampleRate_Hz where present.';
    Report.RunRecorded = RunRecorded;

    %% Current Code Defaults

    Report.CurrentCodeDefaults = struct( ...
        'Description', [ ...
            'Current preprocessing code defaults; not evidence of ', ...
            'historical run settings.'], ...
        'MissingSensorPolicy', Config.MissingSensors.Policy, ...
        'RequiredSensors', {Config.MissingSensors.RequiredSensors}, ...
        'GapAbsolute_s', Config.Timestamps.GapAbsolute_s, ...
        'GapRelative', Config.Timestamps.GapRelative, ...
        'DuplicatePolicy', Config.Timestamps.DuplicatePolicy, ...
        'StartupTransientWindowSamples', ...
            Config.Quality.StartupTransient.WindowSamples, ...
        'StatisticalWindowSamples', ...
            Config.Quality.Statistical.WindowSamples, ...
        'StatisticalSigmaThreshold', ...
            Config.Quality.Statistical.SigmaThreshold, ...
        'StatisticalDeviationFloor', ...
            Config.Quality.Statistical.DeviationFloor, ...
        'SensorRateFallbacks_Hz', fallbackRates(Contracts), ...
        'SensorRateFallbackProvenance', ...
            Contracts.IMU.RateFallbackSource);

    %% Measured Statistics And Units

    MeasuredStatistics = struct();
    Units = struct();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if isfield(Data.Streams, StreamName) && ...
                ~strcmp(Data.Streams.(StreamName).Status, 'Loaded')

            MeasuredStatistics.(StreamName) = struct( ...
                'Status', Data.Streams.(StreamName).Status, ...
                'AllFields', 'NotMeasured');
            Units.(StreamName) = 'NotMeasured';
            continue;

        end

        if ~isfield(ProcessedStreams, StreamName)

            Entry = struct('Status', 'NotProcessed', ...
                'AllFields', 'NotMeasured');
            MeasuredStatistics.(StreamName) = Entry;
            Units.(StreamName) = 'NotMeasured';
            continue;

        end

        Stream = ProcessedStreams.(StreamName);

        if ~strcmp(Stream.Status, 'Loaded')

            MeasuredStatistics.(StreamName) = struct( ...
                'Status', Stream.Status, ...
                'AllFields', 'NotMeasured');
            Units.(StreamName) = 'NotMeasured';
            continue;

        end

        MeasuredStatistics.(StreamName) = struct( ...
            'Status', 'Loaded', ...
            'SampleCount', Stream.TimestampSummary.TotalRows, ...
            'EstimatorReadyCount', Stream.TimestampSummary.ValidRows, ...
            'OriginalSampleCount', Stream.SampleCount, ...
            'NominalRate_Hz', Stream.NominalRate_Hz, ...
            'NominalPeriod_s', Stream.NominalPeriod_s, ...
            'NominalRateSource', Stream.NominalRateSource, ...
            'NominalRateEvidence', Stream.NominalRateEvidence, ...
            'TimestampSummary', Stream.TimestampSummary, ...
            'QualitySummary', Stream.QualitySummary, ...
            'OutlierSummary', Stream.OutlierSummary, ...
            'OutageCount', numel(Stream.Outages), ...
            'SegmentCount', numel(Stream.Segments));

        Units.(StreamName) = Stream.UnitConversions;

    end

    Report.MeasuredStatistics = MeasuredStatistics;

    MissingSensors = {};
    MalformedSensors = {};

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if isfield(Data.Streams, StreamName)

            if strcmp(Data.Streams.(StreamName).Status, 'Missing')

                MissingSensors{end + 1} = StreamName;

            elseif strcmp(Data.Streams.(StreamName).Status, 'Malformed')

                MalformedSensors{end + 1} = StreamName;

            end

        end

    end

    Report.MissingSensors = MissingSensors;
    Report.MalformedSensors = MalformedSensors;
    Report.Units = Units;

    %% Coordinate Conventions (verified Blocks 2-4 facts)

    Report.CoordinateConventions = struct( ...
        'NavigationFrame', 'NED (North-East-Down)', ...
        'BodyFrame', 'x forward, y right, z down (JSBSim u/v/w mapping)', ...
        'Quaternion', '[w x y z]; ZYX yaw-pitch-roll (+coordinates)', ...
        'Accelerometer', [ ...
            'specific force f_b = dv_b/dt + omega_b x v_b - g_b ', ...
            '(+sensormodels/GenerateIdealIMU.m)'], ...
        'Gravity', [ ...
            'standard g = 9.80665 m/s^2, +Z down in NED ', ...
            '(+dynamics/GravityModel.m)'], ...
        'MagneticField', 'body frame, canonical unit T');

    %% Alignment Section

    AlignmentInfo = struct();
    AlignmentInfo.Enabled = Aligned.Enabled;
    AlignmentInfo.Status = Aligned.Status;
    AlignmentInfo.ReferenceStream = Aligned.ReferenceStream;
    AlignmentInfo.MaxSampleAge_s = Aligned.MaxSampleAge_s;

    if strcmp(Aligned.Status, 'Generated')

        AlignmentInfo.ReferenceSampleCount = numel(Aligned.Time_s);
        AlignmentInfo.StreamCounts = Aligned.Summary;

    else

        AlignmentInfo.ReferenceSampleCount = 0;
        AlignmentInfo.StreamCounts = struct();

    end

    Report.Alignment = AlignmentInfo;

    %% Outputs, Warnings, Status

    Report.Outputs = artifactPaths(RunInfo.OutputDirectory);
    Report.Warnings = RunInfo.Warnings;

    if ~isempty(MetadataWarning)

        Report.Warnings{end + 1} = MetadataWarning;

    end

    Report.Errors = RunInfo.Errors;
    Report.Status = RunInfo.Status;

end

% =========================================================================
%% LOCAL HELPERS
% =========================================================================

function Paths = artifactPaths(OutputDirectory)
%ARTIFACTPATHS Approved output layout (single source of convention).
%   ExpectedReviewFiles lists the four contract paths. ReviewFiles is
%   populated only with files actually written and is finalized by
%   ExportPreprocessedData before the report JSON is published (F-04):
%   missing files are never listed as completed outputs.

    Paths = struct( ...
        'MatFile', fullfile(OutputDirectory, 'PreprocessedData.mat'), ...
        'JsonFile', fullfile(OutputDirectory, 'PreprocessingReport.json'), ...
        'ReviewDirectory', fullfile(OutputDirectory, 'Review'), ...
        'ExpectedReviewFiles', struct( ...
            'IMU', fullfile(OutputDirectory, 'Review', 'IMU.csv'), ...
            'GNSS', fullfile(OutputDirectory, 'Review', 'GNSS.csv'), ...
            'AirData', fullfile(OutputDirectory, 'Review', 'AirData.csv'), ...
            'Magnetometer', fullfile( ...
                OutputDirectory, 'Review', 'Magnetometer.csv')), ...
        'ReviewFiles', struct(), ...
        'ReviewFilesStatus', 'PendingExport');

end

function Rates = fallbackRates(Contracts)
%FALLBACKRATES Code-default reference rates with provenance label.

    Rates = struct();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};
        Rates.(StreamName) = Contracts.(StreamName).RateFallback_Hz;

    end

end
