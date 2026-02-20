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

## Full Lifecycle Query Catalog (Operational Use)

The following are additional real-world lifecycle queries for day-to-day TIE implementation work.
These are not all wired into the automated validator yet, but are intended for interactive E2E checks.

### Discovery and Baseline

#### RW11 Platform Health Snapshot
- Query:
  `Recap current platform health, active production, and runner status.`
- Expected outcome:
  - Returns IRIS health, bridge health, runner health, production name/status, namespace.

#### RW12 Production Host Names Only
- Query:
  `List all production host names only.`
- Expected outcome:
  - Returns host count and flat name list without verbose details.

#### RW13 Disabled Host Inventory
- Query:
  `Show all currently disabled business hosts.`
- Expected outcome:
  - Returns filtered host list where Enabled = false.

#### RW14 Recent Errors Focus
- Query:
  `Show recent production events with level ERROR in the last 60 minutes.`
- Expected outcome:
  - Returns recent error events or explicit empty result.

#### RW15 Queue Hotspots
- Query:
  `Which 10 hosts have the highest queue depth right now?`
- Expected outcome:
  - Returns ranked queue list with top offenders.

### Design and Planning

#### RW16 New Interface Design Plan
- Query:
  `Design an interface plan for ADT A01/A02/A03 from PAS to DrDoctor with required transforms and routing.`
- Expected outcome:
  - Returns structured plan (source, routing, transform, operation, validation steps), no mutation.

#### RW17 Existing Router Change Plan
- Query:
  `Create a change plan to add a new downstream operation to the current PAS router for A08 messages only.`
- Expected outcome:
  - Returns router delta plan and approvals required, no mutation.

#### RW18 DTL Impact Assessment
- Query:
  `Assess impact of changing PID-3 mapping in the existing PAS ADT transform.`
- Expected outcome:
  - Returns affected classes/routes/tests and risk notes.

### Generation (Approval-Gated)

#### RW19 Generate New Business Operation (Dry-run)
- Query:
  `Create a dry-run plan for a new disabled business operation AIAgent.Generated.DrDoctor.Operation.`
- Expected outcome:
  - Returns proposed generated artifact(s), dry-run confirmation, no applied changes.

#### RW20 Generate Router Rule Delta (Dry-run)
- Query:
  `Prepare dry-run router rule updates to route ORM messages to a new operation.`
- Expected outcome:
  - Returns proposed rule delta and dry-run execution output only.

#### RW21 Generate with Approval Gate
- Query:
  `Generate and stage required classes for a new ORU pathway; do not deploy until I approve.`
- Expected outcome:
  - Returns staged generation summary and explicit approval requirement.

### Approval and Deployment

#### RW22 Approve Pending Generation
- Query:
  `Approve the latest staged generation and deploy it now.`
- Expected outcome:
  - Requires approval path; on success returns deploy status and applied artifacts.

#### RW23 Reject Pending Generation
- Query:
  `Reject the currently staged generation and close it without deployment.`
- Expected outcome:
  - Marks generation rejected; no production mutation applied.

#### RW24 Compile Validation
- Query:
  `Compile all newly generated classes and show errors if any.`
- Expected outcome:
  - Returns compile success/failure with class-level diagnostics.

### Post-Deploy Verification

#### RW25 Post-Deploy Smoke Test Checklist
- Query:
  `Run post-deploy verification checklist for the new route and summarize pass/fail.`
- Expected outcome:
  - Returns checklist items and pass/fail summary.

#### RW26 Route Presence Verification
- Query:
  `Confirm the new operation is connected in router rules and currently disabled.`
- Expected outcome:
  - Returns topology/rule verification and enabled state.

#### RW27 Message Flow Readiness
- Query:
  `Validate readiness for A01/A02/A03 traffic through the new route without enabling it.`
- Expected outcome:
  - Returns readiness checks and blockers.

### Monitoring and Incident Response

#### RW28 Spike Investigation
- Query:
  `Investigate why queue depth spiked in the last hour and identify likely bottleneck hosts.`
- Expected outcome:
  - Returns evidence-based hotspot summary and recommended actions.

#### RW29 Failed Message Triage
- Query:
  `Show failed/retried message indicators for the last 2 hours and likely causes.`
- Expected outcome:
  - Returns recent failure indicators and probable root-cause hints.

#### RW30 Runner/Platform Drift Check
- Query:
  `Check whether runner health or bridge connectivity changed in the last 30 minutes.`
- Expected outcome:
  - Returns current state and drift note (or no change).

### Rollback and Recovery

#### RW31 Prepare Rollback Plan
- Query:
  `Prepare rollback plan to previous stable version for the latest deployment, no execution.`
