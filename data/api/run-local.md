# Run the Harbourline mock API locally

The mock API serves fictional Harbourline Energy Co. data for Labs 5, 6, 8 and 10. It runs on Azure Functions (Node.js, v4 programming model). You can run it on your own machine and expose it to Microsoft 365 Copilot and Copilot Studio through a dev tunnel, or deploy it to Azure with `deploy-azure.ps1`.

## 1. Prerequisites

| Tool | Notes |
|---|---|
| Node.js 20 or later (22 recommended) | `node --version` |
| Azure Functions Core Tools v4 | `func --version` should print 4.x. Install from the Azure Functions Core Tools page on Microsoft Learn. |
| devtunnel CLI | Only needed when Copilot or Copilot Studio must call your local API. See section 5. |
| PowerShell 7 and Azure CLI | Only needed for `deploy-azure.ps1`. |

## 2. Install and test

```bash
cd data/api
npm install
npm test
```

`npm test` runs `test/api.test.js` with the built-in `node:test` runner. It calls the handlers directly, so it needs no Functions host, no network and no Azure account. It also checks that the compliant OpenAPI files have an `operationId` on every operation and no `oneOf`/`anyOf`/`allOf`, and that `openapi-broken.yaml` still contains its planted defects.

## 3. Configure and start

```bash
cp local.settings.sample.json local.settings.json
func start
```

`local.settings.json` is ignored by git. Settings:

| Setting | Values | Purpose |
|---|---|---|
| `AUTH_MODE` | `none` (default), `apikey`, `entra` | Selects authentication. See section 6. |
| `API_KEY` | any string | Key expected when `AUTH_MODE=apikey`. |
| `ENTRA_TENANT_ID` | tenant GUID | Issuer check when `AUTH_MODE=entra`. |
| `ENTRA_AUDIENCE` | comma-separated list | Accepted token audiences when `AUTH_MODE=entra`. |
| `ENTRA_REQUIRED_SCOPE` | optional, for example `Outages.ReadWrite` | Scope (`scp`) or app role (`roles`) the token must carry. |

The functions only use HTTP triggers. If `func start` asks for a storage connection, set `AzureWebJobsStorage` to `UseDevelopmentStorage=true` and start the Azurite storage emulator.

The host listens on `http://localhost:7071`. All routes are under `/api`:

| Method and route | operationId | Purpose |
|---|---|---|
| `GET /api/outage-status` | `getOutageStatus` | Active outages, largest first. Filters: `region`, `outageId`, `includeRestored`, `pageSize` (default 10, max 50), `delayMs`. |
| `POST /api/crew-dispatch` | `dispatchCrew` | Flat JSON body `{ outageId, crewId, priority, notes }`. Returns `201` with a `dispatchId`. |
| `GET /api/customer-lookup` | `lookupCustomer` | Filters: `accountNumber`, `lastName`, `postalCode`, `pageSize` (default 5, max 500), `page`. |
| `GET /api/customers` | `listAllCustomers` (broken spec only) | Legacy unbounded export used only by `openapi-broken.yaml`. |

Dispatches are kept in memory and reset when the host restarts. Seed data is in `src/data/*.json` and is regenerated with `npm run seed` (deterministic).

## 4. Sample calls

```bash
# Planted outage: Kingston, ON, 3,214 customers, ETR 14:30 EDT
curl "http://localhost:7071/api/outage-status?outageId=OUT-2026-0412"

# Active outages in Ohio, or in one town
curl "http://localhost:7071/api/outage-status?region=OH"
curl "http://localhost:7071/api/outage-status?region=Kingston"

# Include restored outages
curl "http://localhost:7071/api/outage-status?region=ON&includeRestored=true&pageSize=50"

# Dispatch a crew (201)
curl -X POST "http://localhost:7071/api/crew-dispatch" \
  -H "Content-Type: application/json" \
  -d '{"outageId":"OUT-2026-0433","crewId":"CREW-NY-04","priority":"High","notes":"Sparking at pole behind 415 Lyell Avenue"}'

# Validation error (400 CREW_REGION_MISMATCH: Ontario crew sent to a New York outage)
curl -X POST "http://localhost:7071/api/crew-dispatch" \
  -H "Content-Type: application/json" \
  -d '{"outageId":"OUT-2026-0433","crewId":"CREW-ON-01","priority":"High"}'

# Customer lookups
curl "http://localhost:7071/api/customer-lookup?accountNumber=HLE-ACC-104233"
curl "http://localhost:7071/api/customer-lookup?lastName=Okafor"
curl "http://localhost:7071/api/customer-lookup?lastName=Okafor&postalCode=K7L%203N6"
```

