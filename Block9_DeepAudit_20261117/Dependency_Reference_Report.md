# DEPENDENCY AND REFERENCE REPORT

Scan scope: all text-bearing project files (`.m .mlx .ps1 .bat .cmd .py .json .txt .md .csv .xml .yaml .yml`), 5,708 files scanned (audit report folders excluded). Searched for exact paths, directory names, fixture names, RunIDs, PreprocessIDs, and filenames.

## Reference summary

| Candidate | # referencing files | Referenced by | Status |
|---|---|---|---|
| `Run_001_20261107_110817.zip` | 0 | no reference found | not code-referenced |
| `zipz` | 0 | no reference found | not code-referenced |
| `New folder` | 0 | no reference found | not code-referenced |
| `source data` | 3 | active source | referenced |
| `PreprocessingValidationEvidence` | 0 | no reference found | not code-referenced |
| `RunOnePreprocessing` | 1 | test script / evidence / inventory | referenced |
| `StressFixtures` | 280 | active source | referenced |
| `Phase3Fixtures` | 427 | active source | referenced |
| `TestArtifacts` | 721 | active source | referenced |
| `BaselineManifest` | 10 | test script / evidence / inventory | referenced |
| `.block9_` | 1 | test script / evidence / inventory | referenced |
| `Block9_Upload_Packages` | 1 | test script / evidence / inventory | referenced |
| `Run_900` | 29 | active source | referenced |
| `Run_971` | 42 | active source | referenced |
| `Run_974` | 173 | active source | referenced |
| `Run_985` | 51 | active source | referenced |

## Key findings

- **`Run_001_20261107_110817.zip`, `zipz/`, `New folder.zip`:** **no references** in any scanned file. Not code dependencies. (Note: all three are now ABSENT — see Archive_Verification_Report.md.)
- **`source data`**: referenced by **`+sensormodels/GenerateIdealAirData.m`** (Block 7 active source) — a real code reference. **RISK:** `source data/` is now absent (see discrepancy). This reference must be checked: if `GenerateIdealAirData.m` reads a file under `source data/`, its absence could break Block 7. Classified `REVIEW_DEPENDENCY`.
- **`StressFixtures`, `Phase3Fixtures`:** referenced by the harnesses (`RunPreprocessingTests.m`, `RunPreprocessingStressTests.m`) as **fixture-generation locations** — the harness writes them, so they are regenerated on test run (not a hard dependency on existing data).
- **`Run_900/901/902/908/971/974/985/996`:** appear in the harnesses as **fixture RunID generators** (the harness creates these output folders). Their `PreprocessingReport.json` files also self-reference their RunID. No code READS existing outputs. Reproducible by re-running the harness.
- **`BaselineManifest`:** referenced by integrity/traceability reports (protected baseline hash anchor). Keep.
- **`TestArtifacts` / `Block9_Upload_Packages`:** referenced by harnesses (evidence path) and the package manifests. Keep.

## Reference classification legend
- No reference found → not a code dependency (but absence of reference does NOT alone prove disposable).
- Referenced by active source → keep (code depends on it).
- Referenced by test script → keep reusable scripts; their generated outputs are reproducible.
- Referenced by evidence/manifest → keep for traceability.

**Uncertain/ambiguous:** the `source data` → `GenerateIdealAirData.m` reference (path vs comment to be confirmed). `Run_9xx` RunIDs are generated, not consumed — verified by harness inspection.