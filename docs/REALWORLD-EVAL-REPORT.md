# Real-World E2E Evaluation Report

Generated from:
- `tests/realworld-e2e-last-report.json`
- LLM-as-a-Judge review in `tests/realworld-e2e-judge-report.json`

## Summary

- Total cases: 10
- Judge pass: 9
- Judge fail: 1

## Per-Case Evaluation

| Case | Query Focus | Result | Judge | Notes |
|---|---|---|---|---|
| RW01 | Production topology | Pass | Pass | Correct target and full host detail response. |
| RW02 | Queue depth | Pass | Pass | Correct target; empty queue state handled correctly. |
| RW03 | Recent events | Pass | Pass | Live event rows returned. |
| RW04 | Lookup content | Pass | Pass | ErrorCodes entries returned from live lookup table. |
| RW05 | Class metadata | Fail | Fail | Expected `classmeta/...` result but got IRIS 404. |
| RW06 | Invoke policy | Pass | Pass | Policy mode and limits rendered correctly. |
| RW07 | Package class list | Pass | Pass | Correct dictionary class query and relevant output. |
| RW08 | Dry-run host add | Pass | Pass | Non-mutating dry-run behavior confirmed. |
| RW09 | Apply host add | Pass | Pass | Correctly approval-gated (pending action). |
| RW10 | Dry-run host remove | Pass | Pass | Non-mutating dry-run behavior confirmed. |

## Key Finding

The only functional gap in this run is RW05 (`classmeta/<ClassName>`). This is an environment/runtime mismatch issue (IRIS target returned 404) rather than planner intent quality.

## Recommended Remediation

1. Re-import latest package containing updated `AIAgent.API.Dispatcher`.
2. Recompile in the active namespace.
3. Re-run:
   - `npm run e2e:realworld`
4. Confirm RW05 passes.

