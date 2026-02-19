# IRIS AI Agent Platform — Implementation Plan

## Status: Phase 1 Complete (Core Platform)

---

## Phase 1: Core Platform (COMPLETE)

All foundational components are built and ready for integration testing on a live IRIS instance.

### 1.1 Data Model Layer
| Component | Class | Status |
|-----------|-------|--------|
| Conversation | `AIAgent.Model.Conversation` | Done |
| Message | `AIAgent.Model.Message` | Done |
| Generation | `AIAgent.Model.Generation` | Done |
| GenerationClass | `AIAgent.Model.GenerationClass` | Done |
| Version | `AIAgent.Model.Version` | Done |
| AuditEntry | `AIAgent.Model.AuditEntry` | Done |

### 1.2 Engine Layer
| Component | Class | Status |
|-----------|-------|--------|
| Code Manager | `AIAgent.Engine.CodeManager` | Done |
| Production Manager | `AIAgent.Engine.ProductionManager` | Done |
| Version Manager | `AIAgent.Engine.VersionManager` | Done |
| Test Runner | `AIAgent.Engine.TestRunner` | Done |
| Bridge Client | `AIAgent.Engine.BridgeClient` | Done |
| Orchestrator | `AIAgent.Engine.Orchestrator` | Done |

### 1.3 Template Layer
| Component | Class | Status |
|-----------|-------|--------|
| Business Service | `AIAgent.Templates.BusinessService` | Done |
| Business Process | `AIAgent.Templates.BusinessProcess` | Done |
| Business Operation | `AIAgent.Templates.BusinessOperation` | Done |
| Data Transformation | `AIAgent.Templates.DataTransformation` | Done |
| Routing Rule | `AIAgent.Templates.RoutingRule` | Done |
| Message Class | `AIAgent.Templates.MessageClass` | Done |
| Factory (entry point) | `AIAgent.Templates.Factory` | Done |

### 1.4 API Layer
| Component | Class | Status |
|-----------|-------|--------|
| REST Dispatcher | `AIAgent.API.Dispatcher` | Done (917 lines, 25 routes) |

### 1.5 UI Layer
| Component | Class | Status |
|-----------|-------|--------|
| Chat Interface | `AIAgent.UI.Chat` | Done (1962 lines, full SPA) |

### 1.6 Utility Layer
| Component | Class | Status |
|-----------|-------|--------|
| JSON Helpers | `AIAgent.Util.JSON` | Done |
| Logger | `AIAgent.Util.Logger` | Done |

### 1.7 Installation
| Component | Class | Status |
|-----------|-------|--------|
| Installer | `AIAgent.Install.Installer` | Done |

### 1.8 Node.js Bridge
| Component | File | Status |
|-----------|------|--------|
| Express Server | `bridge/src/server.ts` | Done |
| Configuration | `bridge/src/config.ts` | Done |
| Chat Routes | `bridge/src/routes/chat.ts` | Done |
| Runner Routes | `bridge/src/routes/runners.ts` | Done |
| Health Routes | `bridge/src/routes/health.ts` | Done |
| Runner Interface | `bridge/src/runners/runner-interface.ts` | Done |
| Runner Registry | `bridge/src/runners/runner-registry.ts` | Done |
| Claude SDK Runner | `bridge/src/runners/claude-agent-sdk/index.ts` | Done |
| OpenAI Runner | `bridge/src/runners/openai-codex/index.ts` | Done |
| Azure OpenAI Runner | `bridge/src/runners/azure-openai/index.ts` | Done |
| Orchestrator Agent | `bridge/src/agents/orchestrator.ts` | Done |
| IRIS HTTP Client | `bridge/src/iris/iris-client.ts` | Done |

### 1.9 Knowledge Base
| Document | File | Status |
|----------|------|--------|
| IRIS API Reference | `knowledge/iris-reference.md` | Done |
| Bradford Conventions | `knowledge/bradford-conventions.md` | Done |
| HL7 Schemas Guide | `knowledge/hl7-schemas.md` | Done |

---

