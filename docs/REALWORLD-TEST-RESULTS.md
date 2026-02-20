# Real-World Test Results (Actual Queries and Outcomes)

Generated from latest artifacts:
- `tests/realworld-e2e-cases.json`
- `tests/realworld-e2e-last-report.json`
- `tests/realworld-e2e-judge-report.json`

## Summary

- Total cases: 37
- Harness pass/fail: 37/0
- Judge pass/fail: 31/6

## Case Matrix

| Case | Harness | Judge | Target | Query |
|---|---|---|---|---|
| RW01 | PASS | PASS | `production/topology` | List all production hosts with full details. |
| RW02 | PASS | PASS | `production/queues` | Show queue depth for all hosts. |
| RW03 | PASS | PASS | `production/events` | Show recent production events. |
| RW04 | PASS | PASS | `lookup/ErrorCodes` | Show lookup table ErrorCodes content. |
| RW05 | PASS | PASS | `classmeta/AIAgent.API.Dispatcher` | Show metadata for class AIAgent.API.Dispatcher. |
| RW06 | PASS | PASS | `invoke-policy` | Show invocation policy. |
| RW07 | PASS | PASS | `dictionary/classes` | List classes in the NHSTIE2.* packages. |
| RW08 | PASS | PASS | `production/host/add` | Create a plan to add a disabled test business host named AIAgent.DryRun.TestHost, dry-run only. |
| RW09 | PASS | PASS | `production/host/add` | Add a disabled test business host named AIAgent.DryRun.TestHost. |
| RW10 | PASS | PASS | `production/host/remove` | Remove business host named AIAgent.DryRun.TestHost, dry-run only. |
| RW11 | PASS | PASS | `production/status` | Recap current platform health, active production, and runner status. |
| RW12 | PASS | PASS | `production/topology` | List all production host names only. |
| RW13 | PASS | PASS | `production/topology` | Show all currently disabled business hosts. |
| RW14 | PASS | PASS | `production/events` | Show recent production events with level ERROR in the last 60 minutes. |
| RW15 | PASS | PASS | `production/queues` | Which 10 hosts have the highest queue depth right now? |
| RW16 | PASS | PASS | `plan/preview` | Design an interface plan for ADT A01/A02/A03 from PAS to DrDoctor with required transforms and routing. |
| RW17 | PASS | PASS | `plan/preview` | Create a change plan to add a new downstream operation to the current PAS router for A08 messages only. |
| RW18 | PASS | PASS | `plan/preview` | Assess impact of changing PID-3 mapping in the existing PAS ADT transform. |
| RW19 | PASS | PASS | `production/host/add` | Create a dry-run plan for a new disabled business operation AIAgent.Generated.DrDoctor.Operation. |
| RW20 | PASS | PASS | `plan/preview` | Prepare dry-run router rule updates to route ORM messages to a new operation. |
| RW21 | PASS | PASS | `plan/preview` | Generate and stage required classes for a new ORU pathway; do not deploy until I approve. |
| RW22 | PASS | FAIL | `generate/approve` | Approve the latest staged generation and deploy it now. |
| RW23 | PASS | FAIL | `generate/reject` | Reject the currently staged generation and close it without deployment. |
| RW24 | PASS | PASS | `plan/preview` | Compile all newly generated classes and show errors if any. |
| RW25 | PASS | PASS | `plan/preview` | Run post-deploy verification checklist for the new route and summarize pass/fail. |
| RW26 | PASS | PASS | `production/topology` | Confirm the new operation is connected in router rules and currently disabled. |
| RW27 | PASS | PASS | `plan/preview` | Validate readiness for A01/A02/A03 traffic through the new route without enabling it. |
| RW28 | PASS | PASS | `production/queues` | Investigate why queue depth spiked in the last hour and identify likely bottleneck hosts. |
| RW29 | PASS | FAIL | `production/events` | Show failed/retried message indicators for the last 2 hours and likely causes. |
| RW30 | PASS | PASS | `production/status` | Check whether runner health or bridge connectivity changed in the last 30 minutes. |
| RW31 | PASS | PASS | `plan/preview` | Prepare rollback plan to previous stable version for the latest deployment, no execution. |
| RW32 | PASS | FAIL | `lifecycle/rollback` | Rollback to the previous stable snapshot now. |
| RW33 | PASS | PASS | `plan/preview` | Show the audit trail for this conversation including requested actions and outcomes. |
| RW34 | PASS | PASS | `plan/preview` | Produce CAB-ready summary of planned/applied integration changes and risks. |
| RW35 | PASS | FAIL | `production/host/add` | Add disabled business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC. |
| RW36 | PASS | FAIL | `production/host/settings` | Update business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC set Enabled=0. |
| RW37 | PASS | PASS | `production/host/remove` | Remove business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC. |

