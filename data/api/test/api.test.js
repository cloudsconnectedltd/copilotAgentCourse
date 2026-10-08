// Exercises the handlers directly, without the Azure Functions host.
// Run: npm test   (uses the built-in node:test runner, Node 20+)

import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { generateKeyPair, SignJWT } from 'jose';
import { parse } from 'yaml';
import { outageStatus, crewDispatch, customerLookup, customerExport, MAX_DELAY_MS } from '../src/lib/handlers.js';
import { authorize } from '../src/lib/auth.js';

const NONE = { env: { AUTH_MODE: 'none' } };

function req({ query = {}, headers = {}, body } = {}) {
  return {
    query: new URLSearchParams(query),
    headers: new Headers(headers),
    json: async () => {
      if (typeof body === 'string') return JSON.parse(body);
      if (body === undefined) throw new SyntaxError('Unexpected end of JSON input');
      return body;
    },
  };
}

describe('GET /api/outage-status', () => {
  test('planted Kingston outage by ID', async () => {
    const res = await outageStatus(req({ query: { outageId: 'out-2026-0412' } }), {}, NONE);
    assert.equal(res.status, 200);
    const o = res.jsonBody.results[0];
    assert.equal(o.outageId, 'OUT-2026-0412');
    assert.equal(o.municipality, 'Kingston');
    assert.equal(o.customersAffected, 3214);
    assert.equal(o.estimatedRestorationTime, '2026-09-30T14:30:00-04:00');
    assert.equal(o.assignedCrewId, 'CREW-ON-03');
  });

  test('region by municipality name', async () => {
    const res = await outageStatus(req({ query: { region: 'kingston' } }), {}, NONE);
    assert.equal(res.jsonBody.totalMatches, 1);
  });

  test('default page is 10, largest first, restored excluded', async () => {
    const res = await outageStatus(req(), {}, NONE);
    assert.equal(res.jsonBody.returnedCount, 10);
    assert.equal(res.jsonBody.results[0].outageId, 'OUT-2026-0427');
    assert.ok(res.jsonBody.results.every((o) => o.status !== 'Restored'));
    assert.ok(res.jsonBody.totalMatches > 10);
  });

  test('includeRestored and region code', async () => {
    const res = await outageStatus(req({ query: { region: 'ON', includeRestored: 'true', pageSize: '50' } }), {}, NONE);
    assert.equal(res.jsonBody.totalMatches, 17);
    assert.ok(res.jsonBody.results.every((o) => o.region === 'ON'));
  });

  test('unknown outage is 404, malformed is 400, bad pageSize is 400', async () => {
    assert.equal((await outageStatus(req({ query: { outageId: 'OUT-2026-9999' } }), {}, NONE)).status, 404);
    assert.equal((await outageStatus(req({ query: { outageId: '412' } }), {}, NONE)).status, 400);
    assert.equal((await outageStatus(req({ query: { pageSize: '0' } }), {}, NONE)).status, 400);
  });

  test('unknown region returns empty result with guidance', async () => {
    const res = await outageStatus(req({ query: { region: 'Texas' } }), {}, NONE);
    assert.equal(res.status, 200);
    assert.equal(res.jsonBody.returnedCount, 0);
  });

  test('delayMs is applied and capped at 180000', async () => {
    let slept = null;
    const opts = { ...NONE, sleep: async (ms) => { slept = ms; } };
    let res = await outageStatus(req({ query: { delayMs: '120000' } }), {}, opts);
    assert.equal(slept, 120000);
    assert.equal(res.headers['X-HLE-Delay-Applied-Ms'], '120000');
    res = await outageStatus(req({ query: { delayMs: '999999' } }), {}, opts);
    assert.equal(slept, MAX_DELAY_MS);
    assert.equal(MAX_DELAY_MS, 180000);
  });
});