- Expected outcome:
  - Returns rollback candidate and steps; no mutation.

#### RW32 Execute Rollback (Approval-Gated)
- Query:
  `Rollback to the previous stable snapshot now.`
- Expected outcome:
  - Requires approval, then returns rollback execution status.

### Governance and Audit

#### RW33 Audit Trail by Conversation
- Query:
  `Show the audit trail for this conversation including requested actions and outcomes.`
- Expected outcome:
  - Returns action-by-action audit summary.

#### RW34 Change Summary for CAB
- Query:
  `Produce CAB-ready summary of planned/applied integration changes and risks.`
- Expected outcome:
  - Returns concise governance summary suitable for change review.

## Actual Queries and Answers (Latest E2E Run)

Generated at: 2026-02-20T13:01:42.973Z
Runner: openai-codex-sdk | Namespace: DEMO2_AI2
Summary: 16/34 passed

### RW01 Production topology full detail [PASS]
- Query: `List all production hosts with full details.`
- Actual answer:
```text
Action plan generated from your request.

Production hosts (73):
- to.SCR eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Pathology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- Lab ORM Router | En
```

### RW02 Queue depth overview [PASS]
- Query: `Show queue depth for all hosts.`
- Actual answer:
```text
Action plan generated from your request.

No queue rows were returned.

Execution results:
- Queue snapshot read: 0 host(s).
```

### RW03 Recent production events [PASS]
- Query: `Show recent production events.`
- Actual answer:
```text
Action plan generated from your request.

Recent events (50):
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updated.
```

### RW04 Lookup table content [PASS]
- Query: `Show lookup table ErrorCodes content.`
- Actual answer:
```text
Lookup table ErrorCodes entries (23):
- DC01.01 => Patient Data Missing
- DC01.02 => Document Data Missing
- DC01.03 => Document Notes Exceeds 255 Characters
- DC01.04 => Sender Organisation Exceeds 255 Characters
- DC01.05 => Sender Department Exceeds 255 Characters
- DC01.06 => Sender Person Exceeds 255 Characters
- DC01.07 => Patient Family Name Exceeds 255 Characters
- DC01.08 => Patient Given Names Exceeds 255 Characters
- DC01.09 => Patient Birth Date Missing or Future Date
- DC01.11 => Cl
```

### RW05 Class metadata query [FAIL]
- Query: `Show metadata for class AIAgent.API.Dispatcher.`
- Actual answer:
```text
I could not execute the requested operation. Error: IRIS API error: 404 Not Found
```

### RW06 Invocation policy query [PASS]
- Query: `Show invocation policy.`
- Actual answer:
```text
Invocation policy:
- Mode: allow-by-default
- Max arguments: 4

Execution results:
- Invocation policy read.
```

### RW07 Class catalog by package pattern [PASS]
- Query: `List classes in the NHSTIE2.* packages.`
- Actual answer:
```text
Classes (166):
- NHSTIE2.Alert.Rule | Ens.Rule.Definition
- NHSTIE2.App.CardioBridgeORU.Data.ProcedureCode | %Persistent
- NHSTIE2.App.CardioBridgeORU.Data.SolicitedOrderStaging | %Persistent
- NHSTIE2.App.CardioBridgeORU.Message.AdminMessage | Ens.Request,%XML.Adaptor,Ens.Util.MessageBodyMethods
- NHSTIE2.App.CardioBridgeORU.Message.AlertMessage | Ens.AlertRequest
- NHSTIE2.App.CardioBridgeORU.Message.AlertMessageVirtualProps | 
- NHSTIE2.App.CardioBridgeORU.Message.DeviceMetaXML | Ens.Request

```

### RW08 Dry-run add disabled host [PASS]
- Query: `Create a plan to add a disabled test business host named AIAgent.DryRun.TestHost, dry-run only.`
- Actual answer:
```text
Dry-run executed. No production mutation was applied.

Result:
`json
{
  "status": "dry_run",
  "target": "production/host/add",
  "message": "Mutation was not applied because dryRun=true"
}
```
```

### RW09 Apply add host requires approval [PASS]
- Query: `Add a disabled test business host named AIAgent.DryRun.TestHost.`
- Actual answer:
```text
Execution plan prepared. No production changes were executed yet.
Human approval is required before applying this mutation.
Proposed actions:
- Add host 'AIAgent.DryRun.TestHost.' (Ens.BusinessService), enabled=false.
```

### RW10 Dry-run remove host [PASS]
- Query: `Remove business host named AIAgent.DryRun.TestHost, dry-run only.`
- Actual answer:
```text
Dry-run executed. No production mutation was applied.

Result:
`json
{
  "status": "dry_run",
  "target": "production/host/remove",
  "message": "Mutation was not applied because dryRun=true"
}
```
```

