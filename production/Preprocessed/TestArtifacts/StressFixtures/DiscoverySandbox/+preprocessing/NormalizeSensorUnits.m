function Stream = NormalizeSensorUnits(Stream, StreamName)
%NORMALIZESENSORUNITS Convert stream data to canonical SI units.
%
%   Stream = NORMALIZESENSORUNITS(Stream, StreamName) applies the
%   ScaleToCanonical factors of SensorDataContracts to the canonical
%   measurement fields of one schema-normalized stream and records every
%   conversion.
%
%   Conversion rules:
%       Magnetic field axes: source microtesla -> canonical tesla
%           (ScaleToCanonical 1.0e-6).
%       All other channels: scale factor 1 (source already canonical).
%       Time_s, Available, SourceRowIdx and SourceTime_s are never
%       converted (audit data stays in its original form).
%
%   Output additions:
%       Stream.UnitConversions.<CanonicalField> with fields
%           Factor, SourceUnit, Unit
%       Stream.UnitsApplied = true
%
%   Pure function: no file access and no global state.
%
%   Errors: Preprocessing:NormalizeSensorUnits:<Reason>
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: NormalizeSensorSchema, LoadSensorData, SensorDataContracts.

    %% Validate Inputs

    if ~isstruct(Stream) || ~isscalar(Stream)

        error( ...
            'Preprocessing:NormalizeSensorUnits:InvalidStream', ...
            'Stream must be a scalar structure.');

    end

    Contracts = preprocessing.SensorDataContracts();

    if ~(ischar(StreamName) || (isstring(StreamName) && isscalar(StreamName)))

        error( ...
            'Preprocessing:NormalizeSensorUnits:InvalidStreamName', ...
            'StreamName must be a character vector or scalar string.');

    end

    StreamName = char(StreamName);

    if ~any(strcmp(StreamName, Contracts.Streams))

        error( ...
            'Preprocessing:NormalizeSensorUnits:InvalidStreamName', ...
            'Unknown stream name "%s".', ...
            StreamName);

    end

    Channels = Contracts.(StreamName).Channels;

    %% Apply Channel Scales

    UnitConversions = struct();

    for Index = 1:numel(Channels)

        Channel = Channels(Index);
        FieldName = Channel.CanonicalField;

        if strcmp(FieldName, 'Time_s') || strcmp(FieldName, 'Available')

            continue;

        end

        if ~isfield(Stream, FieldName)

            error( ...
                ['Preprocessing:NormalizeSensorUnits:', ...
                 'MissingCanonicalField'], ...
                'Stream is missing canonical field "%s".', ...
                FieldName);

        end

        Values = Stream.(FieldName);

        if ~isnumeric(Values) || ~isreal(Values) || ~iscolumn(Values)

            error( ...
                'Preprocessing:NormalizeSensorUnits:InvalidData', ...
                'Canonical field "%s" must be a real numeric column.', ...
                FieldName);

        end

        Stream.(FieldName) = Values .* Channel.ScaleToCanonical;

        UnitConversions.(FieldName) = struct( ...
            'Factor', Channel.ScaleToCanonical, ...
            'SourceUnit', Channel.SourceUnit, ...
            'Unit', Channel.Unit);

    end

    %% Record Conversions

    Stream.UnitConversions = UnitConversions;
    Stream.UnitsApplied = true;

end
