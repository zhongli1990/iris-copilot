# IRIS Copilot

[Vision Article: IRIS Copilot Prototype - English (etc.) as IRIS Language](https://community.intersystems.com/post/iris-copilot-prototype-english-etc-iris-language)

Human natural language-driven AI platform for InterSystems IRIS HealthConnect TIE implementation lifecycles.

This project is built for NHS Trust integration delivery: users describe clinical integration requirements in natural language, Copilot designs and generates IRIS artifacts, and deployment is executed only after explicit human approval.

## Product Vision

IRIS Copilot should support full lifecycle delivery in one controlled workflow:

1. Capture requirements in human natural language (English and other languages)
2. Discover current IRIS production context
3. Design topology deltas (BS/BP/BO/DTL/rules/lookups)
4. Generate compilable ObjectScript artifacts
5. Human review + approval gate
6. Compile/deploy/update production
7. Run tests and monitor post-deploy health
8. Rollback by version snapshot if required

## Current Repository Scope

- IRIS server-side classes (`cls/AIAgent/*`) for API, UI, engine, model, templates, installer
- Node bridge (`bridge/*`) for runner orchestration and AI provider adapters
- Deployment tooling (`deploy/*`) including XML export generator and import helper
- Operational docs and demo lifecycle guides (`docs/*`)

## Architecture

- CSP Chat UI: `AIAgent.UI.Chat.cls`
- IRIS REST dispatcher: `AIAgent.API.Dispatcher`
- Orchestrator/engine services in IRIS
- Node bridge adapters for:
  - Claude Agent SDK
  - OpenAI Codex (standard API runner)
  - OpenAI Codex SDK runner
  - Azure OpenAI (optional)

## Quick Start

### 1. Deploy IRIS classes

Use one of:
- `docs/DEPLOYMENT-GUIDE.md`
- `deploy/DEPLOY-README.md`

Typical terminal flow:

```objectscript
zn "<YOUR_NAMESPACE>"
do $system.OBJ.Load("<path>\\deploy\\ImportAll.cls", "ck")
do ##class(AIAgent.Deploy.ImportAll).Run("<path>\\cls\\")
do ##class(AIAgent.Install.Installer).Run()
```

### 2. Create IRIS Web Application

In IRIS Management Portal, create/update two web applications:

1. `/<namespace>/` for CSP pages (for `AIAgent.UI.Chat.cls`)
2. `/ai` for REST APIs (dispatch class `AIAgent.API.Dispatcher`)

Recommended settings:
- Namespace: your target namespace (for example `DEMO2_AI2`)
- Dispatch Class (for `/ai`): `AIAgent.API.Dispatcher`
- Enable Authentication: Password or delegated SSO per site policy
- Allowed Authentication Methods: align with your enterprise security model

### 3. Start bridge

```bash
cd bridge
npm install
npm run build
npm start
```

Configure keys and runner settings in:
- `bridge/.env` (local)
- `bridge/.env.example` (template)

### 4. Open Chat UI

```text
http://<iris-host>:52773/csp/<namespace>/AIAgent.UI.Chat.cls
```

Health checks:
- IRIS API: `http://<iris-host>:52773/ai/health`
- Bridge: `http://localhost:3100/api/health`

## Key Docs

- Deployment: `docs/DEPLOYMENT-GUIDE.md`
- User workflows: `docs/USER-GUIDE.md`
- End-to-end demo scenario: `docs/DEMO-LIFECYCLE.md`
- Design reference: `docs/DESIGN.md`
- Test coverage plan: `docs/TEST-CASES.md`
- Implementation backlog: `docs/IMPLEMENTATION-PLAN.md`

## Safety and Governance

- Human approval required before deployment actions
- Audit logging and version snapshot support
- Intended for controlled healthcare integration environments

## Repository Notes

- This repo is standalone under `Site/AIAgent`
- Secrets are excluded via `.gitignore` (`.env`, build artifacts, generated export XML)

## License

This project is licensed under the **Apache License 2.0**.
See `LICENSE` for the full Apache-2.0 license text.

Enterprise/commercial terms are available separately in `LICENSE-ENTERPRISE.md`.



