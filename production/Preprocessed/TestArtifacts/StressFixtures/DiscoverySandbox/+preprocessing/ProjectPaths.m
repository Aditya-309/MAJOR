function Paths = ProjectPaths()
%PROJECTPATHS Resolve the ASRTE project root and standard project paths.
%
%   Paths = PROJECTPATHS() resolves the project root from the location of
%   the +preprocessing package folder and returns the standard project
%   paths used by the Block 9 preprocessing pipeline.
%
%   The current working directory and hard-coded absolute paths are never
%   used. Returned paths are native character vectors.
%
%   Output structure fields:
%       ProjectRoot      - project root (parent of the +package folders)
%       ProductionRoot   - production folder
%       RunsRoot         - production/Runs
%       WorkingRunsRoot  - production/WorkingRuns
%       FailedRunsRoot   - production/FailedRuns
%       RegistryFile     - production/RunRegistry.json
%       PreprocessedRoot - production/Preprocessed
%
%   INTERNAL function. Not part of the public Block 9 API. The public API
%   is DiscoverRuns, InspectRun, PreprocessRun and GetPreprocessingReport.
%
%   See also: PreprocessingConfig, DiscoverRuns, PreprocessRun.

    %% Resolve Package Location
    %
    % mfilename('fullpath') returns the full path of this file inside the
    % +preprocessing package folder, independent of the MATLAB working
    % directory and of the project root location on disk.

    PackageDirectory = fileparts(mfilename('fullpath'));
    [~, PackageFolderName] = fileparts(PackageDirectory);

    if ~strcmp(PackageFolderName, '+preprocessing')

        error( ...
            'Preprocessing:ProjectPaths:InvalidPackageLocation', ...
            ['ProjectPaths must reside in the +preprocessing package ', ...
             'folder; resolved folder was "%s".'], ...
            PackageFolderName);

    end

    ProjectRoot = fileparts(PackageDirectory);

    %% Validate Project Root Layout

    RequiredPackages = { ...
        '+config', ...
        '+coordinates', ...
        '+dynamics', ...
        '+flightscenario', ...
        '+groundtruthtelemetry', ...
        '+noisemodels', ...
        '+sensormodels', ...
        '+sensorsimulation'};

    for Index = 1:numel(RequiredPackages)

        if ~isfolder(fullfile(ProjectRoot, RequiredPackages{Index}))

            error( ...
                'Preprocessing:ProjectPaths:InvalidRootLayout', ...
                ['Project root "%s" does not contain required ', ...
                 'package folder "%s".'], ...
                ProjectRoot, ...
                RequiredPackages{Index});

        end

    end

    ProductionRoot = fullfile(ProjectRoot, 'production');

    if ~isfolder(ProductionRoot)

        error( ...
            'Preprocessing:ProjectPaths:InvalidRootLayout', ...
            ['Project root "%s" does not contain the required ', ...
             'production folder.'], ...
            ProjectRoot);

    end

    %% Build Output

    Paths = struct();
    Paths.ProjectRoot = ProjectRoot;
    Paths.ProductionRoot = ProductionRoot;
    Paths.RunsRoot = fullfile(ProductionRoot, 'Runs');
    Paths.WorkingRunsRoot = fullfile(ProductionRoot, 'WorkingRuns');
    Paths.FailedRunsRoot = fullfile(ProductionRoot, 'FailedRuns');
    Paths.RegistryFile = fullfile(ProductionRoot, 'RunRegistry.json');
    Paths.PreprocessedRoot = fullfile(ProductionRoot, 'Preprocessed');

end
