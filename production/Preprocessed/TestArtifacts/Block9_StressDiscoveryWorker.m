function Block9_StressDiscoveryWorker(ResultFile)
%BLOCK9_STRESSDISCOVERYWORKER Sandbox discovery probe.
%   Runs with ONLY the sandbox package on the path.
try
    Config = preprocessing.PreprocessingConfig();
    T0 = tic;
    RunList = preprocessing.DiscoverRuns(Config);
    Elapsed = toc(T0);
    R = numel(RunList.Registered);
    U = numel(RunList.UnregisteredRuns);
    E = numel(RunList.EligibleRunIDs);
    I = R - E;
    X = numel(RunList.WorkingRuns) + numel(RunList.FailedRuns);
    Text = sprintf('STATUS=OK ELAPSED=%.3f TOTAL=%d REGISTERED=%d UNREGISTERED=%d ELIGIBLE=%d INELIGIBLE=%d EXCLUDEDTREE=%d', Elapsed, R + U + X, R, U, E, I, X);
catch Failure
    Text = sprintf('STATUS=ERROR ID=%s ', Failure.identifier);
end
fid = fopen(ResultFile, 'w');
fprintf(fid, '%s\n', Text);
fclose(fid);
end
