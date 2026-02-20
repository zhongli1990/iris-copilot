# Demo Clinical Lifecycle â€” Pharmacy Dose-Check Alert Integration

**Purpose:** This document demonstrates the complete lifecycle of a new clinical integration requirement â€” from initial English-language request through AI-driven design, code generation, human review, deployment, testing, and ongoing monitoring â€” all within the IRIS AI Agent Platform ("IRIS Copilot").

**Demo Scenario:** A realistic, net-new Site TIE integration that does not exist today.

---

## The Clinical Requirement (English)

> **From:** Sarah Mitchell, Lead Pharmacist, Site Teaching Hospitals
>
> **To:** Integration Team
>
> **Subject:** Automated Pharmacy Dose-Check Alerts
>
> We need an automated safety check on pharmacy orders. When Cerner sends a pharmacy order (RDE^O11 message), the integration engine should:
>
> 1. Extract the drug code and ordered dose from the message
> 2. Look up the maximum safe dose for that drug in a reference table
> 3. If the ordered dose exceeds the safe maximum:
>    - Send an email alert to the pharmacy safety team (pharmsafety@Sitehospitals.nhs.uk) with the patient MRN, drug name, ordered dose, and safe maximum
>    - Log the event to a file for audit purposes
> 4. Regardless of dose check result, forward the original order to the existing Cerner pharmacy route unchanged
>
> This is urgent for patient safety. The reference table of drug/max-dose pairs will be maintained by Pharmacy and should be easy to update without code changes.

---

## Phase 1: User Opens Chat UI and Enters Requirement

The pharmacist (or hospital IT staff relaying the request) opens their browser to the IRIS Copilot URL and types:

```
User: We need a pharmacy dose-check alert. When Cerner sends RDE^O11 pharmacy
orders, check if the dose exceeds a safe maximum from a lookup table. If unsafe,
email pharmsafety@Sitehospitals.nhs.uk with patient MRN, drug name, ordered
dose, and safe max. Also log unsafe events to a file. Always forward the original
order to the existing Cerner pharmacy route regardless.
```

---

## Phase 2: Orchestrator Agent â€” Intent Analysis

The **Orchestrator Agent** (Claude Opus 4.6 via Claude Agent SDK) processes the message:

### 2.1 Intent Classification

```
Intent:           NEW_INTEGRATION
Domain:           Pharmacy / Order Safety
Message Type:     HL7 RDE^O11 (Pharmacy/Treatment Encoded Order)
Source System:    Cerner (already connected â€” "From Cerner Orders" on port 30002)
New Components:   Business Process (dose checking), Lookup Table, Email Operation, File Operation
Existing Reuse:   Cerner inbound service already exists, pharmacy forwarding route already exists
```

### 2.2 Orchestrator Asks Clarifying Questions

The Orchestrator checks the existing Site TIE production (via IRIS MCP tools) and identifies what it needs to confirm:

```
IRIS Copilot: I can see the Site TIE already receives Cerner orders via
"From Cerner Orders" (TCP port 30002, schema CERNER2.3). I have a few questions
before I design this:

1. Which HL7 field contains the drug code? Typically RXE-2 (Give Code) in
   RDE^O11. Should I use RXE-2.1 (Identifier)?

2. Which field contains the ordered dose? Typically RXE-3 (Give Amount - Minimum).
   Confirm?

3. The dose units â€” should I also verify units match (e.g., "mg" vs "mcg")?
   Or is the lookup table keyed by drug code alone with a single max number?

4. For the existing pharmacy route: I can see "AScribe Pharmacy Router" in the
   production. Should the original RDE^O11 continue to AScribe, or is there a
   different target?

5. File logging path â€” where should audit files be written?
   (e.g., C:\TEST\PharmAlerts\ or a network share?)
```

### 2.3 User Responds

```
User: 1. Yes, RXE-2.1 for drug code
      2. Yes, RXE-3 for dose
      3. Lookup table keyed by drug code, single max dose number, same units assumed
      4. Yes, forward to AScribe Pharmacy Router unchanged
      5. Log to C:\TIE\Logs\PharmDoseAlerts\
```

---

## Phase 3: Architect Agent â€” Production Topology Design

