# IRIS AI Agent Platform â€” Implementation Plan

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
| Site Conventions | `knowledge/Site-conventions.md` | Done |
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
- [ ] Architect Agent â€” designs topology from requirements
- [ ] Developer Agent â€” generates ObjectScript from design
- [ ] Reviewer Agent â€” validates code quality and safety
- [ ] Testing Agent â€” generates and runs test cases
- [ ] Pipeline: Architect â†’ Developer â†’ Reviewer â†’ (human approval) â†’ Deploy â†’ Test

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
- [ ] Proactive monitoring â€” AI analyzes error patterns and suggests fixes
- [ ] Capacity planning â€” predict queue depths and bottlenecks
- [ ] Anomaly detection â€” flag unusual message volumes or latency spikes

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
       |        |         +--> [Google Vertex, Ollama â€” planned]
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
â”œâ”€â”€ API/
â”‚   â””â”€â”€ Dispatcher.cls          # REST API (917 lines)
â”œâ”€â”€ Engine/
â”‚   â”œâ”€â”€ BridgeClient.cls        # HTTP client to Node.js bridge
â”‚   â”œâ”€â”€ CodeManager.cls         # Class read/write/compile/import/export
â”‚   â”œâ”€â”€ Orchestrator.cls        # Workflow coordinator
â”‚   â”œâ”€â”€ ProductionManager.cls   # Production lifecycle management
â”‚   â”œâ”€â”€ TestRunner.cls          # Test execution
â”‚   â””â”€â”€ VersionManager.cls      # Code versioning & rollback
â”œâ”€â”€ Install/
â”‚   â””â”€â”€ Installer.cls           # One-click deployment
â”œâ”€â”€ Model/
â”‚   â”œâ”€â”€ AuditEntry.cls          # Audit trail
â”‚   â”œâ”€â”€ Conversation.cls        # Chat conversations
â”‚   â”œâ”€â”€ Generation.cls          # Code generation batches
â”‚   â”œâ”€â”€ GenerationClass.cls     # Individual generated classes
â”‚   â”œâ”€â”€ Message.cls             # Chat messages
â”‚   â””â”€â”€ Version.cls             # Deployment snapshots
â”œâ”€â”€ Templates/
â”‚   â”œâ”€â”€ BusinessOperation.cls   # BO templates (TCP/HTTP/File/Email)
â”‚   â”œâ”€â”€ BusinessProcess.cls     # BP templates (BPL/Code)
â”‚   â”œâ”€â”€ BusinessService.cls     # BS templates (TCP/HTTP/File)
â”‚   â”œâ”€â”€ DataTransformation.cls  # DTL templates (HL7/Object/Code)
â”‚   â”œâ”€â”€ Factory.cls             # Unified template entry point
â”‚   â”œâ”€â”€ MessageClass.cls        # Message templates (Request/Response)
â”‚   â””â”€â”€ RoutingRule.cls         # Routing rule templates
â”œâ”€â”€ UI/
â”‚   â””â”€â”€ Chat.cls                # Chat SPA (1962 lines)
â””â”€â”€ Util/
    â”œâ”€â”€ JSON.cls                # JSON response helpers
    â””â”€â”€ Logger.cls              # Structured logging
```

### Node.js Bridge (12 files)
```
bridge/
â”œâ”€â”€ package.json
â”œâ”€â”€ tsconfig.json
â”œâ”€â”€ .env.example
â””â”€â”€ src/
    â”œâ”€â”€ config.ts               # Environment configuration
    â”œâ”€â”€ server.ts               # Express server entry point
    â”œâ”€â”€ agents/
    â”‚   â””â”€â”€ orchestrator.ts     # Intent classification & routing
    â”œâ”€â”€ iris/
    â”‚   â””â”€â”€ iris-client.ts      # IRIS REST API callback client
    â”œâ”€â”€ routes/
    â”‚   â”œâ”€â”€ chat.ts             # POST /api/chat, /api/chat/stream
    â”‚   â”œâ”€â”€ health.ts           # GET /api/health
    â”‚   â””â”€â”€ runners.ts          # GET /api/runners, /api/runners/health
    â””â”€â”€ runners/
        â”œâ”€â”€ runner-interface.ts # Core AIRunnerAdapter interface
        â”œâ”€â”€ runner-registry.ts  # Capability-based runner selection
        â”œâ”€â”€ claude-agent-sdk/
        â”‚   â””â”€â”€ index.ts        # Anthropic Claude runner
        â”œâ”€â”€ openai-codex/
        â”‚   â””â”€â”€ index.ts        # OpenAI GPT runner
        â””â”€â”€ azure-openai/
            â””â”€â”€ index.ts        # Azure OpenAI runner
```

### Knowledge Base (3 files)
```
knowledge/
â”œâ”€â”€ iris-reference.md           # IRIS API & ObjectScript reference
â”œâ”€â”€ Site-conventions.md     # TIE patterns & naming
â””â”€â”€ hl7-schemas.md              # HL7 v2 message structures
```

### Documentation (4 files)
```
docs/
â”œâ”€â”€ DESIGN.md                   # Architecture design document
â”œâ”€â”€ DEMO-LIFECYCLE.md           # Pharmacy Dose-Check demo scenario
â”œâ”€â”€ TEST-CASES.md               # 28 formal test cases
â””â”€â”€ IMPLEMENTATION-PLAN.md      # This file
```

