function Results = RunPreprocessingTests(Phase)
%RUNPREPROCESSINGTESTS Run the Block 9 preprocessing test suite.
%
%   Results = RUNPREPROCESSINGTESTS(Phase) runs the test groups for the
%   requested phase and returns a structure array with fields:
%       Name   - test case name
%       Status - 'PASS' or 'FAIL'
%       Detail - evidence text
%
%   Phase is 'Phase1' to 'Phase5' or 'All' (default 'All'). Additional
%   phase groups are added as implementation proceeds.
%
%   One status line is printed per test case plus a summary line. When
%   called without an output argument and at least one test fails, the
%   function raises 'Preprocessing:RunPreprocessingTests:TestFailure' so
%   that matlab -batch exits with a nonzero status.
%
%   Developer test entry point (internal; not part of the public API).
%   The public API is DiscoverRuns, InspectRun, PreprocessRun and
%   GetPreprocessingReport.
%
%   See also: PreprocessingConfig, SensorDataContracts, QualityFlags.

    %% Validate Phase Argument

    if nargin < 1
        Phase = 'All';
    end

    if ~(ischar(Phase) || (isstring(Phase) && isscalar(Phase)))

        error( ...
            'Preprocessing:RunPreprocessingTests:InvalidPhase', ...
            'Phase must be a character vector or scalar string.');

    end

    Phase = char(Phase);
    AllowedPhases = { ...
        'All', 'Phase1', 'Phase2', 'Phase3', 'Phase4', 'Phase5'};

    if ~any(strcmpi(Phase, AllowedPhases))

        error( ...
            'Preprocessing:RunPreprocessingTests:InvalidPhase', ...
            'Phase must be one of: %s.', ...
            strjoin(AllowedPhases, ', '));

    end

    %% Environment Evidence

    Paths = preprocessing.ProjectPaths();
    PackageDir = fullfile(Paths.ProjectRoot, '+preprocessing');

    fprintf('Block 9 test suite\n');
    fprintf('Phase request   : %s\n', Phase);
    fprintf('MATLAB release  : %s\n', version('-release'));
    fprintf('MATLAB version  : %s\n', version());
    fprintf('Start directory : %s\n', pwd());

    %% Static Integrity Checks

    Results = struct('Name', {}, 'Status', {}, 'Detail', {});

    PackageFiles = { ...
        'ProjectPaths.m', ...
        'SensorDataContracts.m', ...
        'QualityFlags.m', ...
        'PreprocessingConfig.m', ...
        'ValidatePreprocessingConfig.m', ...
        'DiscoverRuns.m', ...
        'InspectRun.m', ...
        'LoadSensorData.m', ...
        'NormalizeSensorSchema.m', ...
        'NormalizeSensorUnits.m', ...
        'ProcessSensorTimestamps.m', ...
        'InspectSensorQuality.m', ...
        'DetectSensorOutliers.m', ...
        'BuildAlignedSensorData.m', ...
        'BuildPreprocessingReport.m', ...
        'ExportPreprocessedData.m', ...
        'PreprocessRun.m', ...
        'GetPreprocessingReport.m', ...
        'RunPreprocessingTests.m'};

    Results = [Results, runCase( ...
        'Static/FilenameMatchesFunctionName', ...
        @() checkFilenames(PackageFiles, PackageDir))];
    Results = [Results, runCase( ...
        'Static/CheckcodeNoUndefinedReferences', ...
        @() checkCodeMessages(PackageFiles, PackageDir))];
    Results = [Results, runCase( ...
        'Static/PackageResolutionAndShadowing', ...
        @() checkResolution(PackageFiles, PackageDir))];

    %% Phase 1: Configuration And Contracts

    if any(strcmpi(Phase, {'All', 'Phase1'}))

        Results = [Results, runCase( ...
            'Phase1/DefaultConfigValid', ...
            @() checkDefaultConfigValid())];
        Results = [Results, runCase( ...
            'Phase1/DefaultConfigValues', ...
            @() checkDefaultConfigValues())];
        Results = [Results, runCase( ...
            'Phase1/ConfigOverridesApply', ...
            @() checkConfigOverrides())];
        Results = [Results, runCase( ...
            'Phase1/ConfigRejectsInvalid', ...
            @() checkConfigRejectsInvalid())];
        Results = [Results, runCase( ...
            'Phase1/ContractsStreamsAndChannels', ...
            @() checkContractsStreamsAndChannels())];
        Results = [Results, runCase( ...
            'Phase1/ContractsDialectCoverage', ...
            @() checkContractsDialectCoverage())];
        Results = [Results, runCase( ...
            'Phase1/ContractsMagneticUnitScaling', ...
            @() checkContractsMagneticUnits())];
        Results = [Results, runCase( ...
            'Phase1/ContractsRateFallbackProvenance', ...
            @() checkContractsRateFallbacks())];
        Results = [Results, runCase( ...
            'Phase1/QualityStateFieldsDistinct', ...
            @() checkQualityStateFields())];
        Results = [Results, runCase( ...
            'Phase1/QualityFindingsRegistry', ...
            @() checkQualityFindings())];
        Results = [Results, runCase( ...
            'Phase1/ProjectPathsCwdIndependence', ...
            @() checkProjectPathsCwdIndependence())];

    end

    %% Phase 2: Run Discovery And Inspection

    if any(strcmpi(Phase, {'All', 'Phase2'}))

        Results = [Results, runCase( ...
            'Phase2/DiscoverRunsRegistryCrossCheck', ...
            @() checkDiscoverRunsRegistryCrossCheck())];
        Results = [Results, runCase( ...
            'Phase2/DiscoverRunsCwdIndependence', ...
            @() checkDiscoverRunsCwdIndependence())];
        Results = [Results, runCase( ...
            'Phase2/DiscoverAndInspectReadOnly', ...
            @() checkDiscoverAndInspectReadOnly())];
        Results = [Results, runCase( ...
            'Phase2/InspectRunRegisteredEligible', ...
            @() checkInspectRunRegisteredEligible())];
        Results = [Results, runCase( ...
            'Phase2/InspectRunUnregisteredReview', ...
            @() checkInspectRunUnregisteredReview())];
        Results = [Results, runCase( ...
            'Phase2/InspectRunExcludedLocations', ...
            @() checkInspectRunExcludedLocations())];
        Results = [Results, runCase( ...
            'Phase2/InspectRunNotFound', ...
            @() checkInspectRunNotFound())];
        Results = [Results, runCase( ...
            'Phase2/InspectRunArtifactChecks', ...
            @() checkInspectRunArtifactChecks())];

    end

    %% Phase 3: Sensor Ingestion And Normalization

    if any(strcmpi(Phase, {'All', 'Phase3'}))

        Results = [Results, runCase( ...
            'Phase3/LoadRealisticCsvAuto', ...
            @() checkLoadRealisticCsvAuto())];
        Results = [Results, runCase( ...
            'Phase3/LoadIdealCsvSynthesizedAvailable', ...
            @() checkLoadIdealCsvSynthesizedAvailable())];
        Results = [Results, runCase( ...
            'Phase3/MatV73AndV7CrossFormat', ...
            @() checkMatV73AndV7CrossFormat())];
        Results = [Results, runCase( ...
            'Phase3/MatVariableDiscoveryUnknownName', ...
            @() checkMatVariableDiscoveryUnknownName())];
        Results = [Results, runCase( ...
            'Phase3/MissingSensorFile', ...
            @() checkMissingSensorFile())];
        Results = [Results, runCase( ...
            'Phase3/MalformedSensorFile', ...
            @() checkMalformedSensorFile())];
        Results = [Results, runCase( ...
            'Phase3/TraceabilityAndDialects', ...
            @() checkTraceabilityAndDialects())];
        Results = [Results, runCase( ...
            'Phase3/GroundTruthExcluded', ...
            @() checkGroundTruthExcluded())];
        Results = [Results, runCase( ...
            'Phase3/NormalizeSchemaSynthesis', ...
            @() checkNormalizeSchemaSynthesis())];
        Results = [Results, runCase( ...
            'Phase3/NormalizeUnitsScaling', ...
            @() checkNormalizeUnitsScaling())];
        Results = [Results, runCase( ...
            'Phase3/LoadSensorDataCwdIndependence', ...
            @() checkLoadSensorDataCwdIndependence())];

    end

    %% Phase 4: Timestamp And Quality Processing

    if any(strcmpi(Phase, {'All', 'Phase4'}))

        Results = [Results, runCase( ...
            'Phase4/RealRunTimestampsAndProvenance', ...
            @() checkRealRunTimestampsAndProvenance())];
        Results = [Results, runCase( ...
            'Phase4/DuplicateAndBackwardSemantics', ...
            @() checkDuplicateAndBackwardSemantics())];
        Results = [Results, runCase( ...
            'Phase4/GapOrSemantics', ...
            @() checkGapOrSemantics())];
        Results = [Results, runCase( ...
            'Phase4/AvailabilityOutageSeparation', ...
            @() checkAvailabilityOutageSeparation())];
        Results = [Results, runCase( ...
            'Phase4/StateFieldIndependence', ...
            @() checkStateFieldIndependence())];
        Results = [Results, runCase( ...
            'Phase4/OutlierChecksRetainValues', ...
            @() checkOutlierChecksRetainValues())];
        Results = [Results, runCase( ...
            'Phase4/StatisticalPerSegmentNoCrossing', ...
            @() checkStatisticalPerSegmentNoCrossing())];
        Results = [Results, runCase( ...
            'Phase4/SuddenChangeSkipsInvalidReference', ...
            @() checkSuddenChangeSkipsInvalidReference())];
        Results = [Results, runCase( ...
            'Phase4/StartupTransientFlaggedRetained', ...
            @() checkStartupTransientFlaggedRetained())];
        Results = [Results, runCase( ...
            'Phase4/TraceabilityThroughProcessing', ...
            @() checkTraceabilityThroughProcessing())];
        Results = [Results, runCase( ...
            'Phase4/DuplicateAlsoBackwardJump', ...
            @() checkDuplicateAlsoBackwardJump())];
        Results = [Results, runCase( ...
            'Phase4/BackwardToPreviouslySeenTime', ...
            @() checkBackwardToPreviouslySeenTime())];
        Results = [Results, runCase( ...
            'Phase4/DuplicateNotBackward', ...
            @() checkDuplicateNotBackward())];
        Results = [Results, runCase( ...
            'Phase4/BackwardThenIncreasing', ...
            @() checkBackwardThenIncreasing())];
        Results = [Results, runCase( ...
            'Phase4/SegmentIdsAndTraceability', ...
            @() checkSegmentIdsAndTraceability())];
        Results = [Results, runCase( ...
            'Phase4/StatisticalDeviationFloor', ...
            @() checkStatisticalDeviationFloor())];
        Results = [Results, runCase( ...
            'Phase4/InitialNonFinitePendingBreak', ...
            @() checkInitialNonFinitePendingBreak())];
        Results = [Results, runCase( ...
            'Phase4/MeasuredRateAdjacentIntervals', ...
            @() checkMeasuredRateAdjacentIntervals())];
        Results = [Results, runCase( ...
            'Phase4/StatisticalDeviationFloorRejections', ...
            @() checkStatisticalDeviationFloorRejections())];
        Results = [Results, runCase( ...
            'Phase4/MultiplePendingDiscontinuities', ...
            @() checkMultiplePendingDiscontinuities())];

    end

    %% Phase 5: Alignment, Report, Export And Integration

    if any(strcmpi(Phase, {'All', 'Phase5'}))

        Results = [Results, runCase( ...
            'Phase5/AlignmentDisabled', ...
            @() checkAlignmentDisabled())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentCausalZohAndReference', ...
            @() checkAlignmentCausalZohAndReference())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentNoFutureNoExtrapolation', ...
            @() checkAlignmentNoFutureNoExtrapolation())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentMaxSampleAge', ...
            @() checkAlignmentMaxSampleAge())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentOutageValidityPropagation', ...
            @() checkAlignmentOutageValidityPropagation())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentSegmentBoundaries', ...
            @() checkAlignmentSegmentBoundaries())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentMissingSensorSkipped', ...
            @() checkAlignmentMissingSensorSkipped())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentDuplicateExclusion', ...
            @() checkAlignmentDuplicateExclusion())];
        Results = [Results, runCase( ...
            'Phase5/AlignmentNativeRateImmutable', ...
            @() checkAlignmentNativeRateImmutable())];
        Results = [Results, runCase( ...
            'Phase5/ReportProvenanceCategories', ...
            @() checkReportProvenanceCategories())];
        Results = [Results, runCase( ...
            'Phase5/ReportQualityAlignmentUnits', ...
            @() checkReportQualityAlignmentUnits())];
        Results = [Results, runCase( ...
            'Phase5/ReportMissingSensorRepresentation', ...
            @() checkReportMissingSensorRepresentation())];
        Results = [Results, runCase( ...
            'Phase5/MatHierarchyAndPreservation', ...
            @() checkMatHierarchyAndPreservation())];
        Results = [Results, runCase( ...
            'Phase5/MatAlignmentAndReadBack', ...
            @() checkMatAlignmentAndReadBack())];
        Results = [Results, runCase( ...
            'Phase5/JsonValidTypesAndReadBack', ...
            @() checkJsonValidTypesAndReadBack())];
        Results = [Results, runCase( ...
            'Phase5/JsonNanInfAndMatConsistency', ...
            @() checkJsonNanInfAndMatConsistency())];
        Results = [Results, runCase( ...
            'Phase5/CsvSchemaTraceabilityAndNoFabrication', ...
            @() checkCsvSchemaTraceabilityAndNoFabrication())];
        Results = [Results, runCase( ...
            'Phase5/PreprocessRunSuccessRealRun', ...
            @() checkPreprocessRunSuccessRealRun())];
        Results = [Results, runCase( ...
            'Phase5/PreprocessRunPartialAndStrict', ...
            @() checkPreprocessRunPartialAndStrict())];
        Results = [Results, runCase( ...
            'Phase5/PreprocessRunUnregisteredApproval', ...
            @() checkPreprocessRunUnregisteredApproval())];
        Results = [Results, runCase( ...
            'Phase5/PreprocessRunNoOverwriteUniqueIds', ...
            @() checkPreprocessRunNoOverwriteUniqueIds())];
        Results = [Results, runCase( ...
            'Phase5/PreprocessRunInvalidRun', ...
            @() checkPreprocessRunInvalidRun())];
        Results = [Results, runCase( ...
            'Phase5/ExportFailureGuards', ...
            @() checkExportFailureGuards())];
        Results = [Results, runCase( ...
            'Phase5/GetPreprocessingReportValidAndReadOnly', ...
            @() checkGetPreprocessingReportValidAndReadOnly())];
        Results = [Results, runCase( ...
            'Phase5/GetPreprocessingReportErrors', ...
            @() checkGetPreprocessingReportErrors())];
        Results = [Results, runCase( ...
            'Phase5/RunDirectoryRegisteredEligible', ...
            @() checkRunDirectoryRegisteredEligible())];
        Results = [Results, runCase( ...
            'Phase5/RunDirectoryUnregisteredRejected', ...
            @() checkRunDirectoryUnregisteredRejected())];
        Results = [Results, runCase( ...
            'Phase5/RunDirectoryUnregisteredApproved', ...
            @() checkRunDirectoryUnregisteredApproved())];
        Results = [Results, runCase( ...
            'Phase5/RunDirectoryRunIDMismatch', ...
            @() checkRunDirectoryRunIDMismatch())];
        Results = [Results, runCase( ...
            'Phase5/RunDirectoryWorkingRunsRejected', ...
            @() checkRunDirectoryWorkingRunsRejected())];
        Results = [Results, runCase( ...
            'Phase5/RunDirectoryFailedRunsRejected', ...
            @() checkRunDirectoryFailedRunsRejected())];
        Results = [Results, runCase( ...
            'Phase5/RunDirectorySyntheticProvenance', ...
            @() checkRunDirectorySyntheticProvenance())];
        Results = [Results, runCase( ...
            'Phase5/NormalRegisteredRunPathUnchanged', ...
            @() checkNormalRegisteredRunPathUnchanged())];
        Results = [Results, runCase( ...
            'Phase5/GetReportMarkerOnly', ...
            @() checkGetReportMarkerOnly())];
        Results = [Results, runCase( ...
            'Phase5/GetReportSuccessJsonPlusMarker', ...
            @() checkGetReportSuccessJsonPlusMarker())];
        Results = [Results, runCase( ...
            'Phase5/GetReportPartialArtifactsPlusMarker', ...
            @() checkGetReportPartialArtifactsPlusMarker())];
        Results = [Results, runCase( ...
            'Phase5/GetReportMalformedJson', ...
            @() checkGetReportMalformedJson())];
        Results = [Results, runCase( ...
            'Phase5/PreprocessRunFailureMarkerAndRetrieval', ...
            @() checkPreprocessRunFailureMarkerAndRetrieval())];
        Results = [Results, runCase( ...
            'Phase5/CanonicalPathNormalResolution', ...
            @() checkCanonicalPathNormalResolution())];
        Results = [Results, runCase( ...
            'Phase5/CanonicalPathRelativeResolution', ...
            @() checkCanonicalPathRelativeResolution())];
        Results = [Results, runCase( ...
            'Phase5/CanonicalPathParentTraversal', ...
            @() checkCanonicalPathParentTraversal())];
        Results = [Results, runCase( ...
            'Phase5/ProtectedDirectoryViaTraversal', ...
            @() checkProtectedDirectoryViaTraversal())];
        Results = [Results, runCase( ...
            'Phase5/CanonicalPathFailureTypedError', ...
            @() checkCanonicalPathFailureTypedError())];
        Results = [Results, runCase( ...
            'Phase5/ExportJsonTempWriteFailure', ...
            @() checkExportJsonTempWriteFailure())];
        Results = [Results, runCase( ...
            'Phase5/ExportJsonTempReadBackFailure', ...
            @() checkExportJsonTempReadBackFailure())];
        Results = [Results, runCase( ...
            'Phase5/ExportJsonPreprocessIDMismatch', ...
            @() checkExportJsonPreprocessIDMismatch())];
        Results = [Results, runCase( ...
            'Phase5/ExportJsonPublishFailure', ...
            @() checkExportJsonPublishFailure())];
        Results = [Results, runCase( ...
            'Phase5/ExportJsonTransactionalPublish', ...
            @() checkExportJsonTransactionalPublish())];
        Results = [Results, runCase( ...
            'Phase5/PublishedReportRetrievable', ...
            @() checkPublishedReportRetrievable())];
        Results = [Results, runCase( ...
            'Phase5/FailedExportNoRetrievableSuccess', ...
            @() checkFailedExportNoRetrievableSuccess())];
        Results = [Results, runCase( ...
            'Phase5/MarkerPrecedenceUnchanged', ...
            @() checkMarkerPrecedenceUnchanged())];
        Results = [Results, runCase( ...
            'Closure/AllNineteenModulesAccounted', ...
            @() checkDependencyAllModulesAccounted())];
        Results = [Results, runCase( ...
            'Closure/NoMissingModules', ...
            @() checkDependencyNoMissingModules())];
        Results = [Results, runCase( ...
            'Closure/NoUnexpectedProjectDependencies', ...
            @() checkDependencyNoUnexpectedProjectDeps())];
        Results = [Results, runCase( ...
            'Closure/AcyclicArchitecture', ...
            @() checkDependencyAcyclic())];
        Results = [Results, runCase( ...
            'Closure/ExpectedProductsIdentified', ...
            @() checkDependencyExpectedProducts())];
        Results = [Results, runCase( ...
            'Closure/InjectedUnexpectedDependencyDetected', ...
            @() checkDependencyInjectedUnexpected())];
        Results = [Results, runCase( ...
            'Closure/InjectedCycleDetected', ...
            @() checkDependencyInjectedCycle())];
        Results = [Results, runCase( ...
            'Metadata/AbsentNotRecorded', ...
            @() checkMetadataAbsentNotRecorded())];
        Results = [Results, runCase( ...
            'Metadata/ValidRecorded', ...
            @() checkMetadataValidRecorded())];
        Results = [Results, runCase( ...
            'Metadata/MalformedDecodeFailed', ...
            @() checkMetadataMalformedDecodeFailed())];
        Results = [Results, runCase( ...
            'Metadata/EmptyJson', ...
            @() checkMetadataEmptyJson())];
        Results = [Results, runCase( ...
            'Metadata/MissingOptionalFields', ...
            @() checkMetadataMissingOptionalFields())];
        Results = [Results, runCase( ...
            'Outputs/SuccessFourCsvs', ...
            @() checkOutputsSuccessFourCsvs())];
        Results = [Results, runCase( ...
            'Outputs/PartialThreeCsvs', ...
            @() checkOutputsPartialThreeCsvs())];
        Results = [Results, runCase( ...
            'Outputs/PartialOneCsv', ...
            @() checkOutputsPartialOneCsv())];
        Results = [Results, runCase( ...
            'Outputs/EmptyStreamConsistency', ...
            @() checkOutputsEmptyStreamConsistency())];
        Results = [Results, runCase( ...
            'Outputs/FailedExportNoFalseRefs', ...
            @() checkOutputsFailedExportNoFalseRefs())];
        Results = [Results, runCase( ...
            'Allocation/SequentialRepeated', ...
            @() checkAllocationSequentialRepeated())];
        Results = [Results, runCase( ...
            'Allocation/CollisionSequence', ...
            @() checkAllocationCollisionSequence())];
        Results = [Results, runCase( ...
            'Allocation/ParentIsFileFailure', ...
            @() checkAllocationParentIsFileFailure())];
        Results = [Results, runCase( ...
            'Allocation/RecoveryAfterFailure', ...
            @() checkAllocationRecoveryAfterFailure())];
        Results = [Results, runCase( ...
            'RoundTrip/FullVerification', ...
            @() checkFullRoundTripVerification())];
        Results = [Results, runCase( ...
            'Provenance/OffsetMapping', ...
            @() checkProvenanceOffsetMapping())];
        Results = [Results, runCase( ...
            'Provenance/RowOrderInvariant', ...
            @() checkProvenanceRowOrderInvariant())];

    end

    %% Summary

    PassedCount = sum(strcmp({Results.Status}, 'PASS'));
    FailedCount = sum(strcmp({Results.Status}, 'FAIL'));
    fprintf('Summary: %d passed, %d failed, %d total\n', ...
        PassedCount, FailedCount, numel(Results));

    if FailedCount > 0 && nargout == 0

        error( ...
            'Preprocessing:RunPreprocessingTests:TestFailure', ...
            '%d test case(s) failed.', ...
            FailedCount);

    end

end

% =========================================================================
%% TEST INFRASTRUCTURE
% =========================================================================

function Result = runCase(Name, Fun)
%RUNCASE Execute one test case and capture its outcome.

    try

        Detail = Fun();

        if ~ischar(Detail)
            Detail = 'ok';
        end

        Result = struct('Name', Name, 'Status', 'PASS', 'Detail', Detail);
        fprintf('[PASS] %s - %s\n', Name, Detail);

    catch Failure

        Detail = sprintf('%s: %s', ...
            Failure.identifier, Failure.message);
        Result = struct('Name', Name, 'Status', 'FAIL', 'Detail', Detail);
        fprintf('[FAIL] %s - %s\n', Name, Detail);

    end

end

function assertErrorIdIn(Fun, ExpectedIds)
%ASSERTERRORIDIN Assert that Fun raises one of the expected identifiers.

    try

        Fun();

    catch Caught

        if any(strcmp(Caught.identifier, ExpectedIds))

            return;

        end

        error( ...
            'Preprocessing:RunPreprocessingTests:WrongErrorIdentifier', ...
            'Expected one of {%s} but got "%s": %s', ...
            strjoin(ExpectedIds, ', '), ...
            Caught.identifier, ...
            Caught.message);

    end

    error( ...
        'Preprocessing:RunPreprocessingTests:ExpectedErrorMissing', ...
        'Expected one of {%s} was not raised.', ...
        strjoin(ExpectedIds, ', '));

end

function assertErrorId(Fun, ExpectedId)
%ASSERTERRORID Assert that Fun raises exactly the expected identifier.
    try

        Fun();

    catch Caught

        if ~strcmp(Caught.identifier, ExpectedId)

            error( ...
                ['Preprocessing:RunPreprocessingTests:', ...
                 'WrongErrorIdentifier'], ...
                'Expected "%s" but got "%s": %s', ...
                ExpectedId, ...
                Caught.identifier, ...
                Caught.message);

        end

        return;

    end

    error( ...
        ['Preprocessing:RunPreprocessingTests:', ...
         'ExpectedErrorMissing'], ...
        'Expected error "%s" was not raised.', ...
        ExpectedId);

end

function expectEqual(Actual, Expected, Label)
%EXPECTEQUAL Assert isequaln (NaN-tolerant) with a labeled message.

    if ~isequaln(Actual, Expected)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            '%s: expected %s but found %s.', ...
            Label, ...
            valueText(Expected), ...
            valueText(Actual));

    end

end

function Text = valueText(Value)
%VALUETEXT Render a value for assertion messages.

    if ischar(Value)

        Text = ['"' Value '"'];

    elseif iscell(Value)

        Parts = cellfun(@(x) ['"' x '"'], Value, 'UniformOutput', false);
        Text = ['{' strjoin(Parts, ', ') '}'];

    elseif islogical(Value) || isnumeric(Value)

        Text = mat2str(Value);

    else

        Text = '<value>';

    end

end

% =========================================================================
%% STATIC INTEGRITY CHECKS
% =========================================================================