## Phase 2: Integration Testing (NEXT)

Deploy to a live IRIS HealthConnect instance and validate end-to-end flows.

### 2.1 Prerequisites
- [ ] IRIS HealthConnect instance with HSBUS namespace
- [ ] Node.js 20+ on same server or network-accessible host
- [ ] At least one AI API key (Anthropic or OpenAI)

### 2.2 Deployment Steps
1. **Import COS classes** into IRIS:
   ```objectscript
   do $system.OBJ.LoadDir("C:\path\to\AIAgent\cls\", "ck")
   ```
2. **Run installer**:
   ```objectscript
   do ##class(AIAgent.Install.Installer).Run()
   do ##class(AIAgent.Install.Installer).Configure("http://localhost:3100", "sk-ant-...", "sk-...", "", "")
   ```
3. **Start Node.js bridge**:
   ```bash
   cd bridge && npm install && cp .env.example .env
   # Edit .env with API keys
   npm start
   ```
4. **Verify health**:
   ```
   GET http://localhost:52773/ai/health
   GET http://localhost:3100/api/health
   ```

### 2.3 Test Matrix
| Test | Expected Result |
|------|----------------|
| Health check (IRIS) | `{"status":"ok","iris":true,"bridge":true}` |
| Health check (Bridge) | `{"status":"ok","runners":[...]}` |
| Create conversation | 201 with conversationId |
| Send message (non-streaming) | 200 with AI response |
| Send message (SSE streaming) | Event stream with tokens |
| Generate code | ObjectScript class in response |
| Preview generation | GenerationId + class preview |
| Approve & deploy | Class compiled in namespace |
| Rollback | Previous version restored |
| Production status | Current production state |

---

## Phase 3: Advanced Features (PLANNED)

### 3.1 MCP Server Integration
- [ ] Expose IRIS APIs via Model Context Protocol (MCP)
- [ ] Allow AI agents to directly query IRIS without bridge REST roundtrip
- [ ] MCP tools: read_class, list_classes, production_status, execute_sql, lookup_table

### 3.2 Multi-Agent Pipelines
- [ ] Architect Agent — designs topology from requirements
- [ ] Developer Agent — generates ObjectScript from design
- [ ] Reviewer Agent — validates code quality and safety
- [ ] Testing Agent — generates and runs test cases
- [ ] Pipeline: Architect → Developer → Reviewer → (human approval) → Deploy → Test

### 3.3 Additional Runners
- [ ] Google Vertex AI runner (`bridge/src/runners/google-vertex/`)
- [ ] AWS Bedrock runner
- [ ] Local Ollama runner (`bridge/src/runners/local-ollama/`) for air-gapped environments

### 3.4 Enhanced UI
- [ ] Visual production topology graph (D3.js / Cytoscape)
- [ ] Side-by-side code diff viewer for approvals
- [ ] Drag-and-drop production designer
- [ ] Dark/light theme toggle
- [ ] Multi-language UI (i18n)

### 3.5 Security Hardening
- [ ] RBAC: role-based access (admin, developer, viewer)
- [ ] API key rotation and vault integration
- [ ] Audit log export to SIEM
- [ ] Rate limiting on AI API calls
- [ ] PII redaction in HL7 messages before sending to AI

### 3.6 Production Intelligence
- [ ] Proactive monitoring — AI analyzes error patterns and suggests fixes
- [ ] Capacity planning — predict queue depths and bottlenecks
- [ ] Anomaly detection — flag unusual message volumes or latency spikes

---

## Architecture Summary

