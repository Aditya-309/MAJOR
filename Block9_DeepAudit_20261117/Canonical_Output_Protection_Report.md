# CANONICAL OUTPUT PROTECTION REPORT

Source of truth: `production/PreprocessingValidationEvidence/Block9_RegistryValidation_20261116_223106/Block9_PreprocessingOutput_Manifest.csv` (14 registry outputs) + the interactive demo output.
Independently verified each output exists with all six required artifacts (PreprocessedData.mat, PreprocessingReport.json, Review/{IMU,GNSS,AirData,Magnetometer}.csv).

| # | PreprocessID | Parent RunID | Exists | 6 artifacts | Status | ProcessingTimestamp | Warn | Err | InManifest |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Run_001_20260906_160634__PP_20261116_222744_01 | Run_001_20260906_160634 | True | ALL | SUCCESS | 2026-11-16T22:27:44 | 0 | 0 | yes |
| 2 | Run_001_20260906_161035__PP_20261116_222746_01 | Run_001_20260906_161035 | True | ALL | SUCCESS | 2026-11-16T22:27:46 | 0 | 0 | yes |
| 3 | Run_001_20260906_161043__PP_20261116_222748_01 | Run_001_20260906_161043 | True | ALL | SUCCESS | 2026-11-16T22:27:49 | 0 | 0 | yes |
| 4 | Run_001_20260906_161050__PP_20261116_222750_01 | Run_001_20260906_161050 | True | ALL | SUCCESS | 2026-11-16T22:27:50 | 0 | 0 | yes |
| 5 | Run_001_20260906_161056__PP_20261116_222752_01 | Run_001_20260906_161056 | True | ALL | SUCCESS | 2026-11-16T22:27:52 | 0 | 0 | yes |
| 6 | Run_001_20260906_161104__PP_20261116_222754_01 | Run_001_20260906_161104 | True | ALL | SUCCESS | 2026-11-16T22:27:54 | 0 | 0 | yes |
| 7 | Run_001_20260906_161111__PP_20261116_222756_01 | Run_001_20260906_161111 | True | ALL | SUCCESS | 2026-11-16T22:27:56 | 0 | 0 | yes |
| 8 | Run_001_20260923_182027__PP_20261116_222759_01 | Run_001_20260923_182027 | True | ALL | SUCCESS | 2026-11-16T22:27:59 | 0 | 0 | yes |
| 9 | Run_001_20260923_182157__PP_20261116_222801_01 | Run_001_20260923_182157 | True | ALL | SUCCESS | 2026-11-16T22:28:01 | 0 | 0 | yes |
| 10 | Run_001_20260928_133100__PP_20261116_222803_01 | Run_001_20260928_133100 | True | ALL | SUCCESS | 2026-11-16T22:28:04 | 0 | 0 | yes |
| 11 | Run_001_20261015_104138__PP_20261116_222806_01 | Run_001_20261015_104138 | True | ALL | SUCCESS | 2026-11-16T22:28:06 | 0 | 0 | yes |
| 12 | Run_001_20261015_111942__PP_20261116_222808_01 | Run_001_20261015_111942 | True | ALL | SUCCESS | 2026-11-16T22:28:08 | 0 | 0 | yes |
| 13 | Run_001_20261015_114742__PP_20261116_222810_01 | Run_001_20261015_114742 | True | ALL | SUCCESS | 2026-11-16T22:28:10 | 0 | 0 | yes |
| 14 | Run_001_20261107_110817__PP_20261116_215747_01 | Run_001_20261107_110817 | True | ALL | SUCCESS | 2026-11-16T21:57:47 | 0 | 0 | no (interactive) |
| 15 | Run_001_20261107_110817__PP_20261116_222812_01 | Run_001_20261107_110817 | True | ALL | SUCCESS | 2026-11-16T22:28:12 | 0 | 0 | yes |

**Result: all 15 canonical outputs PRESENT and VERIFIED** (6/6 artifacts, SUCCESS, 0 warnings, 0 errors). 14 are registry-validation outputs (in manifest, `AllArtifactsPresent=1`); 1 is the interactive demonstration (`Run_001_20261107_110817__PP_20261116_215747_01`). Classification: **KEEP_PROTECTED_CANONICAL_OUTPUT**. Do not move, delete, or overwrite.