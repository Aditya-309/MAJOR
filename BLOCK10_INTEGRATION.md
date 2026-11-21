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
