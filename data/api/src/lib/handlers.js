// Request handlers. They take an Azure Functions v4 HttpRequest (or a test double with
// `query`, `headers` and `json()`), and return a response init object
// ({ status, headers, jsonBody }). They do not depend on the Functions host, so the
// tests in test/ call them directly.

import { authorize } from './auth.js';
import { error, intParam, json, queryParam, sleep } from './http.js';
import { crewById, customers, dispatchLog, isKnownRegion, matchesRegion, outageById, outages } from './data.js';

export const MAX_DELAY_MS = 180000;
const OUTAGE_ID_RE = /^OUT-\d{4}-\d{4}$/;
const CREW_ID_RE = /^CREW-(ON|NY|OH)-\d{2}$/;
const ACCOUNT_RE = /^HLE-ACC-\d{6}$/;
const PRIORITIES = ['Low', 'Normal', 'High', 'Emergency'];

// ------------------------------------------------------------------ GET /api/outage-status
export async function outageStatus(request, context = {}, options = {}) {
  const denied = await authorize(request, options);
  if (denied) return denied;

  const region = queryParam(request, 'region');
  const outageIdRaw = queryParam(request, 'outageId');
  const includeRestoredRaw = queryParam(request, 'includeRestored');
  const page = intParam(request, 'pageSize', { min: 1, max: 50, defaultValue: 10 });
  if (page.error) return page.error;
  const delay = intParam(request, 'delayMs', { min: 0, max: Number.MAX_SAFE_INTEGER, defaultValue: 0 });
  if (delay.error) return delay.error;

  if (includeRestoredRaw !== null && !['true', 'false'].includes(includeRestoredRaw.toLowerCase())) {
    return error(400, 'INVALID_PARAMETER', 'includeRestored must be true or false.', 'includeRestored');
  }
  const includeRestored = includeRestoredRaw !== null && includeRestoredRaw.toLowerCase() === 'true';

  // delayMs lets instructors demonstrate timeouts: Copilot Studio agent flows (CS-A02)
  // and declarative agent plugin calls (DA-07). It is capped to protect the host.
  const delayApplied = Math.min(delay.value, MAX_DELAY_MS);
  if (delayApplied > 0) {
    context.log?.(`outage-status: delaying response by ${delayApplied} ms (requested ${delay.value}).`);
    await (options.sleep || sleep)(delayApplied);
  }
  const headers = delayApplied > 0 ? { 'X-HLE-Delay-Applied-Ms': String(delayApplied) } : {};

  if (outageIdRaw !== null) {
    const outageId = outageIdRaw.toUpperCase();
    if (!OUTAGE_ID_RE.test(outageId)) {
      return error(400, 'INVALID_PARAMETER', 'outageId must look like OUT-2026-0412.', 'outageId');
    }
    const o = outageById.get(outageId);
    if (!o) return error(404, 'OUTAGE_NOT_FOUND', `No outage with ID ${outageId} exists.`, 'outageId');
    return json(200, envelope([o], 1, page.value, `Outage ${o.outageId} in ${o.municipality}, ${o.region}: ${o.status}.`), headers);
  }

  let matches = outages.filter((o) => includeRestored || o.status !== 'Restored');
  if (region !== null) {
    if (!isKnownRegion(region)) {
      return json(200, envelope([], 0, page.value,
        `No outages found for "${region}". Harbourline Energy Co. serves Ontario (ON), New York (NY) and Ohio (OH).`), headers);
    }
    matches = matches.filter((o) => matchesRegion(o, region));
  }
  // Largest outages first so a truncated page still shows the most important ones.
  matches = [...matches].sort((a, b) => b.customersAffected - a.customersAffected || a.outageId.localeCompare(b.outageId));
  const results = matches.slice(0, page.value);
  const note = matches.length > results.length
    ? `Showing the ${results.length} largest of ${matches.length} matching outages. Narrow by region or outageId for more detail.`
    : `${matches.length} matching outage(s).`;
  return json(200, envelope(results, matches.length, page.value, note), headers);
}

