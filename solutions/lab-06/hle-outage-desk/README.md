# HLE Outage Desk (Microsoft 365 Agents Toolkit project)

Declarative agent for Microsoft 365 Copilot built in [Lab 6](../../../labs/lab-06-declarative-agents-toolkit/README.md). It calls the Harbourline mock API (`data/api`) through an API plugin with API key authentication, and grounds on two SharePoint libraries.

## Layout

| Path | What it is | Verified against |
|---|---|---|
| `appPackage/manifest.json` | Microsoft 365 app manifest (Teams app manifest), schema v1.24, with `copilotAgents.declarativeAgents` pointing at `declarativeAgent.json`. | Learn "Manage environments and versions for declarative agents" (uses v1.24 with `copilotAgents`). The Teams docs also show v1.27 for agent connectors; use the version your toolkit generates if it is newer. |
| `appPackage/declarativeAgent.json` | Declarative agent manifest, schema v1.8 (DA-01). Capabilities: `OneDriveAndSharePoint` scoped with `items_by_url` to HR-Policies and Procedures, `WebSearch` limited to 3 sites (DA-05 allows 4), `CodeInterpreter`. One action (the plugin). | `declarative-agent-manifest-1.8.md` |
| `appPackage/ai-plugin.json` | API plugin manifest, schema v2.4 (DA-08). Functions `getOutageStatus`, `dispatchCrew`, `lookupCustomer`; `response_semantics` with `data_path`, `properties` and a file-based `static_template`; runtime auth `ApiKeyPluginVault`. | `plugin-manifest-2.4.md` |
| `appPackage/adaptiveCards/getOutageStatus.json` | Adaptive Card (1.5) used as the static template for outage results. No `Action.OpenUrl` (not supported in response semantics, known issues). | `api-plugin-adaptive-cards.md`, `known-issues.md` |
| `appPackage/apiSpecificationFile/openapi.yaml` | Copy of `data/api/openapi-apikey.yaml` with `servers.url` = `${{OPENAPI_SERVER_URL}}/api`. | `data/api` tests |
| `appPackage/color.png`, `outline.png` | App icons, 192 x 192 color and 32 x 32 transparent outline. | |
| `m365agents.yml` | Agents Toolkit project file: provision steps including `apiKey/register`. The toolkit file name is `m365agents.yml` (older Teams Toolkit projects used `teamsapp.yml`). | Learn "Provision cloud resources" (teamsApp actions); `typespec-authentication.md` (apiKey/register, oauth/register). `version` line and `teamsApp/extendToM365` UNVERIFIED. |
| `env/.env.dev` | Non-secret environment values: tunnel URL, SharePoint library URLs, IDs written by provision. | `declarative-agents-multi-environment.md`, `plugin-debug-local.md` |
| `env/.env.dev.user.sample` | Template for secrets (`SECRET_API_KEY`). Copy to `env/.env.dev.user`. | |
| `variants/` | Bearer scheme (C-06-f), Lab 7 connector capability, Entra OAuth variant with registration steps. | See `variants/README.md` |

## Run it

1. Start the API with `AUTH_MODE=apikey` and a persistent dev tunnel (`data/api/run-local.md`).
2. Fill in `env/.env.dev` (`OPENAPI_SERVER_URL`, `SP_HR_POLICIES_URL`, `SP_PROCEDURES_URL`) and create `env/.env.dev.user` with `SECRET_API_KEY`.
3. Open this folder in VS Code with Microsoft 365 Agents Toolkit. **Accounts**: sign in to Microsoft 365 and confirm **Custom App Upload Enabled** and **Copilot Access Enabled**.
4. **Lifecycle** > **Provision**.
5. Open Microsoft 365 Copilot (https://microsoft365.com/chat), select **HLE Outage Desk dev** in the agents list, and try the conversation starters.

Recommended alternative if the toolkit rejects `m365agents.yml` because its `version` differs: create a fresh project with **Create a New Agent/App** > **Declarative Agent** > **Add an Action** > **Start with an OpenAPI Description Document**, browse to `data/api/openapi-apikey.yaml`, select all three operations, then copy the files in `appPackage/` from this folder over the generated ones and merge the `apiKey/register` step.

## Check JSON

```bash
node -e "for (const f of ['appPackage/manifest.json','appPackage/declarativeAgent.json','appPackage/ai-plugin.json','appPackage/adaptiveCards/getOutageStatus.json']) { JSON.parse(require('fs').readFileSync(f,'utf8')); console.log('ok', f); }"
```