function Detail = checkFilenames(PackageFiles, PackageDir)
%CHECKFILENAMES Assert filename matches declared function name.

    for Index = 1:numel(PackageFiles)

        FilePath = fullfile(PackageDir, PackageFiles{Index});

        if ~isfile(FilePath)

            error( ...
                'Preprocessing:RunPreprocessingTests:MissingFile', ...
                'Expected file "%s" does not exist.', ...
                FilePath);

        end

        Text = fileread(FilePath);
        Lines = cellstr(splitlines(Text));
        FirstFunctionLine = '';

        for LineIndex = 1:numel(Lines)

            if startsWith(strtrim(Lines{LineIndex}), 'function')

                FirstFunctionLine = strtrim(Lines{LineIndex});
                break;

            end

        end

        if isempty(FirstFunctionLine)

            error( ...
                ['Preprocessing:RunPreprocessingTests:', ...
                 'MissingFunctionLine'], ...
                'File "%s" has no function declaration line.', ...
                PackageFiles{Index});

        end

        OpenParen = strfind(FirstFunctionLine, '(');

        if isempty(OpenParen)

            error( ...
                ['Preprocessing:RunPreprocessingTests:', ...
                 'MalformedFunctionLine'], ...
                'File "%s" has a malformed function line.', ...
                PackageFiles{Index});

        end

        Head = FirstFunctionLine(1:OpenParen(1) - 1);
        EqualSign = strfind(Head, '=');

        if isempty(EqualSign)

            FunctionName = strtrim(Head(length('function') + 1:end));

        else

            FunctionName = strtrim(Head(EqualSign(end) + 1:end));

        end

        ExpectedName = PackageFiles{Index}(1:end - 2);

        if ~strcmp(FunctionName, ExpectedName)

            error( ...
                'Preprocessing:RunPreprocessingTests:NameMismatch', ...
                'File "%s" declares function "%s".', ...
                PackageFiles{Index}, ...
                FunctionName);

        end

    end

    Detail = sprintf('%d filenames match their function names', ...
        numel(PackageFiles));

end

function Detail = checkCodeMessages(PackageFiles, PackageDir)
%CHECKCODEMESSAGES Run checkcode and reject undefined references.

    TotalCount = 0;
    UndefinedCount = 0;

    for Index = 1:numel(PackageFiles)

        FilePath = fullfile(PackageDir, PackageFiles{Index});
        Messages = checkcode(FilePath, '-id');

        for MessageIndex = 1:numel(Messages)

            TotalCount = TotalCount + 1;
            MessageText = Messages(MessageIndex).message;

            fprintf('    checkcode %s | %s:%d:%d | %s\n', ...
                Messages(MessageIndex).id, ...
                PackageFiles{Index}, ...
                Messages(MessageIndex).line, ...
                Messages(MessageIndex).column, ...
                regexprep(MessageText, '\s+', ' '));

            if ~isempty(regexpi(MessageText, ...
                    ['Undefined (function|variable)|is not defined|', ...
                     'not found'], 'once'))

                UndefinedCount = UndefinedCount + 1;

            end

        end

    end

    if UndefinedCount > 0

        error( ...
            ['Preprocessing:RunPreprocessingTests:', ...
             'UndefinedReferences'], ...
            ['%d checkcode message(s) report undefined references ', ...
             '(see listing above).'], ...
            UndefinedCount);

    end

    Detail = sprintf( ...
        ['%d checkcode message(s) total, 0 undefined-reference ', ...
         'messages (full listing printed)'], ...
        TotalCount);

end

function Detail = checkResolution(PackageFiles, PackageDir)
%CHECKRESOLUTION Assert unique resolution inside +preprocessing.

    for Index = 1:numel(PackageFiles)

        FunctionName = PackageFiles{Index}(1:end - 2);
        QualifiedName = ['preprocessing.' FunctionName];
        Resolution = which(QualifiedName, '-all');

        if ischar(Resolution)
            Resolution = {Resolution};
        end

        if isempty(Resolution)

            error( ...
                ['Preprocessing:RunPreprocessingTests:', ...
                 'UnresolvedFunction'], ...
                'Function "%s" does not resolve.', ...
                QualifiedName);

        end

        for ResolutionIndex = 1:numel(Resolution)

            ResolvedPath = strrep(Resolution{ResolutionIndex}, ...
                '/', filesep);

            if ~startsWith(ResolvedPath, [PackageDir filesep], ...
                    'IgnoreCase', true)

                fprintf('    unexpected resolution: %s -> %s\n', ...
                    QualifiedName, ...
                    Resolution{ResolutionIndex});

                error( ...
                    ['Preprocessing:RunPreprocessingTests:', ...
                     'ShadowingDetected'], ...
                    ['Function "%s" resolves outside +preprocessing: ', ...
                     '%s'], ...
                    QualifiedName, ...
                    Resolution{ResolutionIndex});

            end

        end

    end

    Detail = sprintf( ...
        '%d functions resolve uniquely inside +preprocessing', ...
        numel(PackageFiles));

end

% =========================================================================
%% PHASE 1 CHECKS
% =========================================================================

function Detail = checkDefaultConfigValid()
%CHECKDEFAULTCONFIGVALID Default configuration passes validation.

    preprocessing.PreprocessingConfig();
    Detail = 'default configuration passes validation';

end

function Detail = checkDefaultConfigValues()
%CHECKDEFAULTCONFIGVALUES All documented defaults match exactly.

    Config = preprocessing.PreprocessingConfig();

    expectEqual(Config.Source, ...
        'RealisticSensorTelemetry', 'Source');
    expectEqual(Config.MissingSensors.Policy, ...
        'Continue', 'MissingSensors.Policy');
    expectEqual(Config.MissingSensors.RequiredSensors, ...
        {'IMU', 'GNSS', 'AirData', 'Magnetometer'}, ...
        'MissingSensors.RequiredSensors');
    expectEqual(Config.Timestamps.DuplicatePolicy, ...
        'KeepFirst', 'Timestamps.DuplicatePolicy');
    expectEqual(Config.Timestamps.GapAbsolute_s, ...
        1.0, 'Timestamps.GapAbsolute_s');
    expectEqual(Config.Timestamps.GapRelative, ...
        1.5, 'Timestamps.GapRelative');
    expectEqual(Config.Timestamps.NominalRateSource, ...
        'Auto', 'Timestamps.NominalRateSource');
    expectEqual(Config.Quality.StartupTransient.Enabled, ...
        true, 'Quality.StartupTransient.Enabled');
    expectEqual(Config.Quality.StartupTransient.WindowSamples, ...
        5, 'Quality.StartupTransient.WindowSamples');
    expectEqual(Config.Quality.Statistical.Enabled, ...
        true, 'Quality.Statistical.Enabled');
    expectEqual(Config.Quality.Statistical.WindowSamples, ...
        51, 'Quality.Statistical.WindowSamples');
    expectEqual(Config.Quality.Statistical.SigmaThreshold, ...
        4.0, 'Quality.Statistical.SigmaThreshold');
    expectEqual(Config.Quality.SuddenChange.Enabled, ...
        false, 'Quality.SuddenChange.Enabled');
    expectEqual(Config.Alignment.Enabled, ...
        false, 'Alignment.Enabled');
    expectEqual(Config.Alignment.ReferenceStream, ...
        'IMU', 'Alignment.ReferenceStream');

    if ~isempty(fieldnames(Config.Quality.SuddenChange.Thresholds)) || ...
            ~isempty(fieldnames(Config.Quality.Physical.Bounds)) || ...
            ~isempty(fieldnames(Config.Alignment.MaxSampleAge_s))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Disabled-by-default tables must start empty.');

    end

    Detail = 'all documented defaults match the approved specification';

end

function Detail = checkConfigOverrides()
%CHECKCONFIGOVERRIDES Approved name-value overrides apply.

    Config = preprocessing.PreprocessingConfig( ...
        'Source', 'IdealSensorTelemetry', ...
        'MissingSensorPolicy', 'Strict', ...
        'RequiredSensors', {'IMU', 'GNSS'}, ...
        'GapAbsolute_s', 0.5, ...
        'GapRelative', [], ...
        'NominalRateSource', 'Measured', ...
        'StartupTransientEnabled', false, ...
        'StartupTransientWindowSamples', 3, ...
        'StatisticalEnabled', false, ...
        'StatisticalWindowSamples', 21, ...
        'StatisticalSigmaThreshold', 3.0, ...
        'SuddenChangeEnabled', true, ...
        'AlignmentEnabled', true, ...
        'ReferenceStream', 'GNSS', ...
        'MaxSampleAge_s', struct('GNSS', 0.05));

    expectEqual(Config.Source, ...
        'IdealSensorTelemetry', 'Source');
    expectEqual(Config.MissingSensors.Policy, ...
        'Strict', 'MissingSensors.Policy');
    expectEqual(Config.MissingSensors.RequiredSensors, ...
        {'IMU', 'GNSS'}, 'MissingSensors.RequiredSensors');
    expectEqual(Config.Timestamps.GapAbsolute_s, ...
        0.5, 'Timestamps.GapAbsolute_s');
    expectEqual(Config.Timestamps.GapRelative, ...
        [], 'Timestamps.GapRelative');
    expectEqual(Config.Timestamps.NominalRateSource, ...
        'Measured', 'Timestamps.NominalRateSource');
    expectEqual(Config.Quality.StartupTransient.Enabled, ...
        false, 'StartupTransient.Enabled');
    expectEqual(Config.Quality.StartupTransient.WindowSamples, ...
        3, 'StartupTransient.WindowSamples');
    expectEqual(Config.Quality.Statistical.Enabled, ...
        false, 'Statistical.Enabled');
    expectEqual(Config.Quality.Statistical.WindowSamples, ...
        21, 'Statistical.WindowSamples');
    expectEqual(Config.Quality.Statistical.SigmaThreshold, ...
        3.0, 'Statistical.SigmaThreshold');
    expectEqual(Config.Quality.SuddenChange.Enabled, ...
        true, 'SuddenChange.Enabled');
    expectEqual(Config.Alignment.Enabled, ...
        true, 'Alignment.Enabled');
    expectEqual(Config.Alignment.ReferenceStream, ...
        'GNSS', 'Alignment.ReferenceStream');
    expectEqual(Config.Alignment.MaxSampleAge_s.GNSS, ...
        0.05, 'Alignment.MaxSampleAge_s.GNSS');

    Detail = 'all 15 approved overrides apply and validate';

end

function Detail = checkConfigRejectsInvalid()
%CHECKCONFIGREJECTSINVALID Invalid configurations raise expected IDs.

    CaseCount = 0;

    assertErrorId( ...
        @() preprocessing.PreprocessingConfig('Source', 'Foo'), ...
        'Preprocessing:ValidatePreprocessingConfig:InvalidSource');
    CaseCount = CaseCount + 1;
    assertErrorId( ...
        @() preprocessing.PreprocessingConfig( ...
            'MissingSensorPolicy', 'Maybe'), ...
        'Preprocessing:ValidatePreprocessingConfig:InvalidPolicy');
    CaseCount = CaseCount + 1;
    assertErrorId( ...
        @() preprocessing.PreprocessingConfig( ...
            'RequiredSensors', {'Foo'}), ...
        'Preprocessing:ValidatePreprocessingConfig:InvalidRequiredSensors');
    CaseCount = CaseCount + 1;
    assertErrorId( ...
        @() preprocessing.PreprocessingConfig('GapAbsolute_s', -1), ...
        'Preprocessing:ValidatePreprocessingConfig:InvalidGapAbsolute');
    CaseCount = CaseCount + 1;
    assertErrorId( ...
        @() preprocessing.PreprocessingConfig('GapRelative', 0), ...
        'Preprocessing:ValidatePreprocessingConfig:InvalidGapRelative');
    CaseCount = CaseCount + 1;
    assertErrorId( ...
        @() preprocessing.PreprocessingConfig( ...
            'GapAbsolute_s', [], 'GapRelative', []), ...
        'Preprocessing:ValidatePreprocessingConfig:InvalidGapConfiguration');
    CaseCount = CaseCount + 1;
    assertErrorId( ...
        @() preprocessing.PreprocessingConfig( ...
            'NominalRateSource', 'Guess'), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'InvalidNominalRateSource']);
    CaseCount = CaseCount + 1;
    assertErrorId( ...
        @() preprocessing.PreprocessingConfig( ...
            'StatisticalWindowSamples', 2), ...
        'Preprocessing:ValidatePreprocessingConfig:InvalidStatistical');
    CaseCount = CaseCount + 1;

    Mutated = preprocessing.PreprocessingConfig();
    Mutated.Timestamps.DuplicatePolicy = 'KeepLast';
    assertErrorId( ...
        @() preprocessing.ValidatePreprocessingConfig(Mutated), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'InvalidDuplicatePolicy']);
    CaseCount = CaseCount + 1;

    Mutated = preprocessing.PreprocessingConfig();
    Mutated.Quality.Physical.Bounds = struct('Foo_mps2', [0, 1]);
    assertErrorId( ...
        @() preprocessing.ValidatePreprocessingConfig(Mutated), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'InvalidPhysicalBoundField']);
    CaseCount = CaseCount + 1;

    Mutated = preprocessing.PreprocessingConfig();
    Mutated.Quality.Physical.Bounds = struct('Altitude_m', [5, 1]);
    assertErrorId( ...
        @() preprocessing.ValidatePreprocessingConfig(Mutated), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'InvalidPhysicalBounds']);
    CaseCount = CaseCount + 1;

    Mutated = preprocessing.PreprocessingConfig();
    Mutated.Alignment.ReferenceStream = 'Bar';
    assertErrorId( ...
        @() preprocessing.ValidatePreprocessingConfig(Mutated), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'InvalidReferenceStream']);
    CaseCount = CaseCount + 1;

    Mutated = preprocessing.PreprocessingConfig();
    Mutated.Alignment.MaxSampleAge_s = struct('GNSS', -1);
    assertErrorId( ...
        @() preprocessing.ValidatePreprocessingConfig(Mutated), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'InvalidMaxSampleAge']);
    CaseCount = CaseCount + 1;

    Mutated = preprocessing.PreprocessingConfig();
    Mutated = rmfield(Mutated, 'Alignment');
    assertErrorId( ...
        @() preprocessing.ValidatePreprocessingConfig(Mutated), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'MissingConfigField']);
    CaseCount = CaseCount + 1;

    assertErrorId( ...
        @() preprocessing.ValidatePreprocessingConfig('not-a-struct'), ...
        ['Preprocessing:ValidatePreprocessingConfig:', ...
         'InvalidConfigStructure']);
    CaseCount = CaseCount + 1;

    Detail = sprintf( ...
        '%d invalid configurations rejected with expected identifiers', ...
        CaseCount);

end

function Detail = checkContractsStreamsAndChannels()
%CHECKCONTRACTSSTREAMSANDCHANNELS Canonical stream/channel sets are complete.

    Contracts = preprocessing.SensorDataContracts();

    expectEqual(Contracts.Streams, ...
        {'IMU', 'GNSS', 'AirData', 'Magnetometer'}, 'Streams');

    RequiredChannelFields = { ...
        'CanonicalField', ...
        'Unit', ...
        'SourceUnit', ...
        'ScaleToCanonical', ...
        'IdealCsvField', ...
        'RealisticCsvField', ...
        'MatField', ...
        'MatColumn'};

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};
        Stream = Contracts.(StreamName);

        if ~all(ismember(RequiredChannelFields, ...
                fieldnames(Stream.Channels)))

            error( ...
                'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                'Stream "%s" channel definitions are incomplete.', ...
                StreamName);

        end

        ChannelNames = {Stream.Channels.CanonicalField};

        if numel(unique(ChannelNames)) ~= numel(ChannelNames) || ...
                ~all(ismember({'Time_s', 'Available'}, ChannelNames))

            error( ...
                'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                'Stream "%s" canonical channel set is invalid.', ...
                StreamName);

        end

    end

    Detail = '4 streams with complete, unique canonical channel sets';

end

function Detail = checkContractsDialectCoverage()
%CHECKCONTRACTSDIALECTCOVERAGE All three naming dialects are mapped.

    Contracts = preprocessing.SensorDataContracts();
    CheckedCount = 0;

    for Index = 1:numel(Contracts.Streams)

        Stream = Contracts.(Contracts.Streams{Index});

        for ChannelIndex = 1:numel(Stream.Channels)

            Channel = Stream.Channels(ChannelIndex);
            CheckedCount = CheckedCount + 1;

            if isempty(Channel.RealisticCsvField) || ...
                    isempty(Channel.MatField)

                error( ...
                    'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                    ['Channel "%s" of stream "%s" lacks a realistic ', ...
                     'CSV or MAT name.'], ...
                    Channel.CanonicalField, ...
                    Contracts.Streams{Index});

            end

            IsOptionalIdeal = strcmp(Channel.CanonicalField, 'Available');

            if IsOptionalIdeal && ~isempty(Channel.IdealCsvField)

                error( ...
                    'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                    ['Available channel must document ideal CSV ', ...
                     'absence (empty IdealCsvField).']);

            end

            if ~IsOptionalIdeal && isempty(Channel.IdealCsvField)

                error( ...
                    'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                    'Channel "%s" must document its ideal CSV name.', ...
                    Channel.CanonicalField);

            end

            IsAxisField = ...
                ~(strcmp(Channel.CanonicalField, 'Time_s') || ...
                  strcmp(Channel.CanonicalField, 'Available'));

            if IsAxisField && isempty(Channel.Unit)

                error( ...
                    'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                    'Channel "%s" must declare a unit.', ...
                    Channel.CanonicalField);

            end

        end

        % MatColumn convention: scalar MAT fields carry column 0; Nx3 MAT
        % fields shared by three channels carry columns 1, 2, 3.
        MatFields = {Stream.Channels.MatField};
        UniqueMatFields = unique(MatFields);

        for FieldIndex = 1:numel(UniqueMatFields)

            Columns = [Stream.Channels( ...
                strcmp(MatFields, UniqueMatFields{FieldIndex})).MatColumn];

            IsScalarField = isscalar(Columns) && Columns == 0;
            IsTriadField = numel(Columns) == 3 && ...
                isequal(sort(Columns), [1, 2, 3]);

            if ~IsScalarField && ~IsTriadField

                error( ...
                    'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                    ['MAT field "%s" must be a scalar field with ', ...
                     'MatColumn 0 or an Nx3 field with MatColumn 1, 2, 3.'], ...
                    UniqueMatFields{FieldIndex});

            end

        end

    end

    Detail = sprintf( ...
        '%d channel definitions cover all three naming dialects', ...
        CheckedCount);

end

function Detail = checkContractsMagneticUnits()
%CHECKCONTRACTSMAGNETICUNITS Magnetic channels scale uT to canonical T.

    Contracts = preprocessing.SensorDataContracts();
    Stream = Contracts.Magnetometer;
    FieldNames = {Stream.Channels.CanonicalField};
    AxisChannels = Stream.Channels(startsWith(FieldNames, ...
        'MagneticFieldBody'));

    if numel(AxisChannels) ~= 3

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Magnetometer must define exactly 3 body axes.');

    end

    for Index = 1:numel(AxisChannels)

        Channel = AxisChannels(Index);
        expectEqual(Channel.Unit, 'T', [Channel.CanonicalField ' unit']);
        expectEqual(Channel.SourceUnit, 'uT', ...
            [Channel.CanonicalField ' source unit']);
        expectEqual(Channel.ScaleToCanonical, 1.0e-6, ...
            [Channel.CanonicalField ' scale']);

    end

    Detail = 'magnetic body axes scale uT to canonical T (factor 1e-6)';

end

function Detail = checkContractsRateFallbacks()
%CHECKCONTRACTSRATEFALLBACKS Code-default rates are provenance-labeled.

    Contracts = preprocessing.SensorDataContracts();

    expectEqual(Contracts.IMU.RateFallback_Hz, ...
        100.0, 'IMU rate fallback');
    expectEqual(Contracts.GNSS.RateFallback_Hz, ...
        10.0, 'GNSS rate fallback');
    expectEqual(Contracts.AirData.RateFallback_Hz, ...
        50.0, 'AirData rate fallback');
    expectEqual(Contracts.Magnetometer.RateFallback_Hz, ...
        50.0, 'Magnetometer rate fallback');

    for Index = 1:numel(Contracts.Streams)

        Stream = Contracts.(Contracts.Streams{Index});
        SourceText = lower(Stream.RateFallbackSource);

        if ~contains(SourceText, 'not evidence') || ...
                ~contains(SourceText, 'sensormodels')

            error( ...
                'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                'Stream "%s" rate fallback lacks provenance text.', ...
                Contracts.Streams{Index});

        end

    end

    Detail = ['code-default rate fallbacks present and explicitly ', ...
        'labeled as non-historical'];

end

function Detail = checkQualityStateFields()
%CHECKQUALITYSTATEFIELDS Available, RowValid, MeasurementValid are distinct.

    Flags = preprocessing.QualityFlags();
    Names = {Flags.StateFields.Name};

    expectEqual(sort(Names), ...
        sort({'Available', 'RowValid', 'MeasurementValid'}), ...
        'state field names');

    if numel(unique(Names)) ~= 3

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'State fields must be three distinct names.');

    end

    Detail = ['Available, RowValid and MeasurementValid are three ', ...
        'distinct state fields'];

end

function Detail = checkQualityFindings()
%CHECKQUALITYFINDINGS Finding registry is complete and well-formed.

    Flags = preprocessing.QualityFlags();
    FindingNames = {Flags.Findings.Name};
    Severities = {Flags.Findings.Severity};

    if numel(unique(FindingNames)) ~= numel(FindingNames)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Finding names must be unique.');

    end

    if ~all(ismember(Severities, {'Info', 'Warning', 'Error'}))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Finding severities must be Info, Warning or Error.');

    end

    ExpectedFindings = { ...
        'MissingSensor', ...
        'NonFiniteTimestamp', ...
        'BackwardTimestamp', ...
        'DuplicateTimestampLater', ...
        'UnexpectedGap', ...
        'NonFiniteMeasurement', ...
        'Unavailable', ...
        'PhysicalOutlier', ...
        'StatisticalOutlier', ...
        'SuddenChange', ...
        'StartupTransient', ...
        'StaleAlignedSample', ...
        'AlignedNoCoverage'};

    MissingFindings = setdiff(ExpectedFindings, FindingNames);

    if ~isempty(MissingFindings)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Missing findings: %s.', ...
            strjoin(MissingFindings, ', '));

    end

    Detail = sprintf('%d findings registered with valid severities', ...
        numel(FindingNames));

end

function Detail = checkProjectPathsCwdIndependence()
%CHECKPROJECTPATHSCWDINDEPENDENCE Root resolution ignores the working dir.

    OriginalDir = pwd();
    Cleanup = onCleanup(@() cd(OriginalDir));

    PathsA = preprocessing.ProjectPaths();
    cd(tempdir());
    PathsB = preprocessing.ProjectPaths();

    if ~strcmp(PathsA.ProjectRoot, PathsB.ProjectRoot)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'ProjectPaths root resolution depends on the working directory.');

    end

    if strcmp(pwd(), PathsB.ProjectRoot)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Check did not execute from an unrelated working directory.');

    end

    RequiredFields = { ...
        'ProjectRoot', ...
        'ProductionRoot', ...
        'RunsRoot', ...
        'WorkingRunsRoot', ...
        'FailedRunsRoot', ...
        'RegistryFile', ...
        'PreprocessedRoot'};

    if ~all(ismember(RequiredFields, fieldnames(PathsB)))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'ProjectPaths output fields are incomplete.');

    end

    Detail = sprintf('root "%s" resolved identically from tempdir', ...
        PathsB.ProjectRoot);

end

% =========================================================================
%% PHASE 2 CHECKS
% =========================================================================

function Detail = checkDiscoverRunsRegistryCrossCheck()
%CHECKDISCOVERRUNSREGISTRYCROSSCHECK Registry entries and folders reconcile.

    Config = preprocessing.PreprocessingConfig();
    RunList = preprocessing.DiscoverRuns(Config);
    Paths = preprocessing.ProjectPaths();

    Registry = jsondecode(fileread(Paths.RegistryFile));
    RegistryRunList = Registry.Runs(:);
    RegistryIDs = {RegistryRunList.RunID};
    RegisteredIDs = {RunList.Registered.RunID};

    expectEqual(sort(RegisteredIDs), sort(RegistryIDs), ...
        'registered IDs vs registry IDs');

    RunFolderNames = listFolders(Paths.RunsRoot);
    CoveredIDs = [RegisteredIDs, {RunList.UnregisteredRuns.RunID}];
    expectEqual(sort(RunFolderNames), sort(unique(CoveredIDs)), ...
        'run folder coverage by registered + unregistered');

    ExcludedIDs = ...
        [{RunList.WorkingRuns.RunID}, {RunList.FailedRuns.RunID}];

    if any(ismember(RunList.EligibleRunIDs, ExcludedIDs))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'WorkingRuns/FailedRuns leaked into EligibleRunIDs.');

    end

    KnownUnregistered = 'Run_001_20260906_160342';

    if any(strcmp(RunFolderNames, KnownUnregistered)) && ...
            ~any(strcmp(RegistryIDs, KnownUnregistered)) && ...
            ~any(strcmp({RunList.UnregisteredRuns.RunID}, ...
                KnownUnregistered))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Unregistered run "%s" was not surfaced for review.', ...
            KnownUnregistered);

    end

    Detail = sprintf([ ...
        '%d registry entries, %d run folders, %d unregistered, ', ...
        '%d WorkingRuns, %d FailedRuns, %d eligible'], ...
        RunList.Summary.RegisteredCount, ...
        RunList.Summary.RunFolderCount, ...
        RunList.Summary.UnregisteredCount, ...
        RunList.Summary.WorkingRunCount, ...
        RunList.Summary.FailedRunCount, ...
        RunList.Summary.EligibleCount);

end

function Detail = checkDiscoverRunsCwdIndependence()
%CHECKDISCOVERRUNSCWDINDEPENDENCE Discovery ignores the working directory.

    OriginalDir = pwd();
    Cleanup = onCleanup(@() cd(OriginalDir));

    Config = preprocessing.PreprocessingConfig();
    RunListA = preprocessing.DiscoverRuns(Config);
    cd(tempdir());
    RunListB = preprocessing.DiscoverRuns(Config);

    expectEqual(RunListA.Summary, RunListB.Summary, 'summary');
    expectEqual(sort(RunListA.EligibleRunIDs), ...
        sort(RunListB.EligibleRunIDs), 'eligible IDs');

    Detail = sprintf( ...
        'identical discovery from tempdir: %d eligible runs', ...
        numel(RunListB.EligibleRunIDs));