PowerShell equivalent: `Invoke-RestMethod "http://localhost:7071/api/outage-status?outageId=OUT-2026-0412"`.

### Caveat demos

| Demo | Call | What it shows |
|---|---|---|
| Copilot Studio agent flow timeout (Lab 5) | `GET /api/outage-status?region=ON&delayMs=120000` | An agent flow must return within 100 seconds (limits.md CS-A02). A 120-second delay exceeds it. |
| API plugin timeout (Lab 6) | `GET /api/outage-status?region=ON&delayMs=60000` | Plugin calls have a 45-second timeout (DA-07). |
| Oversized plugin response (Lab 6) | `GET /api/customer-lookup?pageSize=200` | Returns 200 accounts. A plugin response is limited to 25 items and 4,096 tokens (DA-07). A KB or MB response size limit is not documented (DA-16, UNVERIFIED). |
| Unbounded response (Lab 6 break-it) | `GET /api/customers` | Bare array of all 300 accounts. Described only in `openapi-broken.yaml`. |

`delayMs` is capped at 180000 (3 minutes). The applied delay is returned in the `X-HLE-Delay-Applied-Ms` response header.

## 5. Let Copilot reach your local API (dev tunnel)

Microsoft 365 Copilot and Copilot Studio call your API from the cloud, so `localhost` is not reachable. Microsoft Learn ("Debug MCP and API plugins locally") recommends a reverse proxy such as dev tunnels. If you created the project with Microsoft 365 Agents Toolkit from a new API, the toolkit configures the reverse proxy for you. For this existing API, create a persistent tunnel with the `devtunnel` CLI:

```powershell
devtunnel user login
devtunnel create --allow-anonymous
devtunnel port create --port-number 7071 --protocol http
devtunnel host
```

- `--allow-anonymous` is needed so Copilot can reach the tunnel. It is unrelated to the API's own authentication (`AUTH_MODE`).
- The first time, open the URL labeled **Connect via browser** and select **Continue** to enable the tunnel. The browser then shows an error; that is expected.
- Stop the tunnel with Ctrl+C. A persistent tunnel keeps the same URL when you run `devtunnel host` again, so you do not need to rebuild the app package.

Then put the tunnel URL, with `/api` appended, in the `servers` entry of the OpenAPI file you use:

```yaml
servers:
  - url: <your-dev-tunnel-url>/api
```

With Agents Toolkit you can keep the URL in `env/.env.dev.user` instead of editing the file. The Learn page names this variable both `PLUGIN_SERVER_URL` and `OPENAPI_SERVER_URL` in different places; use whichever name your generated project's OpenAPI file references (`${{...}}`), then run **Provision** in the **Lifecycle** pane.

For Copilot Studio (Lab 5), use the same tunnel URL as the host of the custom connector or HTTP request.

## 6. Authentication modes

Set `AUTH_MODE` in `local.settings.json` (locally) or as an app setting (Azure), then restart the host. Use the matching OpenAPI file.

| AUTH_MODE | OpenAPI file | Plugin manifest auth type (DA-09) | What the API checks |
|---|---|---|---|
| `none` | `openapi.yaml` | `None` | Nothing. |
| `apikey` | `openapi-apikey.yaml` | `ApiKeyPluginVault` | `X-API-Key` header, or `Authorization: Bearer <key>`, equals `API_KEY`. |
| `entra` | `openapi-oauth.yaml` | `OAuthPluginVault` | Bearer JWT signed by Entra ID for `ENTRA_TENANT_ID`, audience in `ENTRA_AUDIENCE`, optional scope. |

