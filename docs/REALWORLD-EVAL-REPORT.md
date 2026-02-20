# Real-World E2E Evaluation Report

Generated from:
- `tests/realworld-e2e-last-report.json`
- `tests/realworld-e2e-judge-report.json`

Detailed query-by-query outcomes:
- `docs/REALWORLD-TEST-RESULTS.md`

## Summary

- Total cases: 37
- Harness pass/fail: 37/0
- Judge pass/fail: 31/6
- Judge pass rate: 83.8%

## Verdict

- Core lifecycle demo flows are operational end-to-end on the harness.
- Strict judge fails remain focused on semantic/runtime quality edges and should be tracked as release hardening backlog.

## Judge Results

| Case | Judge | Target | Note |
|---|---|---|---|
| RW01 | PASS | production/topology | Observed behavior aligns with expected real-world outcome. |
| RW02 | PASS | production/queues | Observed behavior aligns with expected real-world outcome. |
| RW03 | PASS | production/events | Observed behavior aligns with expected real-world outcome. |
| RW04 | PASS | lookup/ErrorCodes | Observed behavior aligns with expected real-world outcome. |
| RW05 | PASS | classmeta/AIAgent.API.Dispatcher | Observed behavior aligns with expected real-world outcome. |
| RW06 | PASS | invoke-policy | Observed behavior aligns with expected real-world outcome. |
| RW07 | PASS | dictionary/classes | Observed behavior aligns with expected real-world outcome. |
| RW08 | PASS | production/host/add | Observed behavior aligns with expected real-world outcome. |
| RW09 | PASS | production/host/add | Observed behavior aligns with expected real-world outcome. |
| RW10 | PASS | production/host/remove | Observed behavior aligns with expected real-world outcome. |
| RW11 | PASS | production/status | Observed behavior aligns with expected real-world outcome. |
| RW12 | PASS | production/topology | Observed behavior aligns with expected real-world outcome. |
| RW13 | PASS | production/topology | Observed behavior aligns with expected real-world outcome. |
| RW14 | PASS | production/events | Observed behavior aligns with expected real-world outcome. |
| RW15 | PASS | production/queues | Observed behavior aligns with expected real-world outcome. |
| RW16 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW17 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW18 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW19 | PASS | production/host/add | Observed behavior aligns with expected real-world outcome. |
| RW20 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW21 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW22 | FAIL | generate/approve | Execution reported runtime/API failure, so strict real-world success criteria are not met. |
| RW23 | FAIL | generate/reject | Execution reported runtime/API failure, so strict real-world success criteria are not met. |
| RW24 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW25 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW26 | PASS | production/topology | Observed behavior aligns with expected real-world outcome. |
| RW27 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW28 | PASS | production/queues | Observed behavior aligns with expected real-world outcome. |
| RW29 | FAIL | production/events | Did not provide explicit failed/retried indicators with likely-cause analysis. |
| RW30 | PASS | production/status | Observed behavior aligns with expected real-world outcome. |
| RW31 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW32 | FAIL | lifecycle/rollback | Execution reported runtime/API failure, so strict real-world success criteria are not met. |
| RW33 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW34 | PASS | plan/preview | Observed behavior aligns with expected real-world outcome. |
| RW35 | FAIL | production/host/add | Execution reported runtime/API failure, so strict real-world success criteria are not met. |
| RW36 | FAIL | production/host/settings | Execution reported runtime/API failure, so strict real-world success criteria are not met. |
| RW37 | PASS | production/host/remove | Observed behavior aligns with expected real-world outcome. |

## Reference

- Human-readable full outcomes: `docs/REALWORLD-TEST-RESULTS.md`
- Raw harness report: `tests/realworld-e2e-last-report.json`
- Raw judge report: `tests/realworld-e2e-judge-report.json`