end

function Detail = checkDiscoverAndInspectReadOnly()
%CHECKDISCOVERANDINSPECTREADONLY Discovery and inspection never write.

    Paths = preprocessing.ProjectPaths();
    Config = preprocessing.PreprocessingConfig();
    MetadataPath = fullfile( ...
        Paths.RunsRoot, 'Run_001_20261107_110817', 'RunMetadata.json');

    RegistryBytes = readBytes(Paths.RegistryFile);
    MetadataBytes = readBytes(MetadataPath);

    preprocessing.DiscoverRuns(Config);
    preprocessing.InspectRun('Run_001_20261107_110817', Config);

    if ~isequal(RegistryBytes, readBytes(Paths.RegistryFile)) || ...
            ~isequal(MetadataBytes, readBytes(MetadataPath))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            ['Registry or run metadata changed during discovery or ', ...
             'inspection.']);

    end

    Detail = [ ...
        'registry and run metadata byte-identical after discovery ', ...
        'and inspection'];

end

function Detail = checkInspectRunRegisteredEligible()
%CHECKINSPECTRUNREGISTEREDELIGIBLE Registered run resolves and qualifies.

    Config = preprocessing.PreprocessingConfig();
    Inspection = preprocessing.InspectRun('Run_001_20261107_110817', Config);

    expectEqual(Inspection.Category, 'Registered', 'category');
    expectEqual(Inspection.PathSource, ...
        'RunRegistry.FinalRunDirectory', 'path source');
    expectEqual(Inspection.Eligibility, 'Eligible', 'eligibility');

    if ~isempty(Inspection.Issues)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Unexpected issues: %s.', ...
            strjoin(Inspection.Issues, '; '));

    end

    if ~contains(Inspection.ReportedWorkingRunDirectory, ...
            'WorkingRuns') || ...
            ~contains(Inspection.RunDirectory, [filesep 'Runs' filesep])

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            ['Stale-path handling not evidenced: reported "%s", ', ...
             'resolved "%s".'], ...
            Inspection.ReportedWorkingRunDirectory, ...
            Inspection.RunDirectory);

    end

    Detail = sprintf([ ...
        'eligible; %d/%d required artifacts; stale WorkingRuns path ', ...
        'recorded but ignored for resolution'], ...
        Inspection.Summary.RequiredPresent, ...
        Inspection.Summary.RequiredCount);

end

function Detail = checkInspectRunUnregisteredReview()
%CHECKINSPECTRUNUNREGISTEREDREVIEW Unregistered run needs explicit review.

    RunID = 'Run_001_20260906_160342';
    Paths = preprocessing.ProjectPaths();

    if ~isfolder(fullfile(Paths.RunsRoot, RunID))

        Detail = sprintf('skipped: %s folder not present', RunID);
        return;

    end

    Inspection = preprocessing.InspectRun(RunID, ...
        preprocessing.PreprocessingConfig());

    expectEqual(Inspection.Category, 'Unregistered', 'category');
    expectEqual(Inspection.Eligibility, 'ReviewRequired', 'eligibility');

    if ~any(strcmp(Inspection.Issues, 'NotInRunRegistry'))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Missing NotInRunRegistry issue for unregistered run.');

    end

    Detail = sprintf( ...
        '%s flagged ReviewRequired (%d/%d required artifacts present)', ...
        RunID, ...
        Inspection.Summary.RequiredPresent, ...
        Inspection.Summary.RequiredCount);

end

function Detail = checkInspectRunExcludedLocations()
%CHECKINSPECTRUNEXCLUDEDLOCATIONS WorkingRuns/FailedRuns are excluded.

    Paths = preprocessing.ProjectPaths();
    Config = preprocessing.PreprocessingConfig();
    WorkingNames = listFolders(Paths.WorkingRunsRoot);

    if isempty(WorkingNames)

        Detail = 'skipped: no WorkingRuns folders present';
        return;

    end

    Inspection = preprocessing.InspectRun(WorkingNames{1}, Config);
    expectEqual(Inspection.Eligibility, 'Ineligible', 'eligibility');

    if ~any(strcmp(Inspection.Issues, 'ExcludedLocation:WorkingRuns'))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'WorkingRuns run was not excluded from normal selection.');

    end

    Detail = sprintf([ ...
        '%s excluded as WorkingRun; %d WorkingRuns and %d FailedRuns ', ...
        'folders present'], ...
        WorkingNames{1}, ...
        numel(WorkingNames), ...
        numel(listFolders(Paths.FailedRunsRoot)));

end

function Detail = checkInspectRunNotFound()
%CHECKINSPECTRUNNOTFOUND Unknown run IDs raise a typed error.

    assertErrorId( ...
        @() preprocessing.InspectRun( ...
            'Run_999_20260101_000000', ...
            preprocessing.PreprocessingConfig()), ...
        'Preprocessing:InspectRun:RunNotFound');

    Detail = [ ...
        'unknown RunID rejected with ', ...
        'Preprocessing:InspectRun:RunNotFound'];

end

function Detail = checkInspectRunArtifactChecks()
%CHECKINSPECTRUNARTIFACTCHECKS Artifact presence and content checks pass.

    Config = preprocessing.PreprocessingConfig();
    Inspection = preprocessing.InspectRun('Run_001_20261107_110817', Config);
    Artifacts = Inspection.Artifacts;

    Required = Artifacts(strcmp({Artifacts.Source}, 'Required'));

    if ~all([Required.Exists])

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Missing required artifacts.');

    end

    Checked = Artifacts(~cellfun(@isnan, {Artifacts.CheckOk}));

    if ~all([Checked.CheckOk])

        FailedNames = ...
            {Checked(~[Checked.CheckOk]).RelativePath};
        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Artifact checks failed: %s.', ...
            strjoin(FailedNames, ', '));

    end

    Detail = sprintf([ ...
        '%d required artifacts present; %d content checks passed ', ...
        'across %d MAT and %d CSV files'], ...
        numel(Required), ...
        sum([Checked.CheckOk]), ...
        sum(strcmp({Artifacts.Kind}, 'Mat')), ...
        sum(strcmp({Artifacts.Kind}, 'Csv')));

end

% =========================================================================
%% PHASE 2 HELPERS
% =========================================================================

function Names = listFolders(Root)
%LISTFOLDERS Sorted folder names under Root (dots excluded).

    Listing = dir(Root);
    Listing = Listing([Listing.isdir]);
    Names = {Listing.name};
    Names = sort(Names(~ismember(Names, {'.', '..'})));

end

function Bytes = readBytes(FilePath)
%READBYTES Read an entire file as uint8 bytes for mutation checks.

    fid = fopen(FilePath, 'rb');

    if fid < 0

        error( ...
            'Preprocessing:RunPreprocessingTests:FileOpenFailure', ...
            'Cannot open "%s".', ...
            FilePath);

    end

    Cleanup = onCleanup(@() fclose(fid));
    Bytes = fread(fid, Inf, '*uint8');

end

% =========================================================================
%% PHASE 3 CHECKS
% =========================================================================

function Detail = checkLoadRealisticCsvAuto()
%CHECKLOADREALISTICCSVAUTO Real run loads with counts matching metadata.

    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');

    Data = preprocessing.LoadSensorData(RunDirectory, Config, 'Auto');

    expectEqual(Data.Source, 'RealisticSensorTelemetry', 'source');

    Contracts = preprocessing.SensorDataContracts();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};
        expectEqual(Data.Streams.(StreamName).Status, ...
            'Loaded', [StreamName ' status']);
        expectEqual(Data.Streams.(StreamName).SourceDialect, ...
            'RealisticCsv', [StreamName ' dialect']);

    end

    Metadata = jsondecode(fileread( ...
        fullfile(RunDirectory, 'RunMetadata.json')));

    expectEqual(Data.Summary.SampleCounts.IMU, ...
        Metadata.Telemetry.IMUSampleCount, 'IMU count vs metadata');
    expectEqual(Data.Summary.SampleCounts.GNSS, ...
        Metadata.Telemetry.GNSSSampleCount, 'GNSS count vs metadata');
    expectEqual(Data.Summary.SampleCounts.AirData, ...
        Metadata.Telemetry.AirDataSampleCount, 'AirData count vs metadata');
    expectEqual(Data.Summary.SampleCounts.Magnetometer, ...
        Metadata.Telemetry.MagnetometerSampleCount, ...
        'Magnetometer count vs metadata');

    Detail = sprintf([ ...
        '4 streams loaded via CSV; sample counts IMU %d, GNSS %d, ', ...
        'AirData %d, Mag %d match RunMetadata.Telemetry'], ...
        Data.Summary.SampleCounts.IMU, ...
        Data.Summary.SampleCounts.GNSS, ...
        Data.Summary.SampleCounts.AirData, ...
        Data.Summary.SampleCounts.Magnetometer);

end

function Detail = checkLoadIdealCsvSynthesizedAvailable()
%CHECKLOADIDEALCSVSYNTHESIZEDAVAILABLE Ideal CSV availability synthesis.

    Config = preprocessing.PreprocessingConfig( ...
        'Source', 'IdealSensorTelemetry');
    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');

    Data = preprocessing.LoadSensorData(RunDirectory, Config, 'Csv');
    IMU = Data.Streams.IMU;

    expectEqual(IMU.Status, 'Loaded', 'status');

    if ~all(IMU.Available)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Synthesized availability must be all-true.');

    end

    if ~any(strcmp(IMU.SynthesizedFields, 'Available'))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Synthesized Available must be documented.');

    end

    expectEqual(IMU.SourceFieldNames.Available, ...
        '<synthesized>', 'Available source field');

    Raw = readmatrix(fullfile( ...
        RunDirectory, 'IdealSensorTelemetry', 'IMU.csv'), ...
        'NumHeaderLines', 1);

    if ~isequal(IMU.Accelerometer_X_mps2, Raw(:, 2))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Ideal CSV accelerometer values must pass through unchanged.');

    end

    expectEqual(IMU.SourceRowIdx, (1:IMU.SampleCount).', 'row index');
    expectEqual(IMU.SourceTime_s, Raw(:, 1), 'source time');

    Detail = sprintf([ ...
        'ideal CSV loaded with documented synthesized Available ', ...
        '(%d rows, values unchanged, row trace intact)'], ...
        IMU.SampleCount);

end

function Detail = checkMatV73AndV7CrossFormat()
%CHECKMATV73ANDV7CROSSFORMAT Both MAT formats load and agree with CSV.

    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');

    ConfigRealistic = preprocessing.PreprocessingConfig();
    DataCsv = preprocessing.LoadSensorData( ...
        RunDirectory, ConfigRealistic, 'Csv');
    DataMat = preprocessing.LoadSensorData( ...
        RunDirectory, ConfigRealistic, 'Mat');

    expectEqual(DataMat.Streams.IMU.SourceFormat, ...
        'MatLevel5', 'realistic MAT format');
    expectEqual(DataMat.Streams.IMU.SourceVariable, ...
        'RealisticSensorTelemetry', 'realistic MAT variable');

    ConfigIdeal = preprocessing.PreprocessingConfig( ...
        'Source', 'IdealSensorTelemetry');
    DataIdealMat = preprocessing.LoadSensorData( ...
        RunDirectory, ConfigIdeal, 'Mat');

    expectEqual(DataIdealMat.Streams.IMU.SourceFormat, ...
        'MatV73', 'ideal MAT format');
    expectEqual(DataIdealMat.Streams.IMU.SourceVariable, ...
        'IdealSensorTelemetryToSave', 'ideal MAT variable');

    assertApprox(DataCsv.Streams.IMU.Time_s, ...
        DataMat.Streams.IMU.Time_s, 1.0e-9, 'IMU time CSV vs MAT');
    assertApprox(DataCsv.Streams.Magnetometer.MagneticFieldBody_X_T, ...
        DataMat.Streams.Magnetometer.MagneticFieldBody_X_T, ...
        1.0e-12, 'magnetic X CSV vs MAT');
    assertApprox(DataCsv.Streams.IMU.Accelerometer_Z_mps2, ...
        DataMat.Streams.IMU.Accelerometer_Z_mps2, ...
        1.0e-9, 'accelerometer Z CSV vs MAT');

    Detail = [ ...
        'v7.3 and Level-5 MAT both load with recorded variable names; ', ...
        'CSV and MAT values agree within text precision'];

end

function Detail = checkMatVariableDiscoveryUnknownName()
%CHECKMATVARIABLEDISCOVERYUNKNOWNNAME Discovery works without known names.

    FixtureRoot = fixtureDir('DiscoveryFixture');
    buildDiscoveryFixture(FixtureRoot);

    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(FixtureRoot, Config, 'Auto');

    Contracts = preprocessing.SensorDataContracts();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};
        Stream = Data.Streams.(StreamName);

        expectEqual(Stream.Status, 'Loaded', [StreamName ' status']);
        expectEqual(Stream.SourceVariable, ...
            'MyTelemetry', [StreamName ' variable']);

    end

    expectEqual(Data.Streams.GNSS.SampleCount, 5, 'fixture sample count');

    Detail = [ ...
        'renamed v7.3 variable "MyTelemetry" discovered by file ', ...
        'contents; all 4 streams loaded'];

end

function Detail = checkMissingSensorFile()
%CHECKMISSINGSENSORFILE Missing sensor files are reported, not fatal.

    FixtureRoot = fixtureDir('MissingFixture');
    buildMissingFixture(FixtureRoot);

    Config = preprocessing.PreprocessingConfig( ...
        'Source', 'IdealSensorTelemetry');
    Data = preprocessing.LoadSensorData(FixtureRoot, Config, 'Auto');

    expectEqual(Data.Streams.GNSS.Status, 'Missing', 'GNSS status');
    expectEqual(Data.Streams.IMU.Status, 'Loaded', 'IMU status');
    expectEqual(Data.Streams.AirData.Status, 'Loaded', 'AirData status');
    expectEqual(Data.Streams.Magnetometer.Status, ...
        'Loaded', 'Magnetometer status');

    if ~any(strcmp(Data.MissingSensors, 'GNSS'))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Missing GNSS must be listed in Data.MissingSensors.');

    end

    Detail = [ ...
        'GNSS reported Missing with typed issues; other three ', ...
        'streams loaded normally'];

end

function Detail = checkMalformedSensorFile()
%CHECKMALFORMEDSENSORFILE Malformed files are isolated and reported.

    FixtureRoot = fixtureDir('MalformedFixture');
    buildMalformedFixture(FixtureRoot);

    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(FixtureRoot, Config, 'Auto');

    expectEqual(Data.Streams.IMU.Status, 'Malformed', 'IMU status');
    expectEqual(Data.Streams.GNSS.Status, 'Loaded', 'GNSS status');

    if isempty(Data.Streams.IMU.Issues)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Malformed IMU must record typed issues.');

    end

    DataMat = preprocessing.LoadSensorData(FixtureRoot, Config, 'Mat');

    expectEqual(DataMat.Streams.IMU.Status, 'Malformed', ...
        'corrupt MAT status');

    if isempty(DataMat.Streams.IMU.Issues)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Corrupt MAT must record typed issues.');

    end

    Detail = sprintf([ ...
        'bad-header CSV and corrupt MAT isolated as Malformed ', ...
        '(%d and %d typed issues); sibling streams unaffected'], ...
        numel(Data.Streams.IMU.Issues), ...
        numel(DataMat.Streams.IMU.Issues));

end

function Detail = checkTraceabilityAndDialects()
%CHECKTRACEABILITYANDDIALECTS Row trace and all three dialect mappings.

    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');

    DataRealisticCsv = preprocessing.LoadSensorData(RunDirectory, ...
        preprocessing.PreprocessingConfig(), 'Csv');
    DataRealisticMat = preprocessing.LoadSensorData(RunDirectory, ...
        preprocessing.PreprocessingConfig(), 'Mat');
    DataIdealCsv = preprocessing.LoadSensorData(RunDirectory, ...
        preprocessing.PreprocessingConfig( ...
            'Source', 'IdealSensorTelemetry'), 'Csv');

    expectEqual( ...
        DataRealisticCsv.Streams.IMU.SourceFieldNames.Accelerometer_X_mps2, ...
        'AccelerometerX_mps2', 'realistic CSV mapping');
    expectEqual( ...
        DataIdealCsv.Streams.IMU.SourceFieldNames.Accelerometer_X_mps2, ...
        'Accelerometer_X_mps2', 'ideal CSV mapping');
    expectEqual( ...
        DataRealisticMat.Streams.IMU.SourceFieldNames.Accelerometer_X_mps2, ...
        'Accelerometer_mps2', 'MAT mapping');

    IMU = DataRealisticCsv.Streams.IMU;
    expectEqual(IMU.SourceRowIdx, (1:IMU.SampleCount).', 'row index');

    Raw = readmatrix(fullfile( ...
        RunDirectory, 'RealisticSensorTelemetry', 'IMU.csv'), ...
        'NumHeaderLines', 1);
    expectEqual(IMU.SourceTime_s, Raw(:, 1), 'source time');
    expectEqual(IMU.Time_s, IMU.SourceTime_s, 'time passthrough');

    Detail = [ ...
        'all three dialects map to identical canonical fields; ', ...
        'source row index and raw timestamps preserved exactly'];

end

function Detail = checkGroundTruthExcluded()
%CHECKGROUNDTHEXCLUDED Ground truth never enters estimator input.

    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');
    GtCsv = fullfile(RunDirectory, 'GroundTruth', ...
        'GroundTruthTelemetry.csv');
    GtMat = fullfile(RunDirectory, 'GroundTruth', ...
        'GroundTruthTelemetry.mat');

    CsvBytes = readBytes(GtCsv);
    MatBytes = readBytes(GtMat);

    Data = preprocessing.LoadSensorData(RunDirectory, ...
        preprocessing.PreprocessingConfig(), 'Auto');

    if ~isequal(CsvBytes, readBytes(GtCsv)) || ...
            ~isequal(MatBytes, readBytes(GtMat))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'GroundTruth files changed during sensor loading.');

    end

    StreamFields = fieldnames(Data.Streams.IMU);
    GroundTruthFields = ...
        {'VelocityBody_mps', 'Euler_rad', 'AirDensity_kgpm3'};

    if any(ismember(GroundTruthFields, StreamFields))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Ground truth fields leaked into estimator data.');

    end

    if ~all(strcmp(Data.ExcludedSources, ...
            {'GroundTruthTelemetry', 'Block7'}))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'ExcludedSources must document GroundTruth and Block7.');

    end

    Detail = [ ...
        'GroundTruth files byte-identical after loading; no ', ...
        'ground-truth fields present in sensor output'];

end

function Detail = checkNormalizeSchemaSynthesis()
%CHECKNORMALIZESCHEMASYNTHESIS Direct schema mapping and synthesis rules.

    Raw = struct();
    Raw.Time_s = (0:4).' * 0.01;
    Raw.Accelerometer_X_mps2 = ones(5, 1);
    Raw.Accelerometer_Y_mps2 = ones(5, 1);
    Raw.Accelerometer_Z_mps2 = -9.81 * ones(5, 1);
    Raw.Gyroscope_X_radps = zeros(5, 1);
    Raw.Gyroscope_Y_radps = zeros(5, 1);
    Raw.Gyroscope_Z_radps = zeros(5, 1);

    Stream = preprocessing.NormalizeSensorSchema(Raw, 'IMU', 'IdealCsv');

    expectEqual(Stream.SynthesizedFields, {'Available'}, 'synthesis list');

    if ~all(Stream.Available)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Synthesized availability must be all-true.');

    end

    expectEqual(Stream.SourceFieldNames.Available, ...
        '<synthesized>', 'synthesized field marker');

    RawBad = rmfield(Raw, 'Gyroscope_Z_radps');
    assertErrorId( ...
        @() preprocessing.NormalizeSensorSchema(RawBad, 'IMU', 'IdealCsv'), ...
        ['Preprocessing:NormalizeSensorSchema:', ...
         'MissingSourceField']);

    RawRealistic = rmfield(Raw, {'Accelerometer_X_mps2', ...
        'Accelerometer_Y_mps2', 'Accelerometer_Z_mps2', ...
        'Gyroscope_X_radps', 'Gyroscope_Y_radps', 'Gyroscope_Z_radps'});
    RawRealistic.AccelerometerX_mps2 = ones(5, 1);
    RawRealistic.AccelerometerY_mps2 = ones(5, 1);
    RawRealistic.AccelerometerZ_mps2 = ones(5, 1);
    RawRealistic.GyroscopeX_radps = zeros(5, 1);
    RawRealistic.GyroscopeY_radps = zeros(5, 1);
    RawRealistic.GyroscopeZ_radps = zeros(5, 1);

    assertErrorId( ...
        @() preprocessing.NormalizeSensorSchema( ...
            RawRealistic, 'IMU', 'RealisticCsv'), ...
        ['Preprocessing:NormalizeSensorSchema:', ...
         'MissingSourceField']);

    Detail = [ ...
        'ideal CSV Available synthesized and documented; missing ', ...
        'fields in both dialects raise typed schema errors'];

end

function Detail = checkNormalizeUnitsScaling()
%CHECKNORMALIZEUNITSSCALING uT -> T conversion and conversion records.

    Raw = struct();
    Raw.Time_s = (0:4).' * 0.01;
    Raw.MagneticFieldX_uT = 27.5 * ones(5, 1);
    Raw.MagneticFieldY_uT = -1.5 * ones(5, 1);
    Raw.MagneticFieldZ_uT = -16.0 * ones(5, 1);
    Raw.Available = ones(5, 1);

    Stream = preprocessing.NormalizeSensorSchema( ...
        Raw, 'Magnetometer', 'RealisticCsv');
    Stream = preprocessing.NormalizeSensorUnits(Stream, 'Magnetometer');

    assertApprox(Stream.MagneticFieldBody_X_T, ...
        27.5e-6 * ones(5, 1), 1.0e-15, 'X axis scaling');
    assertApprox(Stream.MagneticFieldBody_Z_T, ...
        -16.0e-6 * ones(5, 1), 1.0e-15, 'Z axis scaling');

    expectEqual(Stream.UnitConversions.MagneticFieldBody_X_T.Factor, ...
        1.0e-6, 'conversion factor');
    expectEqual(Stream.UnitConversions.MagneticFieldBody_X_T.SourceUnit, ...
        'uT', 'source unit');
    expectEqual(Stream.UnitConversions.MagneticFieldBody_X_T.Unit, ...
        'T', 'canonical unit');
    expectEqual(Stream.SourceTime_s, (0:4).' * 0.01, ...
        'audit time unchanged');
    expectEqual(Stream.SourceFieldNames.MagneticFieldBody_X_T, ...
        'MagneticFieldX_uT', 'trace name');

    Broken = rmfield(Stream, 'MagneticFieldBody_Y_T');
    assertErrorId( ...
        @() preprocessing.NormalizeSensorUnits(Broken, 'Magnetometer'), ...
        ['Preprocessing:NormalizeSensorUnits:', ...
         'MissingCanonicalField']);

    Detail = [ ...
        'magnetic axes scaled uT to T with recorded factors; audit ', ...
        'fields untouched; missing canonical field raises typed error'];

end

function Detail = checkLoadSensorDataCwdIndependence()
%CHECKLOADSENSORDATACWDINDEPENDENCE Loading ignores the working directory.

    OriginalDir = pwd();
    Cleanup = onCleanup(@() cd(OriginalDir));

    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');
    Config = preprocessing.PreprocessingConfig();

    DataA = preprocessing.LoadSensorData(RunDirectory, Config, 'Auto');
    cd(tempdir());
    DataB = preprocessing.LoadSensorData(RunDirectory, Config, 'Auto');

    expectEqual(DataA.Summary.SampleCounts, ...
        DataB.Summary.SampleCounts, 'sample counts');

    Detail = 'identical loads from tempdir and project root';

end

% =========================================================================
%% PHASE 3 HELPERS AND FIXTURES
% =========================================================================

function assertApprox(Actual, Expected, Tol, Label)
%ASSERTAPPROX Assert max absolute difference within tolerance.

    if ~isequal(size(Actual), size(Expected))

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            '%s: size mismatch.', ...
            Label);

    end

    MaxDiff = max(abs(Actual(:) - Expected(:)));

    if ~(MaxDiff <= Tol)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            '%s: max abs difference %g exceeds tolerance %g.', ...
            Label, ...
            MaxDiff, ...
            Tol);

    end

end

function FixtureRoot = fixtureDir(Name)
%FIXTUREDIR Create and return a fixture folder under TestArtifacts.

    Paths = preprocessing.ProjectPaths();
    FixtureRoot = fullfile(Paths.PreprocessedRoot, ...
        'TestArtifacts', 'Phase3Fixtures', Name);

    if ~isfolder(FixtureRoot)

        mkdir(FixtureRoot);

    end

end

function buildDiscoveryFixture(FixtureRoot)
%BUILDDISCOVERYFIXTURE MAT with a renamed telemetry variable (v7.3).

    SourceFolder = fullfile(FixtureRoot, 'RealisticSensorTelemetry');

    if ~isfolder(SourceFolder)

        mkdir(SourceFolder);

    end

    MyTelemetry = struct();
    MyTelemetry.IMU = makeMatStream('IMU', 5, 100);
    MyTelemetry.GNSS = makeMatStream('GNSS', 5, 10);
    MyTelemetry.AirData = makeMatStream('AirData', 5, 50);
    MyTelemetry.Magnetometer = makeMatStream('Magnetometer', 5, 50);

    save(fullfile(SourceFolder, 'RealisticSensorTelemetry.mat'), ...
        'MyTelemetry', '-v7.3');