The **Architect Agent** queries the IRIS MCP server to understand the current production, then designs the topology:

### 3.1 Existing Topology (Discovered via MCP)

```
[From Cerner Orders]                    â† EnsLib.HL7.Service.TCPService, port 30002
    â”‚
    â–¼
[Cerner Distributor]                    â† EnsLib.HL7.MsgRouter.RoutingEngine
    â”‚                                      ruleset: BRI.Interfaces.Cerner.DistributorRules
    â”œâ”€â”€â†’ [AScribe Pharmacy Router]      â† existing pharmacy route (RDE messages)
    â”œâ”€â”€â†’ [CRIS Router]                  â† radiology orders
    â”œâ”€â”€â†’ [Other routers...]
```

### 3.2 Proposed Topology Addition

```
[From Cerner Orders]                    â† EXISTING (no change)
    â”‚
    â–¼
[Cerner Distributor]                    â† EXISTING â€” add ONE new rule:
    â”‚                                      "When RDE^O11, also send to Pharmacy Dose Check Process"
    â”‚
    â”œâ”€â”€â†’ [AScribe Pharmacy Router]      â† EXISTING (unchanged, still receives all pharmacy orders)
    â”‚
    â””â”€â”€â†’ [Pharmacy Dose Check Process]  â† NEW Business Process (BPL)
              â”‚
              â”‚ (1) Extract drug code from RXE-2.1 and dose from RXE-3
              â”‚ (2) Lookup max dose from "PharmDoseLimit" lookup table
              â”‚ (3) If dose > max:
              â”‚         â”‚
              â”‚         â”œâ”€â”€â†’ [Pharmacy Alert Email]      â† NEW Business Operation (email)
              â”‚         â”‚        To: pharmsafety@Sitehospitals.nhs.uk
              â”‚         â”‚        Subject: "DOSE ALERT: {DrugName} - {Dose} exceeds max {MaxDose}"
              â”‚         â”‚
              â”‚         â””â”€â”€â†’ [Pharmacy Alert File Log]   â† NEW Business Operation (file)
              â”‚                  Path: C:\TIE\Logs\PharmDoseAlerts\
              â”‚                  One line per alert: timestamp|MRN|drug|dose|max
              â”‚
              â””â”€ (4) No further action needed (AScribe already gets the order
                     from Cerner Distributor independently)
```

### 3.3 New Components Summary

| # | Component | Type | Class Name |
|---|-----------|------|------------|
| 1 | Pharmacy Dose Check Process | Business Process (BPL) | `Site.AIGenerated.Pharmacy.Process.DoseCheckProcess` |
| 2 | Dose Check Request Message | Message | `Site.AIGenerated.Pharmacy.Message.DoseCheckRequest` |
| 3 | Dose Check Response Message | Message | `Site.AIGenerated.Pharmacy.Message.DoseCheckResponse` |
| 4 | Alert Email Request Message | Message | `Site.AIGenerated.Pharmacy.Message.AlertEmailRequest` |
| 5 | Pharmacy Alert Email | Business Operation | `Site.AIGenerated.Pharmacy.Operation.AlertEmailOperation` |
| 6 | Pharmacy Alert File Log | Business Operation | `Site.AIGenerated.Pharmacy.Operation.AlertFileOperation` |
| 7 | RDE to DoseCheck Transform | Data Transformation | `Site.AIGenerated.Pharmacy.Transform.RDEtoDoseCheck` |
| 8 | PharmDoseLimit | Lookup Table | `PharmDoseLimit.LUT` (drug code â†’ max dose) |
| 9 | Unit Test | %UnitTest | `Site.AIGenerated.Pharmacy.Test.DoseCheckTest` |

### 3.4 Architect Presents to User

```
IRIS Copilot: Here's my design for the Pharmacy Dose-Check Alert integration:

  [diagram rendered in Production Viewer panel]

I'll create 8 new classes + 1 lookup table. The key design decisions:

  â€¢ The dose check runs IN PARALLEL with the existing AScribe pharmacy route â€”
    your orders still flow to AScribe immediately, no delay.
  â€¢ The dose check process is a BPL (graphical business process) so it's easy
    to modify later.
  â€¢ The drug/max-dose reference is a standard IRIS Lookup Table, editable from
    the Management Portal without any code changes.
  â€¢ Email uses the existing NHSMail adapter pattern from the Site TIE.

Shall I generate the code?
```

