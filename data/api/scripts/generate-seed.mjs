#!/usr/bin/env node
// Deterministic seed data generator for the Harbourline Energy Co. mock API.
// Re-run with: npm run seed
// Output: src/data/outages.json, src/data/crews.json, src/data/customers.json
// All names, accounts and addresses are fictional. Planted records used by evals
// are defined explicitly below and documented in data/answer-keys/api.md.

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'src', 'data');
mkdirSync(outDir, { recursive: true });

// Mulberry32 PRNG with a fixed seed so every run produces identical files.
function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20260930);
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const int = (min, max) => min + Math.floor(rand() * (max - min + 1));

const REGION_NAMES = { ON: 'Ontario', NY: 'New York', OH: 'Ohio' };

// Municipality, region, postal prefixes (Canadian FSA or US ZIP), streets.
const PLACES = [
  { m: 'Kingston', r: 'ON', codes: ['K7L', 'K7M', 'K7K', 'K7P'], feeder: 'KGN' },
  { m: 'Belleville', r: 'ON', codes: ['K8N', 'K8P'], feeder: 'BLV' },
  { m: 'Peterborough', r: 'ON', codes: ['K9H', 'K9J', 'K9K'], feeder: 'PTB' },
  { m: 'Cobourg', r: 'ON', codes: ['K9A'], feeder: 'CBG' },
  { m: 'Brockville', r: 'ON', codes: ['K6V'], feeder: 'BRK' },
  { m: 'Napanee', r: 'ON', codes: ['K7R'], feeder: 'NPN' },
  { m: 'Oshawa', r: 'ON', codes: ['L1G', 'L1H', 'L1J'], feeder: 'OSH' },
  { m: 'Barrie', r: 'ON', codes: ['L4M', 'L4N'], feeder: 'BAR' },
  { m: 'Syracuse', r: 'NY', codes: ['13202', '13203', '13204', '13206', '13208', '13210'], feeder: 'SYR' },
  { m: 'Rochester', r: 'NY', codes: ['14604', '14607', '14609', '14613', '14620'], feeder: 'ROC' },
  { m: 'Watertown', r: 'NY', codes: ['13601'], feeder: 'WAT' },
  { m: 'Oswego', r: 'NY', codes: ['13126'], feeder: 'OSW' },
  { m: 'Utica', r: 'NY', codes: ['13501', '13502'], feeder: 'UTC' },
  { m: 'Auburn', r: 'NY', codes: ['13021'], feeder: 'AUB' },
  { m: 'Toledo', r: 'OH', codes: ['43604', '43607', '43609', '43612', '43615'], feeder: 'TOL' },
  { m: 'Sandusky', r: 'OH', codes: ['44870'], feeder: 'SAN' },
  { m: 'Findlay', r: 'OH', codes: ['45840'], feeder: 'FIN' },
  { m: 'Lima', r: 'OH', codes: ['45801', '45804', '45805'], feeder: 'LIM' },
  { m: 'Mansfield', r: 'OH', codes: ['44902', '44903', '44906', '44907'], feeder: 'MAN' },
  { m: 'Bowling Green', r: 'OH', codes: ['43402'], feeder: 'BGR' },
];
const placeByName = Object.fromEntries(PLACES.map((p) => [p.m, p]));

const STREETS = ['Princess Street', 'Johnson Street', 'Bath Road', 'Division Street', 'King Street',
  'Queen Street', 'Maple Avenue', 'Elm Street', 'Lakeview Drive', 'Cedar Lane', 'Front Street',
  'Water Street', 'Park Avenue', 'Church Street', 'Oak Ridge Road', 'Harbour Road', 'Mill Street',
  'Riverside Drive', 'Birch Crescent', 'Victoria Street', 'Wellington Street', 'Main Street',
  'Center Street', 'Highland Avenue', 'Sunset Boulevard', 'Orchard Way', 'Pine Street'];