end

function Sub = makeMatStream(StreamName, RowCount, Rate_Hz)
%MAKEMATSTREAM Build one contract-shaped MAT stream struct.

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(StreamName).Channels;

    Sub = struct();
    Sub.Time_s = (0:RowCount - 1).' * (1 / Rate_Hz);
    Sub.SampleRate_Hz = Rate_Hz;
    Sub.SampleCount = RowCount;

    for Index = 1:numel(Channels)

        Channel = Channels(Index);

        if strcmp(Channel.CanonicalField, 'Time_s')

            continue;

        end

        if strcmp(Channel.CanonicalField, 'Available')

            Sub.(Channel.MatField) = true(RowCount, 1);
            continue;

        end

        if Channel.MatColumn == 0

            Sub.(Channel.MatField) = ...
                (1:RowCount).' * 0.001 * Index;

        elseif ~isfield(Sub, Channel.MatField)

            Sub.(Channel.MatField) = ...
                ones(RowCount, 3) * 0.001 * Index;

        end

    end

end

function buildMissingFixture(FixtureRoot)
%BUILDMISSINGFIXTURE Ideal source with the GNSS CSV absent.

    SourceFolder = fullfile(FixtureRoot, 'IdealSensorTelemetry');

    if ~isfolder(SourceFolder)

        mkdir(SourceFolder);

    end

    writeFixtureCsv(fullfile(SourceFolder, 'IMU.csv'), ...
        'IMU', 'IdealCsv', 5);
    writeFixtureCsv(fullfile(SourceFolder, 'AirData.csv'), ...
        'AirData', 'IdealCsv', 5);
    writeFixtureCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', 'IdealCsv', 5);

end

function buildMalformedFixture(FixtureRoot)
%BUILDMALFORMEDFIXTURE Bad-header CSV and a corrupt MAT file.

    SourceFolder = fullfile(FixtureRoot, 'RealisticSensorTelemetry');

    if ~isfolder(SourceFolder)

        mkdir(SourceFolder);

    end

    fid = fopen(fullfile(SourceFolder, 'IMU.csv'), 'w');
    fprintf(fid, 'Foo,Bar\n1,2\n3,4\n');
    fclose(fid);

    writeFixtureCsv(fullfile(SourceFolder, 'GNSS.csv'), ...
        'GNSS', 'RealisticCsv', 5);
    writeFixtureCsv(fullfile(SourceFolder, 'AirData.csv'), ...
        'AirData', 'RealisticCsv', 5);
    writeFixtureCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', 'RealisticCsv', 5);

    fid = fopen(fullfile(SourceFolder, ...
        'RealisticSensorTelemetry.mat'), 'wb');
    fwrite(fid, uint8('this is not a MAT file'));
    fclose(fid);

end

function writeFixtureCsv(FilePath, StreamName, Dialect, RowCount)
%WRITEFIXTURECSV Write one contract-shaped sensor CSV fixture.

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(StreamName).Channels;

    HeaderNames = {};

    for Index = 1:numel(Channels)

        if strcmp(Dialect, 'IdealCsv')

            SourceName = Channels(Index).IdealCsvField;

        else

            SourceName = Channels(Index).RealisticCsvField;

        end

        if ~isempty(SourceName)

            HeaderNames{end + 1} = SourceName;

        end

    end

    fid = fopen(FilePath, 'w');
    Cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '%s\n', strjoin(HeaderNames, ','));

    for Row = 1:RowCount

        for Col = 1:numel(HeaderNames)

            if Col > 1

                fprintf(fid, ',');

            end

            switch HeaderNames{Col}

                case 'Time_s'

                    fprintf(fid, '%.15g', (Row - 1) * 0.01);

                case 'Available'

                    fprintf(fid, '%d', 1);

                otherwise

                    fprintf(fid, '%.15g', Row * 0.001 * Col);

            end

        end

        fprintf(fid, '\n');

    end

end

% =========================================================================
%% PHASE 4 CHECKS
% =========================================================================

function Detail = checkRealRunTimestampsAndProvenance()
%CHECKREALRUNTIMESTAMPSANDPROVENANCE Real runs and the provenance chain.

    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');

    DataCsv = preprocessing.LoadSensorData(RunDirectory, Config, 'Csv');
    DataMat = preprocessing.LoadSensorData(RunDirectory, Config, 'Mat');

    ExpectedRates = struct( ...
        'IMU', 100, 'GNSS', 10, 'AirData', 50, 'Magnetometer', 50);
    Contracts = preprocessing.SensorDataContracts();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        Proc = preprocessing.ProcessSensorTimestamps( ...
            Config, DataCsv.Streams.(StreamName), StreamName);

        expectEqual(Proc.NominalRateSource, 'Measured', ...
            [StreamName ' CSV provenance']);
        assertApprox(Proc.NominalRate_Hz, ...
            ExpectedRates.(StreamName), 1.0e-6, ...
            [StreamName ' measured rate']);

        if Proc.TimestampSummary.SegmentCount ~= 1 || ...
                Proc.TimestampSummary.ExcludedRows ~= 0

            error( ...
                'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
                'Unexpected segmentation on real stream "%s".', ...
                StreamName);

        end

        ProcMat = preprocessing.ProcessSensorTimestamps( ...
            Config, DataMat.Streams.(StreamName), StreamName);

        expectEqual(ProcMat.NominalRateSource, 'Recorded', ...
            [StreamName ' MAT provenance']);
        assertApprox(ProcMat.NominalRate_Hz, ...
            ExpectedRates.(StreamName), 1.0e-9, ...
            [StreamName ' recorded rate']);

    end

    ConfigCode = preprocessing.PreprocessingConfig( ...
        'NominalRateSource', 'CodeDefault');
    ProcCode = preprocessing.ProcessSensorTimestamps( ...
        ConfigCode, DataCsv.Streams.IMU, 'IMU');
    expectEqual(ProcCode.NominalRateSource, ...
        'CodeDefault', 'forced code default');
    expectEqual(ProcCode.NominalRate_Hz, 100.0, 'code default rate');

    assertErrorId( ...
        @() preprocessing.ProcessSensorTimestamps( ...
            preprocessing.PreprocessingConfig( ...
                'NominalRateSource', 'Recorded'), ...
            DataCsv.Streams.IMU, 'IMU'), ...
        ['Preprocessing:ProcessSensorTimestamps:', ...
         'RecordedRateUnavailable']);

    Detail = [ ...
        'provenance chain verified per stream: CSV->Measured, ', ...
        'MAT->Recorded, forced->CodeDefault; real runs single-segment ', ...
        'with zero excluded rows'];

end

function Detail = checkDuplicateAndBackwardSemantics()
%CHECKDUPLICATEANDBACKWARDSEMANTICS First-kept duplicates, segment breaks.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 0.01; 0.01; 0.02; 0.03; 0.025; 0.026; NaN];
    AccelX = (1:8).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.RowValid, ...
        logical([1; 1; 0; 1; 1; 1; 1; 0]), 'RowValid');
    expectEqual(Proc.Flags.DuplicateTimestampLater, ...
        logical([0; 0; 1; 0; 0; 0; 0; 0]), 'duplicate flags');
    expectEqual(Proc.Flags.BackwardTimestamp, ...
        logical([0; 0; 0; 0; 0; 1; 0; 0]), 'backward flags');
    expectEqual(Proc.Flags.NonFiniteTimestamp, ...
        logical([0; 0; 0; 0; 0; 0; 0; 1]), 'nonfinite time flags');
    expectEqual(Proc.SegmentID, ...
        [1; 1; 0; 1; 1; 2; 2; 0], 'segment IDs');
    expectEqual(Proc.TimestampSummary.SegmentCount, 2, 'segment count');
    expectEqual(Proc.Segments(2).BreakReason, ...
        'BackwardTimestamp', 'break reason');
    expectEqual(Proc.Time_s, Time_s, 'time vector unchanged');
    expectEqual(Proc.Accelerometer_X_mps2, AccelX, 'values retained');

    Detail = [ ...
        'later duplicates excluded+flagged; backward row opens segment ', ...
        '2; all 8 original rows retained as audit data'];

end

function Detail = checkGapOrSemantics()
%CHECKGAPORSEMANTICS Either threshold exceeded means a gap.

    Time_s = [0; 0.01; 0.02; 0.04; 0.05; 0.30; 0.31];
    Stream = buildImuStream(Time_s, zeros(7, 1));

    Config = preprocessing.PreprocessingConfig();
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    expectEqual(Proc.TimestampSummary.SegmentCount, ...
        3, 'OR: relative-only and both criteria');
    expectEqual(Proc.Flags.UnexpectedGap, ...
        logical([0; 0; 0; 1; 0; 1; 0]), 'gap rows');

    ConfigAbsolute = preprocessing.PreprocessingConfig( ...
        'GapRelative', []);
    ProcAbsolute = preprocessing.ProcessSensorTimestamps( ...
        ConfigAbsolute, Stream, 'IMU');
    expectEqual(ProcAbsolute.TimestampSummary.SegmentCount, ...
        1, 'absolute-only 1.0 s: no gap');

    ConfigMixed = preprocessing.PreprocessingConfig( ...
        'GapAbsolute_s', 0.2, 'GapRelative', []);
    ProcMixed = preprocessing.ProcessSensorTimestamps( ...
        ConfigMixed, Stream, 'IMU');
    expectEqual(ProcMixed.TimestampSummary.SegmentCount, ...
        2, 'absolute-only 0.2 s: one gap');
    expectEqual(ProcMixed.Flags.UnexpectedGap, ...
        logical([0; 0; 0; 0; 0; 1; 0]), 'gap only at dt 0.25');

    Detail = [ ...
        'OR semantics proven: dt 0.02 s gaps on the relative criterion ', ...
        'alone; each threshold individually disableable'];

end

function Detail = checkAvailabilityOutageSeparation()
%CHECKAVAILABILITYOUTAGESEPARATION Outages never split segments.

    Time_s = (0:9).' * 0.01;
    Stream = buildImuStream(Time_s, zeros(10, 1));
    Stream.Available = true(10, 1);
    Stream.Available(3:4) = false;

    Config = preprocessing.PreprocessingConfig();
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');

    expectEqual(Proc.TimestampSummary.SegmentCount, ...
        1, 'outage does not split segments');
    expectEqual(Proc.Flags.Unavailable, ...
        logical([0; 0; 1; 1; 0; 0; 0; 0; 0; 0]), 'unavailable flags');
    expectEqual(numel(Proc.Outages), 1, 'outage span count');
    expectEqual(Proc.Outages(1).FirstRowIdx, 3, 'outage first row');
    expectEqual(Proc.Outages(1).LastRowIdx, 4, 'outage last row');
    expectEqual(Proc.RowValid, true(10, 1), ...
        'RowValid unaffected by outages');
    expectEqual(Proc.MeasurementValid, true(10, 1), ...
        'MeasurementValid distinct from Available');

    Detail = [ ...
        'availability outage recorded as one outage span, separate ', ...
        'from segmentation; segment count stays 1'];

end

function Detail = checkStateFieldIndependence()
%CHECKSTATEFIELDINDEPENDENCE RowValid, MeasurementValid, Available distinct.

    Time_s = [0; 0.01; 0.01; 0.02; 0.03; 0.04; 0.05];
    Stream = buildImuStream(Time_s, [1; 2; 3; 4; NaN; 6; 7]);
    Stream.Available(7) = false;

    Config = preprocessing.PreprocessingConfig();
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');

    expectEqual(Proc.RowValid, ...
        logical([1; 1; 0; 1; 1; 1; 1]), 'RowValid column');
    expectEqual(Proc.MeasurementValid, ...
        logical([1; 1; 1; 1; 0; 1; 1]), 'MeasurementValid column');
    expectEqual(Proc.Available, ...
        logical([1; 1; 1; 1; 1; 1; 0]), 'Available column');

    assertErrorId( ...
        @() preprocessing.InspectSensorQuality(Config, Stream, 'IMU'), ...
        ['Preprocessing:InspectSensorQuality:', ...
         'MissingProcessingField']);
    assertErrorId( ...
        @() preprocessing.DetectSensorOutliers(Config, Stream, 'IMU'), ...
        ['Preprocessing:DetectSensorOutliers:', ...
         'MissingProcessingField']);

    Detail = [ ...
        'three state columns independent per row (duplicate, NaN, ', ...
        'unavailable cases); unprocessed streams rejected with typed ', ...
        'errors'];

end

function Detail = checkOutlierChecksRetainValues()
%CHECKOUTLIERCHECKSRETAINVALUES Flag-only checks on known synthetic data.

    Time_s = (0:9).' * 0.01;
    AccelX = [0; 0; 0; 50; 0; 0; 30; 0; 0; 0];
    Stream = buildImuStream(Time_s, AccelX);

    Config = preprocessing.PreprocessingConfig( ...
        'SuddenChangeEnabled', true);
    Config.Quality.Physical.Bounds = ...
        struct('Accelerometer_X_mps2', [-10, 10]);
    Config.Quality.SuddenChange.Thresholds = ...
        struct('Accelerometer_X_mps2', 5.0);
    preprocessing.ValidatePreprocessingConfig(Config);

    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');
    Proc = preprocessing.DetectSensorOutliers(Config, Proc, 'IMU');

    expectEqual( ...
        Proc.ChannelFlags.PhysicalOutlier.Accelerometer_X_mps2, ...
        logical([0; 0; 0; 1; 0; 0; 1; 0; 0; 0]), 'physical flags');
    expectEqual( ...
        Proc.ChannelFlags.StatisticalOutlier.Accelerometer_X_mps2, ...
        logical([0; 0; 0; 1; 0; 0; 1; 0; 0; 0]), 'statistical flags');
    expectEqual( ...
        Proc.ChannelFlags.SuddenChange.Accelerometer_X_mps2, ...
        logical([0; 0; 0; 1; 1; 0; 1; 1; 0; 0]), 'sudden-change flags');
    expectEqual( ...
        Proc.ChannelFlags.StartupTransient.Accelerometer_X_mps2, ...
        logical([0; 0; 0; 1; 1; 0; 0; 0; 0; 0]), 'transient flags');
    expectEqual(Proc.Accelerometer_X_mps2, AccelX, ...
        'measurements retained unchanged');

    Detail = [ ...
        'physical, statistical, sudden-change and transient flags on ', ...
        'expected rows; all original values retained byte-exact'];

end

function Detail = checkStatisticalPerSegmentNoCrossing()
%CHECKSTATISTICALSEGMENTNOCROSSING Windows never cross segments.

    Time_s = [(0:19).' * 0.01; 2.0 + (0:9).' * 0.01];
    AccelX = [zeros(20, 1); 10 * ones(10, 1)];
    Stream = buildImuStream(Time_s, AccelX);

    Config = preprocessing.PreprocessingConfig();
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');
    Proc = preprocessing.DetectSensorOutliers(Config, Proc, 'IMU');

    expectEqual(Proc.TimestampSummary.SegmentCount, 2, 'segment count');

    if any(Proc.ChannelFlags.StatisticalOutlier.Accelerometer_X_mps2)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            ['Statistical window crossed a segment boundary: the ', ...
             'constant-10 segment must not compare against the ', ...
             'constant-0 segment.']);

    end

    Detail = [ ...
        'constant-10 segment not flagged against constant-0 segment: ', ...
        'rolling statistics confined to segments'];

end

function Detail = checkSuddenChangeSkipsInvalidReference()
%CHECKSUDDENCHANGESKIPSINVALIDREFERENCE NaN is never a step reference.

    Time_s = (0:4).' * 0.01;
    AccelX = [0; NaN; 2; 2; 2];
    Stream = buildImuStream(Time_s, AccelX);

    Config = preprocessing.PreprocessingConfig( ...
        'SuddenChangeEnabled', true);
    Config.Quality.SuddenChange.Thresholds = ...
        struct('Accelerometer_X_mps2', 1.0);
    preprocessing.ValidatePreprocessingConfig(Config);

    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');
    Proc = preprocessing.DetectSensorOutliers(Config, Proc, 'IMU');

    expectEqual(Proc.MeasurementValid, ...
        logical([1; 0; 1; 1; 1]), 'measurement validity');
    expectEqual( ...
        Proc.ChannelFlags.NonFiniteMeasurement.Accelerometer_X_mps2, ...
        logical([0; 1; 0; 0; 0]), 'NaN flagged');
    expectEqual( ...
        Proc.ChannelFlags.SuddenChange.Accelerometer_X_mps2, ...
        logical([0; 0; 1; 0; 0]), ...
        'row 3 step measured against row 1 (last valid sample)');

    Detail = [ ...
        'invalid sample skipped as reference: row 3 flagged against ', ...
        'row 1, not against the NaN row'];

end

function Detail = checkStartupTransientFlaggedRetained()
%CHECKSTARTUPTRANSIENTFLAGGEDRETAINED Real IMU transient flagged, kept.

    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();
    RunDirectory = fullfile(Paths.RunsRoot, 'Run_001_20261107_110817');
    Data = preprocessing.LoadSensorData(RunDirectory, Config, 'Csv');

    LoadedZ = Data.Streams.IMU.Accelerometer_Z_mps2(1);

    Proc = preprocessing.ProcessSensorTimestamps( ...
        Config, Data.Streams.IMU, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');
    Proc = preprocessing.DetectSensorOutliers(Config, Proc, 'IMU');

    if ~isequal(Proc.Accelerometer_Z_mps2(1), LoadedZ)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Startup transient value must be retained unchanged.');

    end

    if ~Proc.Flags.StartupTransient(1)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Known IMU startup transient was not flagged.');

    end

    if ~Proc.Flags.StatisticalOutlier(1)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Startup transient should trip the statistical check.');

    end

    if ~Proc.RowValid(1) || ~Proc.MeasurementValid(1)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Startup transient row must remain estimator-visible.');

    end

    Detail = sprintf([ ...
        'startup transient Z=%.3f m/s2 retained unchanged and ', ...
        'flagged StartupTransient + StatisticalOutlier; row remains ', ...
        'valid'], ...
        LoadedZ);

end

function Detail = checkTraceabilityThroughProcessing()
%CHECKTRACEABILITYTHROUGHPROCESSING Row trace survives all stages.

    Time_s = [0; 0.01; 0.01; 0.02; NaN];
    AccelX = (1:5).';
    Stream = buildImuStream(Time_s, AccelX);

    Config = preprocessing.PreprocessingConfig();
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');
    Proc = preprocessing.InspectSensorQuality(Config, Proc, 'IMU');
    Proc = preprocessing.DetectSensorOutliers(Config, Proc, 'IMU');

    expectEqual(Proc.SourceRowIdx, (1:5).', 'row index preserved');
    expectEqual(Proc.SourceTime_s, Time_s, 'source time preserved');
    expectEqual(Proc.Accelerometer_X_mps2, AccelX, ...
        'excluded rows preserved in audit data');
    expectEqual(Proc.TimestampSummary.ValidRows, 3, ...
        'estimator-ready row count');

    Detail = [ ...
        'source row index, raw timestamps and excluded audit rows ', ...
        'preserved through all three processing stages'];

end

% =========================================================================
%% PHASE 4 HELPERS
% =========================================================================

function Stream = buildImuStream(Time_s, AccelX)
%BUILDIMUSTREAM Build a normalized synthetic IMU stream.

    RowCount = numel(Time_s);

    Raw = struct();
    Raw.Time_s = Time_s(:);
    Raw.Accelerometer_X_mps2 = AccelX(:);
    Raw.Accelerometer_Y_mps2 = zeros(RowCount, 1);
    Raw.Accelerometer_Z_mps2 = zeros(RowCount, 1);
    Raw.Gyroscope_X_radps = zeros(RowCount, 1);
    Raw.Gyroscope_Y_radps = zeros(RowCount, 1);
    Raw.Gyroscope_Z_radps = zeros(RowCount, 1);

    Stream = preprocessing.NormalizeSensorSchema(Raw, 'IMU', 'IdealCsv');
    Stream = preprocessing.NormalizeSensorUnits(Stream, 'IMU');

end

% =========================================================================
%% PHASE 4 CORRECTION CHECKS (duplicate vs backward interaction)
% =========================================================================

function Detail = checkDuplicateAlsoBackwardJump()
%CHECKDUPLICATEALSOBACKWARDJUMP Duplicate row must keep its backward flag.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 0.01; 0.02; 0.01; 0.03];
    AccelX = (1:5).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.Flags.DuplicateTimestampLater, ...
        logical([0; 0; 0; 1; 0]), 'duplicate flags');
    expectEqual(Proc.Flags.BackwardTimestamp, ...
        logical([0; 0; 0; 1; 0]), 'backward flags (row 4)');
    expectEqual(Proc.Flags.UnexpectedGap, ...
        logical([0; 0; 0; 0; 1]), 'gap flags (row 5)');
    expectEqual(Proc.RowValid, ...
        logical([1; 1; 1; 0; 1]), 'RowValid');
    expectEqual(Proc.SegmentID, ...
        [1; 1; 1; 0; 2], 'segment IDs');
    expectEqual(Proc.TimestampSummary.SegmentCount, 2, 'segment count');
    expectEqual(Proc.Segments(2).BreakReason, ...
        'BackwardTimestamp', 'break reason');
    expectEqual(Proc.Time_s, Time_s, 'rows preserved');
    expectEqual(Proc.Accelerometer_X_mps2, AccelX, 'values preserved');

    Detail = [ ...
        'row 4 flagged DUPLICATE + BACKWARD, excluded from ', ...
        'estimator-ready data, and its discontinuity still breaks the ', ...
        'segment before row 5'];

end

function Detail = checkBackwardToPreviouslySeenTime()
%CHECKBACKWARDTOPREVIOUSLYSEENTIME Backward to a non-adjacent old time.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 0.01; 0.02; 0.03; 0.01; 0.015];
    AccelX = (1:6).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.Flags.DuplicateTimestampLater, ...
        logical([0; 0; 0; 0; 1; 0]), 'duplicate flags');
    expectEqual(Proc.Flags.BackwardTimestamp, ...
        logical([0; 0; 0; 0; 1; 0]), 'backward flags');
    expectEqual(Proc.RowValid, ...
        logical([1; 1; 1; 1; 0; 1]), 'RowValid');
    expectEqual(Proc.SegmentID, ...
        [1; 1; 1; 1; 0; 2], 'segment IDs');
    expectEqual(Proc.Segments(2).BreakReason, ...
        'BackwardTimestamp', 'break reason');

    Detail = [ ...
        'backward jump to previously seen 0.01 s keeps both findings; ', ...
        'next eligible row (6) starts segment 2'];

end

function Detail = checkDuplicateNotBackward()
%CHECKDUPLICATENOTBACKWARD Plain duplicates never create a break.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 0.01; 0.01; 0.02; 0.02; 0.03];
    AccelX = (1:6).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.Flags.DuplicateTimestampLater, ...
        logical([0; 0; 1; 0; 1; 0]), 'duplicate flags');
    expectEqual(Proc.Flags.BackwardTimestamp, ...
        false(6, 1), 'no backward flags');
    expectEqual(Proc.Flags.UnexpectedGap, ...
        false(6, 1), 'no gap flags');
    expectEqual(Proc.RowValid, ...
        logical([1; 1; 0; 1; 0; 1]), 'RowValid');
    expectEqual(Proc.SegmentID, ...
        [1; 1; 0; 1; 0; 1], 'segment IDs');
    expectEqual(Proc.TimestampSummary.SegmentCount, ...
        1, 'single segment');
    expectEqual(Proc.Segments(1).ValidSampleCount, 4, ...
        'valid sample count');

    Detail = [ ...
        'adjacent duplicates excluded+flagged only; no discontinuity ', ...
        'invented and no segment break'];

end

function Detail = checkBackwardThenIncreasing()
%CHECKBACKWARDTHENINCREASING Eligible backward row opens its own segment.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 0.01; 0.02; 0.015; 0.025; 0.035];
    AccelX = (1:6).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.Flags.BackwardTimestamp, ...
        logical([0; 0; 0; 1; 0; 0]), 'backward flags');
    expectEqual(Proc.Flags.DuplicateTimestampLater, ...
        false(6, 1), 'no duplicates');
    expectEqual(Proc.RowValid, true(6, 1), ...
        'backward row remains estimator-ready');
    expectEqual(Proc.SegmentID, ...
        [1; 1; 1; 2; 2; 2], 'segment IDs');
    expectEqual(Proc.Segments(2).BreakReason, ...
        'BackwardTimestamp', 'break reason');

    Detail = [ ...
        'backward jump to a fresh time keeps the row valid and opens ', ...
        'segment 2; following increasing rows join segment 2'];

end