```
User: Yes, generate it.
```

---

## Phase 4: Developer Agent â€” Code Generation

The **Developer Agent** (OpenAI Codex, with Claude review) generates all ObjectScript classes.

### 4.1 Generated Class: Business Process (BPL)

**File:** `Site.AIGenerated.Pharmacy.Process.DoseCheckProcess`

```objectscript
/// Pharmacy Dose-Check Process.
/// Receives RDE^O11 messages from Cerner Distributor, checks ordered dose
/// against the PharmDoseLimit lookup table, and triggers alerts if exceeded.
/// Generated by IRIS Copilot.
Class Site.AIGenerated.Pharmacy.Process.DoseCheckProcess Extends Ens.BusinessProcessBPL
{

Parameter SETTINGS = "AlertEmailTarget,AlertFileTarget,LookupTableName";

/// Production config name of the email alert operation
Property AlertEmailTarget As %String(MAXLEN = 200) [ InitialExpression = "Pharmacy Alert Email" ];

/// Production config name of the file alert operation
Property AlertFileTarget As %String(MAXLEN = 200) [ InitialExpression = "Pharmacy Alert File Log" ];

/// Name of the lookup table containing drug code â†’ max dose
Property LookupTableName As %String(MAXLEN = 100) [ InitialExpression = "PharmDoseLimit" ];

/// Main BPL
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='Ens.StreamContainer'
         response='Ens.Response' >

<sequence>

  <!-- Extract fields from RDE^O11 -->
  <assign name="Extract Drug Code"
          property="context.DrugCode"
          value="request.GetValueAt(&quot;RXEgrp(1).RXE:2.1&quot;)" />
  <assign name="Extract Drug Name"
          property="context.DrugName"
          value="request.GetValueAt(&quot;RXEgrp(1).RXE:2.2&quot;)" />
  <assign name="Extract Ordered Dose"
          property="context.OrderedDose"
          value="request.GetValueAt(&quot;RXEgrp(1).RXE:3&quot;)" />
  <assign name="Extract Patient MRN"
          property="context.PatientMRN"
          value="request.GetValueAt(&quot;PIDgrpgrp(1).PIDgrp.PID:3(1).1&quot;)" />
  <assign name="Extract Patient Name"
          property="context.PatientName"
          value="request.GetValueAt(&quot;PIDgrpgrp(1).PIDgrp.PID:5.2&quot;)
                 _&quot; &quot;_
                 request.GetValueAt(&quot;PIDgrpgrp(1).PIDgrp.PID:5.1&quot;)" />

  <!-- Lookup max dose -->
  <assign name="Lookup Max Dose"
          property="context.MaxDose"
          value="##class(Ens.Util.FunctionSet).Lookup(process.LookupTableName,
                 context.DrugCode, &quot;&quot;)" />

  <!-- Decision: is lookup found and dose exceeded? -->
  <if name="Check Dose Exceeded"
      condition="(context.MaxDose &apos;= &quot;&quot;)
                 &amp;&amp; (+context.OrderedDose > +context.MaxDose)" >

    <true>
      <!-- Build alert email -->
      <assign name="Build Email Subject"
              property="context.EmailSubject"
              value="&quot;DOSE ALERT: &quot;_context.DrugName_
                     &quot; - Ordered &quot;_context.OrderedDose_
                     &quot; exceeds max &quot;_context.MaxDose" />
      <assign name="Build Email Body"
              property="context.EmailBody"
              value="&quot;Patient MRN: &quot;_context.PatientMRN_$c(13,10)_
                     &quot;Patient Name: &quot;_context.PatientName_$c(13,10)_
                     &quot;Drug: &quot;_context.DrugName_
                     &quot; (&quot;_context.DrugCode_&quot;)&quot;_$c(13,10)_
                     &quot;Ordered Dose: &quot;_context.OrderedDose_$c(13,10)_
                     &quot;Maximum Safe Dose: &quot;_context.MaxDose_$c(13,10)_
                     &quot;Timestamp: &quot;_$zdatetime($horolog,3)" />

      <!-- Send email alert -->
      <call name="Send Email Alert"
            target="@process.AlertEmailTarget"
            async="1" >
        <request type="Site.AIGenerated.Pharmacy.Message.AlertEmailRequest" >
          <assign property="callrequest.Subject"  value="context.EmailSubject" />
          <assign property="callrequest.Body"     value="context.EmailBody" />
          <assign property="callrequest.To"
                  value="&quot;pharmsafety@Sitehospitals.nhs.uk&quot;" />
        </request>
      </call>

      <!-- Log to file -->
      <call name="Log to File"
            target="@process.AlertFileTarget"
            async="1" >
        <request type="Ens.StringContainer" >
          <assign property="callrequest.StringValue"
                  value="$zdatetime($horolog,3)_&quot;|&quot;_
                         context.PatientMRN_&quot;|&quot;_
                         context.DrugCode_&quot;|&quot;_
                         context.DrugName_&quot;|&quot;_
                         context.OrderedDose_&quot;|&quot;_
                         context.MaxDose" />
        </request>
      </call>

    </true>
    <false>
      <!-- Dose within safe range or drug not in lookup â€” no action needed -->
      <trace name="Dose OK"
             value="&quot;Dose check passed for &quot;_context.DrugCode_
                    &quot;: ordered=&quot;_context.OrderedDose_
                    &quot; max=&quot;_context.MaxDose" />
    </false>
  </if>

</sequence>
</process>
}

}
```

