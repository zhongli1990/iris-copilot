# Release Notes

## v0.2.0 - 2026-05-30

### Summary
Public-distribution sanitisation release. Removes site-specific names, hostnames,
and an embedded reference production catalogue from the public source tree, and
re-establishes the deployment package on a clean baseline (`v34`). No runtime
behaviour changes.

### Changes
- Source code:
  - `bridge/src/server.ts`: removed hard-coded site CORS regex; added
    `CORS_EXTRA_ORIGINS` env var so deploying sites configure their own
    trust domain in `.env` rather than in source.
  - `bridge/src/runners/claude-agent-sdk/index.ts`: removed trust-specific
    system prompt content (host counts, system catalogue, trust name).
    Replaced with guidance to read the live production via discovery API.
  - `bridge/src/runners/runner-interface.ts`: generic example in JSDoc.
  - `bridge/src/tools/e2e-sample-queries.ts`: example query uses
    `AIAgent.*` namespace pattern.
- ObjectScript classes:
  - `AIAgent.Templates.RoutingRule.GenerateStandard` renamed to
    `GenerateStandard`. Caller in `AIAgent.Templates.Factory` updated.
  - `AIAgent.Engine.CodeManager`: example pattern doc-comment uses generic
    `Trust.Interfaces.Cerner.%` placeholder.
  - `AIAgent.Test.E2E`: example chat query uses `AIAgent.*` pattern.
- Knowledge:
  - `knowledge/tie-conventions.md` renamed to `knowledge/tie-conventions.md`
    and rewritten as a generic placeholder. Deploying sites override with
    their own private copy at the same path.
  - `knowledge/hl7-schemas.md`: generic example values (no trust facility code).
- Documentation:
  - `docs/DEMO-LIFECYCLE.md`, `docs/USER-GUIDE.md`, `docs/TEST-CASES.md`,
    `README.md`: replaced site-specific class prefixes, system names, and
    email addresses with generic placeholders (`Trust.*`, `EPMA`,
    `MaternityNetwork`, `example.nhs.uk`).
  - `docs/REALWORLD-LIFECYCLE-QUERIES.md` and `docs/REALWORLD-TEST-RESULTS.md`
    rewritten as generic operator-facing docs; site-specific harness output
    must be regenerated locally and is not committed.
- Reference / test artefacts:
  - `reference/VersionControl.UpdateBranch.cls` reduced to an abstract stub.
    The original embedded a non-public site's package list.
  - `tests/realworld-e2e-{last,judge}-report.json` reduced to schema-valid
    placeholders. The harness regenerates these on each `npm run e2e:realworld`
    run; regenerated content is local to the deployment site and must not
    be committed to a public repository.
- Deployment package:
  - Legacy export snapshots `v24`-`v33` removed. They embedded the
    pre-sanitisation symbol set (`Trust.*`, `GenerateStandard`).
  - New clean export generated as `deploy/AIAgent-export-v34.xml` from the
    sanitised `.cls` source.
  - `.gitignore` updated to commit only the current release snapshot.
  - `deploy/.export-version` untracked (now per-developer local state).

### Backwards Compatibility
- IRIS class API surface: one method renamed
  (`GenerateStandard` -> `GenerateStandard` on `AIAgent.Templates.RoutingRule`).
  Internal-only call site updated. No external API consumers are documented.
- Bridge HTTP API surface: unchanged.
- IRIS REST dispatcher: unchanged.
- CSP UI: unchanged.
- Deployment process: import `deploy/AIAgent-export-v34.xml` instead of `v33.xml`.

### Validation (Quality Gates)
- QG1 Bridge TypeScript: `npm run typecheck` and `npm run build` both pass.
- QG2 Leakage grep: zero matches across all tracked files for any of:
  `Trust`, `TRUST`, `\bTrust\b`, `GenerateTrust`, `example`,
  `EXAMPLE`, `EXAMPLE2`, `RegionalCareRecord`, `MaternityNetwork`, `WardManagement`, `LegacyADT`, `LegacyPathology`, `InfectionControlNet`,
  `EndoscopyReporting`, `EPMA`, `EDSystem`, `CardiologyReporting`, `PACS`, `example`,
  `TIE`, `Example`, `Trust.AIGenerated`, `AIAgent`,
  `example trust`, `teaching hospital`.
- QG3 Internal references:
  - `GenerateStandard` rename consistent across .cls source and v34 XML.
  - Factory.cls call site passes the 6 expected parameters.
  - v34 XML parses (25 classes, generator=IRIS, exportversion=34).
  - Cross-doc links resolve (REALWORLD docs exist as stubs).
  - Compiled `bridge/dist` JS contains zero leakage tokens after `npm run build`.

### Known Follow-ups (out of scope for this release)
- **Git history**: prior commits on `main` still contain the un-sanitised
  symbols. To fully purge from the public repo, choose one of:
  (a) `git filter-repo` + force-push with team coordination; or
  (b) re-publish from a sanitised single-commit copy and delete the old repo.
  This release sanitises `HEAD`; the history rewrite is a separate operation.
- Live realworld harness output regenerated post-deploy will need
  trust-specific anonymisation logic if/when sites want to publish their
  own evaluation reports.



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