## Actual Query and Outcome Details

### RW01 Production topology full detail
- Query: `List all production hosts with full details.`
- Action target: `production/topology`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/topology"] => actual 'production/topology' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Production hosts (","Current production has"] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Production hosts (78):
- to.SCR eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Pathology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- Lab ORM Router | En
```

### RW02 Queue depth overview
- Query: `Show queue depth for all hosts.`
- Action target: `production/queues`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/queues"] => actual 'production/queues' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Queue counts","Current queue counts","No queue rows were returned."] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

No queue rows were returned.

Execution results:
- Queue snapshot read: 0 host(s).
```

### RW03 Recent production events
- Query: `Show recent production events.`
- Action target: `production/events`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/events"] => actual 'production/events' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Recent events","Recent production events"] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Recent events (50):
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updated.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Disabled item 'AIAgent.Demo.OpC' in Production 'NHSTIE2.Production.OCSProductio
```

### RW04 Lookup table content
- Query: `Show lookup table ErrorCodes content.`
- Action target: `lookup/ErrorCodes`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["lookup/ErrorCodes"] => actual 'lookup/ErrorCodes' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Lookup table ErrorCodes","has no entries"] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
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

### RW05 Class metadata query
- Query: `Show metadata for class AIAgent.API.Dispatcher.`
- Action target: `classmeta/AIAgent.API.Dispatcher`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["classmeta/AIAgent.API.Dispatcher"] => actual 'classmeta/AIAgent.API.Dispatcher' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Class metadata:","Methods:"] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
```text
Class metadata: AIAgent.API.Dispatcher
- Super: %CSP.REST
- Methods: 40
- Properties: 0
- Parameters: 0
- Method ApproveGeneration() -> %Status
- Method BuildCapabilities(ns:%String="") -> %DynamicObject
- Method BuildTargetCatalog() -> %DynamicArray
- Method Cap(capability:%String,ns:%String,allowed:%Integer=1,reason:%String="") -> %DynamicObject
- Method CreateConversation() -> %Status
- Method DeleteConversation(id:%String) -> %Status
- Method ExecuteSQL() -> %Status
- Method GetAuditLog() ->
```

### RW06 Invocation policy query
- Query: `Show invocation policy.`
- Action target: `invoke-policy`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["invoke-policy"] => actual 'invoke-policy' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Invocation policy:","Mode:"] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
```text
Invocation policy:
- Mode: allow-by-default
- Max arguments: 4

Execution results:
- Invocation policy read.
```

### RW07 Class catalog by package pattern
- Query: `List classes in the NHSTIE2.* packages.`
- Action target: `dictionary/classes`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["dictionary/classes"] => actual 'dictionary/classes' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Classes (","Dictionary class catalog read"] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
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

### RW08 Dry-run add disabled host
- Query: `Create a plan to add a disabled test business host named AIAgent.DryRun.TestHost, dry-run only.`
- Action target: `production/host/add`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/host/add"] => actual 'production/host/add' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Dry-run executed","\"dry_run\""] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
```text
Dry-run executed. No production mutation was applied.

