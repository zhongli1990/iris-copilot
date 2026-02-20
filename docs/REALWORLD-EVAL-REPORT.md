# Real-World E2E Evaluation Report

Generated from:
- `tests/realworld-e2e-last-report.json`
- `tests/realworld-e2e-judge-report.json`

## Summary

- Total cases: 37
- Harness pass/fail: 33/4
- Judge pass/fail: 27/10
- Judge pass rate: 73%

## Verdict

- Partially aligned. Read/query and plan-preview behavior is strong, but several real execution paths still fail and block fully reliable lifecycle automation.

## Judge Results

| Case | Judge | Target | Note |
|---|---|---|---|
| RW01 | PASS | production/topology | Meets expected behavior. |
| RW02 | PASS | production/queues | Meets expected behavior. |
| RW03 | PASS | production/events | Meets expected behavior. |
| RW04 | PASS | lookup/ErrorCodes | Meets expected behavior. |
| RW05 | PASS | classmeta/AIAgent.API.Dispatcher | Meets expected behavior. |
| RW06 | PASS | invoke-policy | Meets expected behavior. |
| RW07 | PASS | dictionary/classes | Meets expected behavior. |
| RW08 | PASS | production/host/add | Meets expected behavior. |
| RW09 | FAIL | (none) | Execution failed at runtime (IRIS API error), so end-to-end outcome is not successful. |
| RW10 | PASS | production/host/remove | Meets expected behavior. |
| RW11 | PASS | production/status | Meets expected behavior. |
| RW12 | PASS | production/topology | Meets expected behavior. |
| RW13 | PASS | production/topology | Meets expected behavior. |
| RW14 | PASS | production/events | Meets expected behavior. |
| RW15 | PASS | production/queues | Meets expected behavior. |
| RW16 | PASS | plan/preview | Meets expected behavior. |
| RW17 | PASS | plan/preview | Meets expected behavior. |
| RW18 | PASS | plan/preview | Meets expected behavior. |
| RW19 | PASS | production/host/add | Meets expected behavior. |
| RW20 | PASS | plan/preview | Meets expected behavior. |
| RW21 | PASS | plan/preview | Meets expected behavior. |
| RW22 | FAIL | generate/approve | Execution failed at runtime (IRIS API error), so end-to-end outcome is not successful. |
| RW23 | FAIL | generate/reject | Execution failed at runtime (IRIS API error), so end-to-end outcome is not successful. |
| RW24 | PASS | plan/preview | Meets expected behavior. |
| RW25 | PASS | plan/preview | Meets expected behavior. |
| RW26 | FAIL | plan/preview | Used plan preview instead of verifying live topology/routing state for the requested confirmation task. |
| RW27 | PASS | plan/preview | Meets expected behavior. |
| RW28 | PASS | production/queues | Meets expected behavior. |
| RW29 | FAIL | production/events | Returned raw events but did not provide failed/retried indicators and likely-cause analysis requested. |
| RW30 | FAIL | production/events | Did not evaluate runner/bridge health drift; returned production events instead of the requested platform connectivity analysis. |
| RW31 | PASS | plan/preview | Meets expected behavior. |
| RW32 | FAIL | lifecycle/rollback | Execution failed at runtime (IRIS API error), so end-to-end outcome is not successful. |
| RW33 | PASS | plan/preview | Meets expected behavior. |
| RW34 | PASS | plan/preview | Meets expected behavior. |
| RW35 | FAIL | (none) | Execution failed at runtime (IRIS API error), so end-to-end outcome is not successful. |
| RW36 | FAIL | production/host/settings | Response payload appears to be generic production snapshot output, not clear item-level confirmation for requested AIAgent.Demo.* host mutations. |
| RW37 | FAIL | production/host/remove | Response payload appears to be generic production snapshot output, not clear item-level confirmation for requested AIAgent.Demo.* host mutations. |

## Priority Fixes

1. Make add/update/remove host mutations idempotent and return per-item operation results.
2. Guard generation approve/reject with pending-generation precheck and user-facing message.
3. Complete rollback path: list snapshots, select valid id, then execute rollback.
4. Improve event triage responses with explicit failed/retried metrics and likely causes.
5. Keep plan-preview generic, but ensure verification prompts execute live checks when user asks to confirm current state.
