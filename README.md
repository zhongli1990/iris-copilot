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
do $system.OBJ.Load("<path>\\deploy\\AIAgent-export-v34.xml", "ck")
```

### 2. Create IRIS Web Application

The `/ai` REST web application is created automatically by
`do ##class(AIAgent.Install.Installer).Run()` after import. It is dispatched
via `AIAgent.API.Dispatcher` and serves all REST endpoints.

The Chat UI (`AIAgent.UI.Chat.cls`) is a CSP page served from the
**namespace's own CSP application**, which IRIS creates automatically per
namespace. The exact path differs between IRIS HealthShare and vanilla IRIS:

| IRIS edition       | Chat UI URL (substitute `<ns>` lowercased) |
|--------------------|---------------------------------------------|
| **HealthShare**    | `http://<iris-host>:52773/csp/healthshare/<ns>/AIAgent.UI.Chat.cls` |
| **Vanilla IRIS**   | `http://<iris-host>:52773/csp/<ns>/AIAgent.UI.Chat.cls` |

In Management Portal -> System Administration -> Security -> Applications -> Web Applications,
confirm both apps are present:

1. `/ai` (REST, dispatch class `AIAgent.API.Dispatcher`) - created by Installer
2. `/csp/healthshare/<ns>/` or `/csp/<ns>/` (CSP, namespace default) - auto-created by IRIS

Recommended settings on `/ai`:
- Namespace: your target namespace (for example `DEMO2_AI2`)
- Dispatch Class: `AIAgent.API.Dispatcher`
- Enable Authentication: Password or delegated SSO per site policy
- Allowed Authentication Methods: align with your enterprise security model

**Gotcha:** the namespace fragment in the CSP URL must be **lowercase**,
even if your namespace name is uppercase (e.g. `DEMO2_AI2` -> `demo2_ai2`
in the URL).

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

Substitute your IRIS edition and lowercased namespace:

```text
# IRIS HealthShare:
http://<iris-host>:52773/csp/healthshare/<ns>/AIAgent.UI.Chat.cls

# Vanilla IRIS:
http://<iris-host>:52773/csp/<ns>/AIAgent.UI.Chat.cls
```

(The `/ai` web app is REST-only; it does not serve the CSP Chat page.)

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

- Secrets are excluded via `.gitignore` (`.env`, build artifacts, generated export XML)
- The `knowledge/tie-conventions.md` document is a generic placeholder. Deploying
  sites should replace it with a trust-specific copy (same path) reflecting their
  own package prefix, integration estate, and coding standards. Keep site-specific
  copies in a private repo, not in this public one.

## License

Copyright (c) Lightweight Integration Limited. See [`LICENSE`](LICENSE) for terms.
Enterprise licensing: [Zhong@li-ai.co.uk](mailto:Zhong@li-ai.co.uk)



