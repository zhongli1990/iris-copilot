# Release Notes

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

