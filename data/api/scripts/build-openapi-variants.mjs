#!/usr/bin/env node
// Regenerates openapi-apikey.yaml and openapi-oauth.yaml from openapi.yaml so the three
// compliant variants always describe identical operations. Run: npm run openapi
// Edit openapi.yaml, then re-run this script. Only the header comment, securitySchemes and
// security differ between variants.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const base = readFileSync(join(root, 'openapi.yaml'), 'utf8');
const idx = base.indexOf('\ninfo:\n');
if (idx < 0) throw new Error('openapi.yaml: could not find the info: section');
const body = base.slice(idx + 1).replace(/\s+$/, '') + '\n';

const apikeyHeader = `openapi: 3.0.3
# GENERATED from openapi.yaml by scripts/build-openapi-variants.mjs. Do not edit by hand.
# Harbourline Energy Co. mock API, compliant variant, AUTH_MODE=apikey.
# Same operations as openapi.yaml. Only securitySchemes and security differ.
# The API accepts the key in the X-API-Key header OR as Authorization: Bearer <key>.
# Microsoft Learn sources conflict on custom-header API keys for API plugins
# (reference/limits.md DA-10 says supported, DA-11 known issues says not supported).
# If Agents Toolkit or Copilot rejects the header scheme, replace the ApiKeyAuth block with:
#     ApiKeyAuth:
#       type: http
#       scheme: bearer
# and provision again. No change to the API is needed.
# Plugin manifest auth type: ApiKeyPluginVault (DA-09).
`;
const apikeyTail = `  securitySchemes:
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key
      description: Harbourline course API key (the API_KEY app setting of the Function App).
security:
  - ApiKeyAuth: []
`;

const oauthHeader = `openapi: 3.0.3
# GENERATED from openapi.yaml by scripts/build-openapi-variants.mjs. Do not edit by hand.
# Harbourline Energy Co. mock API, compliant variant, AUTH_MODE=entra.
# Same operations as openapi.yaml. Only securitySchemes and security differ.
# OAuth 2.0 authorization code flow against Microsoft Entra ID. Authorization code is the only
# OAuth flow supported for API plugins (DA-12); Agents Toolkit enables PKCE by default (DA-09).
# Plugin manifest auth type: OAuthPluginVault.
# Replace before use:
#   REPLACE_WITH_TENANT_ID      your Entra tenant ID (GUID)
#   REPLACE_WITH_API_CLIENT_ID  application (client) ID of the Entra app that protects this API
# Add https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect as a Web redirect URI on the
# app registration used as the OAuth client. Set ENTRA_AUDIENCE on the Function App to every
# audience your tokens carry, for example: api://REPLACE_WITH_API_CLIENT_ID,REPLACE_WITH_API_CLIENT_ID
`;
const oauthTail = `  securitySchemes:
    EntraOAuth:
      type: oauth2
      description: Microsoft Entra ID sign-in (delegated). The user signs in once and Copilot sends the access token as a bearer token.
      flows:
        authorizationCode:
          authorizationUrl: https://login.microsoftonline.com/REPLACE_WITH_TENANT_ID/oauth2/v2.0/authorize
          tokenUrl: https://login.microsoftonline.com/REPLACE_WITH_TENANT_ID/oauth2/v2.0/token
          refreshUrl: https://login.microsoftonline.com/REPLACE_WITH_TENANT_ID/oauth2/v2.0/token
          scopes:
            api://REPLACE_WITH_API_CLIENT_ID/Outages.ReadWrite: Read outages and customer accounts and dispatch crews as the signed-in user.
security:
  - EntraOAuth:
      - api://REPLACE_WITH_API_CLIENT_ID/Outages.ReadWrite
`;

writeFileSync(join(root, 'openapi-apikey.yaml'), apikeyHeader + body + apikeyTail);
writeFileSync(join(root, 'openapi-oauth.yaml'), oauthHeader + body + oauthTail);
console.log('Wrote openapi-apikey.yaml and openapi-oauth.yaml');
