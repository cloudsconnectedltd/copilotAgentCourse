# Answer key: mock REST API (`data/api/`)

For eval authors. All data is fictional (Harbourline Energy Co.). Seed data is deterministic: `npm run seed` (script `data/api/scripts/generate-seed.mjs`, fixed seed 20260930) always regenerates identical files. If the generator changes, re-verify every number below.

Snapshot time for the data: 2026-09-30 10:00 EDT. All timestamps are Eastern Daylight Time (UTC-04:00).

## Files

| Path | Summary |
|---|---|
| `data/api/src/data/outages.json` | 40 outages, IDs OUT-2026-0400 to OUT-2026-0439, in Ontario, New York and Ohio. |
| `data/api/src/data/crews.json` | 18 crews: CREW-ON-01 to 08, CREW-NY-01 to 05, CREW-OH-01 to 05. |
| `data/api/src/data/customers.json` | 300 customer accounts, HLE-ACC-xxxxxx, sorted by account number. |
| `data/api/src/lib/handlers.js` | Endpoint logic, validation rules, error codes. |
| `data/api/src/lib/auth.js` | AUTH_MODE none / apikey / entra. |
| `data/api/openapi.yaml`, `openapi-apikey.yaml`, `openapi-oauth.yaml` | Compliant OpenAPI 3.0.3 (operationIds `getOutageStatus`, `dispatchCrew`, `lookupCustomer`). |
| `data/api/openapi-broken.yaml`, `openapi-broken-NOTES.md` | Deliberately broken spec, 4 defects. |
| `data/api/run-local.md`, `data/api/deploy-azure.ps1` | Local run and Azure deployment. |

## Planted records (primary eval targets)

### Outages

| Fact | Value | Where |
|---|---|---|
| OUT-2026-0412 location | Kingston, Ontario (region ON) | `outages.json`, `GET /api/outage-status?outageId=OUT-2026-0412` |
| OUT-2026-0412 customers affected | 3,214 | same |
| OUT-2026-0412 status | Crew On Site | same |
| OUT-2026-0412 cause | Tree contact on 44 kV feeder during high winds | same |
| OUT-2026-0412 start | 2026-09-30 06:42 EDT | same |
| OUT-2026-0412 ETR | 2026-09-30 14:30 EDT (2:30 PM) | `estimatedRestorationTime` |
| OUT-2026-0412 crew | CREW-ON-03, crew lead Devon Achebe, 5 people, Kingston Service Centre | `assignedCrewId`; `crews.json` |
| OUT-2026-0412 feeder | KGN-44-F7 | `feederId` |
| Kingston | Only one outage in Kingston (OUT-2026-0412). `?region=Kingston` returns exactly 1. | |
| OUT-2026-0427 | Toledo, Ohio. Largest outage: 12,480 customers. Cause: Substation transformer failure at Maumee Bay substation. Started 2026-09-29 22:05. ETR 2026-10-01 18:00 (next day). Crew CREW-OH-01 (Dale Rutherford, 6, Substation). Feeder TOL-69-F1. Only Toledo outage. | |
| OUT-2026-0419 | Syracuse, NY. 1,087 customers. Underground cable fault. Crew Assigned, CREW-NY-02 (Megan Iverson). Start 04:15, ETR 12:00 on 2026-09-30. Only Syracuse outage. | |
| OUT-2026-0405 | Belleville, ON. RESTORED at 2026-09-29 19:20 (ETR had been 19:30). 642 customers. Animal contact at substation. Crew CREW-ON-04. Dispatching to it returns 409 OUTAGE_ALREADY_RESTORED. | |
| OUT-2026-0433 | Rochester, NY. Reported, 58 customers, cause Under investigation, no crew, no ETR (null). Started 09:50. Intended target for the dispatch lab with CREW-NY-04. | |

### Crews

| Fact | Value |
|---|---|
| CREW-NY-04 | Brianna Holt, 4 people, Rochester Depot, Underground cable, Available. Dispatch lab crew. |
| CREW-ON-07 | Graham Oduya, Barrie Depot. Off Shift. Dispatching it returns 400 CREW_OFF_SHIFT. |
| Available crews | CREW-ON-08, CREW-NY-04 only. All others Assigned except CREW-ON-07 (Off Shift). |

Full crew table:

