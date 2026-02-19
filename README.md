# IRIS AI Agent Platform (IRIS Copilot)

AI-powered autonomous development platform for InterSystems IRIS HealthConnect integration engines.

Clinical users, hospital IT, and developers describe integration requirements in **natural language** — English, Spanish, Chinese, or any language — and AI agents autonomously design, generate, compile, test, deploy, and manage the complete HealthConnect production lifecycle.

Built for **NHS Bradford Teaching Hospitals Trust**, designed to be deployable on **any IRIS HealthConnect instance**.

---

## Quick Start

### 1. Import into IRIS

```objectscript
// Load all classes
do $system.OBJ.LoadDir("/path/to/AIAgent/cls/", "ck")

// Run installer (creates /ai web app)
do ##class(AIAgent.Install.Installer).Run()

// Configure API keys
do ##class(AIAgent.Install.Installer).Configure("http://localhost:3100", "sk-ant-...", "sk-...", "", "")
```

### 2. Start the Node.js Bridge

```bash
cd bridge
npm install
cp .env.example .env
# Edit .env with your API keys
npm start
```

### 3. Open the Chat UI

Navigate to: `http://your-iris-server:52773/ai/AIAgent.UI.Chat.cls`

---

## Architecture

```
Browser → Chat UI (CSP/Alpine.js) → REST API (Dispatcher.cls)
                                          |
                                          v
                                    Orchestrator
                                     /        \
                              IRIS Engine    Node.js Bridge
                             (COS classes)   (AI SDK calls)
                                               |
                                    +----------+----------+
                                    |          |          |
                                  Claude    OpenAI    Azure
                                   SDK       SDK      OpenAI
```

**Key design principles:**
- **Human-in-the-loop**: All generated code requires explicit human approval before compilation
- **Pluggable AI runners**: Add or swap AI providers without code changes
- **Template scaffolding**: AI fills in business logic within known-good class structures
- **Full audit trail**: Every action logged for NHS compliance
- **Version snapshots**: Point-and-click rollback for any deployment

---

## Project Structure

```
AIAgent/
├── cls/AIAgent/           # ObjectScript classes (24 classes)
│   ├── API/               # REST dispatcher (25 routes)
│   ├── Engine/            # Core business logic
│   ├── Install/           # One-click installer
│   ├── Model/             # Persistent data model
│   ├── Templates/         # COS code scaffolding (7 classes)
│   ├── UI/                # Chat interface (Alpine.js SPA)
│   └── Util/              # JSON helpers, logging
├── bridge/                # Node.js AI Bridge (TypeScript)
│   └── src/
│       ├── agents/        # Orchestrator with intent classification
│       ├── iris/          # IRIS REST callback client
│       ├── routes/        # Express API routes
│       └── runners/       # Pluggable AI adapters
│           ├── claude-agent-sdk/
│           ├── openai-codex/
│           └── azure-openai/
├── knowledge/             # AI context documents
├── docs/                  # Design docs, test cases, demo
└── reference/             # IRIS code reference examples
```

---

## AI Runners

| Runner | SDK | Status |
|--------|-----|--------|
| Claude Agent SDK | `@anthropic-ai/sdk` | Ready |
| OpenAI (GPT-4o) | `openai` | Ready |
| Azure OpenAI | `openai` (Azure config) | Ready |
| Google Vertex AI | — | Planned |
| Local Ollama | — | Planned |

Runners implement the `AIRunnerAdapter` interface and are auto-registered at startup based on which API keys are configured in `.env`.

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ai/chat` | POST | Send message, get full response |
| `/ai/chat/stream` | POST | Send message, get SSE stream |
| `/ai/conversations` | GET/POST | List or create conversations |
| `/ai/generate/preview` | POST | Preview generated code |
| `/ai/generate/approve` | POST | Approve & compile code |
| `/ai/generate/reject` | POST | Reject generated code |
| `/ai/production/status` | GET | Production health |
| `/ai/production/topology` | GET | All production hosts |
| `/ai/classes` | GET | List classes by pattern |
| `/ai/lookups` | GET | List lookup tables |
| `/ai/hl7schemas` | GET | List HL7 schemas |
| `/ai/lifecycle/versions` | GET | Deployment versions |
| `/ai/lifecycle/rollback/:id` | POST | Rollback to version |
| `/ai/runners` | GET | List AI runners |
| `/ai/health` | GET | System health check |

---

## Template System

The template factory generates structurally correct ObjectScript scaffolding:

```objectscript
// Generate a Business Service from template
set spec = {"className": "AIAgent.Generated.Lab.Service.WinPathReceiver",
            "description": "Receive HL7 from WinPath LIMS",
            "port": 35100,
            "targetProcess": "LabRouter",
            "hl7Schema": "2.4"}
set source = ##class(AIAgent.Templates.Factory).Generate("BusinessService", spec)
```

Supported types: `BusinessService`, `BusinessProcess`, `BusinessOperation`, `DataTransformation`, `RoutingRule`, `RequestMessage`, `ResponseMessage`.

---

## Documentation

- [DESIGN.md](docs/DESIGN.md) — Full architecture design
- [DEMO-LIFECYCLE.md](docs/DEMO-LIFECYCLE.md) — Pharmacy Dose-Check demo walkthrough
- [TEST-CASES.md](docs/TEST-CASES.md) — 28 formal test cases
- [IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md) — Build phases and status

---

## Requirements

- InterSystems IRIS HealthConnect 2023.1+
- Node.js 20+ (for the AI bridge)
- At least one AI API key: Anthropic (Claude) or OpenAI (GPT-4o) or Azure OpenAI

---

## Standalone Deployment

Export the entire platform as a deployable package:

```objectscript
do ##class(AIAgent.Install.Installer).ExportPackage("C:\deploy\AIAgent\")
```

Import on another IRIS instance:

```objectscript
do ##class(AIAgent.Install.Installer).ImportPackage("C:\deploy\AIAgent\")
```

---

## License

Internal NHS Bradford Teaching Hospitals Trust. Not for external distribution without authorization.