function Detail = checkSegmentIdsAndTraceability()
%CHECKSEGMENTIDSANDTRACEABILITY Mixed defects: IDs and row trace exact.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 0.01; 0.01; 0.02; 0.01; 0.05; 0.06];
    AccelX = (1:7).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.Flags.DuplicateTimestampLater, ...
        logical([0; 0; 1; 0; 1; 0; 0]), 'duplicate flags');
    expectEqual(Proc.Flags.BackwardTimestamp, ...
        logical([0; 0; 0; 0; 1; 0; 0]), 'backward flags');
    expectEqual(Proc.Flags.UnexpectedGap, ...
        logical([0; 0; 0; 0; 0; 1; 0]), 'gap flags');
    expectEqual(Proc.RowValid, ...
        logical([1; 1; 0; 1; 0; 1; 1]), 'RowValid');
    expectEqual(Proc.SegmentID, ...
        [1; 1; 0; 1; 0; 2; 2], 'segment IDs');
    expectEqual(Proc.TimestampSummary.SegmentCount, 2, 'segment count');
    expectEqual(Proc.Segments(2).BreakReason, ...
        'BackwardTimestamp', 'chronologically first defect wins');
    expectEqual(Proc.SourceRowIdx, (1:7).', 'row trace preserved');
    expectEqual(Proc.SourceTime_s, Time_s, 'source time preserved');
    expectEqual(Proc.Accelerometer_X_mps2, AccelX, 'audit rows preserved');

    Detail = [ ...
        'mixed stream (adjacent dup, dup+backward, gap): segment IDs ', ...
        'exact, both row-5 findings preserved, full row trace intact'];

end

function Detail = checkStatisticalDeviationFloor()
%CHECKSTATISTICALDEVIATIONFLOOR Zero-MAD tolerance is configurable.

    Time_s = (0:5).' * 0.01;
    AccelX = [10; 10; 10 + 1e-12; 10; 999; 10];

    ConfigDefault = preprocessing.PreprocessingConfig();
    expectEqual(ConfigDefault.Quality.Statistical.DeviationFloor, ...
        0.0, 'default DeviationFloor');

    Stream = buildImuStream(Time_s, AccelX);

    ProcStrict = preprocessing.ProcessSensorTimestamps( ...
        ConfigDefault, Stream, 'IMU');
    ProcStrict = preprocessing.InspectSensorQuality( ...
        ConfigDefault, ProcStrict, 'IMU');
    ProcStrict = preprocessing.DetectSensorOutliers( ...
        ConfigDefault, ProcStrict, 'IMU');

    expectEqual( ...
        ProcStrict.ChannelFlags.StatisticalOutlier.Accelerometer_X_mps2, ...
        logical([0; 0; 1; 0; 1; 0]), ...
        'floor 0.0: FP-level deviation also flagged');

    ConfigFloor = preprocessing.PreprocessingConfig( ...
        'StatisticalDeviationFloor', 1e-9);

    ProcFloor = preprocessing.ProcessSensorTimestamps( ...
        ConfigFloor, Stream, 'IMU');
    ProcFloor = preprocessing.InspectSensorQuality( ...
        ConfigFloor, ProcFloor, 'IMU');
    ProcFloor = preprocessing.DetectSensorOutliers( ...
        ConfigFloor, ProcFloor, 'IMU');

    expectEqual( ...
        ProcFloor.ChannelFlags.StatisticalOutlier.Accelerometer_X_mps2, ...
        logical([0; 0; 0; 0; 1; 0]), ...
        'floor 1e-9: FP-level deviation suppressed, spike kept');
    expectEqual(ProcFloor.Accelerometer_X_mps2, AccelX, ...
        'values retained unchanged');

    Detail = [ ...
        'DeviationFloor verified in a zero-MAD window: 0.0 flags the ', ...
        '1e-12 deviation, 1e-9 suppresses it while the 989 spike is ', ...
        'still flagged'];

end

% =========================================================================
%% PHASE 4 TARGETED CORRECTION CHECKS
% =========================================================================

function Detail = checkInitialNonFinitePendingBreak()
%CHECKINITIALNONFINITEPENDINGBREAK First eligible row keeps pending reason.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [NaN; 0.01; 0.02; 0.03];
    AccelX = (1:4).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.Flags.NonFiniteTimestamp, ...
        logical([1; 0; 0; 0]), 'nonfinite flags');
    expectEqual(Proc.RowValid, ...
        logical([0; 1; 1; 1]), 'RowValid');
    expectEqual(Proc.SegmentID, ...
        [0; 1; 1; 1], 'segment IDs');
    expectEqual(Proc.TimestampSummary.SegmentCount, 1, 'segment count');
    expectEqual(Proc.Segments(1).BreakReason, ...
        'NonFiniteTimestamp', ...
        'pending reason assigned to first eligible row');
    expectEqual(Proc.SourceRowIdx, (1:4).', 'row trace preserved');
    expectEqual(Proc.SourceTime_s, Time_s, 'source time preserved');

    Detail = [ ...
        'leading non-finite timestamp excluded+flagged; first eligible ', ...
        'row (2) gets BreakReason NonFiniteTimestamp, not Start; rows ', ...
        '2-4 form segment 1 with full traceability'];

end

function Detail = checkMeasuredRateAdjacentIntervals()
%CHECKMEASUREDRATEADJACENTINTERVALS Measured rate never bridges rows.
%
%   Fixture Time_s = [0; 1; 3; 1; NaN; 10; 11]:
%       row 4 is a duplicate of row 2 (t = 1 s) AND a backward jump
%       (3 -> 1); row 5 is non-finite.
%   Corrected calculation (original adjacent finite pairs, positive
%   only): (0,1)=1, (1,3)=2, (3,1)=-1 skipped, pairs around the NaN
%   skipped, (10,11)=1  ->  positive intervals [1 2 1], count 3,
%   median 1 -> measured rate 1.0 Hz.
%   The old implementation diffed the RowValid rows [0 1 3 10 11] ->
%   [1 2 7 1], median 1.5 -> 0.667 Hz with 4 intervals. The fixture
%   therefore distinguishes both the rate and the interval count.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 1; 3; 1; NaN; 10; 11];
    AccelX = (1:7).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.NominalRateSource, 'Measured', 'rate source');
    assertApprox(Proc.NominalRate_Hz, 1.0, 1.0e-12, 'measured rate');
    assertApprox(Proc.NominalPeriod_s, 1.0, 1.0e-12, 'measured period');

    if ~contains(Proc.NominalRateEvidence, ...
            'median of 3 positive original adjacent finite intervals')

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Interval count must be 3 (adjacent finite positives); got "%s".', ...
            Proc.NominalRateEvidence);

    end

    Detail = [ ...
        'measured rate 1.0 Hz from positive ORIGINAL ADJACENT finite ', ...
        'intervals [1 2 1] (count 3, median 1); old bridged ', ...
        'calculation would give 0.667 Hz with count 4'];

end

function Detail = checkStatisticalDeviationFloorRejections()
%CHECKSTATISTICALDEVIATIONFLOORREJECTIONS Invalid floors are rejected.

    InvalidValues = { ...
        -1, ...
        NaN, ...
        Inf, ...
        1 + 1i, ...
        [1.0e-9, 1.0e-9]};

    for Index = 1:numel(InvalidValues)

        assertErrorId( ...
            @() preprocessing.PreprocessingConfig( ...
                'StatisticalDeviationFloor', InvalidValues{Index}), ...
            ['Preprocessing:ValidatePreprocessingConfig:', ...
             'InvalidStatistical']);

    end

    Detail = [ ...
        'negative, NaN, Inf, complex and vector DeviationFloor values ', ...
        'all rejected with Preprocessing:ValidatePreprocessingConfig:', ...
        'InvalidStatistical'];

end

function Detail = checkMultiplePendingDiscontinuities()
%CHECKMULTIPLEPENDINGDISCONTINUITIES First pending reason wins, none lost.

    Config = preprocessing.PreprocessingConfig();
    Time_s = [0; 0.01; 0.02; 0.01; NaN; 0.03; 0.04];
    AccelX = (1:7).';

    Stream = buildImuStream(Time_s, AccelX);
    Proc = preprocessing.ProcessSensorTimestamps(Config, Stream, 'IMU');

    expectEqual(Proc.Flags.DuplicateTimestampLater, ...
        logical([0; 0; 0; 1; 0; 0; 0]), 'duplicate flags');
    expectEqual(Proc.Flags.BackwardTimestamp, ...
        logical([0; 0; 0; 1; 0; 0; 0]), 'backward flags');
    expectEqual(Proc.Flags.NonFiniteTimestamp, ...
        logical([0; 0; 0; 0; 1; 0; 0]), 'nonfinite flags');
    expectEqual(Proc.RowValid, ...
        logical([1; 1; 1; 0; 0; 1; 1]), 'RowValid');
    expectEqual(Proc.SegmentID, ...
        [1; 1; 1; 0; 0; 2; 2], 'segment IDs');
    expectEqual(Proc.TimestampSummary.SegmentCount, 2, 'segment count');
    expectEqual(Proc.TimestampSummary.DuplicateCount, 1, ...
        'duplicate count');
    expectEqual(Proc.TimestampSummary.BackwardCount, 1, ...
        'backward count');
    expectEqual(Proc.TimestampSummary.NonFiniteTimeCount, 1, ...
        'nonfinite count');
    expectEqual(Proc.Segments(1).BreakReason, 'Start', ...
        'first segment reason');
    expectEqual(Proc.Segments(2).BreakReason, 'BackwardTimestamp', ...
        'chronological-first pending reason wins');
    expectEqual(Proc.SourceRowIdx, (1:7).', 'row trace preserved');
    expectEqual(Proc.SourceTime_s, Time_s, 'source time preserved');
    expectEqual(Proc.Accelerometer_X_mps2, AccelX, 'audit rows preserved');

    Detail = [ ...
        'two excluded rows (dup+backward at row 4, non-finite at row ', ...
        '5) before the next eligible row: both findings retained per ', ...
        'row, BreakReason deterministic BackwardTimestamp (earlier ', ...
        'event, later NonFiniteTimestamp does not overwrite it)'];

end

% =========================================================================
%% PHASE 5 CHECKS: ALIGNMENT
% =========================================================================

function Detail = checkAlignmentDisabled()
%CHECKALIGNMENTDISABLED Disabled alignment generates no samples.

    Config = preprocessing.PreprocessingConfig();
    Streams = struct( ...
        'IMU', processChain(Config, ...
            buildImuStream((0:3).' * 0.1, (1:4).'), 'IMU'));

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);

    expectEqual(Aligned.Enabled, false, 'Enabled');
    expectEqual(Aligned.Status, 'Disabled', 'status');
    expectEqual(fieldnames(Aligned.Streams), cell(0, 1), 'no streams');
    expectEqual(numel(Aligned.Time_s), 0, 'no reference samples');

    Detail = [ ...
        'alignment disabled by default: no aligned samples, no ', ...
        'fabricated representation, explicit Disabled status'];

end

function Detail = checkAlignmentCausalZohAndReference()
%CHECKALIGNMENTCAUSALZOHANDREFERENCE ZOH values, ages, IMU reference.

    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true);
    ImuStream = processChain(Config, ...
        buildImuStream((0:9).' * 0.1, (1:10).'), 'IMU');
    AirStream = processChain(Config, ...
        buildAirDataStream([0; 0.25; 0.55; 0.85; 0.95], ...
            [10; 20; 30; 40; 50]), ...
        'AirData');
    Streams = struct('IMU', ImuStream, 'AirData', AirStream);

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);

    expectEqual(Aligned.Status, 'Generated', 'status');
    expectEqual(Aligned.ReferenceStream, 'IMU', 'reference stream');
    assertApprox(Aligned.Time_s, (0:9).' * 0.1, 1e-12, 'reference times');

    Air = Aligned.Streams.AirData;
    assertApprox(Air.TrueAirspeed_mps, ...
        [10; 10; 10; 20; 20; 20; 30; 30; 30; 40], 1e-12, 'held values');
    expectEqual(Air.SourceRowIdx, ...
        [1; 1; 1; 2; 2; 2; 3; 3; 3; 4], 'source rows');
    assertApprox(Air.SampleAge_s, ...
        [0; 0.1; 0.2; 0.05; 0.15; 0.25; 0.05; 0.15; 0.25; 0.05], ...
        1e-12, 'sample ages');
    expectEqual(Air.AlignedValid, true(10, 1), 'all valid');
    expectEqual(Aligned.Summary.AirData.ValidCount, 10, 'valid count');

    Detail = [ ...
        'IMU RowValid timeline used as reference; causal ZOH holds ', ...
        'values [10 20 30 40] with exact source rows and ages; all ', ...
        'aligned samples valid within the age limit'];

end

function Detail = checkAlignmentNoFutureNoExtrapolation()
%CHECKALIGNMENTNOFUTURENOEXTRAPOLATION Never future, never beyond end.

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, 'ReferenceStream', 'IMU');
    ImuStream = processChain(Config, ...
        buildImuStream([0.2; 0.5; 1.3], (1:3).'), 'IMU');
    AirStream = processChain(Config, ...
        buildAirDataStream([0; 0.25; 0.55; 0.85], [10; 20; 30; 40]), ...
        'AirData');
    Streams = struct('IMU', ImuStream, 'AirData', AirStream);

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Air = Aligned.Streams.AirData;

    expectEqual(Air.SourceRowIdx(1), 1, ...
        'ref 0.2 holds row 1, never future row 2 (0.25)');
    expectEqual(Air.SourceRowIdx(2), 2, ...
        'ref 0.5 holds row 2, never future row 3 (0.55)');
    expectEqual(Air.SourceRowIdx(3), 4, 'ref 1.3 holds last row 4');
    expectEqual(Air.WithinCoverage(3), false, 'beyond source coverage');
    expectEqual(Air.AlignedValid(3), false, 'beyond-coverage invalid');
    expectEqual(Air.AlignedValid(1:2), true(2, 1), 'in-coverage valid');

    Detail = [ ...
        'future source rows never used; reference time 1.3 s beyond ', ...
        'the last source sample (0.85 s) marked invalid, not ', ...
        'extrapolated'];

end

function Detail = checkAlignmentMaxSampleAge()
%CHECKALIGNMENTMAXSAMPLEAGE Configured age limit enforced.

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('AirData', 0.15));
    ImuStream = processChain(Config, ...
        buildImuStream([0.1; 0.2], [1; 2]), 'IMU');
    AirStream = processChain(Config, ...
        buildAirDataStream([0; 0.25], [10; 20]), 'AirData');
    Streams = struct('IMU', ImuStream, 'AirData', AirStream);

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Air = Aligned.Streams.AirData;

    expectEqual(Aligned.MaxSampleAge_s.AirData.Seconds, 0.15, ...
        'configured age');
    expectEqual(Aligned.MaxSampleAge_s.AirData.Source, ...
        'Configured', 'age source');
    expectEqual(Air.AgeOk, logical([1; 0]), 'age checks');
    expectEqual(Air.AlignedValid, logical([1; 0]), 'validity');
    assertApprox(Air.SampleAge_s(2), 0.2, 1e-12, 'stale age recorded');

    Detail = [ ...
        'configured MaxSampleAge 0.15 s enforced: age 0.2 s sample ', ...
        'marked stale and invalid but fully traceable'];

end

function Detail = checkAlignmentOutageValidityPropagation()
%CHECKALIGNMENTOUTAGEVALIDITYPROPAGATION Availability/validity forwarded.

    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true);
    ImuStream = processChain(Config, ...
        buildImuStream((0:9).' * 0.1, (1:10).'), 'IMU');
    AirRaw = buildAirDataStream( ...
        [0; 0.25; 0.55; 0.85; 0.95], [10; NaN; 30; 40; 50]);
    AirRaw.Available(3) = false;
    AirStream = processChain(Config, AirRaw, 'AirData');
    Streams = struct('IMU', ImuStream, 'AirData', AirStream);

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Air = Aligned.Streams.AirData;

    expectEqual(Air.SourceMeasurementValid, ...
        logical([1; 1; 1; 0; 0; 0; 1; 1; 1; 1]), ...
        'measurement validity propagated');
    expectEqual(Air.SourceAvailable, ...
        logical([1; 1; 1; 1; 1; 1; 0; 0; 0; 1]), ...
        'availability propagated');
    expectEqual(Air.AlignedValid, ...
        logical([1; 1; 1; 0; 0; 0; 0; 0; 0; 1]), ...
        'invalid/unavailable aligned samples marked');

    Detail = [ ...
        'outage and invalid source rows propagate explicitly: ', ...
        'AlignedValid false exactly where source is unavailable or ', ...
        'measurement-invalid; values never fabricated'];

end

function Detail = checkAlignmentSegmentBoundaries()
%CHECKALIGNMENTSEGMENTBOUNDARIES No holds across segment boundaries.

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('AirData', 0.5));
    ImuStream = processChain(Config, ...
        buildImuStream([0; 0.1; 0.2; 2.0; 2.1; 2.2], (1:6).'), 'IMU');
    AirStream = processChain(Config, ...
        buildAirDataStream([0; 0.2; 2.15; 2.3], [10; 20; 30; 40]), ...
        'AirData');
    Streams = struct('IMU', ImuStream, 'AirData', AirStream);

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Air = Aligned.Streams.AirData;

    expectEqual(ImuStream.SegmentID, [1; 1; 1; 2; 2; 2], ...
        'IMU segments (gap break)');
    expectEqual(Air.SourceRowIdx, [1; 1; 2; 0; 0; 3], ...
        'no cross-segment holds');
    expectEqual(Air.AlignedValid, ...
        logical([1; 1; 1; 0; 0; 1]), 'validity by segment');

    Detail = [ ...
        'segment 2 reference samples 2.0/2.1 s hold NO source (row 2 ', ...
        'of segment 1 is never bridged across the gap); only 2.2 s ', ...
        'maps to segment-2 source row 3'];

end

function Detail = checkAlignmentMissingSensorSkipped()
%CHECKALIGNMENTMISSINGSENSORSKIPPED Missing streams are not fabricated.

    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true);
    ImuStream = processChain(Config, ...
        buildImuStream((0:3).' * 0.1, (1:4).'), 'IMU');
    Streams = struct('IMU', ImuStream);

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);

    if isfield(Aligned.Streams, 'AirData') || ...
            isfield(Aligned.Streams, 'GNSS')

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Missing streams must not appear in Aligned.Streams.');

    end

    expectEqual(any(strcmp(Aligned.SkippedStreams, 'AirData')), ...
        true, 'skipped stream recorded');

    Detail = [ ...
        'missing sensors skipped and recorded; no aligned stream is ', ...
        'fabricated for an absent sensor'];

end

function Detail = checkAlignmentDuplicateExclusion()
%CHECKALIGNMENTDUPLICATEEXCLUSION Duplicate rows never used as sources.

    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true);
    ImuStream = processChain(Config, ...
        buildImuStream((0:3).' * 0.1, (1:4).'), 'IMU');
    AirStream = processChain(Config, ...
        buildAirDataStream([0; 0.3; 0.3; 0.6], [10; 20; 999; 40]), ...
        'AirData');
    Streams = struct('IMU', ImuStream, 'AirData', AirStream);

    Aligned = preprocessing.BuildAlignedSensorData(Config, Streams);
    Air = Aligned.Streams.AirData;

    expectEqual(Air.SourceRowIdx(4), 2, ...
        'ref 0.3 uses first occurrence row 2');
    assertApprox(Air.TrueAirspeed_mps(4), 20, 1e-12, ...
        'duplicate row 3 value never used');

    Detail = [ ...
        'later duplicate row (999) excluded by Phase 4 is never a ', ...
        'ZOH source; first occurrence retained'];

end

function Detail = checkAlignmentNativeRateImmutable()
%CHECKALIGNMENTNATIVERATEIMMUTABLE Native-rate streams unchanged.

    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true);
    ImuStream = processChain(Config, ...
        buildImuStream((0:3).' * 0.1, (1:4).'), 'IMU');
    AirStream = processChain(Config, ...
        buildAirDataStream([0; 0.3], [10; 20]), 'AirData');
    Streams = struct('IMU', ImuStream, 'AirData', AirStream);
    Snapshot = Streams;

    preprocessing.BuildAlignedSensorData(Config, Streams);

    if ~isequaln(Streams, Snapshot)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Native-rate processed streams were modified by alignment.');

    end

    Detail = 'native-rate streams byte-identical before and after alignment';

end

% =========================================================================
%% PHASE 5 CHECKS: REPORT
% =========================================================================

function Detail = checkReportProvenanceCategories()
%CHECKREPORTPROVENANCECATEGORIES Recorded/defaults/measured kept apart.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('ReportFixture', false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo(tempname(fixtureDir('ReportFixture')), ...
        'Run_905_20260101_000000__PP_20260101_000000_01');

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    expectEqual(Report.RunRecorded.Status, 'NotRecorded', ...
        'no RunMetadata in fixture');
    expectEqual(Report.RunRecorded.SensorSampleRates_Hz.IMU, ...
        'NotRecorded', 'recorded rate absent');
    expectEqual(contains(lower( ...
        Report.CurrentCodeDefaults.Description), 'not evidence'), ...
        true, 'code defaults labeled');
    expectEqual(Report.MeasuredStatistics.IMU.NominalRateSource, ...
        'Measured', 'measured provenance');
    expectEqual(Report.MeasuredStatistics.IMU.SampleCount, 5, ...
        'measured sample count');
    expectEqual(Report.MeasuredStatistics.IMU.TimestampSummary, ...
        ProcessedStreams.IMU.TimestampSummary, 'quality counts');

    Detail = [ ...
        'report keeps RunRecorded (''NotRecorded''), ', ...
        'CurrentCodeDefaults (labeled) and MeasuredStatistics ', ...
        '(Measured provenance) strictly separate'];

end

function Detail = checkReportQualityAlignmentUnits()
%CHECKREPORTQUALITYALIGNMENTUNITS Quality, alignment, units, conventions.

    [~, Data, ~] = ...
        buildSyntheticProcessed('ReportFixture2', false);
    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true);
    ProcessedStreams = struct( ...
        'IMU', processChain(Config, Data.Streams.IMU, 'IMU'), ...
        'GNSS', processChain(Config, Data.Streams.GNSS, 'GNSS'), ...
        'AirData', processChain(Config, Data.Streams.AirData, 'AirData'), ...
        'Magnetometer', processChain( ...
            Config, Data.Streams.Magnetometer, 'Magnetometer'));
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_02');

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    expectEqual(Report.MeasuredStatistics.IMU.OutlierSummary, ...
        ProcessedStreams.IMU.OutlierSummary, 'outlier counts');
    expectEqual(Report.Alignment.Enabled, true, 'alignment state');
    expectEqual(Report.Alignment.ReferenceStream, 'IMU', ...
        'alignment reference');
    expectEqual(isfield(Report.Alignment.MaxSampleAge_s, 'AirData'), ...
        true, 'age settings recorded');
    expectEqual( ...
        Report.Units.Magnetometer.MagneticFieldBody_X_T.Factor, ...
        1.0e-6, 'unit conversion factor');
    expectEqual(isfield(Report, 'CoordinateConventions'), true, ...
        'coordinate conventions');
    expectEqual(isfield(Report.Outputs, 'MatFile'), true, 'output paths');
    expectEqual(Report.Status, 'SUCCESS', 'status');

    Detail = [ ...
        'quality counts, alignment settings, unit factors, ', ...
        'coordinate conventions, outputs and status all present'];

end

function Detail = checkReportMissingSensorRepresentation()
%CHECKREPORTMISSINGSENSORREPRESENTATION Missing sensors explicitly marked.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('ReportFixture3', true);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_03');
    RunInfo.Status = 'PARTIAL';

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    expectEqual(Report.MissingSensors, {'GNSS'}, 'missing sensors');
    expectEqual(Report.MeasuredStatistics.GNSS.Status, 'Missing', ...
        'GNSS measured status');
    expectEqual(Report.MeasuredStatistics.GNSS.AllFields, 'NotMeasured', ...
        'no invented statistics');

    Detail = [ ...
        'missing GNSS represented as Missing/NotMeasured with no ', ...
        'invented values; partial status recorded'];

end

% =========================================================================
%% PHASE 5 CHECKS: EXPORTS
% =========================================================================

function Detail = checkMatHierarchyAndPreservation()
%CHECKMATHIERARCHYANDPRESERVATION MAT sections and data preservation.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('MatFixture', false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_04');
    OutputDirectory = tempname(fixtureDir('MatFixture'));
    RunInfo.OutputDirectory = OutputDirectory;

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory);

    expectEqual(Artifacts.Validated, true, 'read-back validated');
    Loaded = load(Artifacts.MatFile);
    Pd = Loaded.PreprocessedData;

    RequiredSections = { ...
        'RunInfo', 'Configuration', 'OriginalData', 'NativeRate', ...
        'AlignedData', 'QualitySummary', 'ProcessingInfo'};
    expectEqual(all(ismember( ...
        RequiredSections, fieldnames(Pd))), true, 'MAT hierarchy');

    expectEqual(Pd.OriginalData.IMU.SourceRowIdx, (1:5).', ...
        'audit rows preserved');
    expectEqual(Pd.NativeRate.IMU, ProcessedStreams.IMU, ...
        'native-rate stream preserved exactly');
    expectEqual(Pd.ProcessingInfo.GroundTruthExcluded, true, ...
        'ground truth excluded');
    expectEqual(isfield(Pd.NativeRate.IMU, 'VelocityBody_mps'), ...
        false, 'no ground-truth fields');

    Detail = [ ...
        'MAT v7 hierarchy complete; original audit rows, native-rate ', ...
        'values and quality flags preserved exactly; ground truth ', ...
        'structurally excluded'];

end

function Detail = checkMatAlignmentAndReadBack()
%CHECKMATALIGNMENTANREADBACK Aligned data preserved and validated.

    [~, Data, ~] = ...
        buildSyntheticProcessed('MatFixture2', false);
    Config = preprocessing.PreprocessingConfig('AlignmentEnabled', true);
    ProcessedStreams = struct( ...
        'IMU', processChain(Config, Data.Streams.IMU, 'IMU'), ...
        'GNSS', processChain(Config, Data.Streams.GNSS, 'GNSS'), ...
        'AirData', processChain(Config, Data.Streams.AirData, 'AirData'), ...
        'Magnetometer', processChain( ...
            Config, Data.Streams.Magnetometer, 'Magnetometer'));
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_05');
    OutputDirectory = tempname(fixtureDir('MatFixture2'));
    RunInfo.OutputDirectory = OutputDirectory;

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory);

    Loaded = load(Artifacts.MatFile);
    expectEqual(Loaded.PreprocessedData.AlignedData.Status, ...
        'Generated', 'aligned data in MAT');
    expectEqual( ...
        Loaded.PreprocessedData.AlignedData.Streams.AirData.AlignedValid, ...
        Aligned.Streams.AirData.AlignedValid, 'aligned flags preserved');
    expectEqual(Artifacts.Validated, true, 'read-back validated');

    Detail = [ ...
        'aligned representation preserved in MAT and verified on ', ...
        'read-back (status Generated, flags identical)'];

end