| crewId | crewLead | crewSize | baseDepot | specialty | status |
|---|---|---|---|---|---|
| CREW-ON-01 | Marcus Bellamy | 5 | Kingston Service Centre | Overhead lines | Assigned |
| CREW-ON-02 | Janelle Fortier | 6 | Kingston Service Centre | Underground cable | Assigned |
| CREW-ON-03 | Devon Achebe | 5 | Kingston Service Centre | Overhead lines | Assigned |
| CREW-ON-04 | Shauna Leclerc | 6 | Belleville Depot | Vegetation management | Assigned |
| CREW-ON-05 | Pieter Van Dyk | 3 | Peterborough Depot | Overhead lines | Assigned |
| CREW-ON-06 | Rena Kaplan | 6 | Oshawa Service Centre | Overhead lines | Assigned |
| CREW-ON-07 | Graham Oduya | 6 | Barrie Depot | Underground cable | Off Shift |
| CREW-ON-08 | Colette Aubin | 3 | Brockville Depot | Substation | Available |
| CREW-NY-01 | Tyrone Castellano | 4 | Syracuse Operations Center | Overhead lines | Assigned |
| CREW-NY-02 | Megan Iverson | 6 | Syracuse Operations Center | Underground cable | Assigned |
| CREW-NY-03 | Sal Okonkwo | 5 | Rochester Depot | Substation | Assigned |
| CREW-NY-04 | Brianna Holt | 4 | Rochester Depot | Underground cable | Available |
| CREW-NY-05 | Wes Kaminski | 6 | Utica Depot | Overhead lines | Assigned |
| CREW-OH-01 | Dale Rutherford | 6 | Toledo Operations Center | Substation | Assigned |
| CREW-OH-02 | Keisha Monroe | 3 | Toledo Operations Center | Underground cable | Assigned |
| CREW-OH-03 | Evan Szabo | 5 | Lima Depot | Substation | Assigned |
| CREW-OH-04 | Lorena Pruitt | 6 | Mansfield Depot | Vegetation management | Assigned |
| CREW-OH-05 | Garrett Ames | 5 | Findlay Depot | Overhead lines | Assigned |

Crew status is static seed data. A dispatch does not change a crew's status.

### Customers

| Account | Name | Details | Tests |
|---|---|---|---|
| HLE-ACC-104233 | Jane Okafor | 118 Collingwood Crescent, Kingston ON, K7L 3N6. Residential, Residential Time-of-Use, Active, balance 142.87 (CAD), last payment 2026-09-12, paperless yes, medical priority no, currentOutageId OUT-2026-0412. | Account lookup; join customer to outage ("Is Jane Okafor affected by an outage, and when will power be back?" answer: yes, OUT-2026-0412, ETR 14:30). |
| HLE-ACC-131870 | Daniel Okafor | 77 Westcott Street, Syracuse NY, 13210. Residential Standard (SC-1), Active, balance 0, last payment 2026-09-22, no current outage. | Disambiguation: `lastName=Okafor` returns 2 accounts; adding postal code K7L 3N6 returns only Jane. |
| HLE-ACC-117502 | Marguerite Tremblay | 9 Sydenham Street, Kingston ON, K7L 2V4. Medical priority YES. Balance 61.40. currentOutageId OUT-2026-0412. | Medical priority customer inside the Kingston outage. Only two accounts reference OUT-2026-0412: HLE-ACC-104233 and HLE-ACC-117502. |
| HLE-ACC-150019 | Ruth Castellanos (Lakeshore Cold Storage Ltd.) | 2200 Front Street, Toledo OH, 43605. Commercial, General Service Secondary (GS-2), balance 18,432.10 (USD), last payment 2026-09-01, currentOutageId OUT-2026-0427. | Commercial account; largest balance planted. |
| HLE-ACC-162944 | Victor Albescu | 415 Lyell Avenue, Rochester NY, 14606. Disconnection Pending, balance 986.55, last payment 2026-05-18, currentOutageId OUT-2026-0433. | Account status question; address used in the dispatch notes example. |

Currency convention (stated in the OpenAPI `currentBalance` description): CAD for Ontario, USD for New York and Ohio.

## Aggregate facts

