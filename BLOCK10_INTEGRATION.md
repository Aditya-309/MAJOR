# Block 10 — Integration Notes and Known Limitations

Package: `+estimation` (40 source files). Integrated from
`MAJOR_Block10_Workspace/Source/+estimation` (isolated workspace retained as the
implementation and verification archive). MATLAB R2024b + Sensor Fusion and Tracking
Toolbox. Public API: `EstimationConfig`, `ValidateEstimationConfig`, `ProjectPaths`,
`DiscoverRuns`, `InspectRun`, `RunStateReconstruction`, `GetEstimationReport`.
Production output convention: `production/Estimation/<RunID>/<EstimationID>/`
(unique, transactional, never overwriting; created on first use).

Ground truth (`GroundTruthTelemetry`) is consumed ONLY by
`estimation.EvaluateAgainstGroundTruth`, strictly after estimation completes. It is never
an estimator input, initialization source, tuning input, or measurement update.

## Known limitations (approved for integration with these documented)

### Block 5 — Noise generation (frozen; NOT modified)
- All sensor noise models create local `RandStream('mt19937ar','Seed',...)` instances from
  the SAME fixed default seed (`SensorNoiseConfig.m:35`, `Config.RandomSeed = 20260801`).
- Cross-channel independence is NOT established: identical seeds produce identical leading
  draws across sensors (empirically: IMU accelerometer, airspeed and magnetometer noise
  share identical first draws; cross-channel correlations are structural).
- The registered runs must NOT be described as independent noise realizations. They are
  deterministic, duration-keyed draw sequences from one fixed seed (14 registrations reduce
  to 3 distinct input sequences).

### Block 7 — Ground-truth generation (frozen; NOT modified)
- Scenario controls and initial conditions are not propagated into the executed JSBSim
  script (`BuildJSBSimScript` emits no control directives; `BuildGroundTruthTelemetry`
  does not consume `Scenario.Controls`/`Scenario.Events`; the script's `initialize=` path
  differs from the run's own `Init.xml`).
- Registered scenario names (StraightAndLevelCruise, ControlledClimb, CoordinatedTurn, ...)
  do NOT demonstrate that the requested maneuvers occurred. The generated truth for all
  runs is a brief settle transient followed by a static rest pose.
- Dynamic-flight performance remains UNVALIDATED. No dynamic-performance claim may be made.

### Block 10 — Estimator limitations
- Attitude covariance is overconfident under the available static-flight observability
  conditions (mechanism: accelerometer turn-on bias is inseparable from tilt in static
  flight; NEES ~218-310 vs the 9-DoF expectation of 9, attitude-dominant).
- Smoothed covariance calibration is weaker than forward covariance calibration.
- EKF/UKF superiority has NOT been established (the filters are indistinguishable in the
  available envelope).
- Magnetometer calibration has NOT been demonstrated; magnetometer results describe the
  simulated sensor (ideal WMM reference + white noise) only.
- Euler-angle singularity limitations (warning/stop thresholds; no aerobatic claim) and
  unmodeled sensor scale factors (Block 11 scope) remain as documented.
- Publication-grade uncertainty and dynamic-performance claims are UNSUPPORTED.

These limitations are reported for upstream action in Blocks 5 and 7; this integration
deliberately does not modify those frozen blocks.

---

## Addendum 2026-11-22 — A1 / A3 / A4 / B1 integration (user-authorized)

### A1 — 18-state GNSS position-bias estimator option
`Config.State.EnableGNSSBiasStates` (default OFF = bit-identical 15-state behavior).
ON: states 16-18 are Gauss-Markov GNSS position biases
(b_{k+1} = exp(-dt/tau) b_k, Q_bb = sigma_b^2 (1 - phi^2)), measurement model
z_pos = p + b, and the initialization P0 carries the joint leveling/bias prior
(Cov(delta theta, delta b) = -J_level * Sigma_a). Physical basis: the observed
position NEES elevation came from treating a slowly-varying GNSS bias as white
noise; the bias states close that gap honestly (no tuning).

### A4 — evaluation-layer statistical soundness
- NEES block decomposition (position / velocity / attitude) per estimate series,
  expected mean 3 per block; inconsistency is now attributed to the block causing it.
- Explicit DoF labels: NEES is the 9-DoF navigation block (bias states excluded;
  ground truth carries no bias channels), reported alongside StateDimension (15/18).
- `Report.Limitations`: covariance-optimism disclosure under low dynamics,
  single-run statistics caveat, smoothing honesty note.
- `SmoothingNEESDelta`: whether smoothing improved consistency, as computed.

### B1/A2 — validation lab (`ValidationLab/` folder, code only)
Analytic maneuvering truth in the exact frozen ground-truth schema (Blocks 5/8 run
unchanged on it) plus a seeded Monte-Carlo harness (independent trials,
Bar-Shalom 95% bands, seed manifests). Runs isolated in MAJOR_ValidationLab;
the frozen blocks and production data are never modified. Known limit: truth is
kinematic (analytic trajectories through the audited sensor equations), not
Block 3 6-DOF dynamics — by frozen-block design.

### Verification
Full regression suite (46 assertions, 0 failures): StatisticalCorrections 6/6,
ReviewerFindings 14/14, GNSSBiasStates 7/7, StatisticalReporting 9/9,
EstimationReportAssembly 6/6, RegressionBaseline 4/4 (frozen manifest,
estimator-package hash manifest, git provenance, root cleanliness).
End-to-end execution re-verified on real data (Run_001_20260906_161035 /
PP_20261121_204831_01, 18-state, ES_20261122_092501_01): NEES blocks
pos 0.76 / vel 2.73 / att 259.76 (total 269.20, expectation 9) - position and
velocity blocks CONSISTENT, attitude-dominant optimism as disclosed above;
NIS and all prior metrics unchanged from the pre-integration run on the same
input (pipeline numerically identical where the config is unchanged).

### Incident record (2026-11-22, fixed in 35b5e75)
The first end-to-end run after 1a4cf71 failed at report assembly: a stray
duplicated 'end' in the A4 BuildEstimationReport patch (parse error). Root
cause: .m files have no auto-linter in this toolchain and the suite did not
call the report assembler. Corrective actions: removed the defect; added
TestEstimationReportAssembly (report assembly from synthetic pipeline data,
current and legacy metric shapes) so the gap stays closed; A4 report fields
are isfield-guarded for compatibility with runs saved by earlier package
versions (export-recovery workflow). Rule now applied: every edited MATLAB
file gets checkcode plus at least one real execution before commit.
