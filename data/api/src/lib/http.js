// Small response helpers shared by all handlers.
// Error bodies are flat: { errorCode, message, field } so that Copilot and
// Copilot Studio can read them without walking nested objects.

export function json(status, body, extraHeaders = {}) {
  return {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...extraHeaders },
    jsonBody: body,
  };
}

export function error(status, errorCode, message, field = null) {
  return json(status, { errorCode, message, field });
}

// Reads a query parameter from an Azure Functions HttpRequest (URLSearchParams)
// or from a plain object used in tests. Returns a trimmed string or null.
export function queryParam(request, name) {
  const q = request.query;
  let value = null;
  if (q && typeof q.get === 'function') value = q.get(name);
  else if (q && Object.prototype.hasOwnProperty.call(q, name)) value = q[name];
  if (value === undefined || value === null) return null;
  value = String(value).trim();
  return value === '' ? null : value;
}

export function headerValue(request, name) {
  const h = request.headers;
  if (!h) return null;
  if (typeof h.get === 'function') return h.get(name);
  const key = Object.keys(h).find((k) => k.toLowerCase() === name.toLowerCase());
  return key ? h[key] : null;
}

// Parses an integer query parameter. Returns { value } or { error }.
export function intParam(request, name, { min, max, defaultValue }) {
  const raw = queryParam(request, name);
  if (raw === null) return { value: defaultValue };
  if (!/^\d+$/.test(raw)) {
    return { error: error(400, 'INVALID_PARAMETER', `${name} must be a whole number between ${min} and ${max}.`, name) };
  }
  const n = Number(raw);
  if (n < min || n > max) {
    return { error: error(400, 'INVALID_PARAMETER', `${name} must be between ${min} and ${max}.`, name) };
  }
  return { value: n };
}

export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