| Fact | Value |
|---|---|
| Outages total | 40 (ON 17, NY 14, OH 9) |
| By status | Restored 16, Crew Assigned 9, Reported 8, Crew On Site 7 |
| Active (not Restored) outages | 24, affecting 39,421 customers |
| Active by region | ON 11 outages / 15,891 customers; NY 8 / 5,137; OH 5 / 18,393 |
| Default `GET /api/outage-status` | Returns 10 of 24 active outages (`totalMatches` 24), largest first: OUT-2026-0427 (12,480), OUT-2026-0412 (3,214), OUT-2026-0420 (2,352), OUT-2026-0421 (2,308), OUT-2026-0431 (2,298), OUT-2026-0438 (1,938), OUT-2026-0435 (1,754), OUT-2026-0413 (1,733), OUT-2026-0429 (1,717), OUT-2026-0414 (1,659) |
| `?region=ON&includeRestored=true&pageSize=50` | 17 outages |
| Customers total | 300 (ON 199, NY 54, OH 47) |
| Commercial accounts | 41 |
| Medical priority accounts | 13 |
| Accounts with a currentOutageId | 67 |
| Account status | Active 287, Disconnection Pending 8, Final Bill Issued 5 |
| `lastName=Tremblay` | 11 matches, default page returns 5 (paging demo) |
| Kingston customer accounts | 18 (8 with postal prefix K7L) |
| Default `GET /api/customer-lookup` (no filter) | `totalMatches` 300, returns 5 |
| `GET /api/customer-lookup?pageSize=200` | returns 200 accounts (oversized response demo, DA-07) |
| `GET /api/customers` | bare array of all 300 accounts (broken spec only) |

## All outages

Times are month-day and HH:MM EDT (2026). "null" means no value.