function envelope(results, totalMatches, pageSize, message) {
  return {
    totalMatches,
    returnedCount: results.length,
    pageSize,
    customersAffectedTotal: results.reduce((s, o) => s + o.customersAffected, 0),
    message,
    results,
  };
}

// ------------------------------------------------------------------ POST /api/crew-dispatch
export async function crewDispatch(request, context = {}, options = {}) {
  const denied = await authorize(request, options);
  if (denied) return denied;

  let body;
  try {
    body = await request.json();
  } catch {
    return error(400, 'INVALID_JSON', 'Request body must be a JSON object with outageId, crewId, priority and optional notes.');
  }
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return error(400, 'INVALID_JSON', 'Request body must be a flat JSON object.');
  }
  // Flat body only (limits.md DA-12): reject nested objects and arrays.
  for (const [k, v] of Object.entries(body)) {
    if (v !== null && typeof v === 'object') {
      return error(400, 'NESTED_VALUE_NOT_SUPPORTED', `Field ${k} must be a string, not an object or array.`, k);
    }
  }

  const outageId = typeof body.outageId === 'string' ? body.outageId.trim().toUpperCase() : '';
  const crewId = typeof body.crewId === 'string' ? body.crewId.trim().toUpperCase() : '';
  const priorityRaw = typeof body.priority === 'string' ? body.priority.trim() : '';
  const notes = body.notes === undefined || body.notes === null ? '' : String(body.notes).trim();

  if (!outageId) return error(400, 'MISSING_FIELD', 'outageId is required.', 'outageId');
  if (!OUTAGE_ID_RE.test(outageId)) return error(400, 'INVALID_FIELD', 'outageId must look like OUT-2026-0412.', 'outageId');
  if (!crewId) return error(400, 'MISSING_FIELD', 'crewId is required.', 'crewId');
  if (!CREW_ID_RE.test(crewId)) return error(400, 'INVALID_FIELD', 'crewId must look like CREW-ON-01, CREW-NY-01 or CREW-OH-01.', 'crewId');
  if (!priorityRaw) return error(400, 'MISSING_FIELD', `priority is required. Use one of: ${PRIORITIES.join(', ')}.`, 'priority');
  const priority = PRIORITIES.find((p) => p.toLowerCase() === priorityRaw.toLowerCase());
  if (!priority) return error(400, 'INVALID_FIELD', `priority must be one of: ${PRIORITIES.join(', ')}.`, 'priority');
  if (notes.length > 500) return error(400, 'INVALID_FIELD', 'notes must be 500 characters or fewer.', 'notes');

  const outage = outageById.get(outageId);
  if (!outage) return error(400, 'UNKNOWN_OUTAGE', `No outage with ID ${outageId} exists.`, 'outageId');
  const crew = crewById.get(crewId);
  if (!crew) return error(400, 'UNKNOWN_CREW', `No crew with ID ${crewId} exists.`, 'crewId');
  if (crew.region !== outage.region) {
    return error(400, 'CREW_REGION_MISMATCH', `${crewId} works in ${crew.regionName} but ${outageId} is in ${outage.regionName}. Choose a ${outage.region} crew.`, 'crewId');
  }
  if (crew.status === 'Off Shift') {
    return error(400, 'CREW_OFF_SHIFT', `${crewId} is off shift and cannot be dispatched.`, 'crewId');
  }
  if (outage.status === 'Restored') {
    return error(409, 'OUTAGE_ALREADY_RESTORED', `${outageId} was restored at ${outage.restoredTime}. No dispatch was created.`, 'outageId');
  }

  const seq = dispatchLog.length + 1;
  const now = options.now ? options.now() : new Date();
  const datePart = now.toISOString().slice(0, 10).replace(/-/g, '');
  const dispatchId = `DSP-${datePart}-${String(seq).padStart(4, '0')}`;
  // Deterministic travel estimate so demos and evals are repeatable.
  const etaMinutes = { Emergency: 20, High: 35, Normal: 60, Low: 120 }[priority];
  const record = {
    dispatchId,
    status: 'Dispatched',
    outageId,
    crewId,
    crewLead: crew.crewLead,
    priority,
    notes,
    municipality: outage.municipality,
    region: outage.region,
    estimatedArrivalMinutes: etaMinutes,
    createdAt: now.toISOString(),
    createdBy: request.hleUser?.upn || 'anonymous',
    message: `${crewId} (${crew.crewLead}) dispatched to ${outageId} in ${outage.municipality} with ${priority} priority. Estimated arrival in ${etaMinutes} minutes.`,
  };
  dispatchLog.push(record);
  context.log?.(`crew-dispatch: ${dispatchId} ${crewId} -> ${outageId} (${priority})`);
  return json(201, record, { Location: `/api/crew-dispatch/${dispatchId}` });
}