Result:
```json
{
  "status": "dry_run",
  "target": "production/host/add",
  "message": "Mutation was not applied because dryRun=true"
}
```
```

### RW09 Apply add host requires approval
- Query: `Add a disabled test business host named AIAgent.DryRun.TestHost.`
- Action target: `production/host/add`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/host/add"] => actual 'production/host/add' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Action executed","Execution results","Add host"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action execution failed.

Execution results:
- Action failed (production/host/add): IRIS API error: 500 Internal Server Error
```

### RW10 Dry-run remove host
- Query: `Remove business host named AIAgent.DryRun.TestHost, dry-run only.`
- Action target: `production/host/remove`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/host/remove"] => actual 'production/host/remove' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Dry-run executed","\"dry_run\""] : PASS
  - response excludes ["Prepare integration change plan"] : PASS
- Actual outcome (response preview):
```text
Dry-run executed. No production mutation was applied.

Result:
```json
{
  "status": "dry_run",
  "target": "production/host/remove",
  "message": "Mutation was not applied because dryRun=true"
}
```
```

### RW11 Platform health snapshot
- Query: `Recap current platform health, active production, and runner status.`
- Action target: `production/status`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/status"] => actual 'production/status' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Production status","Runner health","Bridge"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Production status:
- Name: NHSTIE2.Production.OCSProduction
- Status: Running
- Namespace: DEMO2_AI2
- Runner health: check /runners endpoint for per-runner status.
- Bridge connectivity: healthy if API responses are current.

Execution results:
- Production status: Running (NHSTIE2.Production.OCSProduction)
```

### RW12 Production host names only
- Query: `List all production host names only.`
- Action target: `production/topology`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/topology"] => actual 'production/topology' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Production hosts (","host(s)"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Production hosts (78):
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

### RW13 Disabled host inventory
- Query: `Show all currently disabled business hosts.`
- Action target: `production/topology`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/topology"] => actual 'production/topology' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["disabled","host"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Production hosts (78):
- to.SCR eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Pathology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- Lab ORM Router | En
```

### RW14 Recent error events
- Query: `Show recent production events with level ERROR in the last 60 minutes.`
- Action target: `production/events`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/events"] => actual 'production/events' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Recent events","No recent event rows were returned."] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Recent events (50):
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updated.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Disabled item 'AIAgent.Demo.OpC' in Production 'NHSTIE2.Production.OCSProductio
```

### RW15 Queue hotspots
- Query: `Which 10 hosts have the highest queue depth right now?`
- Action target: `production/queues`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/queues"] => actual 'production/queues' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Queue counts","No queue rows were returned."] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

No queue rows were returned.

Execution results:
- Queue snapshot read: 0 host(s).
```

### RW16 New interface design plan
- Query: `Design an interface plan for ADT A01/A02/A03 from PAS to DrDoctor with required transforms and routing.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["plan","A01","A02","A03"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Design an interface plan for ADT A01/A02/A03 from PAS to DrDoctor with required transforms and routing.
- Message scope: detected HL7 event types from request.
- Routing: evaluate current rules and define target deltas.
- Transformation impact: inspect mapping changes and affected fields.
```

### RW17 Existing router change plan
- Query: `Create a change plan to add a new downstream operation to the current PAS router for A08 messages only.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["plan","A08","router"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Create a change plan to add a new downstream operation to the current PAS router for A08 messages only.
- Message scope: detected HL7 event types from request.
- Routing: evaluate current rules and define target deltas.
```

### RW18 DTL impact assessment
- Query: `Assess impact of changing PID-3 mapping in the existing PAS ADT transform.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["impact","PID-3","transform"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Assess impact of changing PID-3 mapping in the existing PAS ADT transform.
- Message scope: detected HL7 event types from request.
- Transformation impact: inspect mapping changes and affected fields.
```

### RW19 Generate business operation dry-run
- Query: `Create a dry-run plan for a new disabled business operation AIAgent.Generated.DrDoctor.Operation.`
- Action target: `production/host/add`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/host/add"] => actual 'production/host/add' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Dry-run","disabled","business operation"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Dry-run executed. No production mutation was applied.

