# TIE Conventions Reference for AI Agents

This document describes a representative set of patterns, naming conventions,
and architecture that an NHS Trust Integration Engine (TIE) built on IRIS
HealthConnect typically follows. The values shown are illustrative defaults —
deploying sites should override them via runtime discovery (the live IRIS
production catalogue) and/or by replacing this document with their own
trust-specific conventions file.

> All trust names, system names, hostnames, port numbers, and topology details
> in this document are generic placeholders. They do not describe any specific
> NHS Trust's live integration estate.

## 1. Production

- **Main production:** typically a single `<TrustPrefix>.Productions.<Env>` class (e.g. `Trust.Productions.TEST`) per IRIS namespace
- **Host count:** discover live via `query/production/topology` — varies per site
- **Architecture:** hub-and-spoke with routing engines is the common pattern

## 2. Naming Conventions

### Package Structure
A trust's TIE typically uses a short top-level package prefix (e.g. `Trust.`,
`<Initials>.`, or the site-chosen namespace name). The Copilot reads the live
catalogue rather than assuming a fixed prefix.

```
Trust.                                     Top-level namespace (illustrative)
Trust.Productions.<Env>                    Main production class
Trust.Interfaces.<System>.                 Per-system interface classes
Trust.Interfaces.<System>.Service.         Inbound services
Trust.Interfaces.<System>.Process.         Business processes
Trust.Interfaces.<System>.Operations.      Outbound operations
Trust.Interfaces.<System>.Transformations. DTL transforms
Trust.Interfaces.<System>.Messages.        Message classes
Trust.Interfaces.<System>.RoutingRules.    Routing rule classes
Trust.Interfaces.Router.                   Shared routing rulesets
Trust.Interfaces.Canonical.                Canonical normalisation layer
Trust.Operations.NHSMail.                  Shared NHS Mail operation
```

### AI-Generated Classes
```
AIAgent.Generated.<Domain>.<ComponentType>.<Name>
Example: AIAgent.Generated.Pharmacy.Process.DoseCheckProcess
Example: AIAgent.Generated.Radiology.Operation.RadiologyResultForwarder
```

### Production Host Names
Production host names (the `Name` in `Ens.Config.Item`) typically follow these patterns:
- **Services:** `"From <System> <MessageType>"` or `"HL7 from <System>"`
  - Example: `"From PAS ADT"`, `"HL7 from PAS"`, `"From EPR Orders"`
- **Routers:** `"<System> Router"` or `"<System> Distributor"`
  - Example: `"EPR Distributor"`, `"ADT Router"`, `"Pharmacy Router"`
- **Processes:** `"<Descriptive Name> Process"`
  - Example: `"Pharmacy Dose Check Process"`, `"Regional Care Record Process"`
- **Operations:** `"HL7 To <System>"` or `"HL7 To <System> <MessageType>"`
  - Example: `"HL7 To Ward Management TCP"`, `"HL7 To Legacy ADT"`, `"HL7 To Maternity Network"`

## 3. Common Upstream Systems (illustrative)

The combinations and ports below are placeholders. Read the live production for
the actual list of inbound services.

| System (category) | Typical Protocol | Typical Schema | Typical Message Types |
|-------------------|------------------|----------------|-----------------------|
| PAS               | HTTP / TCP       | HL7 v2.3       | ADT (A01-A52), REF (I12-I14) |
| EPR (e.g. Cerner) | TCP              | Vendor schema  | ADT, ORM, ORU, SIU, MDM, MFN, RDE |
| RIS               | TCP              | HL7 v2.3.1     | ORM (orders), ORU (results) |
| LIMS              | TCP              | HL7 v2.4       | ORU (lab results) |
| Pathology         | TCP / File       | HL7 v2.3       | ORU (lab results) |

## 4. Common Downstream Systems (illustrative)

| System (category)             | Typical Protocol | Notes |
|-------------------------------|------------------|-------|
| Emergency Department          | TCP              | ADT feeds |
| Legacy ADT distribution       | TCP              | Hub-of-hubs onward routing |
| Maternity Network             | SOAP             | Web service import endpoint |
| Primary care record (e.g. TPP)| TCP              | ADT / clinical doc forwards |
| RIS                           | TCP              | Result return |
| ICE / order comms             | TCP              | Results to ordering clinician |
| Ward management               | TCP              | Bed/ward state |
| Infection control             | TCP              | ADT plus pathology feeds |
| Electronic prescribing (EPMA) | TCP              | RDE pharmacy order forwarding |
| Regional Care Record / FHIR   | HTTPS            | FHIR R4 patient/encounter resources |

## 5. Routing Architecture

A typical tiered routing architecture:

```
Inbound Service
    |
    v
Sequence Manager (optional, for ordered PAS feeds)
    |
    v
System Distributor (first-level router)
    |--> Domain Router 1 (e.g., "ADT Router")
    |--> Domain Router 2 (e.g., "Ward Management Router")
    |--> Domain Router 3 (e.g., "Pharmacy Router")
    |--> Canonical Router (normalises for multi-target)
    \--> Specialty Router (e.g., "Cardiology Router")
         |
         v
    Transform (DTL)
         |
         v
    Outbound Operation
```

### Routing Rules
- Use `EnsLib.HL7.MsgRouter.RoutingEngine` as the class
- Routing rules are separate classes extending `Ens.Rule.Definition`
- Rules constrain on `Document.DocType` and `MSH-9.2` (event type)
- Transforms are applied inline within rules using DTL classes

## 6. Common Patterns

### Email Alerting
A central email operation (typical name: `Trust.Operations.NHSMail.NHSMailDispatcher`)
provides the shared NHS Mail send adapter via `EnsLib.EMail.OutboundAdapter`.
Processes call it for clinical safety / ops alerts.

### File-based Error Logging
Failed messages are often written to files using `EnsLib.File.OutboundAdapter`.
Error file paths typically follow a per-environment convention such as
`<DataRoot>/<Env>/<System>/Errors/`.

### Canonical Normalisation
Messages from different sources are normalised through a `Canonical.*`
sub-package. Common components:
- `Canonical.Processes.checkID` - validates / enriches identifiers
- `Canonical.Processes.DeceasedMessageProcess` - handles deceased-flag logic
- Canonical DTL transforms normalise field mappings to a single internal shape

### Regional Care Record / FHIR Integration
Regional health data exchange typically uses:
- Custom `PersistentObject` classes for FHIR payloads
- REST operations for FHIR queries
- MDM-to-PatientRequest DTL transforms

## 7. Important Notes for Code Generation

1. **Always use parameterised SQL** (`?` placeholders) - never concatenate values into SQL
2. **Always handle errors** with try/catch and return `%Status`
3. **Use SETTINGS parameter** for configurable values (ports, paths, endpoints)
4. **Use Lookup Tables** for reference data that changes without code deployment
5. **Use async sends** (`SendRequestAsync`) for non-blocking operations
6. **Log significant events** through the Ensemble Event Log
7. **Follow the trust's local package hierarchy** - discover from the live catalogue
   rather than hardcoding a prefix

## 8. Customising This Document

Sites deploying this Copilot are expected to:

1. Replace this generic conventions document with one that reflects the
   trust's actual package prefix, environment naming, integration estate, and
   internal coding standards. Keep it under `knowledge/tie-conventions.md`
   (same path) so the Copilot continues to read it.
2. Treat your local copy as **confidential** - do not commit a site-specific
   version back to a public repository.
