function Paths = ProjectPaths(ProjectRootOverride)
%PROJECTPATHS Resolve the ASRTE project root and Block 10 project paths.
%
%   Paths = PROJECTPATHS() resolves the project root from the location of
%   the +estimation package folder and returns the project paths used by
%   the Block 10 estimation pipeline. The current working directory and
%   hard-coded absolute paths are never used.
%
%   Paths = PROJECTPATHS(ProjectRootOverride) accepts an explicit project
%   root. This form exists for the ISOLATED development phase only: while
%   the +estimation package lives in the external development workspace,
%   self-location cannot find the frozen project tree, and the caller
%   (the workspace test suite) supplies the real project root explicitly.
%   The override is validated against the required layout exactly like
%   the self-located root; after integration into the project root the
%   no-argument form is authoritative and no override is needed.
%
%   Output fields:
%       ProjectRoot      - project root (parent of the +package folders)
%       ProductionRoot   - production/
%       RunsRoot         - production/Runs
%       RegistryFile     - production/RunRegistry.json
%       PreprocessedRoot - production/Preprocessed
%       EstimationRoot   - production/Estimation (may not exist yet)
%
%   The layout check requires the frozen Block 1-9 package folders and
%   the production folder to be present.
%
%   INTERNAL function. Not part of the public Block 10 API. The public
%   API is EstimationConfig, DiscoverRuns, InspectRun,
%   RunStateReconstruction and GetEstimationReport.
%
%   See also: EstimationConfig, LoadPreprocessedRun, DiscoverRuns.

    %% Resolve Project Root

    if nargin >= 1 && ~isempty(ProjectRootOverride)

        if ~(ischar(ProjectRootOverride) || ...
                (isstring(ProjectRootOverride) && ...
                isscalar(ProjectRootOverride)))

            error( ...
                'Estimation:ProjectPaths:InvalidOverride', ...
                ['ProjectRootOverride must be a character vector or ', ...
                 'scalar string.']);

        end

        ProjectRoot = char(ProjectRootOverride);

    else

        PackageDirectory = fileparts(mfilename('fullpath'));
        [~, PackageFolderName] = fileparts(PackageDirectory);

        if ~strcmp(PackageFolderName, '+estimation')

            error( ...
                'Estimation:ProjectPaths:InvalidPackageLocation', ...
                ['ProjectPaths must reside in the +estimation package ', ...
                 'folder; resolved folder was "%s".'], ...
                PackageFolderName);

        end

        ProjectRoot = fileparts(PackageDirectory);

    end

    %% Validate Project Root Layout

    RequiredPackages = { ...
        '+config', ...
        '+coordinates', ...
        '+dynamics', ...
        '+flightscenario', ...
        '+groundtruthtelemetry', ...
        '+noisemodels', ...
        '+preprocessing', ...
        '+sensormodels', ...
        '+sensorsimulation'};

    for Index = 1:numel(RequiredPackages)

        if ~isfolder(fullfile(ProjectRoot, RequiredPackages{Index}))

            error( ...
                'Estimation:ProjectPaths:InvalidRootLayout', ...
                ['Project root "%s" does not contain required ', ...
                 'package folder "%s".'], ...
                ProjectRoot, ...
                RequiredPackages{Index});

        end

    end

    ProductionRoot = fullfile(ProjectRoot, 'production');

    if ~isfolder(ProductionRoot)

        error( ...
            'Estimation:ProjectPaths:InvalidRootLayout', ...
            ['Project root "%s" does not contain the required ', ...
             'production folder.'], ...
            ProjectRoot);

    end

    %% Build Output

    Paths = struct();
    Paths.ProjectRoot = ProjectRoot;
    Paths.ProductionRoot = ProductionRoot;
    Paths.RunsRoot = fullfile(ProductionRoot, 'Runs');
    Paths.RegistryFile = fullfile(ProductionRoot, 'RunRegistry.json');
    Paths.PreprocessedRoot = fullfile(ProductionRoot, 'Preprocessed');
    Paths.EstimationRoot = fullfile(ProductionRoot, 'Estimation');

end