describe('POST /api/crew-dispatch', () => {
  test('valid dispatch returns 201 and dispatchId', async () => {
    const res = await crewDispatch(req({ body: { outageId: 'OUT-2026-0433', crewId: 'CREW-NY-04', priority: 'high', notes: 'Sparking at pole' } }), {},
      { ...NONE, now: () => new Date('2026-09-30T14:00:00Z') });
    assert.equal(res.status, 201);
    assert.match(res.jsonBody.dispatchId, /^DSP-20260930-\d{4}$/);
    assert.equal(res.jsonBody.priority, 'High');
    assert.equal(res.jsonBody.estimatedArrivalMinutes, 35);
    assert.equal(res.jsonBody.crewLead, 'Brianna Holt');
  });

  test('validation errors are 400 with errorCode', async () => {
    const cases = [
      [{ crewId: 'CREW-NY-04', priority: 'High' }, 'MISSING_FIELD'],
      [{ outageId: 'OUT-2026-0433', crewId: 'CREW-NY-04', priority: 'Urgent' }, 'INVALID_FIELD'],
      [{ outageId: 'OUT-2026-0433', crewId: 'CREW-ON-01', priority: 'High' }, 'CREW_REGION_MISMATCH'],
      [{ outageId: 'OUT-2026-0412', crewId: 'CREW-ON-07', priority: 'High' }, 'CREW_OFF_SHIFT'],
      [{ outageId: 'OUT-2026-0499', crewId: 'CREW-ON-01', priority: 'High' }, 'UNKNOWN_OUTAGE'],
      [{ outageId: 'OUT-2026-0433', crewId: 'CREW-NY-09', priority: 'High' }, 'UNKNOWN_CREW'],
      [{ outageId: 'OUT-2026-0433', priority: 'High', assignment: { crewId: 'CREW-NY-04' } }, 'NESTED_VALUE_NOT_SUPPORTED'],
      [['OUT-2026-0433'], 'INVALID_JSON'],
    ];
    for (const [body, code] of cases) {
      const res = await crewDispatch(req({ body }), {}, NONE);
      assert.equal(res.status, 400, code);
      assert.equal(res.jsonBody.errorCode, code);
    }
    const bad = await crewDispatch(req({ body: '{not json' }), {}, NONE);
    assert.equal(bad.jsonBody.errorCode, 'INVALID_JSON');
  });

  test('restored outage is 409', async () => {
    const res = await crewDispatch(req({ body: { outageId: 'OUT-2026-0405', crewId: 'CREW-ON-01', priority: 'Normal' } }), {}, NONE);
    assert.equal(res.status, 409);
    assert.equal(res.jsonBody.errorCode, 'OUTAGE_ALREADY_RESTORED');
  });
});

describe('GET /api/customer-lookup', () => {
  test('planted account', async () => {
    const res = await customerLookup(req({ query: { accountNumber: 'HLE-ACC-104233' } }), {}, NONE);
    const c = res.jsonBody.results[0];
    assert.equal(`${c.firstName} ${c.lastName}`, 'Jane Okafor');
    assert.equal(c.postalCode, 'K7L 3N6');
    assert.equal(c.currentOutageId, 'OUT-2026-0412');
  });

  test('last name alone matches two Okafors; postal code disambiguates', async () => {
    let res = await customerLookup(req({ query: { lastName: 'okafor' } }), {}, NONE);
    assert.equal(res.jsonBody.totalMatches, 2);
    res = await customerLookup(req({ query: { lastName: 'Okafor', postalCode: 'k7l3n6' } }), {}, NONE);
    assert.equal(res.jsonBody.totalMatches, 1);
    assert.equal(res.jsonBody.results[0].accountNumber, 'HLE-ACC-104233');
  });

  test('pageSize defaults to 5 and 200 returns an oversized response', async () => {
    let res = await customerLookup(req(), {}, NONE);
    assert.equal(res.jsonBody.returnedCount, 5);
    assert.equal(res.jsonBody.totalMatches, 300);
    res = await customerLookup(req({ query: { pageSize: '200' } }), {}, NONE);
    assert.equal(res.jsonBody.returnedCount, 200);
    assert.ok(JSON.stringify(res.jsonBody).length > 50000);
  });

  test('invalid account number is 400', async () => {
    const res = await customerLookup(req({ query: { accountNumber: 'ACC-1' } }), {}, NONE);
    assert.equal(res.status, 400);
  });

  test('legacy /customers export is unbounded', async () => {
    const res = await customerExport(req(), {}, NONE);
    assert.ok(Array.isArray(res.jsonBody));
    assert.equal(res.jsonBody.length, 300);
  });
});

