# ARCHIVE / BACKUP VERIFICATION REPORT

## CRITICAL FILESYSTEM DISCREPANCY

The Phase 2A instructions (Section 7) direct inspection of `Run_001_20261107_110817.zip`, `zipz/`, and `source data/New folder.zip`.
**At Phase 2A inspection time these are ABSENT**, though the Phase 1 audit (17 Nov 2026) recorded them as present. This audit is strictly read-only and deleted nothing.

| Archive | Phase 1 record (present) | Phase 2A inspection | Status |
|---|---|---|---|
| `production/Preprocessed/Run_001_20261107_110817.zip` | 336,413,906 B | absent | **ABSENT — cannot verify** |
| `zipz/` (9 zips incl. production.zip) | 193 MB | absent | **ABSENT — cannot verify** |
| `source data/New folder.zip` | 5,662,xxx B | absent | **ABSENT — cannot verify** |
| `source data/` (New folder/, PPTS Docs/) | 35 MB, 23 files | absent | **ABSENT** |
| `.vscode/settings.json` | present | absent | **ABSENT** |

**Total vanished since Phase 1: 34 files, ~564 MB.** Verified absent via Python `os.path.exists`, `os.listdir`, `ls`, `stat`, and `attrib` (all agree).

### Cause (unconfirmed)

- This audit performed **no deletion, move, or modification** — read-only only.
- The project lives under `C:\Users\lalit\OneDrive\Documents\`, so **OneDrive Files On-Demand / sync dehydration** is the most likely cause (files may be cloud-only or mid-sync).
- Alternatively, the files may have been removed outside this audit between the Phase 1 and Phase 2A sessions. The Phase 2A brief expects them present, so this was **not an intended cleanup**.
- **No automatic restoration attempted** (per project rule).

### Impact

- The **§3 protected set is 100% intact** (source packages, production data, canonical outputs, validation evidence, closure evidence, `RunOnePreprocessing.m`). See DeepAudit_Summary.md.
- The vanished archives were **backup/export duplicates**: `Run_001_20261107_110817.zip` duplicated that run's outputs (the live `Run_001_20261107_110817/` folder with 82 children is intact); `zipz/` duplicated live source packages (intact); `New folder.zip` duplicated `source data/New folder/`.
- **`source data/` is the notable loss** — original project reference docs (Block 0–5 specifications, c172p, presentations). It was classified KEEP_PROTECTED in Phase 1. It is also code-referenced by `+sensormodels/GenerateIdealAirData.m` (see Dependency_Reference_Report.md). **Recommend the user restore `source data/` from OneDrive / backup.**

### Verification of archives (not possible — absent)

Hash-comparison against live files could not be performed because the archives no longer exist locally. If restored (e.g. via OneDrive), the planned verification is: extract each archive's file list, SHA-256 hash each member, and compare to the corresponding live file to determine exact-duplicate vs older-snapshot.

### Recommendation

1. **Check OneDrive sync status / recycle / version history** and restore `source data/` (highest priority — original docs + code-referenced).
2. Restore `zipz/` and `Run_001_20261107_110817.zip` only if their verification is desired (they are redundant backups; low priority).
3. Re-run this Section 7 verification after restoration.

*PHASE 2A note: read-only audit only — no project cleanup performed; no archive deleted or moved by this audit.*