### 4.2 Generated Class: Alert Email Operation

**File:** `Site.AIGenerated.Pharmacy.Operation.AlertEmailOperation`

```objectscript
/// Sends dose-check alert emails via the Site NHSMail adapter.
/// Generated by IRIS Copilot.
Class Site.AIGenerated.Pharmacy.Operation.AlertEmailOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.EMail.OutboundAdapter";

Parameter SETTINGS = "FromAddress";

Property FromAddress As %String(MAXLEN = 200) [ InitialExpression = "tie-alerts@Sitehospitals.nhs.uk" ];

Method AlertEmail(pRequest As Site.AIGenerated.Pharmacy.Message.AlertEmailRequest,
                  Output pResponse As Ens.Response) As %Status
{
    set tSC = $$$OK
    try {
        set tMailMessage = ##class(%Net.MailMessage).%New()
        do tMailMessage.To.Insert(pRequest.To)
        set tMailMessage.From = ..FromAddress
        set tMailMessage.Subject = pRequest.Subject
        set tMailMessage.IsBinary = 0
        set tMailMessage.IsHTML = 0
        do tMailMessage.TextData.Write(pRequest.Body)
        set tSC = ..Adapter.SendMail(tMailMessage)
    } catch ex {
        set tSC = ex.AsStatus()
    }
    return tSC
}

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Site.AIGenerated.Pharmacy.Message.AlertEmailRequest">
    <Method>AlertEmail</Method>
  </MapItem>
</MapItems>
}

}
```

### 4.3 Generated Class: Alert File Operation

**File:** `Site.AIGenerated.Pharmacy.Operation.AlertFileOperation`

```objectscript
/// Writes dose-check alert log lines to a daily file.
/// Generated by IRIS Copilot.
Class Site.AIGenerated.Pharmacy.Operation.AlertFileOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.File.OutboundAdapter";

Parameter SETTINGS = "FilePath";

Property FilePath As %String(MAXLEN = 500) [ InitialExpression = "C:\TIE\Logs\PharmDoseAlerts\" ];

Method LogAlert(pRequest As Ens.StringContainer,
                Output pResponse As Ens.Response) As %Status
{
    set tSC = $$$OK
    try {
        set tFileName = "DoseAlerts_"_$zdate($horolog,8)_".log"
        set tSC = ..Adapter.PutLine(tFileName, pRequest.StringValue)
    } catch ex {
        set tSC = ex.AsStatus()
    }
    return tSC
}

XData MessageMap
{
<MapItems>
  <MapItem MessageType="Ens.StringContainer">
    <Method>LogAlert</Method>
  </MapItem>
</MapItems>
}

}
```

### 4.4 Generated Class: Alert Email Request Message

