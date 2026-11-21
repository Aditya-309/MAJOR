function Provenance = BuildInputProvenance(Data, InputInfo)
%BUILDINPUTPROVENANCE Build the run-level input provenance record.
%
%   Provenance = BUILDINPUTPROVENANCE(Data, InputInfo) records, for every
%   consumed stream, the identity and origin information required to
%   trace every estimator update back to its source measurement:
%
%       - source file, format and dialect used by Block 9
%       - SourceRowIdx / SourceTime_s arrays (original file rows)
%       - SegmentID array and segment table
%       - validity and quality flag counts
%       - nominal-rate provenance (value and source)
%
%   Provenance is carried into EstimationResults.SourceProvenance so that
%   every measurement update and diagnostic event can be linked to the
%   original source measurement or measurements.
%
%   Output fields:
%       .RunInfo      - identity echo (RunID, PreprocessID, status)
%       .InputInfo    - resolution metadata from LoadPreprocessedRun
%       .Streams      - per-stream provenance described above
%       .ExcludedSources - sources Block 9 excluded (from ProcessingInfo)
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: LoadPreprocessedRun, BuildMeasurementTimeline.

    Provenance = struct();
    Provenance.RunInfo = struct( ...
        'RunID', Data.RunInfo.RunID, ...
        'PreprocessID', Data.RunInfo.PreprocessID, ...
        'PreprocessStatus', Data.RunInfo.Status);
    Provenance.InputInfo = InputInfo;

    if isfield(Data, 'ProcessingInfo') && ...
            isfield(Data.ProcessingInfo, 'ExcludedSources')

        Provenance.ExcludedSources = Data.ProcessingInfo.ExcludedSources;

    else

        Provenance.ExcludedSources = {};

    end

    Streams = struct();
    StreamNames = fieldnames(Data.NativeRate);

    for Index = 1:numel(StreamNames)

        StreamName = StreamNames{Index};
        Stream = Data.NativeRate.(StreamName);

        Entry = struct();
        Entry.Stream = StreamName;

        if isfield(Stream, 'SourceFile')
            Entry.SourceFile = Stream.SourceFile;
        else
            Entry.SourceFile = '';
        end

        if isfield(Stream, 'SourceFormat')
            Entry.SourceFormat = Stream.SourceFormat;
        else
            Entry.SourceFormat = '';
        end

        if isfield(Stream, 'SourceDialect')
            Entry.SourceDialect = Stream.SourceDialect;
        else
            Entry.SourceDialect = '';
        end

        Entry.SampleCount = numel(Stream.Time_s);
        Entry.SourceRowIdx = Stream.SourceRowIdx(:);
        Entry.SourceTime_s = Stream.SourceTime_s(:);
        Entry.SegmentID = Stream.SegmentID(:);

        if isfield(Stream, 'Segments')
            Entry.Segments = Stream.Segments;
        else
            Entry.Segments = struct([]);
        end

        Entry.NominalRate_Hz = NaN;
        Entry.NominalRateSource = '';

        if isfield(Stream, 'NominalRate_Hz')
            Entry.NominalRate_Hz = Stream.NominalRate_Hz;
        end

        if isfield(Stream, 'NominalRateSource')
            Entry.NominalRateSource = Stream.NominalRateSource;
        end

        Entry.FlagCounts = struct();

        if isfield(Stream, 'Flags')

            FlagNames = fieldnames(Stream.Flags);

            for FlagIndex = 1:numel(FlagNames)

                Entry.FlagCounts.(FlagNames{FlagIndex}) = ...
                    sum(Stream.Flags.(FlagNames{FlagIndex}));

            end

        end

        Entry.UnavailableCount = sum(~Stream.Available);
        Entry.RowInvalidCount = sum(~Stream.RowValid);
        Entry.MeasurementInvalidCount = sum(~Stream.MeasurementValid);

        Streams.(StreamName) = Entry;

    end

    Provenance.Streams = Streams;

end