```bash
# apikey mode
curl -H "X-API-Key: hle-course-demo-key-change-me" "http://localhost:7071/api/outage-status"
curl -H "Authorization: Bearer hle-course-demo-key-change-me" "http://localhost:7071/api/outage-status"
```

**Why both header and bearer for API keys:** Microsoft Learn sources conflict. The API key authentication page says keys can be sent as a bearer token, a custom header or a query parameter (DA-10). The known issues page says keys in custom headers, query parameters or cookies are not supported (DA-11). The API accepts both forms, so if the header scheme in `openapi-apikey.yaml` fails, switch its `securitySchemes` entry to `type: http`, `scheme: bearer` without changing the API.

**Entra token validation** (`src/lib/auth.js`) uses the `jose` library:

- Signing keys come from `https://login.microsoftonline.com/<ENTRA_TENANT_ID>/discovery/v2.0/keys` and are cached.
- Accepted issuers: `https://login.microsoftonline.com/<ENTRA_TENANT_ID>/v2.0` (v2 tokens) and `https://sts.windows.net/<ENTRA_TENANT_ID>/` (v1 tokens).
- Audience must match one entry in `ENTRA_AUDIENCE`. Include every audience your tokens can carry: the API app's client ID, its `api://` Application ID URI and, if you use Entra SSO, the Application ID URI that the Teams developer portal SSO registration generates.
- If `ENTRA_REQUIRED_SCOPE` is set, the token's `scp` (delegated) or `roles` (application) claim must contain it, otherwise the API returns `403`.
- For the OAuth client registration, add the redirect URI `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect`.

Only the authorization code flow is supported for API plugins, and an endpoint must not combine OAuth or Entra SSO with a separate bearer scheme (DA-12).

## 7. Error format

Every error body is flat, so agents can read it without walking nested objects:

```json
{ "errorCode": "CREW_REGION_MISMATCH", "message": "CREW-ON-01 works in Ontario but OUT-2026-0433 is in New York. Choose a NY crew.", "field": "crewId" }
```

| Status | errorCode values |
|---|---|
| 400 | `INVALID_PARAMETER`, `INVALID_JSON`, `MISSING_FIELD`, `INVALID_FIELD`, `NESTED_VALUE_NOT_SUPPORTED`, `UNKNOWN_OUTAGE`, `UNKNOWN_CREW`, `CREW_REGION_MISMATCH`, `CREW_OFF_SHIFT` |
| 401 | `UNAUTHORIZED` |
| 403 | `FORBIDDEN` (valid Entra token without the required scope) |
| 404 | `OUTAGE_NOT_FOUND` |
| 409 | `OUTAGE_ALREADY_RESTORED` |
| 500 | `SERVER_MISCONFIGURED` (bad or incomplete `AUTH_MODE` settings) |

## 8. Deploy to Azure (optional)

```powershell
./deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral
./deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral -AuthMode apikey
./deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral -Cleanup
```

The script prints the base URL to use as `servers.url`. `-Cleanup` deletes the resource group only if it carries the tag `createdBy=hle-course`, which the script adds when it creates the group. Hosting plan and Node.js version support for Azure Functions change over time: check current support on Microsoft Learn, and use `-HostingPlan Consumption` or `-NodeVersion` if the defaults are rejected.

## Files

| Path | Purpose |
|---|---|
| `src/functions/*.js` | Function registrations (one per route). |
| `src/lib/handlers.js` | Request handling and validation. |
| `src/lib/auth.js` | `AUTH_MODE` handling (none, API key, Entra JWT). |
| `src/lib/data.js`, `src/data/*.json` | Seed data: 40 outages, 18 crews, 300 customer accounts. |
| `scripts/generate-seed.mjs` | Deterministic seed generator (`npm run seed`). |
| `scripts/build-openapi-variants.mjs` | Regenerates `openapi-apikey.yaml` and `openapi-oauth.yaml` from `openapi.yaml` (`npm run openapi`). |
| `openapi.yaml`, `openapi-apikey.yaml`, `openapi-oauth.yaml` | Compliant OpenAPI 3.0.3 descriptions. |
| `openapi-broken.yaml`, `openapi-broken-NOTES.md` | Deliberately broken description and its defect list. |
| `test/api.test.js` | `npm test`. |
