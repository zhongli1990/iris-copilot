# Release Notes

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