### RW11 Platform health snapshot [PASS]
- Query: `Recap current platform health, active production, and runner status.`
- Actual answer:
```text
Action plan generated from your request.

Production status:
- Name: NHSTIE2.Production.OCSProduction
- Status: Running
- Namespace: DEMO2_AI2

Execution results:
- Production status: Running (NHSTIE2.Production.OCSProduction)
```

### RW12 Production host names only [PASS]
- Query: `List all production host names only.`
- Actual answer:
```text
Action plan generated from your request.

Production hosts (73):
- to.SCR eImport Oscopy
- to.SCR eImport Pathology
- to.SCR eImport Radiology
- to.RMS eImport Oscopy
- to.RMS eImport Radiology
- Lab ORM Router
- Osc ORM Router
- Rad ORM Router
- to.Winpath.ORM
- from.Winpath.ORU
- to.SolusCardiology.ORM
- to.SolusEndoscopy.ORM
- Lab ORU Router
- Rad ORU Router
- To.Sectra.ORM
- from.Sectra.ORM
- Osc ORU Router
- Car ORU Router
- Car ORM Router
- from.Sectra.ORU
- from.SolusEndoscopy.ORU
- from.
```

### RW13 Disabled host inventory [PASS]
- Query: `Show all currently disabled business hosts.`
- Actual answer:
```text
Action plan generated from your request.

Production hosts (73):
- to.SCR eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Pathology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- Lab ORM Router | En
```

### RW14 Recent error events [PASS]
- Query: `Show recent production events with level ERROR in the last 60 minutes.`
- Actual answer:
```text
Action plan generated from your request.

Recent events (50):
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updated.
```

### RW15 Queue hotspots [PASS]
- Query: `Which 10 hosts have the highest queue depth right now?`
- Actual answer:
```text
Action plan generated from your request.

No queue rows were returned.

Execution results:
- Queue snapshot read: 0 host(s).
```

### RW16 New interface design plan [FAIL]
- Query: `Design an interface plan for ADT A01/A02/A03 from PAS to DrDoctor with required transforms and routing.`
- Actual answer:
```text
Here's a design plan for **PAS Ã¢â€ â€™ DrDoctor** ADT **A01/A02/A03** with transforms and routing. I'll keep it implementationÃ¢â‚¬â€˜ready but won't generate code until you confirm the open items.

**1) Requirement Summary**
- Source: PAS (likely IPM)
- Messages: HL7 ADT A01, A02, A03
- Target: DrDoctor
- Goal: Route specific ADT events to DrDoctor with required HL7 transforms

**2) Proposed Topology (Existing + New)**
- **Inbound Service (existing)**: PAS inbound (e.g., "HL7 from IPM" using HTTP or TCP)
- 
```

### RW17 Existing router change plan [FAIL]
- Query: `Create a change plan to add a new downstream operation to the current PAS router for A08 messages only.`
- Actual answer:
```text
Execution plan prepared. No production changes were executed yet.
Human approval is required before deployment or runtime mutations.
Proposed actions:
- Prepare integration change plan and require explicit approval before apply/deploy.
```

### RW18 DTL impact assessment [FAIL]
- Query: `Assess impact of changing PID-3 mapping in the existing PAS ADT transform.`
- Actual answer:
```text
Impact assessment: changing PID-3 mapping in the existing PAS ADT transform is **highÃ¢â‚¬â€˜impact** and touches identity, routing, downstream acceptance, and audit trails.

**Likely impact areas**
1. **Patient identity in downstream systems**
   - Many consumers treat `PID:3(1).1` as the local MRN and `PID:3(2).1` as NHS number.
   - Swapping repeats or changing components can cause **misÃ¢â‚¬â€˜identification**, duplicate patient creation, or message rejection.

2. **Routing / business rules**
   - Any rul
```

### RW19 Generate business operation dry-run [FAIL]
- Query: `Create a dry-run plan for a new disabled business operation AIAgent.Generated.DrDoctor.Operation.`
- Actual answer:
```text
Action plan generated from your request.

Pending approval actions are ready for `/api/actions/approve`.
```

### RW20 Generate router rule delta dry-run [FAIL]
- Query: `Prepare dry-run router rule updates to route ORM messages to a new operation.`
- Actual answer:
```text
Execution plan prepared. No production changes were executed yet.
Human approval is required before deployment or runtime mutations.
Proposed actions:
- Prepare integration change plan and require explicit approval before apply/deploy.
```

### RW21 Generate with approval gate [FAIL]
- Query: `Generate and stage required classes for a new ORU pathway; do not deploy until I approve.`
- Actual answer:
```text
Execution plan prepared. No production changes were executed yet.
Human approval is required before deployment or runtime mutations.
Proposed actions:
- Approve the pending generation and deploy to IRIS production.
```

