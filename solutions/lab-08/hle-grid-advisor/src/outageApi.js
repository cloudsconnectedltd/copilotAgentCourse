'use strict';
// Tool: calls the Harbourline mock API (data/api) GET /api/outage-status.
// The agent decides when to call it with simple rules (no Copilot orchestrator, limits.md CE-01).

const OUTAGE_ID_RE = /\bOUT-\d{4}-\d{4}\b/gi;
const REGIONS = [
  [/\bontario\b/i, 'ON'],
  [/\bnew york\b/i, 'NY'],
  [/\bohio\b/i, 'OH'],
];
// Municipalities that appear in the mock API seed data (data/api/src/data/outages.json).
const MUNICIPALITIES = ['Auburn', 'Barrie', 'Belleville', 'Bowling Green', 'Brockville', 'Cobourg', 'Findlay', 'Kingston',
  'Lima', 'Mansfield', 'Napanee', 'Oshawa', 'Peterborough', 'Rochester', 'Syracuse', 'Toledo', 'Utica', 'Watertown'];

const LIVE_WORDS = /\b(outages?|out|etr|crews?|customers?|largest|biggest|active|current|now|today|status)\b/i;

function planCalls(question) {
  const ids = [...new Set((question.match(OUTAGE_ID_RE) || []).map((s) => s.toUpperCase()))].slice(0, 3);
  if (ids.length) return ids.map((outageId) => ({ outageId }));

  const includeRestored = /\b(restored|yesterday|history|historical|all outages)\b/i.test(question);
  const town = MUNICIPALITIES.find((m) => new RegExp(`\\b${m}\\b`, 'i').test(question));
  if (town) return [{ region: town, includeRestored }];
  for (const [re, code] of REGIONS) if (re.test(question)) return LIVE_WORDS.test(question) ? [{ region: code, includeRestored }] : [];
  if (/\boutages?\b/i.test(question) && /\b(largest|biggest|active|current|now|today|how many|list|worst|all)\b/i.test(question)) {
    return [{ includeRestored }];
  }
  return [];
}

function createOutageApi(config, fetchImpl = globalThis.fetch) {
  const baseUrl = (config.apiBaseUrl || '').replace(/\/+$/, '');

  async function call(params) {
    const qs = new URLSearchParams();
    if (params.outageId) qs.set('outageId', params.outageId);
    if (params.region) qs.set('region', params.region);
    if (params.includeRestored) qs.set('includeRestored', 'true');
    const url = `${baseUrl}/outage-status?${qs}`;
    const headers = { Accept: 'application/json' };
    if (config.apiKey) headers['X-API-Key'] = config.apiKey;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.apiTimeoutMs || 10000);
    try {
      const res = await fetchImpl(url, { headers, signal: controller.signal });
      const body = await res.json().catch(() => ({}));
      return { url, ok: res.ok, status: res.status, body };
    } catch (err) {
      return { url, ok: false, status: 0, body: { errorCode: 'API_UNREACHABLE', message: String(err && err.message || err) } };
    } finally {
      clearTimeout(timer);
    }
  }

  async function lookup(question) {
    const plan = planCalls(question);
    const results = [];
    for (const p of plan) results.push(await call(p));
    return results;
  }

  return { lookup, planCalls };
}

module.exports = { createOutageApi, planCalls };
