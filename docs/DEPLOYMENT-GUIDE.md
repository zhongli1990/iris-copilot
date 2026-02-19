# IRIS Copilot — Deployment Guide

**Step-by-step instructions for deploying the IRIS AI Agent Platform onto an InterSystems IRIS HealthConnect server.**

Version 1.0 — February 2026

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Deployment Overview](#2-deployment-overview)
3. [Method A: Import via Studio](#3-method-a-import-via-studio)
4. [Method B: Import via Terminal](#4-method-b-import-via-terminal)
5. [Method C: Import via Management Portal](#5-method-c-import-via-management-portal)
6. [Run the Installer](#6-run-the-installer)
7. [Configure API Keys](#7-configure-api-keys)
8. [Deploy the Node.js Bridge](#8-deploy-the-nodejs-bridge)
9. [Verify the Installation](#9-verify-the-installation)
10. [Compile Order Reference](#10-compile-order-reference)
11. [Troubleshooting](#11-troubleshooting)
12. [Uninstall](#12-uninstall)

---

## 1. Prerequisites

### IRIS Server

| Requirement | Minimum |
|-------------|---------|
| InterSystems IRIS | 2023.1 or later |
| IRIS HealthConnect | Licensed and installed |
| Namespace | Any (HSBUS recommended, or a dedicated namespace) |
| User permissions | `%Development` resource, `%DB_IRISSYS` for web app creation |
| Disk space | ~5 MB for classes and data globals |

### Node.js Bridge Server

| Requirement | Minimum |
|-------------|---------|
| Node.js | v20.0 or later |
| npm | v9.0 or later |
| Network | Must reach IRIS server on port 52773 (or your configured web server port) |
| Network | IRIS server must reach Node.js bridge on port 3100 (or configured port) |

### AI API Keys (at least one)

| Provider | Key Format | Get It From |
|----------|-----------|-------------|
| Anthropic (Claude) | `sk-ant-api03-...` | https://console.anthropic.com |
| OpenAI (GPT-4o) | `sk-...` | https://platform.openai.com |
| Azure OpenAI | Endpoint URL + key | Azure Portal > Cognitive Services |

---

## 2. Deployment Overview

```
Step 1: Copy cls/ folder to IRIS server
Step 2: Import & compile 24 ObjectScript classes (via Studio, Terminal, or Portal)
Step 3: Run the Installer class (creates /ai web application)
Step 4: Configure API keys
Step 5: Install and start the Node.js bridge
Step 6: Verify health endpoints
```

### File Structure to Deploy

```
AIAgent/
├── cls/AIAgent/              ← Copy this entire folder to the IRIS server
│   ├── API/Dispatcher.cls
│   ├── Engine/
│   │   ├── BridgeClient.cls
│   │   ├── CodeManager.cls
│   │   ├── Orchestrator.cls
│   │   ├── ProductionManager.cls
│   │   ├── TestRunner.cls
│   │   └── VersionManager.cls
│   ├── Install/Installer.cls
│   ├── Model/
│   │   ├── AuditEntry.cls
│   │   ├── Conversation.cls
│   │   ├── Generation.cls
│   │   ├── GenerationClass.cls
│   │   ├── Message.cls
│   │   └── Version.cls
│   ├── Templates/
│   │   ├── BusinessOperation.cls
│   │   ├── BusinessProcess.cls
│   │   ├── BusinessService.cls
│   │   ├── DataTransformation.cls
│   │   ├── Factory.cls
│   │   ├── MessageClass.cls
│   │   └── RoutingRule.cls
│   ├── UI/Chat.cls
│   └── Util/
│       ├── JSON.cls
│       └── Logger.cls
├── bridge/                   ← Copy to the Node.js host machine
└── deploy/
    └── ImportAll.cls         ← Helper script for batch import
```

---

## 3. Method A: Import via Studio

This is the recommended method for most users.

### Step 1: Copy Files

Copy the entire `cls/AIAgent/` folder to a location accessible from the IRIS server. For example:

```
C:\InterSystems\AIAgent\cls\AIAgent\
```

### Step 2: Open Studio

1. Launch **InterSystems Studio**
2. Connect to your IRIS server
3. Select your target **namespace** (e.g., HSBUS)

### Step 3: Import All Classes

1. Go to **Tools > Import Local...**
   (or press **Ctrl+Shift+I**)
2. In the file dialog, navigate to the `cls\AIAgent\` directory
3. Select **all 24 `.cls` files** across all subdirectories
4. Click **Open**

**Important:** Studio's "Import Local" may only show one directory level at a time. You have two options:

**Option A — Import directory by directory:**

Import in this order (dependencies first):

| Order | Directory | Files | Why First |
|-------|-----------|-------|-----------|
| 1 | `Util/` | JSON.cls, Logger.cls | No dependencies, used by everything |
| 2 | `Model/` | All 6 .cls files | Used by Engine classes |
| 3 | `Engine/` | All 6 .cls files | Uses Model and Util |
| 4 | `Templates/` | All 7 .cls files | Standalone |
| 5 | `API/` | Dispatcher.cls | Uses Engine, Model, Util |
| 6 | `UI/` | Chat.cls | Uses API endpoints |
| 7 | `Install/` | Installer.cls | Uses everything |

For each directory:
1. **Tools > Import Local...**
2. Navigate to the subdirectory
3. Select all `.cls` files
4. Check **"Compile imported items"**
5. Click **Open**

**Option B — Use the ImportAll helper script (recommended):**

1. Import just one file first: `deploy/ImportAll.cls`
   - Tools > Import Local > select `deploy/ImportAll.cls` > Open
   - Compile it (Ctrl+Shift+F7)
2. Open the Terminal (Tools > Terminal) and run:
   ```objectscript
   do ##class(AIAgent.Deploy.ImportAll).Run("C:\InterSystems\AIAgent\cls\")
   ```
   This imports and compiles all 24 classes in the correct order.

### Step 4: Verify Compilation

In Studio, check the Output window (Ctrl+Shift+O) for compile results. You should see:

```
Compiling class AIAgent.Util.JSON
Compiling class AIAgent.Util.Logger
...
Compiling class AIAgent.Install.Installer
Compilation finished successfully. 24 classes compiled.
```

If you see errors, check [Troubleshooting](#11-troubleshooting).

---

## 4. Method B: Import via Terminal

Connect to the IRIS Terminal for your target namespace and run:

### Single Command (imports all classes recursively)

```objectscript
do $system.OBJ.LoadDir("C:\InterSystems\AIAgent\cls\", "ck")
```

Flags:
- `c` = compile after loading
- `k` = keep existing newer versions (safe)

### Or use the deployment helper script

```objectscript
// First, load just the import helper
do $system.OBJ.Load("C:\InterSystems\AIAgent\deploy\ImportAll.cls", "ck")

// Then run it (imports all 24 classes in correct order)
do ##class(AIAgent.Deploy.ImportAll).Run("C:\InterSystems\AIAgent\cls\")
```

### Verify

```objectscript
// Check all classes exist
do ##class(AIAgent.Deploy.ImportAll).Verify()
```

Expected output:
```
[AIAgent.Deploy] Verifying all 24 classes...
  AIAgent.Util.JSON .............. OK
  AIAgent.Util.Logger ............ OK
  AIAgent.Model.Conversation ..... OK
  ...
  AIAgent.Install.Installer ...... OK
[AIAgent.Deploy] All 24 classes verified. Ready for installation.
```

---

## 5. Method C: Import via Management Portal

1. Open the **Management Portal** in your browser
2. Navigate to: **System Explorer > Classes**
3. Select your target namespace
4. Click **Import**
5. Browse to the `cls/` directory
6. Select all `.cls` files
7. Check **"Compile"**
8. Click **Import**

---

## 6. Run the Installer

After all 24 classes are compiled, run the installer to create the web application and initialize data:

### Via Terminal

```objectscript
// Create the /ai web application and initialize
do ##class(AIAgent.Install.Installer).Run()
```

### What the Installer Does

1. **Creates the `/ai` web application** in IRIS Security
   - Maps to the `AIAgent.API.Dispatcher` class
   - Enables CSP pages for `AIAgent.UI.Chat`
   - Sets up authentication (password-based)
   - Configures CORS headers

2. **Initializes data globals**
   - Creates `^AIAgent.Config` for system configuration
   - Verifies storage globals are accessible

3. **Verifies compilation**
   - Checks all 24 classes exist and are compiled
   - Reports any issues

### Expected Output

```
[AIAgent.Install] ================================================
[AIAgent.Install] IRIS Copilot Installer v1.0
[AIAgent.Install] ================================================
[AIAgent.Install] Creating web application /ai ...
[AIAgent.Install] Web application /ai created successfully
[AIAgent.Install] Initializing data ...
[AIAgent.Install] Verifying compilation ...
[AIAgent.Install] All 24 classes compiled and ready
[AIAgent.Install] ================================================
[AIAgent.Install] Installation complete!
[AIAgent.Install]
[AIAgent.Install] Chat UI: http://localhost:52773/ai/AIAgent.UI.Chat.cls
[AIAgent.Install] REST API: http://localhost:52773/ai/health
[AIAgent.Install]
[AIAgent.Install] Next: Configure API keys with:
[AIAgent.Install]   do ##class(AIAgent.Install.Installer).Configure(...)
[AIAgent.Install] ================================================
```

---

## 7. Configure API Keys

After installation, configure the AI provider API keys and bridge URL:

```objectscript
do ##class(AIAgent.Install.Installer).Configure(
    "http://localhost:3100",              /* Bridge URL (Node.js server) */
    "sk-ant-api03-your-anthropic-key",    /* Anthropic API key (or "") */
    "sk-your-openai-key",                 /* OpenAI API key (or "") */
    "https://your-org.openai.azure.com",  /* Azure endpoint (or "") */
    "your-azure-api-key"                  /* Azure API key (or "") */
)
```

You need **at least one** AI provider key. The system works with any combination.

### Where Keys Are Stored

API keys are stored in the IRIS global `^AIAgent.Config` within the server — not in any file. They're accessible only to processes running in the IRIS namespace.

### Updating Keys Later

Run `Configure()` again with the new values. Previous values are overwritten.

---

## 8. Deploy the Node.js Bridge

The Node.js bridge runs alongside IRIS and handles AI SDK communication.

### Step 1: Copy the bridge folder

Copy the entire `bridge/` directory to your Node.js host:

```bash
# On the Node.js machine
mkdir -p /opt/iris-copilot/bridge
# Copy bridge/ contents here
```

### Step 2: Install dependencies

```bash
cd /opt/iris-copilot/bridge
npm install
```

### Step 3: Configure environment

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```env
# AI Provider Keys (at least one required)
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
OPENAI_API_KEY=sk-your-key-here

# Azure OpenAI (optional)
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_KEY=
AZURE_OPENAI_DEPLOYMENT=gpt-4o

# IRIS Connection
IRIS_BASE_URL=http://your-iris-server:52773
IRIS_USERNAME=_SYSTEM
IRIS_PASSWORD=SYS
IRIS_NAMESPACE=HSBUS

# Bridge Settings
PORT=3100
LOG_LEVEL=info
DEFAULT_RUNNER=claude-agent-sdk
```

### Step 4: Start the bridge

```bash
npm start
```

Expected output:
```
================================================================
  IRIS AI Agent Bridge — Running on port 3100
================================================================
  Registered runners: claude-agent-sdk, openai-codex
  IRIS base URL:      http://your-iris-server:52773
  Press Ctrl+C to stop
================================================================
```

### Step 5: Run as a service (production)

For production deployments, run the bridge as a system service:

**Linux (systemd):**

```ini
# /etc/systemd/system/iris-copilot-bridge.service
[Unit]
Description=IRIS Copilot AI Bridge
After=network.target

[Service]
Type=simple
User=iris
WorkingDirectory=/opt/iris-copilot/bridge
ExecStart=/usr/bin/node --loader ts-node/esm src/server.ts
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable iris-copilot-bridge
sudo systemctl start iris-copilot-bridge
```

**Windows (as a service):**

Use `node-windows` or run via Task Scheduler pointing to `npm start` in the bridge directory.

---

## 9. Verify the Installation

### Check IRIS Health

Open in browser or curl:

```
GET http://your-iris-server:52773/ai/health
```

Expected response:
```json
{
  "status": "ok",
  "iris": true,
  "bridge": true,
  "namespace": "HSBUS",
  "runners": [
    {"id": "claude-agent-sdk", "healthy": true},
    {"id": "openai-codex", "healthy": true}
  ]
}
```

### Check Bridge Health

```
GET http://localhost:3100/api/health
```

Expected response:
```json
{
  "status": "ok",
  "runners": ["claude-agent-sdk", "openai-codex"],
  "iris": {"reachable": true}
}
```

### Check Chat UI

Open in browser:

```
http://your-iris-server:52773/ai/AIAgent.UI.Chat.cls
```

You should see the dark-themed chat interface. Create a new conversation and send a test message like "Hello, are you working?" to verify end-to-end connectivity.

### Check via Terminal

```objectscript
// Full system status
do ##class(AIAgent.Install.Installer).Status()
```

---

## 10. Compile Order Reference

If you need to compile classes manually or encounter dependency errors, use this order:

```
Phase 1 — Foundation (no dependencies)
  AIAgent.Util.JSON
  AIAgent.Util.Logger

Phase 2 — Data Model (depends on Util)
  AIAgent.Model.Conversation
  AIAgent.Model.Message
  AIAgent.Model.Generation
  AIAgent.Model.GenerationClass
  AIAgent.Model.Version
  AIAgent.Model.AuditEntry

Phase 3 — Engine (depends on Model + Util)
  AIAgent.Engine.CodeManager
  AIAgent.Engine.ProductionManager
  AIAgent.Engine.VersionManager
  AIAgent.Engine.TestRunner
  AIAgent.Engine.BridgeClient
  AIAgent.Engine.Orchestrator

Phase 4 — Templates (standalone, no cross-dependencies)
  AIAgent.Templates.BusinessService
  AIAgent.Templates.BusinessProcess
  AIAgent.Templates.BusinessOperation
  AIAgent.Templates.DataTransformation
  AIAgent.Templates.RoutingRule
  AIAgent.Templates.MessageClass
  AIAgent.Templates.Factory

Phase 5 — API + UI (depends on Engine)
  AIAgent.API.Dispatcher
  AIAgent.UI.Chat

Phase 6 — Installer (depends on everything)
  AIAgent.Install.Installer
```

---

## 11. Troubleshooting

### "Class does not exist" compile errors

**Cause:** Classes compiled in wrong order (dependency not yet compiled).

**Fix:** Use the ImportAll helper script or follow the compile order in Section 10. Or simply run:
```objectscript
do $system.OBJ.CompileAll("AIAgent.*.cls", "ck")
```
This recompiles everything and resolves dependency order automatically.

### Web application /ai already exists

**Cause:** Previous installation attempt.

**Fix:**
```objectscript
// Remove existing web app first
do ##class(AIAgent.Install.Installer).Uninstall(1)  // 1 = keep data
// Then reinstall
do ##class(AIAgent.Install.Installer).Run()
```

### Bridge connection refused

**Cause:** Node.js bridge not running, wrong port, or firewall blocking.

**Fix:**
1. Verify bridge is running: `curl http://localhost:3100/api/health`
2. Check the bridge URL in IRIS config: `write ^AIAgent.Config("BridgeUrl")`
3. Check firewall allows port 3100 between IRIS and bridge servers
4. If bridge is on a different machine, ensure `IRIS_BASE_URL` in `.env` points back to the IRIS server

### "No AI runners available" in chat

**Cause:** No API keys configured, or keys are invalid.

**Fix:**
1. Check bridge logs for runner registration messages
2. Verify `.env` has valid API keys
3. Test keys directly: `curl https://api.openai.com/v1/models -H "Authorization: Bearer sk-your-key"`
4. Restart the bridge after updating `.env`

### CSP page shows 404

**Cause:** Web application not created or wrong dispatch class.

**Fix:**
1. Check in Management Portal: System Administration > Security > Applications > Web Applications
2. Look for `/ai` application
3. Verify its dispatch class is `AIAgent.API.Dispatcher`
4. Re-run: `do ##class(AIAgent.Install.Installer).Run()`

### Chat UI loads but messages fail

**Cause:** CORS issue or REST API error.

**Fix:**
1. Open browser developer tools (F12) > Network tab
2. Check the failing request URL and response
3. If CORS error: verify the IRIS server allows your browser's origin
4. If 500 error: check the IRIS application error log in Management Portal

---

## 12. Uninstall

### Remove Everything (classes + data)

```objectscript
do ##class(AIAgent.Install.Installer).Uninstall(0)
```

This removes:
- All `AIAgent.*` classes
- All `^AIAgent.*` data globals
- The `/ai` web application

### Remove Classes Only (keep data)

```objectscript
do ##class(AIAgent.Install.Installer).Uninstall(1)
```

This removes classes and web app but keeps conversation history, audit trail, and configuration in globals.

---

*End of Deployment Guide. For usage instructions, see [USER-GUIDE.md](USER-GUIDE.md).*
