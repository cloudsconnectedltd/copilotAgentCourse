# Lab 06: Declarative agent with Microsoft 365 Agents Toolkit (VS Code)

| | |
|---|---|
| Build path | VS Code + Microsoft 365 Agents Toolkit: declarative agent (manifest v1.8) with an API plugin (manifest v2.4) |
| Estimated time | 4 hours |
| Prerequisites | Setup scripts 00 to 03 ([`setup/README.md`](../../setup/README.md)); mock API running with `AUTH_MODE=apikey` behind a persistent dev tunnel ([`data/api/run-local.md`](../../data/api/run-local.md)); "Upload custom apps" enabled for your account (DA-17); a Microsoft 365 Copilot license for the learner (LIC-15). [Lab 5](../lab-05-studio-actions-flows/README.md) is recommended (same API and tunnel) but not required. |
| Personas used | Learner (developer and tester). Sideloaded agents are available only to the account that provisioned them, so no other persona is used. |
| Status | GA. Contains UNVERIFIED limits: DA-16 (response size in KB or MB). Contains CONFLICT: DA-10 vs DA-11 (API key in custom header). `worker_agents` (DA-06) is PREVIEW and not used. |
| Limits referenced | [DA-01, DA-02, DA-03, DA-04, DA-05, DA-07, DA-08, DA-09, DA-10, DA-11, DA-12, DA-13, DA-14, DA-15, DA-16, DA-17, AB-09, LIC-15](../../reference/limits.md) |

> **Check before you run.** Most rows used here are SRC (read from the Learn source repository on 2026-09-30). Re-check these on Microsoft Learn before class:
> - **DA-16** (UNVERIFIED): no response size limit in KB or MB is documented. Observe and record; do not state a number.
> - **DA-10 / DA-11** (CONFLICT): the API key page says keys can be sent in a custom header; the known issues page says custom headers are not supported. https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/plugin-authentication-api-key and https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/known-issues
> - **DA-15**: OpenAPI 3.1 support for Copilot plugins is UNVERIFIED. This lab uses OpenAPI 3.0.3.
> - The Microsoft 365 app manifest version (this lab uses v1.24, as in the Learn declarative agent environment article) and the `m365agents.yml` `version` line change with toolkit releases. Use what your installed toolkit generates.

## Objective

Build **HLE Outage Desk**, a declarative agent for Microsoft 365 Copilot that:

1. Calls the Harbourline mock API through an API plugin: `getOutageStatus`, `dispatchCrew`, `lookupCustomer`, with API key authentication (`ApiKeyPluginVault`).
2. Renders outage results with an Adaptive Card through `response_semantics`.
3. Grounds on two SharePoint libraries only (HR-Policies and Procedures), searches three regulator web sites, and uses Code Interpreter for charts.

Then break it six ways: wrong manifest version, a non-compliant OpenAPI file, oversized responses, sideloading policy, knowledge scoping, and the API key header conflict.

## Concepts

| Concept | What you need to know for this lab |
|---|---|
| App package | A zip with the Microsoft 365 app manifest (`manifest.json`), two icons, the declarative agent manifest, the plugin manifest, the OpenAPI file and any card files. Agents Toolkit builds it at **Provision**. |
| Declarative agent manifest v1.8 | `version` must be `v1.8`. Instructions up to 8,000 characters (DA-03), up to 12 conversation starters (DA-04), 1 to 10 actions (DA-05). Each capability type at most once (DA-02). |
| Plugin manifest v2.4 | `schema_version` `v2.4`. Each function `name` must match an OpenAPI `operationId`. Runtime `auth.type` is `None`, `OAuthPluginVault` or `ApiKeyPluginVault` (DA-09); the secret lives in an auth config, referenced by `reference_id`. |
| `response_semantics` | `data_path` (JSONPath to the items), `properties` (title, subtitle, url for citations) and `static_template` (an Adaptive Card, inline or, new in v2.4, a file). One per function (DA-12). |
| Runtime limits | 25 items per plugin response, 4,096 tokens, 45-second timeout, 50 grounding records (DA-07). |
| Capability scoping | `OneDriveAndSharePoint` with `items_by_url` limits knowledge to those URLs. If you omit both `items_by_url` and `items_by_sharepoint_ids`, the agent can use all SharePoint and OneDrive content the user can access. Copilot searches the full content of up to 20 files; above 20 it uses the 20 most relevant (AB-09). |