### RW22 Approve pending generation deploy [FAIL]
- Query: `Approve the latest staged generation and deploy it now.`
- Actual answer:
```text
Action plan generated from your request.

Pending approval actions are ready for `/api/actions/approve`.
```

### RW23 Reject pending generation [FAIL]
- Query: `Reject the currently staged generation and close it without deployment.`
- Actual answer:
```text
Action plan generated from your request.

Pending approval actions are ready for `/api/actions/approve`.
```

### RW24 Compile validation [FAIL]
- Query: `Compile all newly generated classes and show errors if any.`
- Actual answer:
```text
I can compile, but I don't have a direct compile action exposed in the action catalog. Please provide one of these so I can proceed:

1. The **exact class list** to compile, plus the **approved compile utility/method** (if there's a policyÃ¢â‚¬â€˜approved class method for compilation).
2. Confirmation that I should compile **the latest staged generation** and which API/method your environment uses for that.

Once you confirm, I'll run the compile and report any errors.
```

### RW25 Post-deploy smoke checklist [FAIL]
- Query: `Run post-deploy verification checklist for the new route and summarize pass/fail.`
- Actual answer:
```text
Execution plan prepared. No production changes were executed yet.
Human approval is required before deployment or runtime mutations.
Proposed actions:
- Approve the pending generation and deploy to IRIS production.
```

### RW26 Route presence verification [PASS]
- Query: `Confirm the new operation is connected in router rules and currently disabled.`
- Actual answer:
```text
Action plan generated from your request.

Production hosts (73):
- to.SCR eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Pathology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- Lab ORM Router | En
```

### RW27 Message flow readiness [FAIL]
- Query: `Validate readiness for A01/A02/A03 traffic through the new route without enabling it.`
- Actual answer:
```text
Action plan generated from your request.

Production hosts (73):
- to.SCR eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Pathology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- Lab ORM Router | En
```

### RW28 Queue spike investigation [PASS]
- Query: `Investigate why queue depth spiked in the last hour and identify likely bottleneck hosts.`
- Actual answer:
```text
Action plan generated from your request.

No queue rows were returned.
Recent events (50):
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Produ
```

### RW29 Failed message triage [FAIL]
- Query: `Show failed/retried message indicators for the last 2 hours and likely causes.`
- Actual answer:
```text
Action plan generated from your request.

Recent events (50):
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | ERROR <Ens>ErrException: <DISCONNECT>zIsProductionRunning+1^Ens.Director.1 -- logged as '-' number - @''
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updated.
```

### RW30 Runner platform drift check [FAIL]
- Query: `Check whether runner health or bridge connectivity changed in the last 30 minutes.`
- Actual answer:
```text
Action plan generated from your request.

Production status:
- Name: NHSTIE2.Production.OCSProduction
- Status: Running
- Namespace: DEMO2_AI2

Execution results:
- Production status: Running (NHSTIE2.Production.OCSProduction)
```

### RW31 Prepare rollback plan [FAIL]
- Query: `Prepare rollback plan to previous stable version for the latest deployment, no execution.`
- Actual answer:
```text
Execution plan prepared. No production changes were executed yet.
Human approval is required before deployment or runtime mutations.
Proposed actions:
- Rollback production to a selected previous version snapshot.
```

### RW32 Execute rollback approval gated [FAIL]
- Query: `Rollback to the previous stable snapshot now.`
- Actual answer:
```text
Action plan generated from your request.

Result:
`json
[]
```

Execution results:
- lifecycle/versions executed.
```

### RW33 Audit trail by conversation [FAIL]
- Query: `Show the audit trail for this conversation including requested actions and outcomes.`
- Actual answer:
```text
{"mode":"respond","response":"No audit-trail action is available in the action catalog, so I cannot fetch an authoritative audit log. If you want, I can summarize the actions I proposed in this conversation from chat history. Tell me to proceed.","actions":[]}
```

### RW34 CAB ready summary [FAIL]
- Query: `Produce CAB-ready summary of planned/applied integration changes and risks.`
- Actual answer:
```text
{"mode":"respond","response":"CAB Summary (based on this conversation only; no live audit log available)\n\n**Change Type**\n- Planned integration changes only. No confirmed deployments or applied production mutations in this session.\n\n**Planned/Proposed Changes**\n1. PAS -> DrDoctor ADT A01/A02/A03 route\n   - Add routing rules in existing PAS router for ADT A01/A02/A03\n   - Add DTL transform for PAS ADT to DrDoctor format\n   - Add new outbound business operation for DrDoctor\n\n2. PAS rout
```


