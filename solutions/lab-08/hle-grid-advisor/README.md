# HLE Grid Advisor (sample code, Lab 8)

Custom engine agent built with the Microsoft 365 Agents SDK for JavaScript. It answers outage questions for the fictional Harbourline Energy Co. by calling the course mock API (`data/api`) and grounding on the Outage Response Procedure (OPS-PRO-001 Rev 7). It owns its orchestration, model, retrieval and responsible AI controls (limits.md CE-01).

> **Check the SDK API before you run.** The package names `@microsoft/agents-hosting` and `@microsoft/agents-hosting-express` and the calls marked `CHECK` in `src/index.js` were checked against the published npm packages (version 1.9.1 type definitions) on 2026-09-30. They were not found in the Microsoft Learn source the course authors could read, so they are **UNVERIFIED against Learn**. If the Agents Toolkit template you scaffold uses different calls, keep the template's host code and call `advisor.answer()` from its message handler. Everything outside `src/index.js` is plain Node.js and does not depend on the SDK.

## Files

| Path | What it is |
|---|---|
| `package.json` | Node 20+ project. Dependencies: `@microsoft/agents-hosting`, `@microsoft/agents-hosting-express`. Dev dependency: `@microsoft/m365agentsplayground` (local test client). |
| `.env.sample` | All settings. Copy to `.env`. |
| `src/index.js` | Agents SDK host: `AgentApplication`, message and members-added handlers, `startServer` on port 3978 (`POST /api/messages`, `GET /health`). |
| `src/advisor.js` | The engine: system prompt, input check, retrieval, API tool call, model call, output check, citation list. |
| `src/retrieval.js` | Local BM25 retrieval over `data/outage-response-procedure.md`, one chunk per section. |
| `src/outageApi.js` | Tool: decides when to call `GET /api/outage-status` (outage ID, region or town, or "largest/active" questions) and calls it with a timeout. |
| `src/safety.js` | Responsible AI controls: input filter (prompt injection, unsafe work such as bypassing lockout, customer personal data, HR/finance scope), output filter (canary leak check, redaction of emails, phone numbers and HLE-ACC account numbers, citation enforcement), refusal texts. |
| `src/model.js` | Model client. `azure-openai` (Azure OpenAI, or a Foundry deployment of an Azure OpenAI model with the same endpoint shape) or `mock` (offline, extractive, deterministic). |
| `src/config.js` | Reads environment variables. |
| `scripts/ask.js` | Ask one question from the command line without the SDK: `npm run ask -- "What is the status of OUT-2026-0412?"` |
| `data/outage-response-procedure.md` | Text extract of `data/sharepoint/Harbourline-Operations/Procedures/Outage-Response-Procedure.docx`. This is the only document the agent knows. |
| `appPackage/manifest.json` | Sample app manifest (1.21) with `copilotAgents.customEngineAgents`. Compare with the manifest your Agents Toolkit template generates and prefer the template. Add `color.png` (192 x 192) and `outline.png` (32 x 32) from the template before packaging. |
| `test/advisor.test.js` | Offline tests (`npm test`): retrieval, tool planning, refusals, output filter, API outage handling. |

## Run

```bash
cd solutions/lab-08/hle-grid-advisor
npm install
cp .env.sample .env          # MODEL_PROVIDER=mock works with no Azure resources
npm test
# in another terminal: start the mock API (data/api/run-local.md): cd data/api && func start
npm run ask -- "What is the status of OUT-2026-0412?"
npm start                    # agent on http://localhost:3978/api/messages
npm run playground           # Microsoft 365 Agents Playground, a local chat client
```

Switch to a real model by setting `MODEL_PROVIDER=azure-openai` and the four `AZURE_OPENAI_*` values in `.env`. Look up a current `api-version` on Microsoft Learn. The eval in `evals/lab-08-questions.csv` assumes a real model: the `mock` provider only quotes the top retrieved section and is for plumbing tests.

## Settings

| Variable | Default | Purpose |
|---|---|---|
| `MODEL_PROVIDER` | `mock` | `mock` or `azure-openai`. |
| `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT`, `AZURE_OPENAI_API_VERSION`, `AZURE_OPENAI_API_KEY` | none | Model deployment. On Azure, store the key in App Service settings or Key Vault, not in the package. |
| `HLE_API_BASE_URL` | `http://localhost:7071/api` | Mock API base URL. Must be a public URL (Function App or dev tunnel) once the agent runs on Azure. |
| `HLE_API_KEY` | empty | Sent as `X-API-Key` when the mock API runs with `AUTH_MODE=apikey`. |
| `RAI_FILTERS` | `on` | `off` disables the input and output filters. Break-it C-08-b only. |
| `RETRIEVAL_MIN_SCORE` | `2.5` | Lowest BM25 score a section needs to be used as context. |
| `clientId`, `clientSecret`, `tenantId` | empty | Bot identity read by the SDK (`loadAuthConfigFromEnv`). Empty only for local testing. |
| `PORT` | `3978` | Listening port. |

## How a turn works

1. `safety.checkInput` refuses prompt injection, requests to bypass lockout, tagout or grounding, customer personal data requests and HR or finance questions.
2. `retrieval.search` returns up to 3 procedure sections; `outageApi.lookup` calls the mock API when the question names an outage ID, a region or town, or asks about active or largest outages.
3. If neither source returns anything, the agent answers with an out-of-scope message. It never calls the model without context.
4. The model receives the system prompt (in `src/advisor.js`) and numbered context blocks `[P1]`, `[P2]`, `[API]`.
5. `safety.checkOutput` replaces uncited answers, answers that cite blocks the model was not given, and answers that leak the canary string, then redacts personal data. The agent appends a "Sources" list that maps each marker to the document section or API call.

## Deploy to Azure

See Lab 8 Part B in `labs/lab-08-custom-engine-agent/README.md`: Azure Bot Service registration (single tenant Entra app), App Service (Node 20 or later), app settings from `.env`, messaging endpoint `https://<app-name>.azurewebsites.net/api/messages` (CE-02).