## Steps

### Part A: Check the tenant and the API (20 min)

1. Confirm custom app upload (DA-17). In the Teams admin center: **Teams apps** > **Setup policies** > **Global (Org-wide default)** > **Upload custom apps** = **On** (or a policy assigned to the learner with it on). Policy changes can take time to reach the client.
2. Start the API in API key mode (`AUTH_MODE=apikey`, your own `API_KEY`), start `func start`, and host your persistent dev tunnel (`data/api/run-local.md` sections 3 and 5). Record the tunnel URL, for example `https://abcd1234-7071.use.devtunnels.ms`.
3. Test through the tunnel:

   ```powershell
   $h = @{ 'X-API-Key' = '<your API key>' }
   Invoke-RestMethod -Headers $h "https://<tunnel host>/api/outage-status?outageId=OUT-2026-0412"
   Invoke-RestMethod -Headers @{ Authorization = 'Bearer <your API key>' } "https://<tunnel host>/api/customer-lookup?accountNumber=HLE-ACC-104233"
   ```

   Expected: Kingston outage (3,214 customers); then Jane Okafor, `currentOutageId` OUT-2026-0412.

### Part B: Scaffold the project (30 min)

1. In VS Code, select the **Microsoft 365 Agents Toolkit** icon > **Create a New Agent/App** > **Declarative Agent** > **Add an Action** > **Start with an OpenAPI Description Document**.
2. **Browse** to `data/api/openapi-apikey.yaml`. Select all three operations: `getOutageStatus`, `dispatchCrew`, `lookupCustomer`.
3. Folder: your working folder. Application name: `hle-outage-desk`.
4. Open the generated project. Note the file layout: `appPackage/manifest.json`, `appPackage/declarativeAgent.json`, the plugin manifest (for example `appPackage/ai-plugin.json`), `appPackage/apiSpecificationFile/`, `env/`, and `m365agents.yml`. Note which env variable the generated OpenAPI file uses for its server URL.
5. Open `m365agents.yml` and find the `apiKey/register` step the toolkit added because the OpenAPI file declares `ApiKeyAuth` (`type: apiKey`, `in: header`, `name: X-API-Key`).

The finished project is in [`solutions/lab-06/hle-outage-desk/`](../../solutions/lab-06/hle-outage-desk/). In Parts C and D you bring the generated files to the same state. You can copy the solution files over the generated ones; read each one as you do.

### Part C: Write the declarative agent manifest (40 min)

Target file: [`appPackage/declarativeAgent.json`](../../solutions/lab-06/hle-outage-desk/appPackage/declarativeAgent.json).

1. Set the schema and version exactly:

   ```json
   "$schema": "https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v1.8/schema.json",
   "version": "v1.8",
   ```

2. `name`: `HLE Outage Desk`. `description`: as in the solution file.
3. `instructions`: copy the text from the solution file (about 2,900 characters, well under the 8,000 limit of DA-03). It tells the agent which function to use for which question, to confirm before dispatching, never to request more than 25 customer accounts, and not to answer from general knowledge.
4. `capabilities`: add exactly these three:

   ```json
   { "name": "OneDriveAndSharePoint", "items_by_url": [ { "url": "${{SP_HR_POLICIES_URL}}" }, { "url": "${{SP_PROCEDURES_URL}}" } ] },
   { "name": "WebSearch", "sites": [ { "url": "https://www.oeb.ca" }, { "url": "https://www.nerc.com" }, { "url": "https://www.ferc.gov" } ] },
   { "name": "CodeInterpreter" }
   ```

   `WebSearch.sites` allows up to 4 URLs, each at most two path segments and no query string (DA-05).