// ------------------------------------------------------------------ GET /api/customer-lookup
export async function customerLookup(request, context = {}, options = {}) {
  const denied = await authorize(request, options);
  if (denied) return denied;

  const accountNumberRaw = queryParam(request, 'accountNumber');
  const lastName = queryParam(request, 'lastName');
  const postalCodeRaw = queryParam(request, 'postalCode');
  // pageSize defaults to 5. The upper bound is deliberately high (500) so Lab 6 can
  // request 200 records and observe the 25-items-per-plugin-response limit (DA-07).
  const page = intParam(request, 'pageSize', { min: 1, max: 500, defaultValue: 5 });
  if (page.error) return page.error;
  const pageNum = intParam(request, 'page', { min: 1, max: 10000, defaultValue: 1 });
  if (pageNum.error) return pageNum.error;

  let accountNumber = null;
  if (accountNumberRaw !== null) {
    accountNumber = accountNumberRaw.toUpperCase();
    if (/^\d{6}$/.test(accountNumber)) accountNumber = `HLE-ACC-${accountNumber}`;
    if (!ACCOUNT_RE.test(accountNumber)) {
      return error(400, 'INVALID_PARAMETER', 'accountNumber must look like HLE-ACC-104233.', 'accountNumber');
    }
  }
  const norm = (s) => s.replace(/\s+/g, '').toUpperCase();
  const postalCode = postalCodeRaw === null ? null : norm(postalCodeRaw);

  let matches = customers.filter((c) =>
    (accountNumber === null || c.accountNumber === accountNumber) &&
    (lastName === null || c.lastName.toLowerCase() === lastName.toLowerCase()) &&
    (postalCode === null || norm(c.postalCode) === postalCode || norm(c.postalCode).startsWith(postalCode)));

  const start = (pageNum.value - 1) * page.value;
  const results = matches.slice(start, start + page.value);
  let message;
  if (matches.length === 0) message = 'No customer accounts match. Check the account number, last name or postal code.';
  else if (start + results.length < matches.length) message = `Showing ${results.length} of ${matches.length} matching accounts (page ${pageNum.value}). Add lastName or postalCode to narrow the search.`;
  else message = `${matches.length} matching account(s).`;
  return json(200, {
    totalMatches: matches.length,
    returnedCount: results.length,
    page: pageNum.value,
    pageSize: page.value,
    message,
    results,
  });
}

// ------------------------------------------------------------------ GET /api/customers
// Legacy bulk export used ONLY by openapi-broken.yaml to demonstrate an unbounded array
// response (no paging, returns every matching account as a bare JSON array, up to 300).
// The compliant specs do not describe this route.
export async function customerExport(request, context = {}, options = {}) {
  const denied = await authorize(request, options);
  if (denied) return denied;
  const region = queryParam(request, 'region');
  const code = region === null ? null : region.trim().toUpperCase();
  if (code !== null && !['ON', 'NY', 'OH'].includes(code)) {
    return error(400, 'INVALID_PARAMETER', 'region must be ON, NY or OH.', 'region');
  }
  const rows = customers.filter((c) => code === null || c.region === code);
  return json(200, rows);
}
