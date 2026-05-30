# Real-World Test Results (Actual Queries and Outcomes)

> The previously distributed version of this file contained verbatim outputs
> from a live test run, including the host catalogue of the source production.
> That content has been removed for public distribution.

To generate fresh results against your own environment:

1. Confirm `bridge/.env` is configured (Anthropic / OpenAI keys, IRIS URL/namespace).
2. Start the bridge and ensure your IRIS instance is reachable.
3. From `bridge/`, run:
   ```bash
   npm run e2e:realworld
   ```
4. Review the regenerated artefacts (these are local to your deployment and
   should not be committed to a public repository):
   - `tests/realworld-e2e-last-report.json` — per-case harness pass/fail and response preview
   - `tests/realworld-e2e-judge-report.json` — LLM-as-a-Judge semantic scoring (if enabled)
5. The aggregate summary metric you usually want to track is the judge
   pass-rate against your trust's production catalogue, which depends on the
   maturity of routing rules, lookup tables, and host naming in your IRIS
   namespace.

For the catalogue of queries that drive this harness, see
`docs/REALWORLD-LIFECYCLE-QUERIES.md` and `tests/realworld-e2e-cases.json`.

For the operational runbook (preconditions, troubleshooting, expected
runtime), see `docs/REALWORLD-TEST-RUNBOOK.md`.
