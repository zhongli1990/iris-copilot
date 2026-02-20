# Real-World E2E Evaluation Report

Generated from:
- `tests/realworld-e2e-last-report.json`
- LLM-as-a-Judge review in `tests/realworld-e2e-judge-report.json`

## Summary

- Total cases: 34
- Judge pass: 16
- Judge fail: 18
- Pass rate: 47.1%

## Product Vision Verdict

- Not yet aligned: major capability gaps against generic lifecycle execution vision.

## Per-Case Results

| Case | Result | Target | Notes |
|---|---|---|---|
| RW01 | PASS | production/topology | Meets expected behavior. |
| RW02 | PASS | production/queues | Meets expected behavior. |
| RW03 | PASS | production/events | Meets expected behavior. |
| RW04 | PASS | lookup/ErrorCodes | Meets expected behavior. |
| RW05 | FAIL | (none) | See failed checks in JSON report. |
| RW06 | PASS | invoke-policy | Meets expected behavior. |
| RW07 | PASS | dictionary/classes | Meets expected behavior. |
| RW08 | PASS | production/host/add | Meets expected behavior. |
| RW09 | PASS | production/host/add | Meets expected behavior. |
| RW10 | PASS | production/host/remove | Meets expected behavior. |
| RW11 | PASS | production/status | Meets expected behavior. |
| RW12 | PASS | production/topology | Meets expected behavior. |
| RW13 | PASS | production/topology | Meets expected behavior. |
| RW14 | PASS | production/events | Meets expected behavior. |
| RW15 | PASS | production/queues | Meets expected behavior. |
| RW16 | FAIL | (none) | See failed checks in JSON report. |
| RW17 | FAIL | (none) | See failed checks in JSON report. |
| RW18 | FAIL | (none) | See failed checks in JSON report. |
| RW19 | FAIL | production/host/add | See failed checks in JSON report. |
| RW20 | FAIL | (none) | See failed checks in JSON report. |
| RW21 | FAIL | (none) | See failed checks in JSON report. |
| RW22 | FAIL | generation/approve | See failed checks in JSON report. |
| RW23 | FAIL | generation/reject | See failed checks in JSON report. |
| RW24 | FAIL | (none) | See failed checks in JSON report. |
| RW25 | FAIL | (none) | See failed checks in JSON report. |
| RW26 | PASS | production/topology | Meets expected behavior. |
| RW27 | FAIL | production/topology | See failed checks in JSON report. |
| RW28 | PASS | production/queues | Meets expected behavior. |
| RW29 | FAIL | production/events | See failed checks in JSON report. |
| RW30 | FAIL | production/status | See failed checks in JSON report. |
| RW31 | FAIL | (none) | See failed checks in JSON report. |
| RW32 | FAIL | lifecycle/versions | See failed checks in JSON report. |
| RW33 | FAIL | (none) | See failed checks in JSON report. |
| RW34 | FAIL | (none) | See failed checks in JSON report. |

## Main Failure Themes

- Planning/design prompts often return narrative text without executable action target (`plan/preview` not implemented as a real action target).
- Some target naming mismatches (`generation/approve` vs expected `generate/approve`, same for reject).
- Dry-run/approval behavior is inconsistent for some mutate-like prompts.
- Some observability prompts execute but do not provide expected semantic triage detail (failed/retried/cause, bridge/runner drift wording).
- Rollback execution path is incomplete (version listing works, explicit rollback action flow is not fully mapped).

## Recommended Remediation (Priority)

1. Implement a real generic `plan/preview` action target in dispatcher + orchestrator.
2. Standardize action target IDs and update assertions to canonical names.
3. Enforce strict dry-run semantics: no approval for dry-run, ever.
4. Add generic compile/audit/CAB action endpoints for enterprise lifecycle governance.
5. Complete rollback executor with approval-gated snapshot selection and execution.