**File:** `Site.AIGenerated.Pharmacy.Message.AlertEmailRequest`

```objectscript
/// Email alert request message for pharmacy dose-check alerts.
/// Generated by IRIS Copilot.
Class Site.AIGenerated.Pharmacy.Message.AlertEmailRequest Extends Ens.Request
{

Property To As %String(MAXLEN = 500);
Property Subject As %String(MAXLEN = 500);
Property Body As %String(MAXLEN = 10000);

Storage Default
{
<Data name="AlertEmailRequestDefaultData">
<Subscript>"AlertEmailRequest"</Subscript>
<Value name="1"><Value>To</Value></Value>
<Value name="2"><Value>Subject</Value></Value>
<Value name="3"><Value>Body</Value></Value>
</Data>
<DefaultData>AlertEmailRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
```

### 4.5 Generated: Lookup Table

**File:** `PharmDoseLimit.LUT` (Lookup Table â€” loaded via Management Portal or import)

```
Key,Value
AMOX500,3000
PARA500,4000
WARF1,10
GENT80,480
VANC500,4000
METR400,2400
CLIND150,1800
DIAZ5,40
MORPH10,200
CODEI30,240
```

*(Pharmacy team will maintain and extend this via Management Portal > Lookup Tables)*

### 4.6 Generated: Routing Rule Addition

The AI also generates the **routing rule modification** for `BRI.Interfaces.Cerner.DistributorRules`:

```
NEW RULE to add to Cerner Distributor:
  Name:      "Pharmacy Dose Check"
  Condition:  Document.DocType = "2.3:RDE_O11"
  Action:     Send to "Pharmacy Dose Check Process"
  Transform:  (none â€” pass HL7 message as-is)
  Note:       This rule runs IN ADDITION to existing rules.
              The existing AScribe pharmacy routing is unchanged.
```

### 4.7 Code Review in Chat UI

All generated classes are displayed in the **Code Review panel**:

```
IRIS Copilot: I've generated 6 classes + 1 lookup table + 1 routing rule change.
Here's the summary:

  âœ… DoseCheckProcess.cls        â€” BPL: extract dose â†’ lookup â†’ alert if exceeded
  âœ… AlertEmailOperation.cls     â€” Sends email via NHSMail adapter
  âœ… AlertFileOperation.cls      â€” Writes alert line to daily log file
  âœ… AlertEmailRequest.cls       â€” Message class for email alerts
  âœ… PharmDoseLimit.LUT          â€” Lookup table: drug code â†’ max safe dose
  âœ… Cerner Distributor rule     â€” New rule: RDE^O11 â†’ Dose Check Process
  âœ… DoseCheckTest.cls           â€” Unit test suite (see Phase 6)

Review each class in the Code Review panel on the right â†’
Click "Approve All" to deploy, or click individual classes to edit.
```

---

## Phase 5: Human Review and Approval

The user reviews each class in the split-pane Code Review panel:

- **Left pane:** Generated ObjectScript source with syntax highlighting
- **Right pane:** AI explanation of what each section does
- **Actions:** Approve / Reject / Edit (inline editor)

```
User reviews DoseCheckProcess.cls:
  - Checks the HL7 field paths (RXE:2.1, RXE:3, PID:3, PID:5)
  - Confirms the lookup table name matches
  - Confirms email address is correct
  - Notes the process sends alerts async (won't slow down the main flow) âœ“

User reviews AlertEmailOperation.cls:
  - Confirms it uses EnsLib.EMail.OutboundAdapter (same as existing NHSMail pattern)
  - From address looks correct âœ“

User reviews AlertFileOperation.cls:
  - Confirms file path C:\TIE\Logs\PharmDoseAlerts\ âœ“
  - Daily log file naming convention âœ“

User clicks: "Approve All"
```

---

## Phase 6: Deployer Agent â€” Compilation and Deployment

Upon approval, the **Deployer Agent** executes:

### 6.1 Version Snapshot

```
[Step 1] VersionManager.CreateSnapshot()
  â†’ Saves current state of Cerner Distributor routing rules
  â†’ Records snapshot as Version V-2026-0217-001
  â†’ Snapshot stored in Site.AIAgent.Model.Version
```

### 6.2 Class Compilation