const FIRST = ['Amara', 'Liam', 'Sofia', 'Noah', 'Priya', 'Ethan', 'Chloe', 'Mateo', 'Aisha', 'Lucas',
  'Hannah', 'Oliver', 'Mei', 'Jacob', 'Fatima', 'Owen', 'Isabelle', 'Diego', 'Nadia', 'Samuel',
  'Grace', 'Arjun', 'Emily', 'Kwame', 'Leah', 'Tomas', 'Zoe', 'Rafael', 'Ingrid', 'Malik',
  'Claire', 'Yusuf', 'Rosa', 'Connor', 'Anika', 'Declan', 'Mira', 'Gabriel', 'Tessa', 'Hiro'];
const LAST = ['Tremblay', 'Gagnon', 'Roy', 'Chen', 'Patel', 'MacDonald', 'Singh', 'Nguyen', 'Kowalski',
  'Fraser', 'Ramirez', 'Johansson', 'Mensah', 'Doyle', 'Haddad', 'Lindqvist', 'Moreau', 'Osei',
  'Brennan', 'Castillo', 'Novak', 'Ferreira', 'Sato', 'Morrison', 'Delgado', 'Kaur', 'Bergeron',
  'Whitfield', 'Adeyemi', 'Larsen', 'Petrov', 'Hughes', 'Abernathy', 'Vasquez', 'Lemieux', 'Park'];

const CAUSES = ['Tree contact during high winds', 'Equipment failure: pole-mounted transformer',
  'Underground cable fault', 'Vehicle collision with utility pole', 'Animal contact at substation',
  'Lightning strike on distribution line', 'Planned maintenance', 'Insulator failure',
  'Crossarm failure', 'Under investigation'];

// ---------------------------------------------------------------- crews
const CREW_LEADS = {
  ON: ['Marcus Bellamy', 'Janelle Fortier', 'Devon Achebe', 'Shauna Leclerc', 'Pieter Van Dyk', 'Rena Kaplan', 'Graham Oduya', 'Colette Aubin'],
  NY: ['Tyrone Castellano', 'Megan Iverson', 'Sal Okonkwo', 'Brianna Holt', 'Wes Kaminski'],
  OH: ['Dale Rutherford', 'Keisha Monroe', 'Evan Szabo', 'Lorena Pruitt', 'Garrett Ames'],
};
const DEPOTS = {
  ON: ['Kingston Service Centre', 'Kingston Service Centre', 'Kingston Service Centre', 'Belleville Depot', 'Peterborough Depot', 'Oshawa Service Centre', 'Barrie Depot', 'Brockville Depot'],
  NY: ['Syracuse Operations Center', 'Syracuse Operations Center', 'Rochester Depot', 'Rochester Depot', 'Utica Depot'],
  OH: ['Toledo Operations Center', 'Toledo Operations Center', 'Lima Depot', 'Mansfield Depot', 'Findlay Depot'],
};
const SPECIALTIES = ['Overhead lines', 'Underground cable', 'Substation', 'Vegetation management', 'Overhead lines'];
const crews = [];
for (const r of ['ON', 'NY', 'OH']) {
  CREW_LEADS[r].forEach((lead, i) => {
    const n = String(i + 1).padStart(2, '0');
    crews.push({
      crewId: `CREW-${r}-${n}`,
      region: r,
      regionName: REGION_NAMES[r],
      crewLead: lead,
      crewSize: int(3, 6),
      baseDepot: DEPOTS[r][i],
      specialty: SPECIALTIES[i % SPECIALTIES.length],
      status: 'Available',
    });
  });
}
const crewById = Object.fromEntries(crews.map((c) => [c.crewId, c]));
// Planted crew facts.
Object.assign(crewById['CREW-ON-03'], { crewLead: 'Devon Achebe', crewSize: 5, specialty: 'Overhead lines', baseDepot: 'Kingston Service Centre' });
Object.assign(crewById['CREW-ON-07'], { status: 'Off Shift' });
Object.assign(crewById['CREW-NY-04'], { status: 'Available', crewLead: 'Brianna Holt', crewSize: 4, specialty: 'Underground cable' });
Object.assign(crewById['CREW-OH-01'], { crewLead: 'Dale Rutherford', crewSize: 6, specialty: 'Substation' });