| outageId | region | municipality | status | customers | start | ETR | restored | crew | feeder |
|---|---|---|---|---|---|---|---|---|---|
| OUT-2026-0400 | ON | Napanee | Restored | 862 | 09-29T21:25 | 09-29T23:55 | 09-29T23:55 | CREW-ON-03 | NPN-27-F4 |
| OUT-2026-0401 | OH | Lima | Restored | 2,288 | 09-30T01:40 | 09-30T06:10 | 09-30T06:10 | CREW-OH-03 | LIM-44-F9 |
| OUT-2026-0402 | OH | Mansfield | Restored | 742 | 09-29T00:15 | 09-29T02:15 | 09-29T02:00 | CREW-OH-02 | MAN-27-F9 |
| OUT-2026-0403 | OH | Bowling Green | Restored | 748 | 09-29T00:25 | 09-29T04:55 | 09-29T04:40 | CREW-OH-05 | BGR-27-F5 |
| OUT-2026-0404 | NY | Auburn | Crew On Site | 101 | 09-30T04:40 | 09-30T12:30 | null | CREW-NY-03 | AUB-27-F9 |
| OUT-2026-0405 | ON | Belleville | Restored | 642 | 09-29T15:05 | 09-29T19:30 | 09-29T19:20 | CREW-ON-04 | BLV-27-F2 |
| OUT-2026-0406 | NY | Watertown | Restored | 2,342 | 09-29T06:40 | 09-29T08:40 | 09-29T08:25 | CREW-NY-01 | WAT-13-F5 |
| OUT-2026-0407 | NY | Rochester | Restored | 66 | 09-29T18:55 | 09-29T23:55 | 09-29T23:10 | CREW-NY-03 | ROC-13-F8 |
| OUT-2026-0408 | ON | Cobourg | Reported | 50 | 09-29T14:30 | null | null | null | CBG-13-F3 |
| OUT-2026-0409 | ON | Brockville | Restored | 164 | 09-29T07:55 | 09-29T13:25 | 09-29T12:55 | CREW-ON-03 | BRK-13-F9 |
| OUT-2026-0410 | OH | Findlay | Crew Assigned | 630 | 09-30T09:40 | 09-30T20:00 | null | CREW-OH-03 | FIN-44-F5 |
| OUT-2026-0411 | NY | Utica | Restored | 1,143 | 09-29T02:40 | 09-29T07:10 | 09-29T06:55 | CREW-NY-05 | UTC-44-F1 |
| OUT-2026-0412 | ON | Kingston | Crew On Site | 3,214 | 09-30T06:42 | 09-30T14:30 | null | CREW-ON-03 | KGN-44-F7 |
| OUT-2026-0413 | OH | Mansfield | Crew Assigned | 1,733 | 09-30T00:00 | 09-30T12:00 | null | CREW-OH-04 | MAN-44-F8 |
| OUT-2026-0414 | ON | Oshawa | Crew On Site | 1,659 | 09-29T18:40 | 09-30T21:30 | null | CREW-ON-05 | OSH-44-F4 |
| OUT-2026-0415 | NY | Rochester | Reported | 647 | 09-30T06:10 | null | null | null | ROC-27-F7 |
| OUT-2026-0416 | OH | Findlay | Crew Assigned | 1,242 | 09-30T03:00 | 09-30T11:00 | null | CREW-OH-02 | FIN-44-F9 |
| OUT-2026-0417 | OH | Lima | Restored | 2,199 | 09-29T02:50 | 09-29T06:50 | 09-29T06:05 | CREW-OH-04 | LIM-44-F7 |
| OUT-2026-0418 | ON | Brockville | Restored | 1,577 | 09-29T20:00 | 09-30T02:00 | 09-30T01:15 | CREW-ON-06 | BRK-13-F1 |
| OUT-2026-0419 | NY | Syracuse | Crew Assigned | 1,087 | 09-30T04:15 | 09-30T12:00 | null | CREW-NY-02 | SYR-13-F4 |
| OUT-2026-0420 | ON | Peterborough | Reported | 2,352 | 09-29T02:30 | null | null | null | PTB-27-F2 |
| OUT-2026-0421 | OH | Lima | Crew On Site | 2,308 | 09-30T04:20 | 09-30T20:00 | null | CREW-OH-05 | LIM-44-F5 |
| OUT-2026-0422 | ON | Brockville | Restored | 332 | 09-28T11:20 | 09-28T16:20 | 09-28T16:20 | CREW-ON-03 | BRK-13-F8 |
| OUT-2026-0423 | NY | Rochester | Restored | 2,360 | 09-29T05:20 | 09-29T10:20 | 09-29T10:05 | CREW-NY-01 | ROC-27-F8 |
| OUT-2026-0424 | NY | Auburn | Restored | 163 | 09-29T20:35 | 09-29T22:35 | 09-29T22:05 | CREW-NY-01 | AUB-13-F2 |
| OUT-2026-0425 | ON | Napanee | Crew Assigned | 405 | 09-30T01:25 | 09-30T14:30 | null | CREW-ON-02 | NPN-44-F1 |
| OUT-2026-0426 | ON | Brockville | Crew On Site | 777 | 09-30T02:10 | 09-30T19:30 | null | CREW-ON-06 | BRK-13-F7 |
| OUT-2026-0427 | OH | Toledo | Crew On Site | 12,480 | 09-29T22:05 | 10-01T18:00 | null | CREW-OH-01 | TOL-69-F1 |
| OUT-2026-0428 | NY | Rochester | Restored | 2,232 | 09-29T13:30 | 09-29T16:30 | 09-29T16:15 | CREW-NY-03 | ROC-27-F5 |
| OUT-2026-0429 | ON | Barrie | Reported | 1,717 | 09-30T09:05 | null | null | null | BAR-13-F1 |
| OUT-2026-0430 | ON | Belleville | Reported | 1,307 | 09-30T05:45 | null | null | null | BLV-13-F1 |
| OUT-2026-0431 | NY | Watertown | Crew On Site | 2,298 | 09-30T03:15 | 09-30T20:00 | null | CREW-NY-01 | WAT-13-F9 |
| OUT-2026-0432 | ON | Brockville | Crew Assigned | 718 | 09-30T05:15 | 09-30T13:30 | null | CREW-ON-01 | BRK-27-F3 |
| OUT-2026-0433 | NY | Rochester | Reported | 58 | 09-30T09:50 | null | null | null | ROC-13-F9 |
| OUT-2026-0434 | ON | Oshawa | Restored | 423 | 09-29T11:20 | 09-29T13:50 | 09-29T13:50 | CREW-ON-03 | OSH-27-F4 |
| OUT-2026-0435 | ON | Brockville | Crew Assigned | 1,754 | 09-29T23:35 | 09-30T20:00 | null | CREW-ON-04 | BRK-27-F2 |
| OUT-2026-0436 | NY | Utica | Crew Assigned | 126 | 09-30T07:00 | 09-30T18:30 | null | CREW-NY-05 | UTC-44-F3 |
| OUT-2026-0437 | NY | Rochester | Reported | 102 | 09-29T02:55 | null | null | null | ROC-13-F5 |
| OUT-2026-0438 | ON | Peterborough | Reported | 1,938 | 09-29T03:40 | null | null | null | PTB-27-F9 |
| OUT-2026-0439 | NY | Rochester | Crew Assigned | 718 | 09-29T12:20 | 09-30T11:00 | null | CREW-NY-01 | ROC-13-F6 |