function Detail = checkJsonValidTypesAndReadBack()
%CHECKJSONVALIDTYPESANREADBACK Valid JSON, booleans, nested structures.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('JsonFixture', false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_06');
    RunInfo.ApprovalUsed = true;
    OutputDirectory = tempname(fixtureDir('JsonFixture'));
    RunInfo.OutputDirectory = OutputDirectory;

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory);

    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    expectEqual(Decoded.RunInfo.PreprocessID, RunInfo.PreprocessID, ...
        'embedded PreprocessID');
    expectEqual(islogical(Decoded.RunInfo.ApprovalUsed), true, ...
        'logical stays JSON boolean');
    expectEqual(isstruct(Decoded.MeasuredStatistics.IMU), true, ...
        'nested structure');
    expectEqual(isfield(Decoded, 'CoordinateConventions'), true, ...
        'full report content');

    Detail = [ ...
        'JSON decodes cleanly with matching PreprocessID, JSON ', ...
        'booleans as logicals and intact nested structures'];

end

function Detail = checkJsonNanInfAndMatConsistency()
%CHECKJSONNANINFANDMATCONSISTENCY Explicit markers; MAT/JSON agree.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('JsonFixture2', false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_07');
    OutputDirectory = tempname(fixtureDir('JsonFixture2'));
    RunInfo.OutputDirectory = OutputDirectory;

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    Report.NumericMarkers = [1.5, NaN, Inf, -Inf];

    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory);

    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    Markers = Decoded.NumericMarkers;
    expectEqual(numel(Markers), 4, 'marker array length');
    expectEqual(Markers{2}, 'NaN', 'NaN marker');
    expectEqual(Markers{3}, 'Inf', 'Inf marker');
    expectEqual(Markers{4}, '-Inf', '-Inf marker');

    Loaded = load(Artifacts.MatFile);
    expectEqual( ...
        Loaded.PreprocessedData.NativeRate.IMU.SampleCount, ...
        Decoded.MeasuredStatistics.IMU.SampleCount, ...
        'MAT and JSON counts consistent');

    Detail = [ ...
        'NaN/Inf exported as explicit "NaN"/"Inf"/"-Inf" markers in ', ...
        'valid JSON; MAT keeps native numerics; counts consistent'];

end

function Detail = checkCsvSchemaTraceabilityAndNoFabrication()
%CHECKCSVSCHEMATRACEABILITYANDNOFABRICATION Review CSV schema and rows.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('CsvFixture', false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);
    RunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_08');
    OutputDirectory = tempname(fixtureDir('CsvFixture'));
    RunInfo.OutputDirectory = OutputDirectory;

    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, OutputDirectory);

    TableData = readtable(Artifacts.ReviewFiles.IMU);
    ExpectedColumns = [ ...
        {'SourceRowIdx', 'Time_s', 'SegmentID', 'RowValid', ...
         'MeasurementValid', 'Available'}, ...
        strcat('Flags_', { ...
            'NonFiniteTimestamp', 'BackwardTimestamp', ...
            'DuplicateTimestampLater', 'UnexpectedGap', 'Unavailable', ...
            'NonFiniteMeasurement', 'PhysicalOutlier', ...
            'StatisticalOutlier', 'SuddenChange', 'StartupTransient'}), ...
        {'Accelerometer_X_mps2', 'Accelerometer_Y_mps2', ...
         'Accelerometer_Z_mps2', 'Gyroscope_X_radps', ...
         'Gyroscope_Y_radps', 'Gyroscope_Z_radps'}];
    expectEqual(TableData.Properties.VariableNames, ...
        ExpectedColumns, 'CSV columns');
    expectEqual(TableData.SourceRowIdx, (1:5).', 'row trace');
    expectEqual(TableData.Time_s, ProcessedStreams.IMU.Time_s, ...
        'original timestamps');
    expectEqual(TableData.Flags_Unavailable, ...
        double(ProcessedStreams.IMU.Flags.Unavailable), 'flag columns');
    assertApprox(TableData.Accelerometer_Z_mps2, ...
        ProcessedStreams.IMU.Accelerometer_Z_mps2, 0, ...
        'measurements unmodified');

    [Config2, Data2, Processed2] = ...
        buildSyntheticProcessed('CsvFixtureMissing', true);
    Aligned2 = preprocessing.BuildAlignedSensorData(Config2, Processed2);
    RunInfo2 = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_09');
    OutputDirectory2 = tempname(fixtureDir('CsvFixtureMissing'));
    RunInfo2.OutputDirectory = OutputDirectory2;
    Report2 = preprocessing.BuildPreprocessingReport( ...
        Config2, Data2, Processed2, Aligned2, RunInfo2);
    Artifacts2 = preprocessing.ExportPreprocessedData( ...
        Config2, Data2, Processed2, Aligned2, Report2, OutputDirectory2);

    if isfield(Artifacts2.ReviewFiles, 'GNSS')

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'No review CSV may be fabricated for a missing sensor.');

    end

    Detail = [ ...
        'CSV columns canonical with 0/1 flags, row trace and raw ', ...
        'timestamps exact, values unmodified; no GNSS.csv fabricated ', ...
        'for the missing sensor'];

end

% =========================================================================
%% PHASE 5 CHECKS: INTEGRATION
% =========================================================================

function Detail = checkPreprocessRunSuccessRealRun()
%CHECKPREPROCESSRUNSUCCESSREALRUN End-to-end SUCCESS on a real run.

    Config = preprocessing.PreprocessingConfig();
    Result = preprocessing.PreprocessRun( ...
        'Run_001_20261107_110817', Config);

    expectEqual(Result.Status, 'SUCCESS', 'status');
    expectEqual(Result.Eligibility, 'Eligible', 'eligibility');
    expectEqual(isempty(regexp(Result.PreprocessID, ...
        '^Run_001_20261107_110817__PP_[0-9]{8}_[0-9]{6}_[0-9]{2}$', ...
        'once')), false, 'PreprocessID grammar');
    expectEqual(isfile(Result.MatFile), true, 'MAT exists');
    expectEqual(isfile(Result.JsonFile), true, 'JSON exists');
    expectEqual(numel(fieldnames(Result.ReviewFiles)), 4, ...
        'four review CSVs');
    expectEqual(Result.Report.RunRecorded.Scenario.Name, ...
        'ControlledClimb', 'run-recorded scenario');
    expectEqual(Result.Report.Status, 'SUCCESS', 'report status');

    Detail = sprintf([ ...
        'end-to-end SUCCESS on Run_001_20261107_110817: %s with MAT, ', ...
        'JSON and 4 review CSVs validated'], ...
        Result.PreprocessID);

end

function Detail = checkPreprocessRunPartialAndStrict()
%CHECKPREPROCESSRUNPARTIALANDSTRICT Missing-sensor policy enforcement.

    RunID = 'Run_900_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('IntegrationFixture', true, RunID);
    FixtureRoot = fullfile(fixtureDir('IntegrationFixture'), RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, ...
        struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));

    expectEqual(Result.Status, 'PARTIAL', 'continue policy outcome');
    expectEqual(Result.StreamStatuses.GNSS, 'Missing', ...
        'missing sensor recorded');
    expectEqual(Result.Category, 'SyntheticOverride', 'provenance');

    StrictConfig = preprocessing.PreprocessingConfig( ...
        'MissingSensorPolicy', 'Strict');
    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            RunID, StrictConfig, ...
            struct('RunDirectory', FixtureRoot, ...
            'ApproveUnregistered', true)), ...
        'Preprocessing:PreprocessRun:MissingRequiredSensor');

    Detail = [ ...
        'matching-name approved synthetic override: Continue policy ', ...
        'PARTIAL with GNSS recorded Missing; Strict policy: typed ', ...
        'MissingRequiredSensor error'];

end

function Detail = checkPreprocessRunUnregisteredApproval()
%CHECKPREPROCESSRUNUNREGISTEREDAPPROVAL Explicit approval gate works.

    Config = preprocessing.PreprocessingConfig();

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            'Run_001_20260906_160342', Config), ...
        'Preprocessing:PreprocessRun:ApprovalRequired');

    Result = preprocessing.PreprocessRun( ...
        'Run_001_20260906_160342', Config, ...
        struct('ApproveUnregistered', true));

    expectEqual(Result.ApprovalUsed, true, 'approval recorded');
    expectEqual(Result.Status, 'SUCCESS', 'approved run processed');
    expectEqual(isfile(Result.MatFile), true, 'artifacts exported');

    Detail = [ ...
        'unregistered run blocked without approval (typed ', ...
        'ApprovalRequired) and processed with explicit approval, ', ...
        'approval recorded in the result'];

end

function Detail = checkPreprocessRunNoOverwriteUniqueIds()
%CHECKPREPROCESSRUNNOOVERWRITEUNIQUEIDS Unique IDs, no overwrite.

    RunID = 'Run_901_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('IntegrationFixture2', false, RunID);
    FixtureRoot = fullfile(fixtureDir('IntegrationFixture2'), RunID);

    First = preprocessing.PreprocessRun( ...
        RunID, Config, ...
        struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));
    FirstBytes = readBytes(First.MatFile);

    Second = preprocessing.PreprocessRun( ...
        RunID, Config, ...
        struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));

    if strcmp(First.PreprocessID, Second.PreprocessID)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'PreprocessIDs must be unique per call.');

    end

    expectEqual(isfile(Second.MatFile), true, 'second result exists');
    expectEqual(FirstBytes, readBytes(First.MatFile), ...
        'first result untouched by second run');

    Detail = [ ...
        'two runs produced distinct PreprocessIDs; first result ', ...
        'byte-identical after the second run (no overwrite)'];

end

function Detail = checkPreprocessRunInvalidRun()
%CHECKPREPROCESSRUNINVALIDRUN Unknown run selection rejected.

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            'Run_999_20260101_000000', preprocessing.PreprocessingConfig()), ...
        'Preprocessing:InspectRun:RunNotFound');

    Detail = 'invalid run selection rejected with typed RunNotFound';

end

function Detail = checkExportFailureGuards()
%CHECKEXPORTFAILUREGUARDS No-overwrite and failure guards are typed.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('ExportFailureFixture', false);
    Aligned = preprocessing.BuildAlignedSensorData(Config, ProcessedStreams);

    NonEmptyDir = fullfile(fixtureDir('ExportFailureFixture'), ...
        'NonEmptyTarget');
    mkdir(NonEmptyDir);
    fid = fopen(fullfile(NonEmptyDir, 'existing.txt'), 'w');
    fprintf(fid, 'pre-existing result\n');
    fclose(fid);
    RunInfo = buildRunInfo(NonEmptyDir, ...
        'Run_905_20260101_000000__PP_20260101_000000_10');
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, NonEmptyDir), ...
        'Preprocessing:ExportPreprocessedData:OutputDirectoryExists');

    FilePath = fullfile(fixtureDir('ExportFailureFixture'), ...
        'TargetIsFile');
    fid = fopen(FilePath, 'w');
    fclose(fid);
    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, FilePath), ...
        'Preprocessing:ExportPreprocessedData:InvalidOutputDirectory');

    BrokenStreams = ProcessedStreams;
    BrokenStreams.IMU.Time_s = BrokenStreams.IMU.Time_s(1:2);
    BrokenRunInfo = buildRunInfo('', ...
        'Run_905_20260101_000000__PP_20260101_000000_11');
    BrokenOutput = tempname(fixtureDir('ExportFailureFixture'));
    BrokenRunInfo.OutputDirectory = BrokenOutput;
    BrokenReport = preprocessing.BuildPreprocessingReport( ...
        Config, Data, BrokenStreams, Aligned, BrokenRunInfo);
    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, BrokenStreams, Aligned, BrokenReport, ...
            BrokenOutput), ...
        'Preprocessing:ExportPreprocessedData:CsvWriteFailure');

    HandleReport = Report;
    HandleReport.BadValue = onCleanup(@() disp(''));
    HandleOutput = tempname(fixtureDir('ExportFailureFixture'));
    assertErrorIdIn( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, HandleReport, ...
            HandleOutput), ...
        {'Preprocessing:ExportPreprocessedData:JsonWriteFailure', ...
         'Preprocessing:ExportPreprocessedData:MatWriteFailure'});

    Detail = [ ...
        'non-empty target rejected (OutputDirectoryExists), file ', ...
        'target rejected (InvalidOutputDirectory), CSV stage failure ', ...
        'typed (CsvWriteFailure), serialization failure typed'];

end

function Detail = checkGetPreprocessingReportValidAndReadOnly()
%CHECKGETPREPROCESSINGREPORTVALIDANDREADONLY Retrieve and verify.

    Config = preprocessing.PreprocessingConfig();
    Result = preprocessing.PreprocessRun( ...
        'Run_001_20261107_110817', Config);
    ReportBytes = readBytes(Result.JsonFile);

    Retrieved = preprocessing.GetPreprocessingReport( ...
        Result.PreprocessID);

    expectEqual(Retrieved.PreprocessID, Result.PreprocessID, ...
        'resolved ID');
    expectEqual(Retrieved.RunID, 'Run_001_20261107_110817', 'run ID');
    expectEqual(Retrieved.Report.RunInfo.PreprocessID, ...
        Result.PreprocessID, 'embedded ID verified');
    expectEqual(ReportBytes, readBytes(Result.JsonFile), ...
        'report file unmodified by retrieval');

    Detail = [ ...
        'valid PreprocessID resolved to its output directory with ', ...
        'embedded-ID verification; retrieval is read-only'];

end

function Detail = checkGetPreprocessingReportErrors()
%CHECKGETPREPROCESSINGREPORTERRORS All retrieval errors are typed.

    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport('garbage'), ...
        'Preprocessing:GetPreprocessingReport:InvalidPreprocessID');

    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport( ...
            'Run_999_20260101_000000__PP_20260101_000000_01'), ...
        'Preprocessing:GetPreprocessingReport:PreprocessIDNotFound');

    Paths = preprocessing.ProjectPaths();
    MismatchRun = 'Run_997_20260101_000000';
    MismatchID = [MismatchRun '__PP_20260101_000000_01'];
    MismatchDir = fullfile(Paths.PreprocessedRoot, MismatchRun, ...
        MismatchID);
    mkdir(MismatchDir);
    MismatchReport = struct('RunInfo', struct('PreprocessID', ...
        [MismatchRun '__PP_20260101_000000_99']));
    fid = fopen(fullfile(MismatchDir, 'PreprocessingReport.json'), 'w');
    fprintf(fid, '%s\n', jsonencode(MismatchReport));
    fclose(fid);
    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(MismatchID), ...
        'Preprocessing:GetPreprocessingReport:PreprocessIDMismatch');

    MissingRun = 'Run_996_20260101_000000';
    MissingID = [MissingRun '__PP_20260101_000000_01'];
    mkdir(fullfile(Paths.PreprocessedRoot, MissingRun, MissingID));
    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(MissingID), ...
        'Preprocessing:GetPreprocessingReport:ReportFileMissing');

    Detail = [ ...
        'invalid grammar, unknown ID, mismatched embedded ID and ', ...
        'missing report file all raise distinct typed errors'];

end

% =========================================================================
%% PHASE 5 CORRECTION TESTS (F-01 / F-02)
% =========================================================================

function Detail = checkRunDirectoryRegisteredEligible()
%CHECKRUNDIRECTORYREGISTEREDELIGIBLE Registered+eligible override proceeds.

    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();
    RunID = 'Run_001_20261107_110817';
    RunDirectory = fullfile(Paths.RunsRoot, RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', RunDirectory));

    expectEqual(Result.Status, 'SUCCESS', 'status');
    expectEqual(Result.Eligibility, 'Eligible', 'eligibility');
    expectEqual(Result.ApprovalUsed, false, 'no approval needed');
    expectEqual(strcmp(Result.Category, 'SyntheticOverride'), false, ...
        'registry category retained');
    expectEqual(isfile(Result.MatFile), true, 'artifacts exported');

    Detail = [ ...
        'registered+eligible run directory override proceeds under ', ...
        'the standard eligibility rules without approval'];

end

function Detail = checkRunDirectoryUnregisteredRejected()
%CHECKRUNDIRECTORYUNREGISTEREDREJECTED Synthetic override needs approval.

    RunID = 'Run_902_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('RunDirUnregFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('RunDirUnregFixture'), RunID);

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            RunID, Config, struct('RunDirectory', FixtureRoot)), ...
        'Preprocessing:PreprocessRun:ApprovalRequired');

    Detail = [ ...
        'non-registry RunDirectory without ApproveUnregistered is ', ...
        'rejected (typed ApprovalRequired); the override itself never ', ...
        'counts as approval'];

end

function Detail = checkRunDirectoryUnregisteredApproved()
%CHECKRUNDIRECTORYUNREGISTEREDAPPROVED Explicit approval permits it.

    RunID = 'Run_902_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('RunDirUnregFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('RunDirUnregFixture'), RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));

    expectEqual(Result.Status, 'SUCCESS', 'status');
    expectEqual(Result.ApprovalUsed, true, 'approval recorded');

    Detail = [ ...
        'explicit ApproveUnregistered permits the synthetic override; ', ...
        'approval recorded in the result'];

end

function Detail = checkRunDirectoryRunIDMismatch()
%CHECKRUNDIRECTORYRUNIDMISMATCH Relabeling one run as another rejected.

    RunID = 'Run_903_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('RunDirMismatchFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('RunDirMismatchFixture'), RunID);

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            'Run_904_20260101_000000', Config, ...
            struct('RunDirectory', FixtureRoot, ...
            'ApproveUnregistered', true)), ...
        'Preprocessing:PreprocessRun:RunDirectoryRunIDMismatch');

    Detail = [ ...
        'basename/RunID mismatch rejected with typed ', ...
        'RunDirectoryRunIDMismatch even when approval is supplied'];

end

function Detail = checkRunDirectoryWorkingRunsRejected()
%CHECKRUNDIRECTORYWORKINGRUNSREJECTED WorkingRuns never processed.

    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            'WorkingRuns', Config, ...
            struct('RunDirectory', Paths.WorkingRunsRoot, ...
            'ApproveUnregistered', true)), ...
        'Preprocessing:PreprocessRun:ProtectedRunDirectory');

    Listing = dir(Paths.WorkingRunsRoot);
    Listing = Listing([Listing.isdir] & ...
        ~ismember({Listing.name}, {'.', '..'}));

    if ~isempty(Listing)

        assertErrorId( ...
            @() preprocessing.PreprocessRun( ...
                Listing(1).name, Config, ...
                struct('RunDirectory', fullfile( ...
                Paths.WorkingRunsRoot, Listing(1).name), ...
                'ApproveUnregistered', true)), ...
            'Preprocessing:PreprocessRun:ProtectedRunDirectory');

    end

    Detail = [ ...
        'WorkingRuns root and subdirectories refused with typed ', ...
        'ProtectedRunDirectory regardless of approval'];

end

function Detail = checkRunDirectoryFailedRunsRejected()
%CHECKRUNDIRECTORYFAILEDRUNSREJECTED FailedRuns never processed.

    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            'FailedRuns', Config, ...
            struct('RunDirectory', Paths.FailedRunsRoot, ...
            'ApproveUnregistered', true)), ...
        'Preprocessing:PreprocessRun:ProtectedRunDirectory');

    Listing = dir(Paths.FailedRunsRoot);
    Listing = Listing([Listing.isdir] & ...
        ~ismember({Listing.name}, {'.', '..'}));

    if ~isempty(Listing)

        assertErrorId( ...
            @() preprocessing.PreprocessRun( ...
                Listing(1).name, Config, ...
                struct('RunDirectory', fullfile( ...
                Paths.FailedRunsRoot, Listing(1).name), ...
                'ApproveUnregistered', true)), ...
            'Preprocessing:PreprocessRun:ProtectedRunDirectory');

    end

    Detail = [ ...
        'FailedRuns root and subdirectories refused with typed ', ...
        'ProtectedRunDirectory regardless of approval'];

end

function Detail = checkRunDirectorySyntheticProvenance()
%CHECKRUNDIRECTORYSYNTHETICPROVENANCE Synthetic provenance preserved.

    RunID = 'Run_902_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('RunDirUnregFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('RunDirUnregFixture'), RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));

    expectEqual(Result.Category, 'SyntheticOverride', 'category');
    expectEqual(Result.Eligibility, 'Unregistered', 'eligibility');
    expectEqual(Result.ApprovalUsed, true, 'approval flag');
    expectEqual(Result.Report.RunInfo.Category, 'SyntheticOverride', ...
        'report provenance');
    expectEqual(Result.Report.RunInfo.ApprovalUsed, true, ...
        'report approval');

    Detail = [ ...
        'approved synthetic override keeps its distinct provenance: ', ...
        'Category SyntheticOverride, Eligibility Unregistered, ', ...
        'ApprovalUsed true in result and report'];

end

function Detail = checkNormalRegisteredRunPathUnchanged()
%CHECKNORMALREGISTEREDRUNPATHUNCHANGED InspectRun path unchanged.

    Config = preprocessing.PreprocessingConfig();
    RunID = 'Run_001_20261107_110817';

    Result = preprocessing.PreprocessRun(RunID, Config);

    expectEqual(Result.Status, 'SUCCESS', 'status');
    expectEqual(Result.Eligibility, 'Eligible', 'eligibility');
    expectEqual(Result.ApprovalUsed, false, 'no approval');
    expectEqual(strcmp(Result.Category, 'SyntheticOverride'), false, ...
        'not a synthetic override');
    expectEqual(isfile(Result.JsonFile), true, 'artifacts exported');

    Detail = [ ...
        'normal registry-resolved path (no override) unchanged: ', ...
        'Eligible, no approval, registry category, full artifacts'];

end

function Detail = checkGetReportMarkerOnly()
%CHECKGETREPORTMARKERONLY Marker-only directory refused.

    PreprocessID = 'Run_995_20260101_000000__PP_20260101_000000_01';
    makeManualPreprocessDir('Run_995_20260101_000000', PreprocessID, ...
        {'ProcessingFailed.txt'}, {'injected failure'});

    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(PreprocessID), ...
        'Preprocessing:GetPreprocessingReport:ProcessingFailedMarker');

    Detail = [ ...
        'directory containing only ProcessingFailed.txt raises ', ...
        'ProcessingFailedMarker (not ReportFileMissing)'];

end

function Detail = checkGetReportSuccessJsonPlusMarker()
%CHECKGETREPORTSUCCESSJSONPLUSMARKER Marker outranks a SUCCESS report.

    RunID = 'Run_994_20260101_000000';
    PreprocessID = [RunID '__PP_20260101_000000_01'];
    JsonText = jsonencode(struct('RunInfo', struct( ...
        'PreprocessID', PreprocessID, 'Status', 'SUCCESS')));
    makeManualPreprocessDir(RunID, PreprocessID, ...
        {'PreprocessingReport.json', 'ProcessingFailed.txt'}, ...
        {JsonText, 'injected failure'});

    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(PreprocessID), ...
        'Preprocessing:GetPreprocessingReport:ProcessingFailedMarker');

    Detail = [ ...
        'a valid SUCCESS JSON beside a failure marker is refused: ', ...
        'marker takes precedence, the report is never returned'];

end

function Detail = checkGetReportPartialArtifactsPlusMarker()
%CHECKGETREPORTPARTIALARTIFACTSPLUSMARKER Partial outputs refused.

    RunID = 'Run_993_20260101_000000';
    PreprocessID = [RunID '__PP_20260101_000000_01'];
    JsonText = jsonencode(struct('RunInfo', struct( ...
        'PreprocessID', PreprocessID, 'Status', 'SUCCESS')));
    makeManualPreprocessDir(RunID, PreprocessID, ...
        {'PreprocessedData.mat', 'PreprocessingReport.json', ...
         'Review/IMU.csv', 'ProcessingFailed.txt'}, ...
        {'mat-placeholder', JsonText, 'SourceRowIdx,Time_s', ...
         'injected failure'});

    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(PreprocessID), ...
        'Preprocessing:GetPreprocessingReport:ProcessingFailedMarker');

    Detail = [ ...
        'MAT + SUCCESS JSON + partial CSVs beside a failure marker are ', ...
        'refused; artifact presence is never taken as success'];

end

function Detail = checkGetReportMalformedJson()
%CHECKGETREPORTMALFORMEDJSON Malformed JSON raises ReportDecodeFailure.

    RunID = 'Run_992_20260101_000000';
    PreprocessID = [RunID '__PP_20260101_000000_01'];
    makeManualPreprocessDir(RunID, PreprocessID, ...
        {'PreprocessingReport.json'}, {'not valid json {{{'});

    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(PreprocessID), ...
        'Preprocessing:GetPreprocessingReport:ReportDecodeFailure');

    Detail = [ ...
        'malformed JSON without a marker still raises the existing ', ...
        'typed ReportDecodeFailure'];

end

function Detail = checkPreprocessRunFailureMarkerAndRetrieval()
%CHECKPREPROCESSRUNFAILUREMARKERANDRETRIEVAL Real failure path, end to end.

    RunID = 'Run_908_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('InjectionFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('InjectionFixture'), RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true, ...
        'TestFailureInjection', 'ProcessingStage'));

    expectEqual(Result.Status, 'FAILED', 'status');
    expectEqual(contains(Result.Errors{1}, 'InjectedTestFailure'), ...
        true, 'failure recorded');
    MarkerFile = fullfile(Result.OutputDirectory, ...
        'ProcessingFailed.txt');
    expectEqual(isfile(MarkerFile), true, ...
        'marker created by the real failure path');
    expectEqual(isfile(fullfile(Result.OutputDirectory, ...
        'PreprocessingReport.json')), false, ...
        'no success report left behind');
    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(Result.PreprocessID), ...
        'Preprocessing:GetPreprocessingReport:ProcessingFailedMarker');

    Detail = [ ...
        'actual PreprocessRun failure path (controlled injection) ', ...
        'produces FAILED + ProcessingFailed.txt, leaves no success ', ...
        'report, and retrieval raises ProcessingFailedMarker'];

