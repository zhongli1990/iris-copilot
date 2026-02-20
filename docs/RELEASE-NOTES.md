# Release Notes

## v0.1.5 - 2026-02-20

### Summary
Quality hardening and reporting release: production host mutation reliability fixes, orchestrator action-quality improvements, new packaged XML export (`v31`), and full human-readable real-world query/outcome reporting.

### Changes
- IRIS production mutation reliability:
  - Fixed host settings update path in `AIAgent.Engine.ProductionManager` to avoid invalid direct `Ens.Config.Item.Settings` assignment at runtime.
  - Added safer per-setting application helpers and aligned mutation behavior for add/update flows.
- Orchestrator quality improvements:
  - Improved multi-entity name extraction for add/update/remove operations.
  - Added rollback target auto-resolution to latest available lifecycle snapshot when ID is omitted.
  - Added graceful no-pending-generation handling for approve/reject requests.
  - Improved triage response structure for recent-event failure analysis prompts.
- Packaging:
  - Generated new import package `deploy/AIAgent-export-v31.xml` (local artifact for import/retest).
- Evaluation and reporting:
  - Refreshed machine artifacts:
    - `tests/realworld-e2e-last-report.json`
    - `tests/realworld-e2e-judge-report.json`
  - Added human-readable full results:
    - `docs/REALWORLD-TEST-RESULTS.md`
  - Updated executive report:
    - `docs/REALWORLD-EVAL-REPORT.md`

### Validation
- Bridge build passed: `npm.cmd run build`
- Realworld harness run passed: `npm.cmd run e2e:realworld` with 37/37 harness pass.
- Judge strict scoring remains tracked for semantic/runtime edges in `tests/realworld-e2e-judge-report.json`.
## v0.1.3 - 2026-02-20

### Summary
Documentation, governance, and regression-evaluation release: expanded real-world lifecycle query coverage, live E2E outcome capture with LLM-as-a-Judge scoring, setup clarity improvements, and public repo hardening.

### Changes
- Real-world lifecycle coverage:
  - Expanded query catalog from RW01-RW10 to RW01-RW34 in:
    - `docs/REALWORLD-LIFECYCLE-QUERIES.md`
    - `tests/realworld-e2e-cases.json`
  - Added human-readable appendix of actual query/answer outputs from latest E2E run in:
    - `docs/REALWORLD-LIFECYCLE-QUERIES.md`
- Evaluation reporting:
  - Refreshed live run artifact:
    - `tests/realworld-e2e-last-report.json`
  - Refreshed judge artifact (LLM-as-a-Judge):
    - `tests/realworld-e2e-judge-report.json`
  - Updated summary report with honest product-vision alignment verdict:
    - `docs/REALWORLD-EVAL-REPORT.md`
- Setup/operations docs:
  - Added explicit IRIS Web Application setup step after import in:
    - `README.md`
- Licensing/docs policy:
  - README license section updated to standard open-source license statement.
  - Design/generic markdown docs moved to local-only policy and removed from published git history.
- Neutral documentation wording:
  - Removed site-specific `Bradford` naming from published markdown docs.

### Validation
- Executed `npm.cmd run e2e:realworld` against live bridge/IRIS.
- Latest measured outcome:
  - Total: 34
  - Passed: 16
  - Failed: 18
  - Pass rate: 47.1%
- Judge report and markdown evaluation updated from live outputs.

### Known Gaps (from live evaluation)
- Planner/action mapping gaps remain for several design/execution prompts (`plan/preview` style coverage).
- Target naming normalization needed (`generation/...` vs `generate/...` expectation).
- Some dry-run/approval semantics and rollback flow details still require hardening.
## v0.1.2 - 2026-02-19

### Summary
Generic capability gateway expansion release: broad IRIS operate targets, governed class explorer/invocation policy, stronger orchestrator action execution, and executable E2E harnesses for backend + IRIS terminal validation.

### Changes
- IRIS API (`AIAgent.API.Dispatcher`):
  - Expanded `POST /ai/operate` with generic `discover/query/mutate/execute` targets.
  - Added class/object exploration targets:
    - `discover/invoke-policy`
    - `query/dictionary/classes`
    - `query/classmeta/<ClassName>`
    - `query/sql/select` (SELECT-only guarded)
  - Added approval-gated execution/mutation targets:
    - `execute/generation/approve|reject`
    - `execute/production/start|stop`
    - `execute/lifecycle/rollback`
    - `execute/class/invoke` (policy-guarded)
    - `mutate/production/host/add|remove|settings`
  - Added invocation policy helpers and guards.
  - Fixed `InvokeClassMethod` compilation compatibility (return-variable pattern).
- Bridge orchestrator:
  - Supports generic planner actions by `op+target+args` (not catalog-only).
  - Unwraps nested `/ai/operate` payload envelopes correctly.
  - Prioritizes explicit deterministic generic actions before model planner fallback.
  - Added direct parsing for flexible asks (class catalog patterns, host add/remove dry-run).
  - Removed tenant-specific hardcoded base prompt wording.
- Bridge routes:
  - `/api/iris/*` disabled responses now include explicit remediation guidance.
- Testing/validation:
  - Added backend executable harness: `npm run e2e:sample`.
  - Added IRIS terminal harness class: `AIAgent.Test.E2E`.
  - Added/updated runbook: `docs/E2E-GENERIC-VALIDATION.md`.
- Packaging:
  - XML export generator now includes `AIAgent.Test.E2E`.
  - Versioned package generated through `AIAgent-export-v24.xml`.
- Config template:
  - `.env.example` generic gateway default set enabled (`GENERIC_OPERATE_ENABLED=1`).

### Known Issue
- Automated test baseline currently reports one remaining failing edge case:
  - Forbidden `execute/class/invoke` path returns HTTP 500 instead of clean policy-denied payload.
  - All other baseline checks pass.

### Validation
- Bridge `npm run build` passes.
- Backend sample harness executes and reports deterministic pass/fail.
- IRIS export generation succeeds (25 classes, includes test harness class).
## v0.1.1 - 2026-02-19

### Summary
Stability and capability release for real-world IRIS Copilot operation: model-driven action brokering, approval-gated execution endpoint, CSP Chat UI reliability fixes, and end-to-end runbook updates.

### Changes
- Bridge: added approval execution API route `POST /api/actions/approve` with validated action execution mapping.
- Bridge: orchestrator upgraded with model-driven action planning (Codex/Claude planner-first), safe read execution, and approval-required action proposals.
- Bridge: streaming route emits a final assembled fallback payload (`finalResponse`) for persistence reliability.
- IRIS: dispatcher SSE fallback now calls non-stream bridge chat when streamed content is empty, then emits and persists fallback response.
- IRIS: bridge stream parser hardened for IRIS 2022.1 JSON handling (`token` / `response` / `finalResponse` extraction).
- CSP UI: added Raw tab for stream diagnostics, improved assistant content rendering (no raw planner blob in chat), and stronger conversation reload/persistence behavior.
- Docs: expanded user guidance with E2E validation runbook, realistic prompt catalog, and explicit intent-based behavior expectations.

### Impact
- Runtime behavior changed (bridge + IRIS + UI) to reduce blank responses and improve action execution flow.
- New bridge API surface: `/api/actions/approve`.
- Existing working runners remain active; planner/execution logic is orchestrator-level and approval-gated for mutating actions.

### Validation
- Bridge TypeScript build passes (`npm run build`).
- Versioned IRIS export packages regenerated through v17.
- Manual E2E validation guidance included in `docs/USER-GUIDE.md` for operators.