## Behaviors and rules an eval can test

| Behavior | Detail | Where |
|---|---|---|
| outage-status defaults | Restored excluded unless `includeRestored=true`; `pageSize` default 10, 1 to 50; sorted by customersAffected descending | `handlers.js` outageStatus |
| outage-status region | Accepts ON/NY/OH, Ontario/New York/Ohio, or municipality name; unknown region returns 200 with 0 results and a message listing the three regions | same |
| outage-status by ID | Case-insensitive; malformed ID 400 INVALID_PARAMETER; unknown ID 404 OUTAGE_NOT_FOUND | same |
| delayMs | Delays the response; capped at 180000 ms; header `X-HLE-Delay-Applied-Ms`. 120000 exceeds the Copilot Studio agent flow 100 s limit (CS-A02); 60000 exceeds the plugin 45 s timeout (DA-07) | same |
| crew-dispatch success | 201, `dispatchId` format DSP-YYYYMMDD-NNNN (sequence resets on host restart), `status` Dispatched, `Location` header | crewDispatch |
| crew-dispatch ETA | Emergency 20 min, High 35, Normal 60, Low 120 | crewDispatch |
| crew-dispatch priority | Low, Normal, High, Emergency (case-insensitive input, normalized output) | crewDispatch |
| crew-dispatch notes | Optional, max 500 characters | crewDispatch |
| crew-dispatch validation order | JSON object, no nested values, outageId present and format, crewId present and format, priority, notes length, outage exists, crew exists, same region, not off shift, outage not restored | crewDispatch |
| crew-dispatch region rule | Crew region must equal outage region: CREW-ON-01 to OUT-2026-0433 returns 400 CREW_REGION_MISMATCH | crewDispatch |
| customer-lookup | accountNumber exact (six digits alone accepted); lastName exact, case-insensitive; postalCode ignores spaces and case, prefix match (K7L); `pageSize` default 5, max 500; `page` default 1 | customerLookup |
| Error body | Flat `{ errorCode, message, field }` | `http.js` |
| AUTH_MODE apikey | Accepts `X-API-Key` header or `Authorization: Bearer <key>`; missing or wrong key 401 | `auth.js` |
| AUTH_MODE entra | Issuer v2 `https://login.microsoftonline.com/<tenant>/v2.0` or v1 `https://sts.windows.net/<tenant>/`; audience in ENTRA_AUDIENCE list; optional ENTRA_REQUIRED_SCOPE else 403 | `auth.js` |
| Invalid AUTH_MODE | 500 SERVER_MISCONFIGURED | `auth.js` |

## Deliberate defects (openapi-broken.yaml)

| # | Defect | Location in file | Symptom to look for | limits.md |
|---|---|---|---|---|
| 1 | No `operationId` | `GET /outage-status` | Operation not offered or flagged by Agents Toolkit (observe); agent cannot answer outage questions | DA-13, DA-15 |
| 2 | `oneOf` in POST body | `DispatchRequest.assignment` | Unsupported polymorphic schema; flagged or unusable (observe) | DA-12 |
| 3 | Nested object in POST body | `DispatchRequest.siteContact` (with nested `location`) | Unsupported nested request object; API returns 400 NESTED_VALUE_NOT_SUPPORTED if an object is sent | DA-12 |
| 4 | Unbounded array response | `GET /customers` (`listAllCustomers`), no pageSize, no maxItems | Returns 300 accounts; exceeds 25 items per plugin response and 4,096 tokens (DA-07); byte-size limit undocumented (DA-16) | DA-07, DA-16 |

Also: the broken spec's POST body (`assignment`, `siteContact`) does not match the API contract (`crewId`, `notes`), so a call built from it fails with 400 (NESTED_VALUE_NOT_SUPPORTED or MISSING_FIELD for crewId). Broken spec descriptions are deliberately terse (routing quality contrast, not a limit).

## Source conflicts relevant to this API

- API key location: DA-10 (API key auth page: bearer, custom header or query parameter supported) conflicts with DA-11 (known issues: custom headers, query parameters and cookies not supported). The API accepts both the `X-API-Key` header and `Authorization: Bearer`, so either OpenAPI scheme works against it.
- The Learn page "Debug MCP and API plugins locally" names the Agents Toolkit env variable both `PLUGIN_SERVER_URL` and `OPENAPI_SERVER_URL`. `run-local.md` tells learners to use whichever their generated project references.