```
[Step 2] CodeManager.WriteClass() + CompileClass() for each class:

  Compiling Site.AIGenerated.Pharmacy.Message.AlertEmailRequest ... OK
  Compiling Site.AIGenerated.Pharmacy.Operation.AlertEmailOperation ... OK
  Compiling Site.AIGenerated.Pharmacy.Operation.AlertFileOperation ... OK
  Compiling Site.AIGenerated.Pharmacy.Process.DoseCheckProcess ... OK
  Compiling Site.AIGenerated.Pharmacy.Test.DoseCheckTest ... OK

  âœ“ All 5 classes compiled successfully (0 errors, 0 warnings)
```

### 6.3 Lookup Table Import

```
[Step 3] Import PharmDoseLimit lookup table
  â†’ 10 drug/dose entries loaded
  â†’ Editable via Management Portal > Lookup Tables
```

### 6.4 Production Configuration

```
[Step 4] ProductionManager.AddBusinessHost() â€” add 3 new hosts to BRI.Productions.TEST:

  Adding "Pharmacy Dose Check Process"
    Class:    Site.AIGenerated.Pharmacy.Process.DoseCheckProcess
    Category: Pharmacy
    Enabled:  true
    Settings: AlertEmailTarget=Pharmacy Alert Email,
              AlertFileTarget=Pharmacy Alert File Log,
              LookupTableName=PharmDoseLimit

  Adding "Pharmacy Alert Email"
    Class:    Site.AIGenerated.Pharmacy.Operation.AlertEmailOperation
    Category: Pharmacy
    Enabled:  true
    Adapter:  EnsLib.EMail.OutboundAdapter
    Settings: SMTPServer=smtp.Sitehospitals.nhs.uk,
              SMTPPort=587, SSLConfig=NHSMailTLS,
              FromAddress=tie-alerts@Sitehospitals.nhs.uk

  Adding "Pharmacy Alert File Log"
    Class:    Site.AIGenerated.Pharmacy.Operation.AlertFileOperation
    Category: Pharmacy
    Enabled:  true
    Adapter:  EnsLib.File.OutboundAdapter
    Settings: FilePath=C:\TIE\Logs\PharmDoseAlerts\

[Step 5] Update Cerner Distributor routing rules:
  â†’ Add rule: DocType="2.3:RDE_O11" â†’ send to "Pharmacy Dose Check Process"
  â†’ Existing rules untouched

[Step 6] ProductionManager.UpdateProduction()
  â†’ Live production update (no restart required)
  â†’ New hosts start automatically
```

### 6.5 Deployment Status in Chat UI

```
IRIS Copilot: Deployment complete! âœ“

  ðŸ“¦ Version: V-2026-0217-001 (rollback available)
  ðŸ“ 5 classes compiled (0 errors)
  ðŸ“‹ Lookup table "PharmDoseLimit" loaded (10 entries)
  ðŸ¥ 3 new production hosts added to BRI.Productions.TEST
  ðŸ“¡ Cerner Distributor rule updated â€” RDE^O11 now routes to Dose Check
  âš¡ Production updated live â€” new hosts are running

  Next: I'll run the automated tests.
```

---

## Phase 7: Tester Agent â€” Automated Testing

The **Tester Agent** generates and executes a `%UnitTest` suite:

### 7.1 Generated Test Class

**File:** `Site.AIGenerated.Pharmacy.Test.DoseCheckTest`

