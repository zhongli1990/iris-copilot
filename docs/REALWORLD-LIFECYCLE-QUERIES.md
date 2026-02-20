# Real-World NHS TIE Lifecycle Query Pack

This document defines practical user queries for IRIS Copilot aligned to lifecycle delivery in operational TIE environments.

Machine-readable source of truth:
- `tests/realworld-e2e-cases.json`

Automated validator:
- `npm run e2e:realworld` (from `bridge/`)
- report output: `tests/realworld-e2e-last-report.json`

## Query/Outcome Pairs

### RW01 Production Topology Full Detail
- Query:
  `List all production hosts with full details.`
- Expected outcome:
  - First action target: `production/topology`
  - `requiresApproval = false`
  - Response includes host listing summary (for example `Production hosts (` or `Current production has`)

### RW02 Queue Depth Overview
- Query:
  `Show queue depth for all hosts.`
- Expected outcome:
  - First action target: `production/queues`
  - `requiresApproval = false`
  - Response includes queue listing summary

### RW03 Recent Production Events
- Query:
  `Show recent production events.`
- Expected outcome:
  - First action target: `production/events`
  - `requiresApproval = false`
  - Response includes recent events summary

### RW04 Lookup Table Content
- Query:
  `Show lookup table ErrorCodes content.`
- Expected outcome:
  - First action target: `lookup/ErrorCodes`
  - `requiresApproval = false`
  - Response includes lookup content summary or explicit no-entry message

### RW05 Class Metadata Query
- Query:
  `Show metadata for class AIAgent.API.Dispatcher.`
- Expected outcome:
  - First action target: `classmeta/AIAgent.API.Dispatcher`
  - `requiresApproval = false`
  - Response includes class metadata sections (methods/properties/parameters)

### RW06 Invocation Policy Query
- Query:
  `Show invocation policy.`
- Expected outcome:
  - First action target: `invoke-policy`
  - `requiresApproval = false`
  - Response includes policy mode and limits

### RW07 Class Catalog by Package Pattern
- Query:
  `List classes in the NHSTIE2.* packages.`
- Expected outcome:
  - First action target: `dictionary/classes`
  - `requiresApproval = false`
  - Response includes class catalog summary

### RW08 Dry-run Add Disabled Host
- Query:
  `Create a plan to add a disabled test business host named AIAgent.DryRun.TestHost, dry-run only.`
- Expected outcome:
  - First action target: `production/host/add`
  - `requiresApproval = false` (dry-run executes directly)
  - Response explicitly indicates dry-run and no mutation

### RW09 Apply Add Host Requires Approval
- Query:
  `Add a disabled test business host named AIAgent.DryRun.TestHost.`
- Expected outcome:
  - First action target: `production/host/add`
  - `requiresApproval = true`
  - Response states approval required before mutation

### RW10 Dry-run Remove Host
- Query:
  `Remove business host named AIAgent.DryRun.TestHost, dry-run only.`
- Expected outcome:
  - First action target: `production/host/remove`
  - `requiresApproval = false` (dry-run executes directly)
  - Response indicates dry-run and no mutation

## How to Run

From `bridge/`:

```powershell
npm run build
npm run e2e:realworld
```

The command validates each query/outcome pair through live API calls and writes a JSON report.

