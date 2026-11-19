param([string]$SentinelDir,[string]$MatlabExe,[string]$ProjectRoot,[string]$EvidenceDir,[string]$FixtureRoot,[string]$RunID,[int]$N)
$procs = @()
for ($i=1; $i -le $N; $i++) {
  $inner = "addpath('$ProjectRoot'); addpath('$EvidenceDir'); Block9_StressBarrierWorker('$SentinelDir',$i,'$FixtureRoot','$RunID')"
  $arg = '-batch "' + $inner + '"'
  $p = Start-Process -FilePath $MatlabExe -ArgumentList $arg -PassThru -WindowStyle Hidden
  $procs += $p
}
$deadline = (Get-Date).AddSeconds(300)
while ($true) {
  $ready = @(Get-ChildItem $SentinelDir -Filter "ready_*.txt" -ErrorAction SilentlyContinue)
  if ($ready.Count -ge $N) { break }
  if ((Get-Date) -gt $deadline) { break }
  Start-Sleep -Milliseconds 100
}
Set-Content -Path (Join-Path $SentinelDir "GO") -Value "go"
foreach ($p in $procs) { $p.WaitForExit() }
$lines = @()
foreach ($p in $procs) {
  $lines += "SUPERVISOR PID=$($p.Id) EXITCODE=$($p.ExitCode)"
}
Set-Content -Path (Join-Path $SentinelDir "exitcodes.txt") -Value $lines
