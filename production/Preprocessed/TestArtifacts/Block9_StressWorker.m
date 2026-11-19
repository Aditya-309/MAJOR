function Block9_StressWorker(SentinelFile, FixtureRoot, RunID)
%BLOCK9_STRESSWORKER One independent stress worker process.
try
    Result = preprocessing.PreprocessRun(RunID, preprocessing.PreprocessingConfig(), ...
        struct('RunDirectory', FixtureRoot, 'ApproveUnregistered', true));
    Text = sprintf('WORKER=%s STATUS=%s ', Result.PreprocessID, Result.Status);
catch Failure
    Text = sprintf('WORKER=%s STATUS=FAILED(%s) ', 'none', Failure.identifier);
end
fid = fopen(SentinelFile, 'w');
fprintf(fid, '%s\n', Text);
fclose(fid);
end
