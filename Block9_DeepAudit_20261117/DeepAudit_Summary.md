# BLOCK 9 DEEP CLEANUP AUDIT — PHASE 2A SUMMARY

**Project:** `C:\Users\lalit\OneDrive\Documents\Aditya Docs\ENGINEERING\MAJOR`
**Date:** 2026-11-17
**Scope:** Phase 2A — deep read-only inspection of `production/Preprocessed` and `TestArtifacts`.
**Mode:** STRICTLY READ-ONLY. No files moved, deleted, renamed, modified, or overwritten. No preprocessing/stress run, no fixtures regenerated. All output is in this new `Block9_DeepAudit_20261117/` folder.

---

## ⚠ FILESYSTEM DISCREPANCY (read first)

Since the Phase 1 audit (17 Nov 2026), **34 files / ~564 MB vanished** from the project:

| Item | Size | Status |
|---|---|---|
| `production/Preprocessed/Run_001_20261107_110817.zip` | 336 MB | ABSENT (was recorded in Phase 1) |
| `zipz/` (9 ZIP backups) | 193 MB | ABSENT |
| `source data/` (23 original project docs) | 35 MB | ABSENT — **original documentation** |
| `.vscode/settings.json` | — | ABSENT |

Verified absent via 4 independent methods (os.path.exists, os.listdir, ls, stat, attrib). **This audit deleted nothing.** Most likely cause: **OneDrive sync/Files-On-Demand dehydration** (project is under `OneDrive\Documents`); cause unconfirmed. The Phase 2A brief (§7) expects these present, so this was **not an intended cleanup**. No restoration attempted (per project rule).

- **§3 protected set is 100% INTACT** (source packages, production data, canonical outputs, validation evidence, closure evidence, `RunOnePreprocessing.m`) — nothing protected is lost.
- The vanished archives were **redundant backups/exports** (duplicates of intact live data).
- **`source data/` is the notable loss** — original project docs AND code-referenced by `+sensormodels/GenerateIdealAirData.m`. **Recommend restoring it from OneDrive/backup.**
- Full detail: `Archive_Verification_Report.md`.

---

## Size overview

- **Total `production/Preprocessed`:** 2562 MB (2.56 GB)
- **Total `TestArtifacts`:** 1431 MB (1.43 GB)  ← the dominant folder
- **Largest TestArtifacts children:** StressFixtures 1,421 MB · Phase3Fixtures 8.6 MB · loose evidence 0.7 MB
- **Current project total (post-void):** 3.23 GB (Phase 1 measured 3.8 GB before the 564 MB vanished)
- **Preprocessed breakdown:** 15 canonical outputs (144 MB) · 80 historical (682 MB) · 26 unregistered (277 MB) · 498 synthetic (28 MB) · TestArtifacts (1,431 MB) · failure/empty (tiny)

**Size reconciliation (the ~1.4 GB StressFixtures):** `TestArtifacts` as a whole is **1431 MB**. `StressFixtures` **alone** is **1,421 MB** of that. The "1.4 GB" figure refers to **StressFixtures alone**; the "1.3 GB" user observation is consistent with StressFixtures (+ small extras). TestArtifacts total is 1.43 GB. (Sizes are recursive, non-double-counted.)

---

## Important findings

1. **15 canonical outputs: ALL PRESENT & VERIFIED** (6/6 artifacts, SUCCESS, 0 warnings/errors) — 14 registry-validation (per manifest) + 1 interactive. See `Canonical_Output_Protection_Report.md`.
2. **Failure-marker discrepancy RECONCILED** — the prior "77 no-report" was a misnomer (33 truly-no-report + 44 report-with-empty-Status); "56 deletion candidates" was a heuristic subset. Exact 619-folder breakdown in `Failure_Output_Reconciliation.md`. No failure output to be deleted; retain representatives.
3. **619 PreprocessID folders classified:** 15 canonical · 80 historical · 26 unregistered · 498 synthetic · 36 PARTIAL · 21 marker-only · 11 no-report-with-content · 44 empty-status · 5 malformed · 1 empty.
4. **Synthetic Run_9xx → harness mapped:** `Run_900-937/992-997` from `RunPreprocessingTests.m`; `Run_962/970-975/985` from `RunPreprocessingStressTests.m`. All regenerable by re-running the harness.
5. **Dependency scan (5,708 files):** `Run_001_20261107_110817.zip`/`zipz`/`New folder` = no code refs (safe archives). `source data` = **referenced by Block 7 code** (risk). Fixtures = harness-generated. See `Dependency_Reference_Report.md`.
6. **TestArtifacts classified** (granular §5.2 labels) — 2,907 regenerable fixtures, 21 final evidence, 22 manifest/integrity, 6 reusable scripts, 18 historical, 62 intermediate, rest dev/review. See `TestArtifacts_DeepInventory.csv`.

---

## Unresolved risks

- **`source data/` absence + Block 7 code reference** — verify `GenerateIdealAirData.m`'s use of `source data` and restore the folder. **Highest-priority open item.**
- **OneDrive sync instability** — files vanished mid-audit; confirm sync health before any Phase 2B move, or operations may hit missing files.
- **`source data` code reference** is the one dependency that could affect reproducibility if unrestored.
- `JSBSim_Test/` provenance still to confirm.

---

## Recommended next actions

1. **STOP and check OneDrive sync / recycle / version history** — restore `source data/` (docs + code-referenced); optionally `zipz/`, the run-export ZIP.
2. Confirm the `+sensormodels/GenerateIdealAirData.m` → `source data` dependency.
3. After restoration + confirmation, proceed to **Phase 2B** (execute the archive plan in `Phase2_Quarantine_Manifest.csv`) — not started here.
4. Retain representative failure-path outputs; archive (not delete) historical/synthetic/intermediate material.
5. Create `Block9_Development_Archive/` and `Block10_WorkingArea/` only on approval.

---

## Deliverables in this folder

`DeepAudit_Summary.md` (this) · `Preprocessed_DeepInventory.csv` (619) · `TestArtifacts_DeepInventory.csv` (3,159) · `TestArtifacts_SizeBreakdown.csv` (152) · `Dependency_Reference_Report.md` · `Canonical_Output_Protection_Report.md` · `Failure_Output_Reconciliation.md` · `Archive_Verification_Report.md` · `Proposed_Clean_Project_Structure.md` · `Phase2_Quarantine_Manifest.csv`

---

**PHASE 2A COMPLETE — READ-ONLY AUDIT ONLY — NO PROJECT CLEANUP PERFORMED.**
*(No file/folder deleted, moved, renamed, or modified; no MATLAB production run or preprocessing executed; no fixtures regenerated; no existing report overwritten; all audit output created only in `Block9_DeepAudit_20261117/`.)*