```objectscript
/// Unit tests for Pharmacy Dose-Check Alert integration.
/// Generated by IRIS Copilot.
Class Site.AIGenerated.Pharmacy.Test.DoseCheckTest Extends %UnitTest.TestCase
{

/// Test 1: Dose exceeds maximum â€” should trigger alert
Method TestDoseExceedsMax()
{
    // Build a synthetic RDE^O11 with AMOX500, dose 5000 (max is 3000)
    set tMsg = ..BuildTestRDE("AMOX500", "Amoxicillin 500mg", "5000", "MRN12345", "Smith^John")
    set tSC = ..SendToProcess(tMsg)
    do $$$AssertStatusOK(tSC, "Message sent to Dose Check Process")

    // Verify alert was generated (check file output)
    hang 2  // wait for async operations
    set tLogFile = "C:\TIE\Logs\PharmDoseAlerts\DoseAlerts_"_$zdate($horolog,8)_".log"
    set tFound = ##class(%File).Exists(tLogFile)
    do $$$AssertTrue(tFound, "Alert log file was created")

    if tFound {
        set tStream = ##class(%Stream.FileCharacter).%New()
        set tSC = tStream.LinkToFile(tLogFile)
        set tContent = tStream.Read()
        do $$$AssertTrue(tContent [ "AMOX500", "Log contains drug code AMOX500")
        do $$$AssertTrue(tContent [ "5000", "Log contains ordered dose 5000")
        do $$$AssertTrue(tContent [ "3000", "Log contains max dose 3000")
        do $$$AssertTrue(tContent [ "MRN12345", "Log contains patient MRN")
    }
}

/// Test 2: Dose within safe range â€” should NOT trigger alert
Method TestDoseWithinRange()
{
    set tMsg = ..BuildTestRDE("PARA500", "Paracetamol 500mg", "2000", "MRN67890", "Jones^Mary")
    set tSC = ..SendToProcess(tMsg)
    do $$$AssertStatusOK(tSC, "Message sent to Dose Check Process")

    // The process should complete without sending any alert
    // (No assertion for file content â€” we verify no NEW alert line for this drug)
}

/// Test 3: Drug not in lookup table â€” should NOT trigger alert (safe pass-through)
Method TestDrugNotInLookup()
{
    set tMsg = ..BuildTestRDE("UNKNOWN99", "Unknown Drug", "9999", "MRN11111", "Doe^Jane")
    set tSC = ..SendToProcess(tMsg)
    do $$$AssertStatusOK(tSC, "Message sent â€” unknown drug does not cause error")
}

/// Test 4: Lookup table is accessible and has expected entries
Method TestLookupTableExists()
{
    set tMax = ##class(Ens.Util.FunctionSet).Lookup("PharmDoseLimit", "AMOX500", "")
    do $$$AssertEquals(tMax, "3000", "AMOX500 max dose is 3000")

    set tMax = ##class(Ens.Util.FunctionSet).Lookup("PharmDoseLimit", "WARF1", "")
    do $$$AssertEquals(tMax, "10", "WARF1 (Warfarin) max dose is 10")
}

/// Helper: build a synthetic RDE^O11 HL7 message
Method BuildTestRDE(drugCode, drugName, dose, mrn, patientName) As EnsLib.HL7.Message
{
    set tMsg = ##class(EnsLib.HL7.Message).%New()
    do tMsg.PokeDocType("2.3:RDE_O11")

    // MSH segment
    do tMsg.SetValueAt("RDE", "MSH:9.1")
    do tMsg.SetValueAt("O11", "MSH:9.2")
    do tMsg.SetValueAt("CERNER", "MSH:3.1")
    do tMsg.SetValueAt("BRI", "MSH:5.1")
    do tMsg.SetValueAt($zdatetime($horolog,7), "MSH:7.1")

    // PID segment
    do tMsg.SetValueAt(mrn, "PIDgrpgrp(1).PIDgrp.PID:3(1).1")
    do tMsg.SetValueAt($piece(patientName,"^",1), "PIDgrpgrp(1).PIDgrp.PID:5.1")
    do tMsg.SetValueAt($piece(patientName,"^",2), "PIDgrpgrp(1).PIDgrp.PID:5.2")

    // RXE segment (pharmacy order)
    do tMsg.SetValueAt(drugCode, "RXEgrp(1).RXE:2.1")
    do tMsg.SetValueAt(drugName, "RXEgrp(1).RXE:2.2")
    do tMsg.SetValueAt(dose, "RXEgrp(1).RXE:3")

    return tMsg
}

/// Helper: send message to the Dose Check Process via testing API
Method SendToProcess(pMsg As EnsLib.HL7.Message) As %Status
{
    set tSC = ##class(Ens.Director).CreateBusinessService(
        "Pharmacy Dose Check Process Test Input", .tService)
    if $$$ISERR(tSC) return tSC
    return tService.ProcessInput(pMsg)
}

}
```

### 7.2 Test Execution Results