Result:
```json
{
  "status": "dry_run",
  "target": "production/host/add",
  "message": "Mutation was not applied because dryRun=true"
}
```
```

### RW20 Generate router rule delta dry-run
- Query: `Prepare dry-run router rule updates to route ORM messages to a new operation.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["dry-run","ORM","route"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Prepare dry-run router rule updates to route ORM messages to a new operation.
- Message scope: detected HL7 event types from request.
- Routing: evaluate current rules and define target deltas.
```

### RW21 Generate with approval gate
- Query: `Generate and stage required classes for a new ORU pathway; do not deploy until I approve.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Execution plan preview generated","Plan:","ORU"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Generate and stage required classes for a new ORU pathway; do not deploy until I approve.
- Message scope: detected HL7 event types from request.
- Approval placeholder: execution can be gated at runtime.
```

### RW22 Approve pending generation deploy
- Query: `Approve the latest staged generation and deploy it now.`
- Action target: `generate/approve`
- Harness: `PASS`
- Judge: `FAIL`
- Judge rationale: Execution reported runtime/API failure, so strict real-world success criteria are not met.
- Harness checks:
  - target in ["generate/approve"] => actual 'generate/approve' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["approve","deploy","Execution"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Execution results:
- Action failed (generate/approve): IRIS API error: 409 Conflict
```

### RW23 Reject pending generation
- Query: `Reject the currently staged generation and close it without deployment.`
- Action target: `generate/reject`
- Harness: `PASS`
- Judge: `FAIL`
- Judge rationale: Execution reported runtime/API failure, so strict real-world success criteria are not met.
- Harness checks:
  - target in ["generate/reject"] => actual 'generate/reject' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["reject","without deployment","Execution"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Execution results:
- Action failed (generate/reject): IRIS API error: 409 Conflict
```

### RW24 Compile validation
- Query: `Compile all newly generated classes and show errors if any.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["compile","errors","classes"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Compile all newly generated classes and show errors if any.
- Validation: compile impacted classes and collect errors.
```

### RW25 Post-deploy smoke checklist
- Query: `Run post-deploy verification checklist for the new route and summarize pass/fail.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["checklist","pass","fail"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Run post-deploy verification checklist for the new route and summarize pass/fail.
- Routing: evaluate current rules and define target deltas.
- Verification: produce post-change pass/fail checklist.
- Approval placeholder: execution can be gated at runtime.
```

### RW26 Route presence verification
- Query: `Confirm the new operation is connected in router rules and currently disabled.`
- Action target: `production/topology`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/topology"] => actual 'production/topology' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["connected","disabled","router"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Production hosts (78):
- to.SCR eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Pathology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.SCR eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Oscopy | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- to.RMS eImport Radiology | EnsLib.HL7.Operation.TCPOperation | Unknown | Disabled
- Lab ORM Router | EnsLib.HL7.MsgRouter.RoutingEngine | Unknown
```

### RW27 Message flow readiness
- Query: `Validate readiness for A01/A02/A03 traffic through the new route without enabling it.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["readiness","A01","A02","A03"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Validate readiness for A01/A02/A03 traffic through the new route without enabling it.
- Message scope: detected HL7 event types from request.
- Routing: evaluate current rules and define target deltas.
- Verification: produce post-change pass/fail checklist.
```

### RW28 Queue spike investigation
- Query: `Investigate why queue depth spiked in the last hour and identify likely bottleneck hosts.`
- Action target: `production/queues`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/queues"] => actual 'production/queues' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["queue","bottleneck","host"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

No queue rows were returned.
Recent events (50):
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updated.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Disabled item 'AIAgent.Demo.OpC' in Production 'NH
```

### RW29 Failed message triage
- Query: `Show failed/retried message indicators for the last 2 hours and likely causes.`
- Action target: `production/events`
- Harness: `PASS`
- Judge: `FAIL`
- Judge rationale: Did not provide explicit failed/retried indicators with likely-cause analysis.
- Harness checks:
  - target in ["production/events"] => actual 'production/events' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["failed","retried","cause"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action plan generated from your request.

Recent events (50):
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updated.
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' updating...
-  |  |  | Production 'NHSTIE2.Production.OCSProduction' is up-to-date.
-  |  |  | Disabled item 'AIAgent.Demo.OpC' in Production 'NHSTIE2.Production.OCSProductio
```

### RW30 Runner platform drift check
- Query: `Check whether runner health or bridge connectivity changed in the last 30 minutes.`
- Action target: `production/status`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/status"] => actual 'production/status' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["runner","bridge","health"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Production status:
- Name: NHSTIE2.Production.OCSProduction
- Status: Running
- Namespace: DEMO2_AI2
- Runner health: check /runners endpoint for per-runner status.
- Bridge connectivity: healthy if API responses are current.

Execution results:
- Production status: Running (NHSTIE2.Production.OCSProduction)
```

### RW31 Prepare rollback plan
- Query: `Prepare rollback plan to previous stable version for the latest deployment, no execution.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview","lifecycle/rollback"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["rollback","plan","Execution plan"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Prepare rollback plan to previous stable version for the latest deployment, no execution.
- Approval placeholder: execution can be gated at runtime.
```

### RW32 Execute rollback approval gated
- Query: `Rollback to the previous stable snapshot now.`
- Action target: `lifecycle/rollback`
- Harness: `PASS`
- Judge: `FAIL`
- Judge rationale: Execution reported runtime/API failure, so strict real-world success criteria are not met.
- Harness checks:
  - target in ["lifecycle/rollback"] => actual 'lifecycle/rollback' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["rollback","snapshot","Execution"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action execution failed.

Execution results:
- Action failed (lifecycle/rollback): IRIS API error: 400 Bad Request
```

### RW33 Audit trail by conversation
- Query: `Show the audit trail for this conversation including requested actions and outcomes.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["audit","actions","outcomes"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Show the audit trail for this conversation including requested actions and outcomes.
- Governance: include action/outcome audit summary.
```

### RW34 CAB ready summary
- Query: `Produce CAB-ready summary of planned/applied integration changes and risks.`
- Action target: `plan/preview`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["plan/preview"] => actual 'plan/preview' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["CAB","changes","risks"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Execution plan preview generated.

Plan:
- Request: Produce CAB-ready summary of planned/applied integration changes and risks.
- Governance: include CAB-ready change and risk summary.
```

### RW35 Add multiple hosts demo
- Query: `Add disabled business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC.`
- Action target: `production/host/add`
- Harness: `PASS`
- Judge: `FAIL`
- Judge rationale: Execution reported runtime/API failure, so strict real-world success criteria are not met.
- Harness checks:
  - target in ["production/host/add"] => actual 'production/host/add' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Execution","Add host","executed"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action execution failed.

Execution results:
- Action failed (production/host/add): IRIS API error: 500 Internal Server Error
```

### RW36 Edit multiple hosts demo
- Query: `Update business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC set Enabled=0.`
- Action target: `production/host/settings`
- Harness: `PASS`
- Judge: `FAIL`
- Judge rationale: Execution reported runtime/API failure, so strict real-world success criteria are not met.
- Harness checks:
  - target in ["production/host/settings"] => actual 'production/host/settings' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Update host","Execution","settings"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Action execution failed.

Execution results:
- Action failed (production/host/settings): IRIS API error: 500 Internal Server Error
```

### RW37 Remove multiple hosts demo
- Query: `Remove business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC.`
- Action target: `production/host/remove`
- Harness: `PASS`
- Judge: `PASS`
- Judge rationale: Observed behavior aligns with expected real-world outcome.
- Harness checks:
  - target in ["production/host/remove"] => actual 'production/host/remove' : PASS
  - requiresApproval=false => actual false : PASS
  - response includes any ["Remove host","Execution","executed"] : PASS
  - response excludes [] : PASS
- Actual outcome (response preview):
```text
Result:
```json
{
  "target": "production/host/remove",
  "count": 1,
  "results": [
    {
      "action": "remove",
      "hostName": "AIAgent",
      "status": "removed",
      "message": "Host removed."
    }
  ]
}
```

Execution results:
- production/host/remove executed.
```
