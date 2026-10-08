// Authentication for the Harbourline mock API.
//
// The mode is chosen by the app setting AUTH_MODE:
//   none    No authentication. Use for Lab 5 (Copilot Studio) warm-up and first Lab 6 run.
//   apikey  Shared secret compared with the API_KEY app setting. Accepted in either:
//             - the X-API-Key header (matches openapi-apikey.yaml), or
//             - Authorization: Bearer <key>
//           Both are accepted because Microsoft Learn sources disagree on whether API plugins
//           support API keys in a custom header (limits.md DA-10 versus DA-11). If the custom
//           header variant fails in your tenant, switch the OpenAPI securityScheme to
//           `type: http, scheme: bearer` and this API keeps working unchanged.
//   entra   Microsoft Entra ID access token (JWT) in Authorization: Bearer <token>.
//           Validated with `jose` against the tenant JWKS:
//             issuer   https://login.microsoftonline.com/<ENTRA_TENANT_ID>/v2.0 (v2 tokens)
//                      or https://sts.windows.net/<ENTRA_TENANT_ID>/ (v1 tokens)
//             audience any value in ENTRA_AUDIENCE (comma separated). List every audience
//                      your tokens can carry: the API app's client ID, its api:// URI and,
//                      for Entra SSO plugins, the Application ID URI that the Teams developer
//                      portal SSO registration generates.
//             scope    optional ENTRA_REQUIRED_SCOPE (for example Outages.ReadWrite) must
//                      appear in the token `scp` claim, or in `roles` for app tokens.
//
// A failed check returns 401 with a flat JSON error and a WWW-Authenticate header.

import { timingSafeEqual, createHash } from 'node:crypto';
import { error, headerValue } from './http.js';

const VALID_MODES = ['none', 'apikey', 'entra'];

export function getAuthMode(env = process.env) {
  const mode = String(env.AUTH_MODE || 'none').trim().toLowerCase();
  return VALID_MODES.includes(mode) ? mode : null;
}

function safeEqual(a, b) {
  // Hash first so lengths always match and the comparison is constant time.
  const ha = createHash('sha256').update(String(a)).digest();
  const hb = createHash('sha256').update(String(b)).digest();
  return timingSafeEqual(ha, hb);
}

function bearerToken(request) {
  const h = headerValue(request, 'authorization');
  if (!h) return null;
  const m = /^Bearer\s+(.+)$/i.exec(h.trim());
  return m ? m[1].trim() : null;
}

function unauthorized(message, scheme) {
  const res = error(401, 'UNAUTHORIZED', message);
  res.headers['WWW-Authenticate'] = scheme;
  return res;
}

// Cache of remote JWKS resolvers keyed by tenant ID.
const jwksCache = new Map();

async function defaultKeyResolver(tenantId) {
  if (!jwksCache.has(tenantId)) {
    const { createRemoteJWKSet } = await import('jose');
    jwksCache.set(
      tenantId,
      createRemoteJWKSet(new URL(`https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`))
    );
  }
  return jwksCache.get(tenantId);
}

/**
 * Checks the request against the configured auth mode.
 * @param request Azure Functions HttpRequest (or a test double with headers).
 * @param options.env  settings object, defaults to process.env
 * @param options.keyResolver async (tenantId) => jose key or JWKS function (tests inject a local key)
 * @returns null when the caller is allowed, otherwise an HTTP response object to return.
 */
export async function authorize(request, { env = process.env, keyResolver = defaultKeyResolver } = {}) {
  const mode = getAuthMode(env);
  if (mode === null) {
    return error(500, 'SERVER_MISCONFIGURED', `AUTH_MODE must be one of: ${VALID_MODES.join(', ')}.`);
  }
  if (mode === 'none') return null;

  if (mode === 'apikey') {
    const expected = env.API_KEY;
    if (!expected) return error(500, 'SERVER_MISCONFIGURED', 'AUTH_MODE is apikey but API_KEY is not set.');
    const supplied = headerValue(request, 'x-api-key') || bearerToken(request);
    if (!supplied) return unauthorized('Missing API key. Send it in the X-API-Key header or as Authorization: Bearer <key>.', 'Bearer');
    if (!safeEqual(supplied, expected)) return unauthorized('Invalid API key.', 'Bearer error="invalid_token"');
    return null;
  }

  // entra
  const tenantId = env.ENTRA_TENANT_ID;
  const audiences = String(env.ENTRA_AUDIENCE || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (!tenantId || audiences.length === 0) {
    return error(500, 'SERVER_MISCONFIGURED', 'AUTH_MODE is entra but ENTRA_TENANT_ID or ENTRA_AUDIENCE is not set.');
  }
  const token = bearerToken(request);
  if (!token) return unauthorized('Missing bearer token.', 'Bearer');
  try {
    const { jwtVerify } = await import('jose');
    const key = await keyResolver(tenantId);
    const { payload } = await jwtVerify(token, key, {
      issuer: [`https://login.microsoftonline.com/${tenantId}/v2.0`, `https://sts.windows.net/${tenantId}/`],
      audience: audiences,
      clockTolerance: 60,
    });
    const required = String(env.ENTRA_REQUIRED_SCOPE || '').trim();
    if (required) {
      const scopes = String(payload.scp || '').split(' ');
      const roles = Array.isArray(payload.roles) ? payload.roles : [];
      if (!scopes.includes(required) && !roles.includes(required)) {
        return error(403, 'FORBIDDEN', `Token is valid but lacks the required scope or role: ${required}.`);
      }
    }
    request.hleUser = { oid: payload.oid || null, name: payload.name || null, upn: payload.preferred_username || payload.upn || null };
    return null;
  } catch (e) {
    return unauthorized(`Invalid bearer token: ${e.code || e.message}.`, 'Bearer error="invalid_token"');
  }
}
