# PROPOSED CLEAN PROJECT STRUCTURE (Block 10 preparation)

Proposed destinations only — **nothing relocated in this phase**. Existing MATLAB package paths and `production/` layout are preserved; `+preprocessing` and Blocks 1–8 stay put.

```
MAJOR/
├── +config/ … +sensorsimulation/      KEEP (Blocks 1-8 source, frozen)
├── +preprocessing/                    KEEP (Block 9 source, protected)
├── production/
│   ├── Runs/                          KEEP (original run data, frozen)
│   ├── RunRegistry.json               KEEP (frozen)
│   ├── WorkingRuns/  FailedRuns/      KEEP
│   ├── PreprocessingValidationEvidence/  KEEP (permanent validation)
│   ├── *.m, testrunscripts.txt        KEEP (production tooling)
│   └── Preprocessed/
│       ├── Run_001_*/                 KEEP (14 runs)
│       │   └── [15 canonical __PP_* outputs]   KEEP_PROTECTED_CANONICAL_OUTPUT
│       │   └── [80 historical __PP_*]          -> Block9_Development_Archive/
│       ├── Run_001_20260906_160342/   -> Block9_Development_Archive/ (unregistered)
│       ├── Run_9xx_*/                 -> Block9_Development_Archive/ (synthetic)
│       └── TestArtifacts/
│           ├── [final closure evidence, manifests, integrity, scripts]  KEEP
│           ├── Barrier_20261116_212116_*/, Concurrency_20261116_153000_*/  KEEP (final)
│           ├── [dev/intermediate stress + Phase5 + old concurrency]  -> Archive
│           ├── StressFixtures/        -> Block9_Development_Archive/regenerable_fixtures/
│           └── Phase3Fixtures/        -> Block9_Development_Archive/regenerable_fixtures/
├── source data/                       KEEP (original docs) — RESTORE (currently absent)
├── Block9_Upload_Packages/            KEEP (final review evidence)
├── Block9_Closure_Source_*.zip        KEEP
├── Block9_Closure_TestArtifacts_*.zip KEEP
├── RunOnePreprocessing.m              KEEP (interactive demo)
├── JSBSim_Test/                       REVIEW (provenance)
├── Block9_PostCompletion_Audit_20261117/  KEEP (Phase 1 audit)
├── Block9_DeepAudit_20261117/         KEEP (this Phase 2A audit)
│
├── [PROPOSED] Block9_Development_Archive/
│   ├── dev_outputs_registered_runs/
│   ├── dev_outputs_unregistered_run/
│   ├── synthetic_stress_outputs/
│   ├── regenerable_fixtures/
│   └── intermediate/   (dev stress, Phase5, old concurrency)
│
└── [PROPOSED] Block10_WorkingArea/
```

### Relocation notes

- All relocations require explicit Phase 2B approval (this manifest plans only).
- **`source data/` must be RESTORED, not moved** — it is original project documentation and code-referenced.
- Fixtures (`StressFixtures`/`Phase3Fixtures`): demonstrate regeneration in an isolated copy before permanent deletion.
- MATLAB package paths and `production/` structure unchanged; no package relocated.