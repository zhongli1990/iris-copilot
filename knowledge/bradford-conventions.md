# Bradford TIE Conventions for AI Agents

This document describes the specific patterns, naming conventions, and architecture
of the NHS Bradford Teaching Hospitals Trust Integration Engine (TIE).

## 1. Production

- **Main production:** `BRI.Productions.TEST` (in TEST namespace)
- **150+ configured hosts** spanning 74 clinical system interfaces
- **Architecture:** Hub-and-spoke with routing engines

## 2. Naming Conventions

### Package Structure
```
BRI.                                     Top-level namespace
BRI.Productions.TEST                     Main production class
BRI.Interfaces.<System>.                 Per-system interface classes
BRI.Interfaces.<System>.Service.         Inbound services
BRI.Interfaces.<System>.Process.         Business processes
BRI.Interfaces.<System>.Operations.      Outbound operations
BRI.Interfaces.<System>.Transformations. DTL transforms
BRI.Interfaces.<System>.Messages.        Message classes
BRI.Interfaces.<System>.RoutingRules.    Routing rule classes
BRI.Interfaces.Router.                   Shared routing rulesets
BRI.Interfaces.Canonical.               Canonical normalization layer
BRI.Operations.NHSMail.                 Shared NHS Mail operation
```

### AI-Generated Classes
```
AIAgent.Generated.<Domain>.<ComponentType>.<Name>
Example: AIAgent.Generated.Pharmacy.Process.DoseCheckProcess
Example: AIAgent.Generated.Radiology.Operation.CRISResultForwarder
```

### Production Host Names
Production host names (the Name in Ens.Config.Item) follow these patterns:
- **Services:** "From <System> <MessageType>" or "HL7 from <System>"
  - Example: "From Cerner ADT", "HL7 from IPM", "From Cerner Orders"
- **Routers:** "<System> Router" or "<System> Distributor"
  - Example: "Cerner Distributor", "RTADT Router", "AScribe Pharmacy Router"
- **Processes:** "<Descriptive Name> Process"
  - Example: "Pharmacy Dose Check Process", "YHCR Resource Process"
- **Operations:** "HL7 To <System>" or "HL7 To <System> <MessageType>"
  - Example: "HL7 To Waba ADT TCP", "HL7 to RTADT", "HL7 to BadgerNet"

## 3. Key Upstream Systems

| System | Port | Schema | Message Types |
|--------|------|--------|---------------|
| IPM (PAS) | HTTP 443 | 2.3 | ADT (A01-A52), REF (I12-I14) |
| Cerner | TCP 30000-30007 | CERNER2.3 | ADT, ORM, ORU, SIU, MDM, MFN, RDE |
| CRIS | TCP 7982 | 2.3.1 | ORM (orders), ORU (results) |
| WinPath | TCP 35100 | 2.4 | ORU (lab results) |
| TelePath | TCP 9985 | 2.3 | ORU (lab results) |
| Fordman | File | PMIP | Pathology orders/results |

## 4. Key Downstream Systems

| System | Protocol | Port/Address |
|--------|----------|-------------|
| A&E (ExtraMed) | TCP | 10200 |
| RTADT | TCP | 30152 |
| BadgerNet | SOAP | HL7Import.asmx |
| SystmOne | TCP | 2357 |
| CRIS | TCP | 7107 |
| ICE New | TCP | 5412-5415 |
| ICNET | TCP | Various |
| Waba | TCP | 10001 |
| AScribe Pharmacy | TCP | Various |

## 5. Routing Architecture

The Bradford TIE uses a tiered routing architecture:

```
Inbound Service
    ↓
Sequence Manager (optional, for IPM)
    ↓
System Distributor (first-level router)
    ├→ Domain Router 1 (e.g., "RTADT Router")
    ├→ Domain Router 2 (e.g., "Waba Router")
    ├→ Domain Router 3 (e.g., "Unisoft Router")
    ├→ Canonical Router (normalizes for multi-target)
    └→ Specialty Router (e.g., "Cardiology Router")
         ↓
    Transform (DTL)
         ↓
    Outbound Operation
```

### Routing Rules
- Use `EnsLib.HL7.MsgRouter.RoutingEngine` as the class
- Routing rules are separate classes extending `Ens.Rule.Definition`
- Rules constrain on `Document.DocType` and `MSH-9.2` (event type)
- Transforms are applied inline within rules using DTL classes

## 6. Common Patterns

### Email Alerting
The `BRI.Operations.NHSMail.NHSMailDispatcher` is the central email operation.
Many processes send alerts through it. Use `EnsLib.EMail.OutboundAdapter`.

### File-based Error Logging
Failed messages are often written to files using `EnsLib.File.OutboundAdapter`.
Error file paths typically follow: `C:\TEST\<System>\Errors\`

### Canonical Normalization
Messages from different sources are normalized through `BRI.Interfaces.Canonical`:
- `Canonical.Processes.checkID` — validates/enriches identifiers
- `Canonical.Processes.DeceasedMessageProcess` — handles deceased flag logic
- Canonical transforms normalize field mappings

### YHCR/FHIR Integration
Regional health data exchange uses:
- Custom `PersistentObject` classes for FHIR payloads
- REST operations for FHIR queries
- MDM-to-PatientRequest transforms

## 7. Important Notes for Code Generation

1. **Always use parameterized SQL** (`?` placeholders) — never concatenate values into SQL
2. **Always handle errors** with try/catch and return `%Status`
3. **Use SETTINGS parameter** for configurable values (ports, paths, endpoints)
4. **Use Lookup Tables** for reference data that changes without code deployment
5. **Use async sends** (`SendRequestAsync`) for non-blocking operations
6. **Log significant events** through the Ensemble Event Log
7. **Follow the BRI package hierarchy** for new interfaces
8. **Test with synthetic HL7 messages** using `EnsLib.HL7.Message` and `SetValueAt()`
9. **Bradford Trust MRN** is in PID:3(1).1 — it's called "BTHFT MRN"
10. **HL7 schemas in use:** 2.3, 2.3.1, 2.4, CERNER2.3, custom schemas