end

% =========================================================================
%% PHASE 5 FINAL SAFETY TESTS (canonical path + transactional JSON)
% =========================================================================

function Detail = checkCanonicalPathNormalResolution()
%CHECKCANONICALPATHNORMALRESOLUTION Normal absolute path canonicalizes.

    RunID = 'Run_909_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('CanonicalFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('CanonicalFixture'), RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));

    expectEqual(Result.Status, 'SUCCESS', 'status');
    expectEqual(Result.Report.RunInfo.RunDirectory, FixtureRoot, ...
        'canonical run directory recorded');

    Detail = [ ...
        'normal absolute path canonicalizes and processes; canonical ', ...
        'directory recorded as provenance'];

end

function Detail = checkCanonicalPathRelativeResolution()
%CHECKCANONICALPATHRELATIVERESOLUTION Relative input resolves via cwd.

    RunID = 'Run_910_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('RelativeFixture', false, RunID);
    Parent = fixtureDir('RelativeFixture');
    OldDir = pwd;
    Restorer = onCleanup(@() cd(OldDir));
    cd(Parent);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', RunID, ...
        'ApproveUnregistered', true));

    clear Restorer;

    expectEqual(Result.Status, 'SUCCESS', 'status');

    Detail = [ ...
        'relative RunDirectory resolves against the current working ', ...
        'directory and processes; working directory restored after'];

end

function Detail = checkCanonicalPathParentTraversal()
%CHECKCANONICALPATHPARENTTRAVERSAL 'temp/..' resolves to the real dir.

    RunID = 'Run_911_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('TraversalFixture', false, RunID);
    RunDir = fullfile(fixtureDir('TraversalFixture'), RunID);

    if ~isfolder(fullfile(RunDir, 'temp'))

        mkdir(fullfile(RunDir, 'temp'));

    end

    TraversalPath = fullfile(RunDir, 'temp', '..');

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', TraversalPath, ...
        'ApproveUnregistered', true));

    expectEqual(Result.Status, 'SUCCESS', 'status');
    expectEqual(Result.Report.RunInfo.RunDirectory, RunDir, ...
        'traversal resolved to the canonical run directory');

    Detail = [ ...
        '"temp/.." resolves to the real run directory; recorded ', ...
        'provenance is canonical with no traversal remnants'];

end

function Detail = checkProtectedDirectoryViaTraversal()
%CHECKPROTECTEDDIRECTORYVIA Traversal reaches protected trees safely.

    Config = preprocessing.PreprocessingConfig();
    Paths = preprocessing.ProjectPaths();
    TraversalPath = fullfile(Paths.RunsRoot, '..', 'WorkingRuns');

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            'WorkingRuns', Config, ...
            struct('RunDirectory', TraversalPath, ...
            'ApproveUnregistered', true)), ...
        'Preprocessing:PreprocessRun:ProtectedRunDirectory');

    Listing = dir(Paths.WorkingRunsRoot);
    Listing = Listing([Listing.isdir] & ...
        ~ismember({Listing.name}, {'.', '..'}));

    if ~isempty(Listing)

        assertErrorId( ...
            @() preprocessing.PreprocessRun( ...
                Listing(1).name, Config, ...
                struct('RunDirectory', fullfile(Paths.RunsRoot, ...
                '..', 'WorkingRuns', Listing(1).name), ...
                'ApproveUnregistered', true)), ...
            'Preprocessing:PreprocessRun:ProtectedRunDirectory');

    end

    Detail = [ ...
        'WorkingRuns reached through a Runs/../WorkingWorks traversal ', ...
        'is still refused after canonicalization'];

end

function Detail = checkCanonicalPathFailureTypedError()
%CHECKCANONICALPATHFAILURETYPEDERROR Fail-closed canonicalization.

    BadPath = [fullfile(tempdir, 'x') char(0) 'y'];

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            'Run_912_20260101_000000', ...
            preprocessing.PreprocessingConfig(), ...
            struct('RunDirectory', BadPath)), ...
        'Preprocessing:PreprocessRun:PathCanonicalizationFailure');

    Detail = [ ...
        'uncanonicalizable path (embedded NUL) raises typed ', ...
        'PathCanonicalizationFailure before any comparison or ', ...
        'processing; the raw path is never used as a fallback'];

end

function Detail = checkExportJsonTempWriteFailure()
%CHECKEXPORTJSONTEMPWRITEFAILURE Temporary write failure is typed.

    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture('JsonTxnFixture', ...
        'Run_913_20260101_000000__PP_20260101_000000_01');

    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, ...
            OutputDirectory, 'JsonTempWrite'), ...
        'Preprocessing:ExportPreprocessedData:JsonWriteFailure');

    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json.tmp')), false, 'no temp residue');
    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json')), false, 'no published report');

    Detail = [ ...
        'temporary JSON write failure raises JsonWriteFailure and ', ...
        'leaves neither a temp file nor a published report'];

end

function Detail = checkExportJsonTempReadBackFailure()
%CHECKEXPORTJSONTEMPREADBACKFAILURE Corrupt temp never publishes.

    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture('JsonTxnFixture', ...
        'Run_914_20260101_000000__PP_20260101_000000_01');

    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, ...
            OutputDirectory, 'JsonTempReadBack'), ...
        'Preprocessing:ExportPreprocessedData:ReadBackValidationFailure');

    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json.tmp')), false, 'temp removed');
    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json')), false, 'never published');

    Detail = [ ...
        'temp JSON read-back failure raises ReadBackValidationFailure, ', ...
        'the corrupt temp is removed and never published'];

end

function Detail = checkExportJsonPreprocessIDMismatch()
%CHECKEXPORTJSONPREPROCESSIDMISMATCH Mismatched temp never publishes.

    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture('JsonTxnFixture', ...
        'Run_915_20260101_000000__PP_20260101_000000_01');

    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, ...
            OutputDirectory, 'JsonPreprocessIDMismatch'), ...
        'Preprocessing:ExportPreprocessedData:ReadBackValidationFailure');

    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json.tmp')), false, 'temp removed');
    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json')), false, 'never published');

    Detail = [ ...
        'embedded PreprocessID mismatch in the temp document raises ', ...
        'ReadBackValidationFailure and is never published'];

end

function Detail = checkExportJsonPublishFailure()
%CHECKEXPORTJSONPUBLISHFAILURE Publication failure is typed.

    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture('JsonTxnFixture', ...
        'Run_916_20260101_000000__PP_20260101_000000_01');

    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, ...
            OutputDirectory, 'JsonPublish'), ...
        'Preprocessing:ExportPreprocessedData:JsonWriteFailure');

    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json.tmp')), false, 'no temp residue');
    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json')), false, 'no published report');

    Detail = [ ...
        'publication failure raises JsonWriteFailure and leaves no ', ...
        'retrievable success report or temp residue'];

end

function Detail = checkExportJsonTransactionalPublish()
%CHECKEXPORTJSONTRANSACTIONALPUBLISH Valid temp publishes atomically.

    PreprocessID = 'Run_917_20260101_000000__PP_20260101_000000_01';
    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture( ...
        'JsonTxnFixture', PreprocessID);

    Artifacts = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory);

    expectEqual(isfile(Artifacts.JsonFile), true, 'published');
    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json.tmp')), false, 'temp consumed');
    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    expectEqual(Decoded.RunInfo.PreprocessID, PreprocessID, ...
        'PreprocessID verified before publication');
    expectEqual(Artifacts.Validated, true, 'validated');

    Detail = [ ...
        'valid temp JSON is decoded and PreprocessID-verified, then ', ...
        'published atomically with no temp residue'];

end

function Detail = checkPublishedReportRetrievable()
%CHECKPUBLISHEDREPORTRETRIEVABLE Published reports remain retrievable.

    RunID = 'Run_918_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('RetrievableFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('RetrievableFixture'), RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));
    Retrieved = preprocessing.GetPreprocessingReport( ...
        Result.PreprocessID);

    expectEqual(Retrieved.PreprocessID, Result.PreprocessID, ...
        'published report retrieved');
    expectEqual(isfile(fullfile(Result.OutputDirectory, ...
        'PreprocessingReport.json.tmp')), false, ...
        'no temp residue in published output');

    Detail = [ ...
        'successfully published reports are retrievable and carry no ', ...
        'temporary-file residue'];

end

function Detail = checkFailedExportNoRetrievableSuccess()
%CHECKFAILEDEXPORTNORETRIEVABLESUCCESS Failed export is unretrievable.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('UnretrievableFixture', false);
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    Stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    PreprocessID = ['Run_919_20260101_000000__PP_' Stamp '_01'];
    Paths = preprocessing.ProjectPaths();
    OutputDirectory = fullfile(Paths.PreprocessedRoot, ...
        'Run_919_20260101_000000', PreprocessID);
    RunInfo = buildRunInfo(OutputDirectory, PreprocessID);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, ...
            OutputDirectory, 'JsonPublish'), ...
        'Preprocessing:ExportPreprocessedData:JsonWriteFailure');

    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json')), false, 'no published report');
    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json.tmp')), false, 'no temp residue');
    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(PreprocessID), ...
        'Preprocessing:GetPreprocessingReport:ReportFileMissing');

    Detail = [ ...
        'failed export leaves no retrievable SUCCESS report: no final ', ...
        'JSON, no temp residue, and retrieval raises ReportFileMissing'];

end

function Detail = checkMarkerPrecedenceUnchanged()
%CHECKMARKERPRECEDENCEUNCHANGED Marker still outranks any report.

    RunID = 'Run_920_20260101_000000';
    PreprocessID = [RunID '__PP_20260101_000000_01'];
    JsonText = jsonencode(struct('RunInfo', struct( ...
        'PreprocessID', PreprocessID, 'Status', 'SUCCESS')));
    makeManualPreprocessDir(RunID, PreprocessID, ...
        {'PreprocessingReport.json', 'ProcessingFailed.txt'}, ...
        {JsonText, 'marker'});

    assertErrorId( ...
        @() preprocessing.GetPreprocessingReport(PreprocessID), ...
        'Preprocessing:GetPreprocessingReport:ProcessingFailedMarker');

    Detail = [ ...
        'ProcessingFailed.txt marker precedence is unchanged: a ', ...
        'published-looking SUCCESS JSON beside the marker is refused'];

end

% =========================================================================
%% BLOCK 9 CLOSURE TESTS (dependency audit, F-03..F-07)
% =========================================================================

function Detail = checkDependencyAllModulesAccounted()
%CHECKDEPENDENCYALLMODULESACCOUNTED All 19 planned modules present.

    Audit = dependencyAudit();

    expectEqual(Audit.AllAccounted, true, 'all planned modules on disk');
    expectEqual(numel(Audit.FoundFiles), 19, '19 planned modules');

    Detail = sprintf([ ...
        'dependency audit: %d/19 planned modules on disk; %d closure ', ...
        'files; %d product dependencies'], ...
        numel(Audit.FoundFiles), numel(Audit.ClosureFiles), ...
        numel(Audit.Products));

end

function Detail = checkDependencyNoMissingModules()
%CHECKDEPENDENCYNOMISSINGMODULES No planned module is missing.

    Audit = dependencyAudit();

    expectEqual(isempty(Audit.Missing), true, 'no missing modules');

    Detail = 'no planned Block 9 module is missing from the package';

end

function Detail = checkDependencyNoUnexpectedProjectDeps()
%CHECKDEPENDENCYNOUNEXPECTEDPROJECTDEPS Clean project closure.

    Audit = dependencyAudit();

    expectEqual(isempty(Audit.UnexpectedProject), true, ...
        'no unexpected project dependencies');
    expectEqual(isempty(Audit.UnexpectedPackageFile), true, ...
        'no unexpected package files in closure');
    expectEqual(isempty(Audit.ExternalFiles), true, ...
        'no external file dependencies');

    Detail = [ ...
        'closure contains only planned +preprocessing modules: no ', ...
        'dependency on other project packages and no external files'];

end

function Detail = checkDependencyAcyclic()
%CHECKDEPENDENCYACYCLIC Directed call graph has no cycles.

    Audit = dependencyAudit();

    expectEqual(isempty(Audit.Cycles), true, 'acyclic architecture');
    expectEqual(Audit.EdgeCount > 30, true, ...
        'graph is substantive (not vacuously acyclic)');

    Detail = sprintf([ ...
        'directed dependency graph over the 19 modules (%d call ', ...
        'edges) is acyclic'], Audit.EdgeCount);

end

function Detail = checkDependencyExpectedProducts()
%CHECKDEPENDENCYEXPECTEDPRODUCTS MATLAB products identified.

    Audit = dependencyAudit();

    ProductNames = {Audit.Products.Name};
    expectEqual( ...
        contains(lower(strjoin(ProductNames, ',')), 'matlab'), true, ...
        'MATLAB identified as a product dependency');
    expectEqual(isempty(Audit.UnexpectedProducts), true, ...
        'no unexpected toolbox/product dependencies');

    Detail = sprintf('product dependencies identified: %s', ...
        strjoin(ProductNames, ', '));

end

function Detail = checkDependencyInjectedUnexpected()
%CHECKDEPENDENCYINJECTEDUNEXPECTED Injected odd dependency is caught.

    FixtureDir = fullfile(fixtureDir('DependencyFixture'), 'Unexpected');

    if ~isfolder(FixtureDir)
        mkdir(FixtureDir);
    end

    FakeFile = fullfile(FixtureDir, 'fakeUnexpectedDep.m');
    fid = fopen(FakeFile, 'w');
    fprintf(fid, 'function y = fakeUnexpectedDep()\n');
    fprintf(fid, 'y = config.AircraftConfig();\n');
    fprintf(fid, 'end\n');
    fclose(fid);
    addpath(FixtureDir);
    Cleanup = onCleanup(@() rmpath(FixtureDir));

    Audit = dependencyAudit({FakeFile});

    expectEqual(Audit.UnexpectedProjectDetected, true, ...
        'injected outside-package project dependency detected');
    clear Cleanup;

    Detail = [ ...
        'a fixture module calling +config (outside the approved ', ...
        'architecture) is flagged as an unexpected project ', ...
        'dependency by the closure audit'];

end

function Detail = checkDependencyInjectedCycle()
%CHECKDEPENDENCYINJECTEDCYCLE Injected cycle is caught.

    FixtureDir = fullfile(fixtureDir('DependencyFixture'), 'Cycle');

    if ~isfolder(FixtureDir)
        mkdir(FixtureDir);
    end

    FileA = fullfile(FixtureDir, 'fakeDepCycleA.m');
    FileB = fullfile(FixtureDir, 'fakeDepCycleB.m');
    fid = fopen(FileA, 'w');
    fprintf(fid, 'function y = fakeDepCycleA()\n');
    fprintf(fid, 'y = fakeDepCycleB();\n');
    fprintf(fid, 'end\n');
    fclose(fid);
    fid = fopen(FileB, 'w');
    fprintf(fid, 'function y = fakeDepCycleB()\n');
    fprintf(fid, 'y = fakeDepCycleA();\n');
    fprintf(fid, 'end\n');
    fclose(fid);
    addpath(FixtureDir);
    Cleanup = onCleanup(@() rmpath(FixtureDir));

    Audit = dependencyAudit({FileA; FileB});

    expectEqual(Audit.CycleDetected, true, ...
        'injected mutual-call cycle detected');
    clear Cleanup;

    Detail = [ ...
        'two fixture modules calling each other are flagged as a ', ...
        'dependency cycle by the graph analysis'];

end

% -------------------------------------------------------------------------

