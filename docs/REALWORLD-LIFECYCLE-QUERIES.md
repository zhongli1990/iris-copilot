# Real-World NHS TIE Lifecycle Query Pack

This document defines practical user queries for IRIS Copilot aligned to lifecycle delivery in operational TIE environments.

Machine-readable source of truth:
- `tests/realworld-e2e-cases.json`

Automated validator:
- `npm run e2e:realworld` (from `bridge/`)
- report output: `tests/realworld-e2e-last-report.json`

Test runbook:
- `docs/REALWORLD-TEST-RUNBOOK.md`

---

## Scope

The case pack (`tests/realworld-e2e-cases.json`) is grouped by lifecycle phase:

1. **Production topology and discovery** — list hosts, queue depth, recent events, lookup table inspection, class metadata, invocation policy, class catalogue by package pattern.
2. **Routing and rule introspection** — list routing rules, inspect a specific ruleset, trace a sample message path.
3. **Change planning (dry-run)** — proposed host add/remove, proposed rule edits, proposed DTL changes, with explicit dry-run and approval flags.
4. **Approval-gated execution** — execute pre-approved host add/remove, rule update, generation approve/reject.
5. **Diagnostics and triage** — failed-message inspection, recent-error summarisation, queue backlog triage.
6. **Rollback** — request rollback to a prior lifecycle snapshot by version ID or "latest available".

Each case in the catalogue declares:
- `query` — the natural-language input
- `expected.actionTargetAny` — at least one of these IRIS operate targets must be invoked
- `expected.requiresApproval` — whether the case should propose-but-not-execute
- `expected.responseIncludesAny` / `responseNotIncludes` — substring assertions

## Live Reports

The expected-output substrings in the case file are deliberately generic
(e.g. "Production hosts (", "Queue counts", "Recent events"). They do not
encode any particular trust's host catalogue or rule set.

The actual host names, rule names, and topology details visible in a live run
depend entirely on the IRIS production loaded in the test namespace. The
generated `tests/realworld-e2e-last-report.json` and
`tests/realworld-e2e-judge-report.json` files capture those site-specific
details — for that reason, the report files distributed in this repository
are blank placeholders; treat any locally-regenerated report as private to
your deployment site and do not commit it back to a public repository.

## Running

```bash
cd bridge
npm install
npm run build
# Make sure the bridge + IRIS are both running and reachable, then:
npm run e2e:realworld
```

The script writes:
- `tests/realworld-e2e-last-report.json` — harness pass/fail and response preview per case
- `tests/realworld-e2e-judge-report.json` — LLM-as-a-Judge strict scoring

Use those files to confirm both deterministic and semantic correctness against
your trust's production.
