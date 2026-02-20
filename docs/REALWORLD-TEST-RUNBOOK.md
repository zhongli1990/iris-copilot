# Real-World E2E Test Runbook

This runbook documents the exact steps used to run the real-world regression and evaluation workflow.

## Scope

- Harness regression run:
  - `tests/realworld-e2e-last-report.json`
- Strict judge scoring run:
  - `tests/realworld-e2e-judge-report.json`
- Human-readable summaries:
  - `docs/REALWORLD-TEST-RESULTS.md`
  - `docs/REALWORLD-EVAL-REPORT.md`

## Prerequisites

1. Import and compile latest IRIS export package in your target namespace.
   Example:
   - `deploy/AIAgent-export-v33.xml` (or newer)
2. Ensure `/ai` web app points to `AIAgent.API.Dispatcher`.
3. Ensure Node bridge environment is configured (`bridge/.env`).
4. Ensure IRIS and bridge are reachable:
   - `http://localhost:52773/ai/health`
   - `http://localhost:3100/api/health`

## Step-by-Step Execution

### 1. Start bridge

From `bridge/`:

```powershell
npm.cmd install
npm.cmd run build
npm.cmd start
```

Keep this terminal running.

### 2. Run real-world harness suite

From `bridge/` in a second terminal:

```powershell
npm.cmd run e2e:realworld
```

Expected output ends with totals, for example:
- `Total: 37, Passed: 37, Failed: 0`

Artifact written:
- `tests/realworld-e2e-last-report.json`

### 3. Run strict judge evaluation

Current project stores strict judge results in:
- `tests/realworld-e2e-judge-report.json`

If you have a local judge script/workflow, execute it here and overwrite that file.
If not, keep the latest committed judge artifact and treat it as the strict semantic baseline.

### 4. Refresh markdown reports from JSON artifacts

Update:
- `docs/REALWORLD-TEST-RESULTS.md`
- `docs/REALWORLD-EVAL-REPORT.md`

These must reflect:
- latest `realworld-e2e-last-report.json`
- latest `realworld-e2e-judge-report.json`

### 5. Quick validation checks

1. `realworld-e2e-last-report.json`:
   - `total` is expected case count
   - `passed`/`failed` align with console output
2. `realworld-e2e-judge-report.json`:
   - `summary.judgePass` / `summary.judgeFail` are present
3. `docs/REALWORLD-EVAL-REPORT.md`:
   - Summary numbers match JSON artifacts
4. `docs/REALWORLD-TEST-RESULTS.md`:
   - Contains all query/outcome pairs and case matrix

## Recommended Release Checklist

1. Import latest XML package and restart bridge.
2. Run `npm.cmd run e2e:realworld`.
3. Refresh judge artifact.
4. Regenerate/update both MD reports.
5. Commit JSON + MD together to keep evidence consistent.