```
  User (Browser)
       |
       v
  AIAgent.UI.Chat (CSP Page, Alpine.js SPA)
       |
       v
  AIAgent.API.Dispatcher (%CSP.REST, 25 routes)
       |
       +--> AIAgent.Engine.Orchestrator (workflow coordinator)
       |        |
       |        +--> AIAgent.Engine.BridgeClient (HTTP to Node.js)
       |        |         |
       |        |         v
       |        |    Node.js Bridge (Express, port 3100)
       |        |         |
       |        |         +--> Claude Agent SDK (Anthropic)
       |        |         +--> OpenAI SDK (GPT-4o)
       |        |         +--> Azure OpenAI (Azure-hosted)
       |        |         +--> [Google Vertex, Ollama — planned]
       |        |
       |        +--> AIAgent.Engine.CodeManager (write/compile/delete classes)
       |        +--> AIAgent.Engine.ProductionManager (start/stop/topology)
       |        +--> AIAgent.Engine.VersionManager (snapshot/rollback)
       |        +--> AIAgent.Engine.TestRunner (unit tests, test messages)
       |
       +--> AIAgent.Templates.Factory (scaffolding for AI-generated code)
       |
       +--> AIAgent.Model.* (persistent data: conversations, generations, versions, audit)
```

---

## File Inventory (32 files)

### ObjectScript Classes (24)
```
cls/AIAgent/
├── API/
│   └── Dispatcher.cls          # REST API (917 lines)
├── Engine/
│   ├── BridgeClient.cls        # HTTP client to Node.js bridge
│   ├── CodeManager.cls         # Class read/write/compile/import/export
│   ├── Orchestrator.cls        # Workflow coordinator
│   ├── ProductionManager.cls   # Production lifecycle management
│   ├── TestRunner.cls          # Test execution
│   └── VersionManager.cls      # Code versioning & rollback
├── Install/
│   └── Installer.cls           # One-click deployment
├── Model/
│   ├── AuditEntry.cls          # Audit trail
│   ├── Conversation.cls        # Chat conversations
│   ├── Generation.cls          # Code generation batches
│   ├── GenerationClass.cls     # Individual generated classes
│   ├── Message.cls             # Chat messages
│   └── Version.cls             # Deployment snapshots
├── Templates/
│   ├── BusinessOperation.cls   # BO templates (TCP/HTTP/File/Email)
│   ├── BusinessProcess.cls     # BP templates (BPL/Code)
│   ├── BusinessService.cls     # BS templates (TCP/HTTP/File)
│   ├── DataTransformation.cls  # DTL templates (HL7/Object/Code)
│   ├── Factory.cls             # Unified template entry point
│   ├── MessageClass.cls        # Message templates (Request/Response)
│   └── RoutingRule.cls         # Routing rule templates
├── UI/
│   └── Chat.cls                # Chat SPA (1962 lines)
└── Util/
    ├── JSON.cls                # JSON response helpers
    └── Logger.cls              # Structured logging
```

### Node.js Bridge (12 files)
```
bridge/
├── package.json
├── tsconfig.json
├── .env.example
└── src/
    ├── config.ts               # Environment configuration
    ├── server.ts               # Express server entry point
    ├── agents/
    │   └── orchestrator.ts     # Intent classification & routing
    ├── iris/
    │   └── iris-client.ts      # IRIS REST API callback client
    ├── routes/
    │   ├── chat.ts             # POST /api/chat, /api/chat/stream
    │   ├── health.ts           # GET /api/health
    │   └── runners.ts          # GET /api/runners, /api/runners/health
    └── runners/
        ├── runner-interface.ts # Core AIRunnerAdapter interface
        ├── runner-registry.ts  # Capability-based runner selection
        ├── claude-agent-sdk/
        │   └── index.ts        # Anthropic Claude runner
        ├── openai-codex/
        │   └── index.ts        # OpenAI GPT runner
        └── azure-openai/
            └── index.ts        # Azure OpenAI runner
```

### Knowledge Base (3 files)
```
knowledge/
├── iris-reference.md           # IRIS API & ObjectScript reference
├── bradford-conventions.md     # Bradford TIE patterns & naming
└── hl7-schemas.md              # HL7 v2 message structures
```

### Documentation (4 files)
```
docs/
├── DESIGN.md                   # Architecture design document
├── DEMO-LIFECYCLE.md           # Pharmacy Dose-Check demo scenario
├── TEST-CASES.md               # 28 formal test cases
└── IMPLEMENTATION-PLAN.md      # This file
```
