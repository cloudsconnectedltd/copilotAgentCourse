# Variants for HLE Outage Desk

Files in this folder are not part of the app package. Copy them into place only when a lab step tells you to.

| File | Used for | How |
|---|---|---|
| `openapi.bearer-securityScheme.yaml` | Break-it C-06-f (API key header vs bearer) | Replace the `ApiKeyAuth` block in `appPackage/apiSpecificationFile/openapi.yaml`, then **Provision**. |
| `lab07-graphconnectors-capability.json` | Lab 7 | Add this object to the `capabilities` array of `appPackage/declarativeAgent.json` after the `hleTickets` connection exists, then **Provision**. |
| `openapi.oauth.yaml`, `ai-plugin.oauth.json`, `m365agents.oauth-register.yml` | Optional Entra OAuth variant (below) | Follow the steps below. |

## Lab 7: adding the Copilot connector

JSON has no comments, so the Lab 7 capability is kept here instead of being commented out in the manifest. Do not add a `GraphConnectors` capability without `connections`: if `connections` is omitted, the agent can search every Copilot connector in the organization (declarative agent manifest v1.8, Copilot connectors object).

```json
{
  "name": "GraphConnectors",
  "connections": [
    { "connection_id": "hleTickets" }
  ]
}
```

## Optional: Entra ID OAuth variant (OAuthPluginVault)

Use this when the API must know which user is calling. With `AUTH_MODE=entra`, the API writes the signed-in user principal name into `createdBy` on each dispatch, instead of `anonymous` in API key mode.

Only the OAuth 2.0 authorization code flow is supported for API plugins, and one endpoint must not combine OAuth with another bearer scheme (limits.md DA-12). PKCE is on by default (DA-09).

### 1. Register the API app (resource) in Microsoft Entra ID

1. Entra admin center > **App registrations** > **New registration**. Name `HLE Outage API (course)`. Single tenant. No redirect URI. Register.
2. Record the **Application (client) ID** as `<api-client-id>` and the **Directory (tenant) ID** as `<tenant-id>`.
3. **Expose an API** > set the **Application ID URI** to `api://<api-client-id>`.
4. **Add a scope**: name `Outages.ReadWrite`, who can consent **Admins and users**, admin consent display name `Read outages and dispatch crews as the user`. Save.

### 2. Register the OAuth client used by Copilot

You can use a second app registration (clearer) or the same app. These steps use a second one.

1. **New registration**: name `HLE Outage Desk plugin client (course)`. Single tenant.
2. **Authentication** > **Add a platform** > **Web**. Redirect URI: `https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect`. Without this redirect URI sign-in fails.
3. **Certificates & secrets** > **New client secret**. Record the value once. (To avoid client secrets, Learn describes registering a public client on the single-page application platform and relying on PKCE instead.)
4. **API permissions** > **Add a permission** > **My APIs** > `HLE Outage API (course)` > delegated `Outages.ReadWrite`. Also add Microsoft Graph delegated `offline_access` if you want refresh tokens.
5. **Grant admin consent**. Provisioning does not check that the scope can be consented to; an unconsented scope provisions successfully and fails later with "Need admin approval".
6. Record the client ID as `AAD_APP_CLIENT_ID` and the secret as `SECRET_AAD_APP_CLIENT_SECRET` in `env/.env.dev.user`.

### 3. Switch the API to Entra mode

In `data/api/local.settings.json` (or the Function App settings):

```json
"AUTH_MODE": "entra",
"ENTRA_TENANT_ID": "<tenant-id>",
"ENTRA_AUDIENCE": "api://<api-client-id>,<api-client-id>",
"ENTRA_REQUIRED_SCOPE": "Outages.ReadWrite"
```

Restart `func start`.

### 4. Switch the project files

1. Back up `appPackage/apiSpecificationFile/openapi.yaml`, `appPackage/ai-plugin.json` and `m365agents.yml` to a folder such as `variants/apikey-backup/` (or rely on source control).
2. Copy `variants/openapi.oauth.yaml` over `appPackage/apiSpecificationFile/openapi.yaml`. Replace `REPLACE_WITH_TENANT_ID` and `REPLACE_WITH_API_CLIENT_ID`.
3. Copy `variants/ai-plugin.oauth.json` over `appPackage/ai-plugin.json`. Its runtime auth is `{"type": "OAuthPluginVault", "reference_id": "${{ENTRAOAUTH_CONFIGURATION_ID}}"}`.
4. In `m365agents.yml`, replace the `apiKey/register` step with the content of `variants/m365agents.oauth-register.yml`. Add `ENTRAOAUTH_CONFIGURATION_ID=` to `env/.env.dev`.
5. **Provision**. The toolkit creates the OAuth auth config in the Enterprise token store and writes `ENTRAOAUTH_CONFIGURATION_ID`.

### 5. Manage the registration in the Teams Developer Portal (optional)

Teams Developer Portal (https://dev.teams.microsoft.com/tools) > **Tools** > **OAuth client registration** shows the auth config the toolkit created. Values must match: **Base URL** equals the `servers` URL in the OpenAPI file (your tunnel URL plus `/api`), the authorization and token endpoints are `https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize` and `.../token`, and the scope is `api://<api-client-id>/Outages.ReadWrite`. The `oauth/register` action never rewrites an existing record; use `oauth/update` or the portal to change values, and the portal to delete.

### 6. Test

Ask HLE Outage Desk `Dispatch crew CREW-NY-04 to outage OUT-2026-0433 with Normal priority.` Expect a sign-in prompt the first time, then a dispatch whose `createdBy` is your user principal name. Users can sign out under **Chat settings** > **Agents** in Microsoft 365 Copilot.

### Undo

Restore the three backed-up files (API key variant), set `AUTH_MODE` back to `apikey`, provision again, and delete both app registrations and the OAuth client registration (see Lab 6 cleanup).
