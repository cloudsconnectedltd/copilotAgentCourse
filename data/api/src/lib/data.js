// Loads the seed data once per process. Data is read-only except for the
// in-memory dispatch log, which resets whenever the function host restarts.

import { readFileSync } from 'node:fs';

const load = (name) => JSON.parse(readFileSync(new URL(`../data/${name}`, import.meta.url), 'utf8'));

export const outages = load('outages.json');
export const crews = load('crews.json');
export const customers = load('customers.json');

export const outageById = new Map(outages.map((o) => [o.outageId, o]));
export const crewById = new Map(crews.map((c) => [c.crewId, c]));

// Accepts region codes, full names and municipality names, case-insensitive.
const REGION_ALIASES = {
  on: 'ON', ontario: 'ON',
  ny: 'NY', 'new york': 'NY', 'new york state': 'NY',
  oh: 'OH', ohio: 'OH',
};

export function matchesRegion(outage, region) {
  const r = region.trim().toLowerCase();
  const code = REGION_ALIASES[r];
  if (code) return outage.region === code;
  return outage.municipality.toLowerCase() === r;
}

export function isKnownRegion(region) {
  const r = region.trim().toLowerCase();
  return Boolean(REGION_ALIASES[r]) || outages.some((o) => o.municipality.toLowerCase() === r);
}

export const dispatchLog = [];