function Detail = checkMetadataAbsentNotRecorded()
%CHECKMETADATAABSENTNOTRECORDED Absent metadata is NotRecorded.

    [Config, Data, ProcessedStreams, RunInfo] = ...
        metadataFixture('MetadataAbsentFixture', '');
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    expectEqual(Report.RunRecorded.Status, 'NotRecorded', 'absent');
    expectEqual(Report.RunRecorded.DecodeError, 'NotApplicable', ...
        'no decode error claimed');

    % Documented boundary: a DIRECTORY named RunMetadata.json is not a
    % metadata file; file-absence semantics apply (disclosed limitation).
    MetaDir = fullfile(fixtureDir('MetadataAbsentFixture'), ...
        'RunMetadata.json');

    if ~isfolder(MetaDir)
        mkdir(MetaDir);
    end

    Report2 = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    expectEqual(Report2.RunRecorded.Status, 'NotRecorded', ...
        'non-file entry treated as absent');

    Detail = [ ...
        'missing RunMetadata.json is NotRecorded with DecodeError ', ...
        '''NotApplicable''; the missing/undecodable distinction is ', ...
        'preserved (a directory with that name is documented as ', ...
        'file-absent)'];

end

function Detail = checkMetadataValidRecorded()
%CHECKMETADATARECORDED Valid metadata is recorded verbatim.

    Content = ['{"Run": {"RunNumber": 7}, ' ...
        '"Scenario": {"Name": "Climb"}, ' ...
        '"Configuration": {"ScenarioConfigPath": "cfg.m"}, ' ...
        '"Telemetry": {"IMU": 5}}'];
    [Config, Data, ProcessedStreams, RunInfo] = ...
        metadataFixture('MetadataValidFixture', Content);
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    expectEqual(Report.RunRecorded.Status, 'Recorded', 'recorded');
    expectEqual(Report.RunRecorded.Scenario.Name, 'Climb', 'scenario');
    expectEqual(Report.RunRecorded.ConfigurationPath, 'cfg.m', 'config');
    expectEqual(Report.RunRecorded.RecordedSampleCounts.IMU, 5, 'counts');

    Detail = [ ...
        'valid RunMetadata.json values recorded verbatim under ', ...
        'RunRecorded (Recorded), never mixed with defaults'];

end

function Detail = checkMetadataMalformedDecodeFailed()
%CHECKMETADATAMALFORMEDDECODEFAILED Malformed metadata is DecodeFailed.

    [Config, Data, ProcessedStreams, RunInfo] = ...
        metadataFixture('MetadataMalformedFixture', 'not json {{{');
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    expectEqual(Report.RunRecorded.Status, 'DecodeFailed', 'status');
    expectEqual(strcmp(Report.RunRecorded.DecodeError, 'NotApplicable'), ...
        false, 'decode error recorded');
    expectEqual( ...
        any(contains(Report.Warnings, 'MetadataDecodeFailure')), true, ...
        'structured warning recorded');
    expectEqual(Report.CurrentCodeDefaults.Description(1:8), ...
        'Current ', 'defaults untouched');

    Detail = [ ...
        'malformed RunMetadata.json yields DecodeFailed (never ', ...
        'NotRecorded) with DecodeError and a structured warning; no ', ...
        'historical values invented'];

end

function Detail = checkMetadataEmptyJson()
%CHECKMETADATAEMPTYJSON Empty content vs empty object distinguished.

    [Config, Data, ProcessedStreams, RunInfo] = ...
        metadataFixture('MetadataEmptyFixture', '');
    fid = fopen(fullfile(fixtureDir('MetadataEmptyFixture'), ...
        'RunMetadata.json'), 'w');
    fclose(fid);
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);
    expectEqual(Report.RunRecorded.Status, 'DecodeFailed', ...
        'empty content is undecodable');

    [Config2, Data2, Streams2, RunInfo2] = ...
        metadataFixture('MetadataEmptyObjectFixture', '{}');
    Aligned2 = preprocessing.BuildAlignedSensorData( ...
        Config2, Streams2);
    Report2 = preprocessing.BuildPreprocessingReport( ...
        Config2, Data2, Streams2, Aligned2, RunInfo2);
    expectEqual(Report2.RunRecorded.Status, 'Recorded', ...
        'empty object decodes');
    expectEqual(Report2.RunRecorded.Run, 'NotRecorded', ...
        'no fields invented');

    Detail = [ ...
        'empty metadata content raises DecodeFailed; a valid empty ', ...
        'JSON object is Recorded with all fields honestly NotRecorded'];

end

function Detail = checkMetadataMissingOptionalFields()
%CHECKMETADATAMISSINGOPTIONALFIELDS Partial metadata stays truthful.

    [Config, Data, ProcessedStreams, RunInfo] = ...
        metadataFixture('MetadataPartialFixture', ...
        '{"Run": {"RunNumber": 3}}');
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    expectEqual(Report.RunRecorded.Status, 'Recorded', 'recorded');
    expectEqual(Report.RunRecorded.Run.RunNumber, 3, 'present field');
    expectEqual(Report.RunRecorded.Scenario, 'NotRecorded', ...
        'absent field stays NotRecorded');

    Detail = [ ...
        'present fields captured, absent optional fields remain ', ...
        'NotRecorded; provenance truthful in every scenario'];

end

% -------------------------------------------------------------------------

function Detail = checkOutputsSuccessFourCsvs()
%CHECKOUTPUTSSUCCESSFOURCSV SUCCESS lists exactly the four CSVs.

    PreprocessID = 'Run_931_20260101_000000__PP_20260101_000000_01';
    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture( ...
        'OutputsFourFixture', PreprocessID);

    [Artifacts, FinalReport] = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory);

    Written = fieldnames(FinalReport.Outputs.ReviewFiles);
    expectEqual(sort(Written), ...
        sort({'IMU'; 'GNSS'; 'AirData'; 'Magnetometer'}), 'four CSVs');
    expectEqual(numel(fieldnames( ...
        FinalReport.Outputs.ExpectedReviewFiles)), 4, 'expected set');
    expectEqual(FinalReport.Outputs.ReviewFilesStatus, 'Written', ...
        'status');

    for Index = 1:numel(Written)
        expectEqual(isfile( ...
            FinalReport.Outputs.ReviewFiles.(Written{Index})), true, ...
            'listed file exists');
    end

    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    expectEqual(sort(fieldnames(Decoded.Outputs.ReviewFiles)), ...
        sort(Written), 'JSON agrees with the report');

    Detail = [ ...
        'SUCCESS export lists exactly the four written review CSVs in ', ...
        'report and JSON; every listed path exists on disk'];

end

function Detail = checkOutputsPartialThreeCsvs()
%CHECKOUTPUTSPARTIALTHREECSV PARTIAL lists only the three written.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed('OutputsThreeFixture', true);
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    PreprocessID = 'Run_932_20260101_000000__PP_20260101_000000_01';
    OutputDirectory = tempname(fixtureDir('OutputsThreeFixture'));
    RunInfo = buildRunInfo(OutputDirectory, PreprocessID);
    RunInfo.Status = 'PARTIAL';
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    [Artifacts, FinalReport] = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory);

    Written = fieldnames(FinalReport.Outputs.ReviewFiles);
    expectEqual(sort(Written), sort({'IMU'; 'AirData'; 'Magnetometer'}), ...
        'three CSVs only');
    expectEqual(isfield(FinalReport.Outputs.ReviewFiles, 'GNSS'), false, ...
        'missing GNSS never listed');
    expectEqual(isfile(fullfile(OutputDirectory, 'Review', ...
        'GNSS.csv')), false, 'GNSS.csv not fabricated');

    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    expectEqual(isfield(Decoded.Outputs.ReviewFiles, 'GNSS'), false, ...
        'JSON has no false GNSS reference');

    Detail = [ ...
        'PARTIAL (missing GNSS) lists exactly the three written CSVs; ', ...
        'no false reference to GNSS.csv in report, JSON or on disk'];

end

function Detail = checkOutputsPartialOneCsv()
%CHECKOUTPUTSPARTIALONECSV Single-stream run lists a single CSV.

    FixtureRoot = fullfile(fixtureDir('OutputsOneFixture'), ...
        'Run_933_20260101_000000');
    SourceFolder = fullfile(FixtureRoot, 'RealisticSensorTelemetry');

    if ~isfolder(SourceFolder)
        mkdir(SourceFolder);
    end

    writeFixtureCsv(fullfile(SourceFolder, 'IMU.csv'), ...
        'IMU', 'RealisticCsv', 5);
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(FixtureRoot, Config, 'Auto');
    ProcessedStreams = struct('IMU', ...
        processChain(Config, Data.Streams.IMU, 'IMU'));
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    PreprocessID = 'Run_933_20260101_000000__PP_20260101_000000_01';
    OutputDirectory = tempname(fixtureDir('OutputsOneFixture'));
    RunInfo = buildRunInfo(OutputDirectory, PreprocessID);
    RunInfo.Status = 'PARTIAL';
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    [Artifacts, FinalReport] = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory);

    Written = fieldnames(FinalReport.Outputs.ReviewFiles);
    expectEqual(Written, {'IMU'}, 'exactly one CSV listed');
    expectEqual(numel(ReviewListing(OutputDirectory)), 1, ...
        'exactly one CSV on disk');

    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    expectEqual(fieldnames(Decoded.Outputs.ReviewFiles), {'IMU'}, ...
        'JSON agrees');

    Detail = [ ...
        'single-stream PARTIAL run lists exactly its one written CSV ', ...
        'in report, JSON and on disk'];

end

function Listing = ReviewListing(OutputDirectory)
%REVIEWLISTING CSV files actually present in the Review folder.

    D = dir(fullfile(OutputDirectory, 'Review', '*.csv'));
    Listing = {D.name};

end

function Detail = checkOutputsEmptyStreamConsistency()
%CHECKOUTPUTSEMPTYSTREAMCONSISTENCY Empty stream keeps inventory truthful.

    FixtureRoot = fullfile(fixtureDir('OutputsEmptyFixture'), ...
        'Run_934_20260101_000000');
    SourceFolder = fullfile(FixtureRoot, 'RealisticSensorTelemetry');

    if ~isfolder(SourceFolder)
        mkdir(SourceFolder);
    end

    writeFixtureCsv(fullfile(SourceFolder, 'IMU.csv'), ...
        'IMU', 'RealisticCsv', 0);
    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(FixtureRoot, Config, 'Auto');
    ProcessedStreams = struct();

    if strcmp(Data.Streams.IMU.Status, 'Loaded')

        ProcessedStreams.IMU = ...
            processChain(Config, Data.Streams.IMU, 'IMU');

    end

    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    PreprocessID = 'Run_934_20260101_000000__PP_20260101_000000_01';
    OutputDirectory = tempname(fixtureDir('OutputsEmptyFixture'));
    RunInfo = buildRunInfo(OutputDirectory, PreprocessID);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

    [Artifacts, FinalReport] = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory);

    Listed = fieldnames(FinalReport.Outputs.ReviewFiles);
    OnDisk = ReviewListing(OutputDirectory);
    OnDiskStreams = cellfun(@(S) erase(S, '.csv'), OnDisk, ...
        'UniformOutput', false);
    expectEqual(sort(Listed), sort(OnDiskStreams(:)), ...
        'listed set equals on-disk set');

    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    expectEqual(sort(fieldnames(Decoded.Outputs.ReviewFiles)), ...
        sort(Listed), 'JSON agrees');

    Detail = [ ...
        'empty stream: whatever was written is exactly what is listed ', ...
        '(header-only CSV if loaded, nothing if not); no false refs'];

end

function Detail = checkOutputsFailedExportNoFalseRefs()
%CHECKOUTPUTSFAILEDEXPORTNOFALSEREFS Failed export keeps inventory honest.

    PreprocessID = 'Run_935_20260101_000000__PP_20260101_000000_01';
    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture( ...
        'OutputsFailedFixture', PreprocessID);

    assertErrorId( ...
        @() preprocessing.ExportPreprocessedData( ...
            Config, Data, ProcessedStreams, Aligned, Report, ...
            OutputDirectory, 'JsonPublish'), ...
        'Preprocessing:ExportPreprocessedData:JsonWriteFailure');

    expectEqual(isfile(fullfile(OutputDirectory, ...
        'PreprocessingReport.json')), false, 'no success JSON');
    Loaded = load(fullfile(OutputDirectory, 'PreprocessedData.mat'));
    Recorded = ...
        Loaded.PreprocessedData.ProcessingInfo.ArtifactPaths.ReviewFiles;
    OnDisk = ReviewListing(OutputDirectory);
    OnDiskStreams = cellfun(@(S) erase(S, '.csv'), OnDisk, ...
        'UniformOutput', false);
    expectEqual(sort(fieldnames(Recorded)), sort(OnDiskStreams(:)), ...
        'MAT inventory matches files that actually exist');

    Detail = [ ...
        'failed export leaves no success JSON, and the recorded output ', ...
        'inventory (even in the leftover MAT) references only files ', ...
        'that actually exist'];

end

% -------------------------------------------------------------------------

function Detail = checkAllocationSequentialRepeated()
%CHECKALLOCATIONSEQUENTIALREPEATED Unique IDs; earlier output untouched.

    RunID = 'Run_936_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('AllocationFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('AllocationFixture'), RunID);
    Options = struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true);

    First = preprocessing.PreprocessRun(RunID, Config, Options);
    FirstBytes = readBytes(First.MatFile);
    Second = preprocessing.PreprocessRun(RunID, Config, Options);
    Third = preprocessing.PreprocessRun(RunID, Config, Options);

    IDs = {First.PreprocessID, Second.PreprocessID, Third.PreprocessID};
    expectEqual(numel(unique(IDs)), 3, 'three unique IDs');
    expectEqual(FirstBytes, readBytes(First.MatFile), ...
        'first output byte-identical');

    Detail = [ ...
        'three sequential allocations: unique PreprocessIDs, unique ', ...
        'directories, earlier outputs byte-identical'];

end

function Detail = checkAllocationCollisionSequence()
%CHECKALLOCATIONCOLLISIONSEQUENCE Same-second calls get distinct IDs.

    RunID = 'Run_937_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('AllocationFixture2', false, RunID);
    FixtureRoot = fullfile(fixtureDir('AllocationFixture2'), RunID);
    Options = struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true);

    First = preprocessing.PreprocessRun(RunID, Config, Options);
    Second = preprocessing.PreprocessRun(RunID, Config, Options);

    if strcmp(First.PreprocessID, Second.PreprocessID)

        error( ...
            'Preprocessing:RunPreprocessingTests:AssertionFailed', ...
            'Colliding allocation must advance the sequence number.');

    end

    expectEqual(isfolder(First.OutputDirectory), true, 'first owned');
    expectEqual(isfolder(Second.OutputDirectory), true, 'second owned');
    expectEqual(strcmp(First.OutputDirectory, Second.OutputDirectory), ...
        false, 'never a shared output directory');

    Detail = [ ...
        'two same-second allocation attempts yield distinct IDs and ', ...
        'distinct exclusive directories (sequence advance), never a ', ...
        'shared directory'];

end

function Detail = checkAllocationParentIsFileFailure()
%CHECKALLOCATIONPARENTISFILEFAILURE Allocation failure is typed.

    Target = fullfile(preprocessing.ProjectPaths().PreprocessedRoot, ...
        'Run_921_20260101_000000');

    if ~isfile(Target) && ~isfolder(Target)

        fid = fopen(Target, 'w');
        fprintf(fid, 'allocation failure fixture\n');
        fclose(fid);

    end

    RunID = 'Run_921_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('AllocationFailFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('AllocationFailFixture'), RunID);

    assertErrorId( ...
        @() preprocessing.PreprocessRun( ...
            RunID, Config, struct('RunDirectory', FixtureRoot, ...
            'ApproveUnregistered', true)), ...
        'Preprocessing:PreprocessRun:OutputDirectoryCreationFailure');

    Detail = [ ...
        'uncreatable output parent (occupied by a file) raises typed ', ...
        'OutputDirectoryCreationFailure; no partial directory claimed'];

end

function Detail = checkAllocationRecoveryAfterFailure()
%CHECKALLOCATIONRECOVERYAFTERFAILURE A later allocation succeeds.

    RunID = 'Run_922_20260101_000000';
    [Config, ~, ~] = ...
        buildSyntheticProcessed('AllocRecoveryFixture', false, RunID);
    FixtureRoot = fullfile(fixtureDir('AllocRecoveryFixture'), RunID);

    Result = preprocessing.PreprocessRun( ...
        RunID, Config, struct('RunDirectory', FixtureRoot, ...
        'ApproveUnregistered', true));

    expectEqual(Result.Status, 'SUCCESS', 'recovered');
    expectEqual(isfile(Result.MatFile), true, 'output produced');

    Detail = [ ...
        'after a failed allocation (parent-is-file fixture), a fresh ', ...
        'allocation for another run succeeds; no stale lock state'];

end

% -------------------------------------------------------------------------

function Detail = checkFullRoundTripVerification()
%CHECKFULLROUNDTRIPVERIFICATION MAT/JSON/CSV content round-trip (F-06).

    PreprocessID = 'Run_938_20260101_000000__PP_20260101_000000_01';
    [Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory] = buildExportFixture( ...
        'RoundTripFixture', PreprocessID);
    Report.NumericMarkers = [1.5, NaN, Inf, -Inf];

    [Artifacts, FinalReport] = preprocessing.ExportPreprocessedData( ...
        Config, Data, ProcessedStreams, Aligned, Report, ...
        OutputDirectory);

    % MAT
    Loaded = load(Artifacts.MatFile);
    Pd = Loaded.PreprocessedData;
    RequiredSections = { ...
        'RunInfo', 'Configuration', 'OriginalData', 'NativeRate', ...
        'AlignedData', 'QualitySummary', 'ProcessingInfo'};
    expectEqual(all(ismember( ...
        RequiredSections, fieldnames(Pd))), true, 'MAT sections');

    Contracts = preprocessing.SensorDataContracts();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        expectEqual(Pd.OriginalData.(StreamName).SourceRowIdx, ...
            Data.Streams.(StreamName).SourceRowIdx, ...
            [StreamName ' OriginalData rows']);
        expectEqual(Pd.OriginalData.(StreamName).SourceTime_s, ...
            Data.Streams.(StreamName).SourceTime_s, ...
            [StreamName ' original timestamps']);
        expectEqual(Pd.NativeRate.(StreamName), ...
            ProcessedStreams.(StreamName), ...
            [StreamName ' NativeRate content']);

    end

    expectEqual(Pd.ProcessingInfo.PreprocessID, PreprocessID, ...
        'MAT PreprocessID');
    expectEqual(Pd.ProcessingInfo.GroundTruthExcluded, true, 'GT flag');
    expectEqual(isfield(Pd.NativeRate.IMU, 'VelocityBody_mps'), false, ...
        'no GT fields');

    % JSON
    Decoded = jsondecode(fileread(Artifacts.JsonFile));
    expectEqual(Decoded.RunInfo.PreprocessID, PreprocessID, 'JSON ID');
    expectEqual(Decoded.RunInfo.Status, FinalReport.Status, ...
        'JSON status');
    expectEqual(islogical(Decoded.RunInfo.ApprovalUsed), true, ...
        'logical stays logical');
    expectEqual(Decoded.NumericMarkers{2}, 'NaN', 'NaN marker');
    expectEqual(Decoded.NumericMarkers{3}, 'Inf', 'Inf marker');
    expectEqual(Decoded.NumericMarkers{4}, '-Inf', '-Inf marker');
    expectEqual(isnumeric(Decoded.NumericMarkers{1}), true, ...
        'finite value stays numeric');
    expectEqual(Decoded.RunRecorded.Status, FinalReport.RunRecorded.Status, ...
        'provenance serialized');

    % CSVs (all four)
    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};
        TableData = readtable(Artifacts.ReviewFiles.(StreamName));
        Stream = ProcessedStreams.(StreamName);
        expectEqual(height(TableData), Stream.SampleCount, ...
            [StreamName ' rows']);
        expectEqual(TableData.SourceRowIdx, Stream.SourceRowIdx, ...
            [StreamName ' row trace']);
        expectEqual(TableData.Time_s, Stream.Time_s, ...
            [StreamName ' timestamps']);
        expectEqual(TableData.Flags_NonFiniteMeasurement, ...
            double(Stream.Flags.NonFiniteMeasurement), ...
            [StreamName ' flags']);

    end

    Detail = [ ...
        'full round-trip verified for MAT (7 sections, audit rows, ', ...
        'native content, PreprocessID, GT exclusion), JSON (ID, ', ...
        'status, logicals, NaN/Inf markers, provenance) and all four ', ...
        'CSVs (rows, row trace, timestamps, flags)'];

end

% -------------------------------------------------------------------------

function Detail = checkProvenanceOffsetMapping()
%CHECKPROVENANCEOFFSETMAPPING Original rows survive alignment (F-03).

    Config = preprocessing.PreprocessingConfig( ...
        'AlignmentEnabled', true, ...
        'MaxSampleAge_s', struct('IMU', 0.5, 'AirData', 0.5));
    Ref = rawProcessedStream('IMU', (0:9).' * 0.1, (1:10).', ...
        {zeros(10, 1), zeros(10, 1), -9.8 * ones(10, 1), ...
         zeros(10, 1), zeros(10, 1), zeros(10, 1)});
    Src = rawProcessedStream('AirData', [0; 0.25; 0.55; 0.85; 0.95], ...
        (101:105).', {[10; 20; 30; 40; 50], ...
        [100; 200; 300; 400; 500]});

    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, struct('IMU', Ref, 'AirData', Src));

    expectEqual(Aligned.Streams.AirData.SourceRowIdx, ...
        [101; 101; 101; 102; 102; 102; 103; 103; 103; 104], ...
        'original file rows carried, not array indices');

    Detail = [ ...
        'with SourceRowIdx = 101..105 (original rows != array ', ...
        'indices), the aligned output carries the ORIGINAL rows via ', ...
        'Stream.SourceRowIdx mapping (F-03 strengthened)'];

end

function Detail = checkProvenanceRowOrderInvariant()
%CHECKPROVENCANCEROWORDERINVARIANT The upstream invariant is enforced.

    Config = preprocessing.PreprocessingConfig();
    Stream = rawProcessedStream('AirData', [0; 0.1], [101; 102], ...
        {[10; 20], [100; 200]});

    assertErrorId( ...
        @() preprocessing.ProcessSensorTimestamps( ...
            Config, Stream, 'AirData'), ...
        'Preprocessing:ProcessSensorTimestamps:RowOrderViolation');

    Detail = [ ...
        'ProcessSensorTimestamps rejects any SourceRowIdx other than ', ...
        '1..N (RowOrderViolation): within the sanctioned pipeline the ', ...
        'original-file-row guarantee is an enforced invariant'];

end

% =========================================================================
%% PHASE 5 HELPERS
% =========================================================================

function [Config, Data, ProcessedStreams, Aligned, Report, ...
    OutputDirectory] = buildExportFixture(FixtureName, PreprocessID)
%BUILDEXPORTFIXTURE Full export-ready fixture with a fresh output dir.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed(FixtureName, false);
    Aligned = preprocessing.BuildAlignedSensorData( ...
        Config, ProcessedStreams);
    OutputDirectory = tempname(fixtureDir(FixtureName));
    RunInfo = buildRunInfo(OutputDirectory, PreprocessID);
    Report = preprocessing.BuildPreprocessingReport( ...
        Config, Data, ProcessedStreams, Aligned, RunInfo);

end

function [Config, Data, ProcessedStreams, RunInfo] = metadataFixture( ...
    FixtureName, MetadataContent)
%METADATAFIXTURE Synthetic run fixture with optional RunMetadata.json.

    [Config, Data, ProcessedStreams] = ...
        buildSyntheticProcessed(FixtureName, false);
    FixtureRoot = fixtureDir(FixtureName);
    RunInfo = buildRunInfo('', ...
        'Run_930_20260101_000000__PP_20260101_000000_01');
    RunInfo.RunDirectory = FixtureRoot;

    if ~isempty(MetadataContent)

        fid = fopen(fullfile(FixtureRoot, 'RunMetadata.json'), 'w');
        fprintf(fid, '%s', MetadataContent);
        fclose(fid);

    end

end

function Stream = rawProcessedStream(SensorName, Time_s, SourceRowIdx, ...
    ChannelColumns)
%RAWPROCESSEDSTREAM Hand-built processed-shaped stream (deliberately
%   bypasses Phase 4 to exercise provenance contracts in isolation).

    RowCount = numel(Time_s);
    Stream = struct();
    Stream.Status = 'Loaded';
    Stream.Time_s = Time_s(:);
    Stream.SourceRowIdx = SourceRowIdx(:);
    Stream.RowValid = true(RowCount, 1);
    Stream.SegmentID = ones(RowCount, 1);
    Stream.Available = true(RowCount, 1);
    Stream.MeasurementValid = true(RowCount, 1);
    Stream.NominalPeriod_s = 0.5;

    Contracts = preprocessing.SensorDataContracts();
    Channels = Contracts.(SensorName).Channels;
    ColIdx = 0;

    for Index = 1:numel(Channels)

        FieldName = Channels(Index).CanonicalField;

        if strcmp(FieldName, 'Time_s') || strcmp(FieldName, 'Available')
            continue;
        end

        ColIdx = ColIdx + 1;
        Stream.(FieldName) = ChannelColumns{ColIdx}(:);

    end

end

function Audit = dependencyAudit(ExtraFiles)
%DEPENDENCYAUDIT Dependency closure, classification and cycle detection.
%   Built on matlab.codetools.requiredFilesAndProducts (closure and
%   products) plus a directed call-graph edge analysis (edges extracted
%   from package-qualified and bare call references; cycles found by
%   DFS). The API returns a flat closure only, so the graph method is
%   derived from source references rather than file counts.

    if nargin < 1
        ExtraFiles = {};
    end

    Paths = preprocessing.ProjectPaths();
    PackageDir = fullfile(Paths.ProjectRoot, '+preprocessing');
    Planned = plannedModuleNames();
    PlannedFiles = cellfun(@(N) fullfile(PackageDir, N), Planned, ...
        'UniformOutput', false);

    Audit.PlannedFiles = PlannedFiles;
    FoundMask = cellfun(@isfile, PlannedFiles);
    Audit.FoundFiles = PlannedFiles(FoundMask);
    Audit.Missing = Planned(~FoundMask);
    Audit.AllAccounted = isempty(Audit.Missing);

    InputFiles = [Audit.FoundFiles(:); ExtraFiles(:)];

    [Closure, Products] = ...
        matlab.codetools.requiredFilesAndProducts(InputFiles);

    if ischar(Closure)
        Closure = {Closure};
    end

    Audit.ClosureFiles = Closure(:);
    Audit.Products = Products;

    if isempty(Products)
        ProductNames = {};
    else
        ProductNames = {Products.Name};
    end

    ApprovedProducts = {'MATLAB'};
    LowerProducts = cellfun(@lower, ProductNames, 'UniformOutput', false);
    LowerApproved = cellfun(@lower, ApprovedProducts, ...
        'UniformOutput', false);
    Audit.UnexpectedProducts = ...
        ProductNames(~ismember(LowerProducts, LowerApproved));

    UnexpectedProject = {};
    UnexpectedPackageFile = {};
    ExternalFiles = {};

    for Index = 1:numel(Closure)

        Entry = Closure{Index};
        [~, BaseName, ~] = fileparts(Entry);

        if startsWith(Entry, [PackageDir filesep], 'IgnoreCase', true)

            if ~ismember([BaseName '.m'], Planned)

                UnexpectedPackageFile{end + 1} = Entry;

            end

        elseif startsWith(Entry, [Paths.ProjectRoot filesep], ...
                'IgnoreCase', true)

            UnexpectedProject{end + 1} = Entry;

        else

            ExternalFiles{end + 1} = Entry;

        end

    end

    Audit.UnexpectedProject = UnexpectedProject;
    Audit.UnexpectedPackageFile = UnexpectedPackageFile;
    Audit.ExternalFiles = ExternalFiles;
    Audit.UnexpectedProjectDetected = ~isempty(UnexpectedProject);

    % Directed edges over the audited modules.
    AuditedNames = cellfun(@(F) fileBaseName(F), InputFiles, ...
        'UniformOutput', false);
    Adjacency = containers.Map('KeyType', 'char', 'ValueType', 'any');
    EdgeCount = 0;

    for Index = 1:numel(InputFiles)

        Text = fileread(InputFiles{Index});
        Targets = {};

        for NameIndex = 1:numel(AuditedNames)

            Name = AuditedNames{NameIndex};

            if isempty(Name) || strcmp(Name, AuditedNames{Index})
                continue;
            end

            % NOTE: in MATLAB regexp '\b' is a backspace, not a word
            % boundary; '\>' asserts end-of-word.
            if ~isempty(regexp(Text, ...
                    ['preprocessing\.\s*' Name '\>'], 'once')) || ...
                    ~isempty(regexp(Text, ...
                    ['(?<![\w.])' Name '\s*\('], 'once'))

                Targets{end + 1} = Name;

            end

        end

        Adjacency(AuditedNames{Index}) = Targets;
        EdgeCount = EdgeCount + numel(Targets);

    end

    Audit.EdgeCount = EdgeCount;
    [CycleFound, Cycles] = findCycles(Adjacency, AuditedNames);
    Audit.Cycles = Cycles;
    Audit.CycleDetected = CycleFound;

end

function Name = fileBaseName(FilePath)
%FILEBASENAME File base name (function name for a .m file).

    [~, Name] = fileparts(FilePath);

end

function [CycleFound, Cycles] = findCycles(Adjacency, Names)
%FINDCYCLES DFS cycle detection over the directed call graph.

    CycleFound = false;
    Cycles = {};
    State = containers.Map('KeyType', 'char', 'ValueType', 'double');

    for Index = 1:numel(Names)

        if isKey(Adjacency, Names{Index})
            State(Names{Index}) = 0;
        end

    end

    for Index = 1:numel(Names)

        if isKey(State, Names{Index}) && State(Names{Index}) == 0

            [CycleFound, Cycles] = dfsVisit(Names{Index}, Adjacency, ...
                State, {}, CycleFound, Cycles);

        end

    end

end

function [CycleFound, Cycles] = dfsVisit(Node, Adjacency, State, Path, ...
    CycleFound, Cycles)
%DFSVISIT Recursive DFS; State 0=unseen, 1=on stack, 2=done.

    State(Node) = 1;
    Path{end + 1} = Node;

    if isKey(Adjacency, Node)
        Targets = Adjacency(Node);
    else
        Targets = {};
    end

    for Index = 1:numel(Targets)

        Target = Targets{Index};

        if ~isKey(State, Target)
            continue;
        end

        if State(Target) == 1

            CycleFound = true;
            Start = find(strcmp(Path, Target), 1);
            Cycles{end + 1} = strjoin(Path(Start:end), ' -> ');

        elseif State(Target) == 0

            [CycleFound, Cycles] = dfsVisit(Target, Adjacency, State, ...
                Path, CycleFound, Cycles);

        end

    end

    State(Node) = 2;

end

function Names = plannedModuleNames()
%PLANNEDMODULENAMES The 19 planned Block 9 source modules (T0 contract).

    Names = { ...
        'ProjectPaths.m', ...
        'SensorDataContracts.m', ...
        'QualityFlags.m', ...
        'PreprocessingConfig.m', ...
        'ValidatePreprocessingConfig.m', ...
        'DiscoverRuns.m', ...
        'InspectRun.m', ...
        'LoadSensorData.m', ...
        'NormalizeSensorSchema.m', ...
        'NormalizeSensorUnits.m', ...
        'ProcessSensorTimestamps.m', ...
        'InspectSensorQuality.m', ...
        'DetectSensorOutliers.m', ...
        'BuildAlignedSensorData.m', ...
        'BuildPreprocessingReport.m', ...
        'ExportPreprocessedData.m', ...
        'PreprocessRun.m', ...
        'GetPreprocessingReport.m', ...
        'RunPreprocessingTests.m'};

end

function OutputDirectory = makeManualPreprocessDir( ...
    RunID, PreprocessID, FileNames, FileContents)
%MAKEMANUALPREPROCESSDIR Review fixture output directory for retrieval
%   tests (test fixture only; never a production result).

    Paths = preprocessing.ProjectPaths();
    OutputDirectory = fullfile( ...
        Paths.PreprocessedRoot, RunID, PreprocessID);
    mkdir(OutputDirectory);

    for Index = 1:numel(FileNames)

        Target = fullfile(OutputDirectory, FileNames{Index});
        Parent = fileparts(Target);

        if ~isempty(Parent) && ~isfolder(Parent)

            mkdir(Parent);

        end

        fid = fopen(Target, 'w');
        fprintf(fid, '%s\n', FileContents{Index});
        fclose(fid);

    end

end

function Stream = processChain(Config, Stream, StreamName)
%PROCESSCHAIN Run the Phase 4 processing chain on one stream.

    Stream = preprocessing.ProcessSensorTimestamps( ...
        Config, Stream, StreamName);
    Stream = preprocessing.InspectSensorQuality( ...
        Config, Stream, StreamName);
    Stream = preprocessing.DetectSensorOutliers( ...
        Config, Stream, StreamName);
    Stream.Status = 'Loaded';

end

function Stream = buildAirDataStream(Time_s, Tas)
%BUILDAIRSTREAM Build a normalized synthetic AirData stream.

    RowCount = numel(Time_s);

    Raw = struct();
    Raw.Time_s = Time_s(:);
    Raw.TrueAirspeed_mps = Tas(:);
    Raw.DynamicPressure_Pa = Tas(:) * 10;
    Raw.Available = ones(RowCount, 1);

    Stream = preprocessing.NormalizeSensorSchema(Raw, 'AirData', ...
        'RealisticCsv');
    Stream = preprocessing.NormalizeSensorUnits(Stream, 'AirData');

end

function [Config, Data, ProcessedStreams] = buildSyntheticProcessed( ...
    FixtureName, SkipGnss, RunName)
%BUILDSYNTHETICPROCESSED Fixture run dir loaded and fully processed.

    if nargin < 2
        SkipGnss = false;
    end

    if nargin < 3
        RunName = '';
    end

    FixtureRoot = fixtureDir(FixtureName);

    if ~isempty(RunName)
        FixtureRoot = fullfile(FixtureRoot, RunName);
    end
    SourceFolder = fullfile(FixtureRoot, 'RealisticSensorTelemetry');

    if ~isfolder(SourceFolder)
        mkdir(SourceFolder);
    end

    writeFixtureCsv(fullfile(SourceFolder, 'IMU.csv'), ...
        'IMU', 'RealisticCsv', 5);

    if ~SkipGnss
        writeFixtureCsv(fullfile(SourceFolder, 'GNSS.csv'), ...
            'GNSS', 'RealisticCsv', 5);
    end

    writeFixtureCsv(fullfile(SourceFolder, 'AirData.csv'), ...
        'AirData', 'RealisticCsv', 5);
    writeFixtureCsv(fullfile(SourceFolder, 'Magnetometer.csv'), ...
        'Magnetometer', 'RealisticCsv', 5);

    Config = preprocessing.PreprocessingConfig();
    Data = preprocessing.LoadSensorData(FixtureRoot, Config, 'Auto');

    ProcessedStreams = struct();
    Contracts = preprocessing.SensorDataContracts();

    for Index = 1:numel(Contracts.Streams)

        StreamName = Contracts.Streams{Index};

        if strcmp(Data.Streams.(StreamName).Status, 'Loaded')

            ProcessedStreams.(StreamName) = processChain( ...
                Config, Data.Streams.(StreamName), StreamName);

        end

    end

end

function RunInfo = buildRunInfo(OutputDirectory, PreprocessID)
%BUILDRUNINFO Synthetic RunInfo for report/export unit tests.

    RunInfo = struct( ...
        'RunID', 'Run_905_20260101_000000', ...
        'PreprocessID', PreprocessID, ...
        'RunDirectory', '', ...
        'OutputDirectory', OutputDirectory, ...
        'Eligibility', 'NotInspected', ...
        'Category', 'SyntheticFixture', ...
        'Status', 'SUCCESS', ...
        'Warnings', {{}}, ...
        'Errors', {{}}, ...
        'ApprovalUsed', false);

end