// ---------------------------------------------------------------- outages
// Timestamps are Eastern Daylight Time (UTC-04:00); course "today" is 2026-09-30.
function ts(day, hh, mm) {
  return `2026-09-${String(day).padStart(2, '0')}T${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00-04:00`;
}
function addMinutes(iso, minutes) {
  const d = new Date(new Date(iso).getTime() + minutes * 60000 - 4 * 3600000);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}T${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:00-04:00`;
}

const planted = {
  'OUT-2026-0405': { municipality: 'Belleville', status: 'Restored', cause: 'Animal contact at substation', customersAffected: 642, startTime: ts(29, 15, 5), estimatedRestorationTime: ts(29, 19, 30), restoredTime: ts(29, 19, 20), assignedCrewId: 'CREW-ON-04', feederId: 'BLV-27-F2' },
  'OUT-2026-0412': { municipality: 'Kingston', status: 'Crew On Site', cause: 'Tree contact on 44 kV feeder during high winds', customersAffected: 3214, startTime: ts(30, 6, 42), estimatedRestorationTime: ts(30, 14, 30), restoredTime: null, assignedCrewId: 'CREW-ON-03', feederId: 'KGN-44-F7' },
  'OUT-2026-0419': { municipality: 'Syracuse', status: 'Crew Assigned', cause: 'Underground cable fault', customersAffected: 1087, startTime: ts(30, 4, 15), estimatedRestorationTime: ts(30, 12, 0), restoredTime: null, assignedCrewId: 'CREW-NY-02', feederId: 'SYR-13-F4' },
  'OUT-2026-0427': { municipality: 'Toledo', status: 'Crew On Site', cause: 'Substation transformer failure at Maumee Bay substation', customersAffected: 12480, startTime: ts(29, 22, 5), estimatedRestorationTime: '2026-10-01T18:00:00-04:00', restoredTime: null, assignedCrewId: 'CREW-OH-01', feederId: 'TOL-69-F1' },
  'OUT-2026-0433': { municipality: 'Rochester', status: 'Reported', cause: 'Under investigation', customersAffected: 58, startTime: ts(30, 9, 50), estimatedRestorationTime: null, restoredTime: null, assignedCrewId: null, feederId: 'ROC-13-F9' },
};

const outages = [];
const busyCrews = new Set(Object.values(planted).filter((p) => p.status !== 'Restored' && p.assignedCrewId).map((p) => p.assignedCrewId));
for (let n = 400; n < 440; n++) {
  const outageId = `OUT-2026-${String(n).padStart(4, '0')}`;
  let o;
  if (planted[outageId]) {
    o = { ...planted[outageId] };
  } else {
    // Keep Kingston and Toledo single-outage so planted answers stay unambiguous.
    const choices = PLACES.filter((p) => p.m !== 'Kingston' && p.m !== 'Toledo');
    const place = pick(choices);
    const status = pick(['Restored', 'Restored', 'Restored', 'Crew On Site', 'Crew Assigned', 'Reported']);
    const day = status === 'Restored' ? pick([28, 29, 29, 30]) : pick([29, 30, 30]);
    const startTime = ts(day, int(0, day === 30 ? (status === 'Restored' ? 3 : 9) : 23), int(0, 11) * 5);
    const cause = pick(CAUSES);
    const customersAffected = cause === 'Planned maintenance' ? int(20, 180) : int(12, 2400);
    // Restored outages lasted 2 to 6 hours. Active outages carry an ETR later today (after the 10:00 snapshot).
    const etrMinutes = int(4, 12) * 30;
    const activeEtr = ts(30, int(11, 21), pick([0, 30]));
    let assignedCrewId = null;
    if (status !== 'Reported') {
      const regionalCrews = crews.filter((c) => c.region === place.r && c.crewId !== 'CREW-ON-07' && c.crewId !== 'CREW-NY-04');
      const free = regionalCrews.filter((c) => !busyCrews.has(c.crewId));
      const crew = status === 'Restored' ? pick(regionalCrews) : (free.length ? pick(free) : pick(regionalCrews));
      assignedCrewId = crew.crewId;
      if (status !== 'Restored') busyCrews.add(crew.crewId);
    }
    o = {
      municipality: place.m,
      status,
      cause,
      customersAffected,
      startTime,
      estimatedRestorationTime: status === 'Reported' ? null : (status === 'Restored' ? addMinutes(startTime, etrMinutes) : activeEtr),
      restoredTime: status === 'Restored' ? addMinutes(startTime, etrMinutes - int(0, 3) * 15) : null,
      assignedCrewId,
      feederId: `${place.feeder}-${pick(['13', '27', '44'])}-F${int(1, 9)}`,
    };
  }
  const place = placeByName[o.municipality];
  outages.push({
    outageId,
    region: place.r,
    regionName: REGION_NAMES[place.r],
    municipality: o.municipality,
    status: o.status,
    cause: o.cause,
    customersAffected: o.customersAffected,
    startTime: o.startTime,
    estimatedRestorationTime: o.estimatedRestorationTime,
    restoredTime: o.restoredTime,
    assignedCrewId: o.assignedCrewId,
    feederId: o.feederId,
    lastUpdated: o.status === 'Restored' ? o.restoredTime : ts(30, 10, 0),
  });
}
for (const c of crews) {
  if (busyCrews.has(c.crewId) && c.status === 'Available') c.status = 'Assigned';
}

// ---------------------------------------------------------------- customers
function onPostal(fsa) {
  const L = 'ABCEGHJKLMNPRSTVWXYZ';
  return `${fsa} ${int(1, 9)}${L[int(0, L.length - 1)]}${int(1, 9)}`;
}
const activeByMunicipality = {};
for (const o of outages) {
  if (o.status !== 'Restored') (activeByMunicipality[o.municipality] ||= []).push(o.outageId);
}

const plantedCustomers = [
  { accountNumber: 'HLE-ACC-104233', firstName: 'Jane', lastName: 'Okafor', businessName: null, serviceAddress: '118 Collingwood Crescent', municipality: 'Kingston', postalCode: 'K7L 3N6', accountType: 'Residential', rateClass: 'Residential Time-of-Use', accountStatus: 'Active', currentBalance: 142.87, lastPaymentDate: '2026-09-12', paperlessBilling: true, medicalPriority: false, currentOutageId: 'OUT-2026-0412' },
  { accountNumber: 'HLE-ACC-131870', firstName: 'Daniel', lastName: 'Okafor', businessName: null, serviceAddress: '77 Westcott Street', municipality: 'Syracuse', postalCode: '13210', accountType: 'Residential', rateClass: 'Residential Standard (SC-1)', accountStatus: 'Active', currentBalance: 0, lastPaymentDate: '2026-09-22', paperlessBilling: false, medicalPriority: false, currentOutageId: null },
  { accountNumber: 'HLE-ACC-117502', firstName: 'Marguerite', lastName: 'Tremblay', businessName: null, serviceAddress: '9 Sydenham Street', municipality: 'Kingston', postalCode: 'K7L 2V4', accountType: 'Residential', rateClass: 'Residential Time-of-Use', accountStatus: 'Active', currentBalance: 61.4, lastPaymentDate: '2026-09-05', paperlessBilling: false, medicalPriority: true, currentOutageId: 'OUT-2026-0412' },
  { accountNumber: 'HLE-ACC-150019', firstName: 'Ruth', lastName: 'Castellanos', businessName: 'Lakeshore Cold Storage Ltd.', serviceAddress: '2200 Front Street', municipality: 'Toledo', postalCode: '43605', accountType: 'Commercial', rateClass: 'General Service Secondary (GS-2)', accountStatus: 'Active', currentBalance: 18432.1, lastPaymentDate: '2026-09-01', paperlessBilling: true, medicalPriority: false, currentOutageId: 'OUT-2026-0427' },
  { accountNumber: 'HLE-ACC-162944', firstName: 'Victor', lastName: 'Albescu', businessName: null, serviceAddress: '415 Lyell Avenue', municipality: 'Rochester', postalCode: '14606', accountType: 'Residential', rateClass: 'Residential Standard (SC-1)', accountStatus: 'Disconnection Pending', currentBalance: 986.55, lastPaymentDate: '2026-05-18', paperlessBilling: false, medicalPriority: false, currentOutageId: 'OUT-2026-0433' },
];
const usedAccounts = new Set(plantedCustomers.map((c) => c.accountNumber));
const plantedLastNames = new Set(['Okafor', 'Albescu', 'Castellanos']);

const customers = [];
while (customers.length + plantedCustomers.length < 300) {
  let acct;
  do { acct = `HLE-ACC-${int(100000, 199999)}`; } while (usedAccounts.has(acct));
  usedAccounts.add(acct);
  const place = rand() < 0.45 ? pick(PLACES.filter((p) => p.r === 'ON')) : pick(PLACES);
  const commercial = rand() < 0.12;
  const firstName = pick(FIRST);
  const lastName = pick(LAST.filter((l) => !plantedLastNames.has(l)));
  const code = pick(place.codes);
  const active = activeByMunicipality[place.m];
  customers.push({
    accountNumber: acct,
    firstName,
    lastName,
    businessName: commercial ? `${lastName} ${pick(['Hardware', 'Dental Clinic', 'Bakery', 'Auto Service', 'Printing', 'Farms'])}` : null,
    serviceAddress: `${int(1, 2400)} ${pick(STREETS)}`,
    municipality: place.m,
    postalCode: place.r === 'ON' ? onPostal(code) : code,
    accountType: commercial ? 'Commercial' : 'Residential',
    rateClass: commercial
      ? (place.r === 'ON' ? 'General Service < 50 kW' : 'General Service Secondary (GS-2)')
      : (place.r === 'ON' ? pick(['Residential Time-of-Use', 'Residential Tiered', 'Residential Ultra-Low Overnight']) : 'Residential Standard (SC-1)'),
    accountStatus: rand() < 0.94 ? 'Active' : pick(['Final Bill Issued', 'Disconnection Pending']),
    currentBalance: Math.round(rand() * (commercial ? 6000 : 450) * 100) / 100,
    lastPaymentDate: `2026-${pick(['08', '09', '09', '09'])}-${String(int(1, 28)).padStart(2, '0')}`,
    paperlessBilling: rand() < 0.55,
    medicalPriority: !commercial && rand() < 0.04,
    currentOutageId: active && place.m !== 'Kingston' && place.m !== 'Toledo' && rand() < 0.25 ? pick(active) : null,
  });
}
const allCustomers = [...plantedCustomers, ...customers].map((c) => {
  const place = placeByName[c.municipality];
  return { ...c, region: place.r, regionName: REGION_NAMES[place.r] };
});
allCustomers.sort((a, b) => a.accountNumber.localeCompare(b.accountNumber));

const write = (name, data) => writeFileSync(join(outDir, name), JSON.stringify(data, null, 2) + '\n');
write('outages.json', outages);
write('crews.json', crews);
write('customers.json', allCustomers);
console.log(`Wrote ${outages.length} outages, ${crews.length} crews, ${allCustomers.length} customers to ${outDir}`);