5. Lab 7 will add `GraphConnectors` with `connection_id` `hleTickets`. Do not add it now: a `GraphConnectors` capability without `connections` would give the agent every Copilot connector in the tenant. The snippet waits in `variants/lab07-graphconnectors-capability.json`.
6. `conversation_starters`: the seven starters from the solution file (DA-04 allows 12). The chart starter uses `depends_on` so it only shows when `CodeInterpreter` is present.
7. `actions`: `[ { "id": "hleOutageApi", "file": "ai-plugin.json" } ]`.
8. `behavior_overrides.special_instructions.discourage_model_knowledge`: `true`, and a short `disclaimer`.

### Part D: Write the plugin manifest and the Adaptive Card (40 min)

Target files: [`appPackage/ai-plugin.json`](../../solutions/lab-06/hle-outage-desk/appPackage/ai-plugin.json) and [`appPackage/adaptiveCards/getOutageStatus.json`](../../solutions/lab-06/hle-outage-desk/appPackage/adaptiveCards/getOutageStatus.json).

1. `"schema_version": "v2.4"`, `"$schema": "https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json"`, `name_for_human` `HLE Outage API` (characters beyond 20 may be ignored), `namespace` `hleoutage`.
2. `functions`: one per operationId. For each, keep `description`, `states.reasoning.instructions` and `states.responding.instructions` from the solution file.
3. `getOutageStatus.capabilities.response_semantics`:

   ```json
   "response_semantics": {
     "data_path": "$.results",
     "properties": { "title": "$.outageId", "subtitle": "$.municipality" },
     "static_template": { "file": "adaptiveCards/getOutageStatus.json" }
   }
   ```

   `data_path` points at the `results` array of the API envelope, so each outage is one card. The file reference for `static_template` is new in v2.4 (DA-08); the path is relative to the plugin manifest.
4. `dispatchCrew.capabilities.confirmation`: an `AdaptiveCard` confirmation with title `Dispatch a field crew`. `security_info.data_handling`: `ResourceStateUpdate`. The two GET functions use `GetPrivateData`.
5. `runtimes`: one `OpenApi` runtime, `spec.url` `apiSpecificationFile/openapi.yaml`, `run_for_functions` all three, and:

   ```json
   "auth": { "type": "ApiKeyPluginVault", "reference_id": "${{APIKEYAUTH_REGISTRATION_ID}}" }
   ```

6. Replace `appPackage/apiSpecificationFile/openapi.yaml` with the solution copy. Its only change from `data/api/openapi-apikey.yaml` is `servers.url: ${{OPENAPI_SERVER_URL}}/api`.

### Part E: Environment files and provision (30 min)

1. Edit `env/.env.dev` (template in the solution):

   ```text
   OPENAPI_SERVER_URL=https://<your tunnel host>
   SP_HR_POLICIES_URL=https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies
   SP_PROCEDURES_URL=https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Procedures
   ```

