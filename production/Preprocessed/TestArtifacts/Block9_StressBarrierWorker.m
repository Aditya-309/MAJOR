function Block9_StressBarrierWorker(SentinelDir, WorkerIndex, FixtureRoot, RunID)
%BLOCK9_STRESSBARRIERWORKER Barrier-synchronized worker.
Pid = feature('getpid');
Stamp = @() char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
Start = Stamp();
fid = fopen(fullfile(SentinelDir, sprintf('ready_%02d.txt', WorkerIndex)), 'w');
fprintf(fid, 'PID=%d\n', Pid);
fclose(fid);
while ~isfile(fullfile(SentinelDir, 'GO')), pause(0.05); end
Release = Stamp();
try
    Result = preprocessing.PreprocessRun(RunID, preprocessing.PreprocessingConfig(), ...
        struct('RunDirectory', FixtureRoot, 'ApproveUnregistered', true));
    Status = Result.Status;
    PreprocessID = Result.PreprocessID;
    OutDir = Result.OutputDirectory;
    ErrId = '';
catch Failure
    Status = 'FAILED';
    PreprocessID = 'none';
    OutDir = '';
    ErrId = Failure.identifier;
end
End = Stamp();
fid = fopen(fullfile(SentinelDir, sprintf('result_%02d.txt', WorkerIndex)), 'w');
fprintf(fid, 'WORKER=%02d\n', WorkerIndex);
fprintf(fid, 'PID=%d\n', Pid);
fprintf(fid, 'START=%s\n', Start);
fprintf(fid, 'RELEASE=%s\n', Release);
fprintf(fid, 'END=%s\n', End);
fprintf(fid, 'STATUS=%s\n', Status);
fprintf(fid, 'WORKER_ID=%s\n', PreprocessID);
fprintf(fid, 'OUTDIR=%s\n', OutDir);
fprintf(fid, 'ERROR=%s\n', ErrId);
fclose(fid);
end
