# IRIS Copilot — User Guide

**IRIS AI Agent Platform for NHS Trust Integration Engines**

Version 1.0 — February 2026

---

## Table of Contents

1. [What is IRIS Copilot?](#1-what-is-iris-copilot)
2. [User Roles](#2-user-roles)
3. [Getting Started](#3-getting-started)
4. [For Clinicians and Service Staff](#4-for-clinicians-and-service-staff)
5. [For TIE Developers and Hospital IT](#5-for-tie-developers-and-hospital-it)
6. [Chat Interface Guide](#6-chat-interface-guide)
7. [End-to-End Lifecycle Walkthrough](#7-end-to-end-lifecycle-walkthrough)
8. [Code Review and Approval](#8-code-review-and-approval)
9. [Monitoring and Status Checks](#9-monitoring-and-status-checks)
10. [Modifications and Rollback](#10-modifications-and-rollback)
11. [Lookup Table Management](#11-lookup-table-management)
12. [FAQ](#12-faq)

---

## 1. What is IRIS Copilot?

IRIS Copilot is an AI-powered platform that lets you build, modify, monitor, and manage clinical system integrations on InterSystems IRIS HealthConnect — using plain English (or Spanish, Chinese, or any language).

**You describe what you need. The AI designs, generates, tests, and deploys it.**

No ObjectScript coding required. No specialist IRIS developers needed for routine integrations.

### What It Can Do

- Build new HL7 integration routes (ADT, ORM, ORU, RDE, SIU, MDM)
- Modify existing integrations (add recipients, change routing rules, update transforms)
- Monitor production health (queue depths, error counts, message volumes)
- Explain existing code and configuration in plain language
- Generate and run automated tests
- Roll back any deployment to a previous version instantly

### What It Cannot Do (by design)

- Deploy code without explicit human approval
- Modify production systems without a version snapshot (rollback point)
- Access patient data — it works with message structures, not message content
- Replace clinical judgement — it builds what you specify, you verify it's correct

---

## 2. User Roles

### Clinician / Service Lead
You know *what* the integration should do but don't need to know *how* it works technically. You describe requirements, answer clarifying questions, and review the design at a high level.

### TIE Developer / Hospital IT
You review the generated ObjectScript code, verify HL7 field paths and adapter settings, approve deployments, and monitor the running production. You're the human in the loop.

### System Administrator
You deploy and configure the platform itself, manage API keys, and handle the IRIS server infrastructure. See the [Deployment Guide](DEPLOYMENT-GUIDE.md).

---

## 3. Getting Started

### Accessing the Chat UI

Open your browser and navigate to:

```
http://<your-iris-server>:52773/ai/AIAgent.UI.Chat.cls
```

You'll need an IRIS account with `%Development` resource access. Log in with your standard IRIS credentials.

### The Interface

The chat interface has three main areas:

| Area | Location | Purpose |
|------|----------|---------|
| **Conversation Sidebar** | Left panel | List of past conversations, create new ones |
| **Chat Area** | Centre | Message input and AI responses |
| **Status/Review Panel** | Right panel | Production status, runner health, code review |

### Creating Your First Conversation

1. Click **"New Conversation"** in the left sidebar
2. Give it a descriptive title (e.g., "Pharmacy Dose Check Alerts")
3. Type your requirement in the message box
4. Press Enter or click Send

---

## 4. For Clinicians and Service Staff

You don't need any technical knowledge to use IRIS Copilot. Here's your workflow:

### Step 1: Describe What You Need

Type your requirement in plain English. Be as specific as you can about:

- **What system** sends the data (e.g., "Cerner", "WinPath", "CRIS")
- **What type** of message (e.g., "pharmacy orders", "lab results", "patient admissions")
- **What should happen** (e.g., "email the safety team", "forward to BadgerNet", "log to a file")
- **Any conditions** (e.g., "only if the dose exceeds a safe maximum")

**Example:**
> "When Cerner sends pharmacy orders, check if the dose exceeds the safe maximum from a lookup table. If it does, email pharmsafety@bradfordhospitals.nhs.uk with the patient MRN, drug name, dose, and safe max. Also log it to a file for audit."

### Step 2: Answer Clarifying Questions

The AI will ask targeted questions to fill in technical details:

- Which HL7 fields contain the data you mentioned?
- Which existing system routes should be preserved?
- Where should log files be saved?

**You can answer in plain English.** If you're unsure about a technical detail, say so — the AI will suggest sensible defaults based on the existing Bradford TIE configuration.

### Step 3: Review the Design

The AI presents a topology diagram showing:

- Which new components will be created
- How they connect to existing systems
- What stays unchanged

**Check that the design matches your intent.** If something looks wrong, say so and the AI will revise.

### Step 4: Hand Off to IT

At this point, the AI has generated ObjectScript code. Your IT colleague reviews and approves the code (see Section 5). You don't need to look at the code unless you want to.

### Step 5: Verify It's Working

After deployment, ask the AI:

> "How is the pharmacy dose check integration running?"

You'll get a plain-English status report with message counts, alert counts, and any errors.

---

## 5. For TIE Developers and Hospital IT

You do everything in Section 4, plus code review, approval, and ongoing management.

### Code Review

When the AI generates code, it appears in the **Code Review Panel** (right side):

- **Left pane**: Generated ObjectScript source with syntax highlighting
- **Right pane**: AI explanation of what each section does
- **Class list**: All generated classes with their types (BS/BP/BO/DTL/Rule/Message)

**What to check:**

| Check | Why |
|-------|-----|
| HL7 field paths (e.g., `PID:3(1).1`, `RXE:2.1`) | Ensure they match the actual message schema |
| Adapter types (TCP, HTTP, File, Email) | Ensure they match the target system's protocol |
| Port numbers and IP addresses | Ensure they point to the right systems |
| Email addresses and file paths | Ensure they're correct for your environment |
| Lookup table names | Ensure they match existing tables or new ones are properly defined |
| Class naming convention | Should follow `AIAgent.Generated.<Domain>.<Type>.<Name>` |
| SETTINGS parameters | Ensure configurable values are exposed, not hardcoded |

### Approval Actions

| Action | What Happens |
|--------|-------------|
| **Approve All** | Creates version snapshot, compiles all classes, updates production, runs tests |
| **Approve Individual** | Approve/reject each class separately |
| **Edit** | Modify the generated source inline before approving |
| **Reject** | Discard the generation with a reason (logged in audit trail) |
| **Regenerate** | Ask the AI to try again with different instructions |

### Post-Deployment Verification

After approval, the platform automatically:

1. Creates a version snapshot (rollback point)
2. Compiles all classes — you'll see compile status for each
3. Loads any lookup tables
4. Adds new hosts to the running production
5. Updates the production live (no restart required)
6. Runs generated unit tests

Check the deployment summary in the chat for any compile errors or test failures.

### Production Management Commands

You can manage the production directly through chat:

| Command | What It Does |
|---------|-------------|
| "What's the production status?" | Shows running/stopped/troubled state, host counts |
| "Show me the production topology" | Lists all hosts with their classes and adapters |
| "How are the queues?" | Shows message queue depths for all hosts |
| "Show recent errors" | Displays the event log filtered to errors |
| "Restart the Cerner receiver" | Disables then re-enables a specific host |

---

## 6. Chat Interface Guide

### Message Types

| Message | Appearance |
|---------|-----------|
| Your messages | Blue bubble, right-aligned |
| AI responses | Dark bubble, left-aligned, with markdown rendering |
| System messages | Grey, centred (deployment status, errors) |
| Code blocks | Syntax-highlighted ObjectScript in monospace |

### Streaming Responses

AI responses stream in real-time token by token. You'll see a typing indicator while the AI is generating. Long responses (especially code generation) may take 10-30 seconds.

### Conversation History

All conversations are saved and can be resumed later. Use the sidebar to switch between conversations. Each conversation maintains its own context — the AI remembers previous messages in the same conversation.

### Language Support

Type in any language. The AI responds in the same language you use:

- English: "Create an ADT router for BadgerNet"
- Spanish: "Crea un enrutador ADT para BadgerNet"
- Chinese: "为BadgerNet创建ADT路由器"

Technical terms (HL7 fields, class names, IRIS APIs) remain in English regardless of conversation language.

---

## 7. End-to-End Lifecycle Walkthrough

This follows the Pharmacy Dose-Check demo (see [DEMO-LIFECYCLE.md](DEMO-LIFECYCLE.md) for full detail).

### Phase 1: Describe (2 minutes)

> "We need pharmacy orders from Cerner checked against a safe dose table. If dose exceeds max, email pharmsafety@ and log to file."

### Phase 2: Clarify (1 minute)

AI asks about HL7 fields, existing routes, file paths. You answer in plain English.

### Phase 3: Design (1 minute)

AI shows topology: 3 new components added in parallel with existing AScribe route. You confirm.

### Phase 4: Generate (automatic)

AI generates 6 ObjectScript classes + 1 lookup table + 1 routing rule change.

### Phase 5: Review & Approve (5 minutes)

TIE developer reviews code in the Code Review panel. Checks HL7 paths, email addresses, file paths. Clicks "Approve All".

### Phase 6: Deploy (30 seconds, automatic)

Platform creates version snapshot, compiles, adds hosts to production, runs tests. All automated.

### Phase 7: Monitor (ongoing)

Ask "How is the pharmacy dose check running?" — get live stats on messages processed, alerts triggered, errors.

### Phase 8: Modify or Rollback (as needed)

Ask "Add ICU nurse as email recipient for Warfarin alerts" or "Roll back to the previous version."

**Total time: ~10 minutes** vs 1-3 days traditional development.

---

## 8. Code Review and Approval

### Understanding the Generated Code

Each generated class has a type that maps to an IRIS HealthConnect component:

| Type | IRIS Component | Purpose |
|------|---------------|---------|
| BusinessService | `Ens.BusinessService` | Receives inbound messages (TCP, HTTP, file) |
| BusinessProcess | `Ens.BusinessProcessBPL` | Orchestrates routing and transformation |
| BusinessOperation | `Ens.BusinessOperation` | Sends outbound messages (TCP, HTTP, file, email) |
| DataTransformation | `Ens.DataTransformDTL` | Maps fields between message formats |
| RoutingRule | `Ens.Rule.Definition` | Routes messages based on content |
| RequestMessage | `Ens.Request` | Custom message object (request) |
| ResponseMessage | `Ens.Response` | Custom message object (response) |

### Approval Workflow

```
Generate → Preview → Human Review → Approve → Compile → Test → Deploy
                         |
                         ├── Edit (modify inline)
                         ├── Reject (discard with reason)
                         └── Regenerate (ask AI to try again)
```

Every action is logged in the audit trail. Nothing is deployed without your explicit approval.

---

## 9. Monitoring and Status Checks

### Natural Language Queries

| You Say | AI Shows |
|---------|---------|
| "How is the production running?" | Overall status, host count, error count |
| "Show me errors from the last hour" | Recent event log entries filtered to errors |
| "How many messages did Cerner send today?" | Message count for Cerner-related hosts |
| "Is the BadgerNet connection working?" | Specific host health, queue depth, last activity |
| "What's in the pharmacy alert log?" | Recent audit/alert entries |

### Production Status Indicators

| Status | Meaning |
|--------|---------|
| Running | Production is active, all enabled hosts operational |
| Stopped | Production is not running |
| Suspended | Production paused, queued messages waiting |
| Troubled | One or more hosts have errors — investigate |

---

## 10. Modifications and Rollback

### Modifying an Existing Integration

Just describe the change in the same conversation:

> "Add a second email recipient — icunurse@bradfordhospitals.nhs.uk — but only for Warfarin alerts"

The AI shows a **diff** — only the changed sections are highlighted. Same review/approve workflow applies.

### Rollback

Every deployment creates a version snapshot. To rollback:

> "Roll back to the previous version"

Or specify a version:

> "Roll back to V-2026-0217-001"

Rollback is instant:
1. Restores all class sources from the snapshot
2. Recompiles
3. Updates the production
4. Creates a new version record (for audit)

### Version History

> "Show me the deployment versions"

Lists all versions with timestamps, descriptions, and which classes were included.

---

## 11. Lookup Table Management

Lookup tables store reference data that changes without code changes (e.g., drug/max-dose pairs, system code mappings).

### Via Chat

> "Show me the PharmDoseLimit lookup table"
> "Add AMOX250 with max dose 2000 to PharmDoseLimit"

### Via Management Portal

1. Open IRIS Management Portal
2. Navigate to: Interoperability > Lookup Tables
3. Select the table name
4. Add, edit, or remove entries
5. Changes take effect immediately — no recompilation needed

---

## 12. FAQ

**Q: Can the AI access patient data?**
A: No. The AI works with message *structures* (HL7 field paths, class definitions, routing rules) — not message *content*. Patient data stays within the IRIS server and is never sent to external AI services.

**Q: What happens if the AI generates incorrect code?**
A: Nothing — until you approve it. The human review step is mandatory. Generated code is shown in preview mode and only compiled after explicit approval.

**Q: Can I undo a deployment?**
A: Yes, instantly. Every deployment creates a version snapshot. Say "Roll back to the previous version" and it's restored in seconds.

**Q: What if the AI doesn't understand my requirement?**
A: Rephrase or provide more detail. The AI will ask clarifying questions. You can also reference existing components by name: "Do the same thing as the Cerner ADT router but for WinPath lab results."

**Q: Which AI providers are supported?**
A: Claude (Anthropic), GPT-4o (OpenAI), and Azure OpenAI are ready. Google Vertex AI and local Ollama are planned. Providers are plug-and-play — the system uses whichever is configured.

**Q: Can I use this on a different IRIS instance?**
A: Yes. The platform is packaged as a standalone deployable. Export with `AIAgent.Install.Installer.ExportPackage()` and import on any IRIS HealthConnect instance.

**Q: What languages can I use?**
A: Any language. The AI responds in the same language you use. Technical terms (HL7 fields, class names) remain in English.

---

*End of User Guide. For deployment instructions, see [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md).*
*For the full demo scenario, see [DEMO-LIFECYCLE.md](DEMO-LIFECYCLE.md).*
*For test specifications, see [TEST-CASES.md](TEST-CASES.md).*