2. Create `env/.env.dev.user` from `env/.env.dev.user.sample` and set `SECRET_API_KEY=<your API key>`. This file must never be committed.
3. Compare your `m365agents.yml` provision steps with the solution [`m365agents.yml`](../../solutions/lab-06/hle-outage-desk/m365agents.yml). Keep your toolkit's `version` line.
4. **Accounts** pane: sign in with the learner account. Confirm **Custom App Upload Enabled** and **Copilot Access Enabled**. If either is missing, go to break-it C-06-d.
5. **Lifecycle** > **Provision**. When it finishes, `env/.env.dev` has `TEAMS_APP_ID` and `APIKEYAUTH_REGISTRATION_ID` values.
6. Optional: open Teams Developer Portal (https://dev.teams.microsoft.com/tools) > **Tools** > **API key registration** and find the registration the toolkit created. Its **Base URL** must match your OpenAPI `servers` URL.

### Part F: Test in Microsoft 365 Copilot (30 min)

1. Open https://microsoft365.com/chat, select **HLE Outage Desk dev** from the agents list.
2. Type `-developer on` to turn on developer mode, so each answer shows which functions and knowledge were used.
3. Run:

   ```text
   What is the status of outage OUT-2026-0412?
   ```

   Expected: `getOutageStatus` called with `outageId`; an Adaptive Card titled `OUT-2026-0412: Kingston, Ontario`, status Crew On Site, 3,214 customers, ETR 2026-09-30 14:30 EDT, crew CREW-ON-03, feeder KGN-44-F7. Select **Always allow** or **Allow once** if prompted.
4. Run:

   ```text
   Is Jane Okafor at postal code K7L 3N6 affected by an outage, and when will power be back?
   ```

   Expected: `lookupCustomer` returns HLE-ACC-104233 with `currentOutageId` OUT-2026-0412, then `getOutageStatus`; answer: yes, ETR 2:30 PM EDT on September 30, 2026.
5. Run:

   ```text
   Dispatch crew CREW-NY-04 to outage OUT-2026-0433 with High priority.
   ```

   Expected: a confirmation card; after you confirm, dispatch ID `DSP-YYYYMMDD-NNNN`, Brianna Holt, 35 minutes.
6. Run:

   ```text
   What customer count makes an outage Severity Level 2?
   ```

   Expected: 500 to 4,999 customers (or any critical facility out, any feeder breaker lockout, or ETR over 4 hours), citing `Outage-Response-Procedure.docx`.
7. Run:

   ```text
   Get all active outages and chart customers affected by region.
   ```

   Expected: `getOutageStatus` with `pageSize` 50 (24 active outages), then Code Interpreter: ON 15,891, NY 5,137, OH 18,393.

### Part G: Optional Entra OAuth variant (45 min)

Follow [`solutions/lab-06/hle-outage-desk/variants/README.md`](../../solutions/lab-06/hle-outage-desk/variants/README.md): register the API and client apps in Entra ID, add the redirect URI `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect`, switch the API to `AUTH_MODE=entra`, switch the plugin to `OAuthPluginVault` with `oauth/register`, provision, and confirm that a dispatch now records your user principal name in `createdBy`.

### Part H: Break it (60 min)

Work through [break-it.md](break-it.md).

### Part I: Validate

Run [validate.md](validate.md) with `evals/lab-06-questions.csv`.

## Caveats this lab triggers

| Caveat ID | Name | Where in break-it.md |
|---|---|---|
| C-06-a | Manifest schema version | [C-06-a](break-it.md#c-06-a-manifest-schema-version) |
| C-06-b | OpenAPI constraints (broken spec) | [C-06-b](break-it.md#c-06-b-openapi-constraints-broken-spec) |
| C-06-c | Plugin response limits (items, tokens, timeout) | [C-06-c](break-it.md#c-06-c-plugin-response-limits-items-tokens-timeout) |
| C-06-d | Sideloading (custom app upload) policy | [C-06-d](break-it.md#c-06-d-sideloading-custom-app-upload-policy) |
| C-06-e | Capability scoping by URL | [C-06-e](break-it.md#c-06-e-capability-scoping-by-url) |
| C-06-f | API key in custom header vs bearer | [C-06-f](break-it.md#c-06-f-api-key-in-custom-header-vs-bearer) |

## What later labs reuse

- Lab 7 attaches the Copilot connector `hleTickets` ("HLE Tickets") to **HLE Outage Desk** by adding `variants/lab07-graphconnectors-capability.json` to `capabilities` and provisioning again. Keep the project folder and `env/.env.dev`.
- Labs 8 and 10 reuse the API and dev tunnel.