describe('auth modes', () => {
  const apikeyEnv = { env: { AUTH_MODE: 'apikey', API_KEY: 'secret-123' } };

  test('apikey: header, bearer, missing, wrong', async () => {
    assert.equal(await authorize(req({ headers: { 'X-API-Key': 'secret-123' } }), apikeyEnv), null);
    assert.equal(await authorize(req({ headers: { Authorization: 'Bearer secret-123' } }), apikeyEnv), null);
    assert.equal((await authorize(req(), apikeyEnv)).status, 401);
    assert.equal((await authorize(req({ headers: { 'X-API-Key': 'nope' } }), apikeyEnv)).status, 401);
    const res = await outageStatus(req(), {}, apikeyEnv);
    assert.equal(res.status, 401);
    assert.equal(res.jsonBody.errorCode, 'UNAUTHORIZED');
  });

  test('invalid AUTH_MODE is a 500 misconfiguration', async () => {
    assert.equal((await authorize(req(), { env: { AUTH_MODE: 'basic' } })).status, 500);
  });

  test('entra: validates issuer, audience, scope with a local key', async () => {
    const tenant = '11111111-2222-3333-4444-555555555555';
    const { publicKey, privateKey } = await generateKeyPair('RS256');
    const env = { AUTH_MODE: 'entra', ENTRA_TENANT_ID: tenant, ENTRA_AUDIENCE: 'api://hle-api, abc', ENTRA_REQUIRED_SCOPE: 'Outages.ReadWrite' };
    const opts = { env, keyResolver: async () => publicKey };
    const sign = (claims, iss = `https://login.microsoftonline.com/${tenant}/v2.0`, aud = 'api://hle-api') =>
      new SignJWT(claims).setProtectedHeader({ alg: 'RS256' }).setIssuer(iss).setAudience(aud)
        .setIssuedAt().setExpirationTime('10m').sign(privateKey);

    const good = await sign({ scp: 'Outages.ReadWrite', preferred_username: 'avery.chen@harbourline.example' });
    const r = req({ headers: { Authorization: `Bearer ${good}` } });
    assert.equal(await authorize(r, opts), null);
    assert.equal(r.hleUser.upn, 'avery.chen@harbourline.example');

    const v1 = await sign({ scp: 'Outages.ReadWrite' }, `https://sts.windows.net/${tenant}/`, 'abc');
    assert.equal(await authorize(req({ headers: { Authorization: `Bearer ${v1}` } }), opts), null);

    const wrongAud = await sign({ scp: 'Outages.ReadWrite' }, undefined, 'api://other');
    assert.equal((await authorize(req({ headers: { Authorization: `Bearer ${wrongAud}` } }), opts)).status, 401);

    const wrongIss = await sign({ scp: 'Outages.ReadWrite' }, 'https://login.microsoftonline.com/other/v2.0');
    assert.equal((await authorize(req({ headers: { Authorization: `Bearer ${wrongIss}` } }), opts)).status, 401);

    const noScope = await sign({ scp: 'User.Read' });
    assert.equal((await authorize(req({ headers: { Authorization: `Bearer ${noScope}` } }), opts)).status, 403);

    assert.equal((await authorize(req(), opts)).status, 401);
  });
});

describe('OpenAPI documents', () => {
  const load = (f) => parse(readFileSync(new URL(`../${f}`, import.meta.url), 'utf8'));
  const ops = (doc) => Object.entries(doc.paths).flatMap(([p, item]) =>
    Object.entries(item).filter(([m]) => ['get', 'post', 'put', 'patch', 'delete'].includes(m)).map(([m, op]) => ({ p, m, op })));
  const hasPoly = (node) => JSON.stringify(node).match(/"(oneOf|anyOf|allOf)"/);

  for (const f of ['openapi.yaml', 'openapi-apikey.yaml', 'openapi-oauth.yaml']) {
    test(`${f} is compliant`, () => {
      const doc = load(f);
      assert.equal(doc.openapi, '3.0.3');
      assert.ok(doc.info.description);
      for (const { p, m, op } of ops(doc)) {
        assert.ok(op.operationId, `${m} ${p} needs operationId`);
        assert.ok(op.description, `${m} ${p} needs description`);
      }
      assert.equal(hasPoly(doc), null);
      for (const [name, prop] of Object.entries(doc.components.schemas.DispatchRequest.properties)) {
        assert.ok(!['object', 'array'].includes(prop.type) && !prop.$ref, `DispatchRequest.${name} must be flat`);
      }
      assert.deepEqual(ops(doc).map((o) => o.op.operationId).sort(), ['dispatchCrew', 'getOutageStatus', 'lookupCustomer']);
    });
  }

  test('openapi-broken.yaml contains each planted defect', () => {
    const doc = load('openapi-broken.yaml');
    assert.equal(doc.paths['/outage-status'].get.operationId, undefined);
    const body = doc.components.schemas.DispatchRequest.properties;
    assert.ok(body.assignment.oneOf);
    assert.equal(body.siteContact.type, 'object');
    const list = doc.paths['/customers'].get;
    assert.equal(list.responses['200'].content['application/json'].schema.type, 'array');
    assert.ok(!list.parameters.some((p) => p.name === 'pageSize'));
  });
});

describe('real @azure/functions request and response objects', () => {
  test('handlers accept HttpRequest and produce a valid HttpResponse', async () => {
    const { default: af } = await import('@azure/functions');
    const get = new af.HttpRequest({ method: 'GET', url: 'http://localhost:7071/api/outage-status?region=Toledo' });
    const res = await outageStatus(get, {}, NONE);
    assert.equal(res.jsonBody.results[0].outageId, 'OUT-2026-0427');
    const post = new af.HttpRequest({
      method: 'POST',
      url: 'http://localhost:7071/api/crew-dispatch',
      headers: { 'content-type': 'application/json' },
      body: { string: JSON.stringify({ outageId: 'OUT-2026-0419', crewId: 'CREW-NY-02', priority: 'Normal' }) },
    });
    const http = new af.HttpResponse(await crewDispatch(post, {}, NONE));
    assert.equal(http.status, 201);
    assert.match(http.headers.get('content-type'), /application\/json/);
  });
});