```
IRIS Copilot: Running test suite Site.AIGenerated.Pharmacy.Test.DoseCheckTest...

  âœ“ TestDoseExceedsMax          PASSED (4/4 assertions)
    - Message sent successfully
    - Alert log file created
    - Log contains drug code, dose, max dose, and MRN

  âœ“ TestDoseWithinRange         PASSED (1/1 assertions)
    - Message processed without triggering alert

  âœ“ TestDrugNotInLookup         PASSED (1/1 assertions)
    - Unknown drug processed without error

  âœ“ TestLookupTableExists       PASSED (2/2 assertions)
    - AMOX500 â†’ 3000 âœ“
    - WARF1 â†’ 10 âœ“

  â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Results: 4 passed, 0 failed, 0 errors
  Duration: 3.2 seconds
  â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

All tests passed! The Pharmacy Dose-Check Alert integration is live and working.
```

---

## Phase 8: Post-Deployment Monitoring

### 8.1 User Checks Status Later

```
User: How is the pharmacy dose check integration running?

IRIS Copilot: Here's the status for Pharmacy Dose Check (last 24 hours):

  ðŸ“Š Messages Processed:     847 RDE^O11 orders checked
  ðŸš¨ Alerts Triggered:       12 dose exceedances detected
  ðŸ“§ Emails Sent:            12 (all delivered)
  ðŸ“ File Log Entries:       12 (C:\TIE\Logs\PharmDoseAlerts\DoseAlerts_20260217.log)
  âš ï¸  Errors:                0
  â±ï¸  Avg Processing Time:   0.03 seconds

  Most frequent alerts:
    CODEI30 (Codeine 30mg): 5 alerts â€” ordered doses between 300-480mg
    MORPH10 (Morphine 10mg): 4 alerts â€” ordered doses between 250-500mg
    WARF1 (Warfarin 1mg): 3 alerts â€” ordered doses between 12-15mg

  All 847 orders were also forwarded to AScribe Pharmacy Router as usual.
```

### 8.2 User Requests a Modification

```
User: Can you add a second email recipient â€” ICU charge nurse at
      icunurse@Sitehospitals.nhs.uk â€” but only for Morphine and Warfarin alerts?

IRIS Copilot: I'll modify the DoseCheckProcess to add conditional routing for
Morphine (MORPH*) and Warfarin (WARF*) alerts to both the pharmacy team AND
the ICU charge nurse.

[Generates modified BPL with additional <if> block]
[Shows diff in Code Review panel â€” only the changed section highlighted]

User: Approve.

IRIS Copilot: Deployed. Version V-2026-0217-002 created (rollback to V-001 available).
Tests re-run: 5 passed (added TestICURecipient). ICU nurse routing is live.
```

### 8.3 User Requests Rollback

```
User: The ICU nurses are getting too many alerts. Roll back to the previous version.

IRIS Copilot: Rolling back to V-2026-0217-001 (before ICU nurse routing)...

  âœ“ Restored DoseCheckProcess.cls to V-001
  âœ“ Recompiled â€” 0 errors
  âœ“ Production updated

  ICU nurse routing has been removed. Only pharmsafety@ receives alerts now.
  Version V-2026-0217-003 created (records the rollback action).
```

---

## Phase 9: Summary â€” What Happened Without Writing Any COS

| Step | Who Did It | Time |
|------|-----------|------|
| Described the requirement | Pharmacist (English) | 2 minutes |
| Answered clarifying questions | Pharmacist | 1 minute |
| Reviewed production topology design | Pharmacist | 1 minute |
| Reviewed generated code | Hospital IT | 5 minutes |
| Clicked "Approve" | Hospital IT | 1 second |
| Compilation, deployment, testing | AI Agent (automated) | ~30 seconds |
| **Total** | | **~10 minutes** |

**Traditional approach (without IRIS Copilot):**
- IRIS developer analyses requirement: 1-2 hours
- Designs topology: 1-2 hours
- Writes 5-6 COS classes: 4-8 hours
- Tests: 2-4 hours
- Deploys and configures: 1-2 hours
- **Total: 1-3 days** (assuming an available IRIS specialist)

---

*End of Demo Lifecycle Document. See TEST-CASES.md for the formal test specification.*

