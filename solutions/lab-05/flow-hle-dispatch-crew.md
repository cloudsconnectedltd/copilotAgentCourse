# Flow definition: HLE Dispatch Crew

| | |
|---|---|
| Type | Agent flow (instant cloud flow, solution-aware) |
| Environment / solution | HLE-Dev / **HLEHarbourlineOps** |
| Called by | **HLE Field Ops Assistant** (tool) |
| Connection references | **HLE Outage API** (custom connector), **Microsoft Dataverse** |
| Must respond within | 100 seconds (CS-A02) |

This is a description of the finished flow, not an exported package. Build it as described in the Lab 5 README Part C. UI labels may differ; check Learn.

The flow deliberately uses two connectors (Dataverse and the custom connector), so a data policy that puts them in different data groups suspends it (break-it C-05-d).

## Trigger: When an agent calls a flow

| # | Input type | Name | Description (the agent reads this) | Required |
|---|---|---|---|---|
| 1 | Text | `outageId` | Active outage to send the crew to, for example OUT-2026-0433. | Yes |
| 2 | Text | `crewId` | Crew code, for example CREW-NY-04. Must be in the same region as the outage. | Yes |
| 3 | Text | `priority` | One of Low, Normal, High, Emergency. | Yes |
| 4 | Text | `notes` | Optional instructions for the crew, up to 500 characters. | No |

## Action 1: Find crew (Microsoft Dataverse, List rows)

| Setting | Value |
|---|---|
| Table name | Crews (`hle_crew`) |
| Select columns | `hle_crewcode,hle_crewname,hle_crewlead,hle_certifications` |
| Filter rows | `hle_crewcode eq '<crewId token>'` |
| Row count | `1` |

The Dataverse crew codes CREW-ON-01 to 08, CREW-NY-01 to 05 and CREW-OH-01 to 05 match the API crews (`data/dataverse/schema.md` section 3.2). The API is still the authority for shift status and region rules.

## Action 2: Dispatch crew (HLE Outage API, dispatchCrew)

| Field | Value |
|---|---|
| Outage ID | `outageId` (trigger) |
| Crew ID | `crewId` (trigger) |
| Priority | `priority` (trigger) |
| Notes | `notes` (trigger) |

Rename the action to `Dispatch crew`. Non-2xx responses (400, 401, 409) make the action fail; the next action runs anyway.

## Action 3: Respond to the agent

**Configure run after** on `Dispatch crew`: **is successful**, **has failed**.

| Output type | Name | Expression |
|---|---|---|
| Number | `statusCode` | `outputs('Dispatch_crew')?['statusCode']` |
| Text | `dispatchId` | `coalesce(body('Dispatch_crew')?['dispatchId'], '')` |
| Text | `message` | `coalesce(body('Dispatch_crew')?['message'], '')` |
| Number | `estimatedArrivalMinutes` | `coalesce(body('Dispatch_crew')?['estimatedArrivalMinutes'], 0)` |
| Text | `errorCode` | `coalesce(body('Dispatch_crew')?['errorCode'], '')` |
| Text | `crewName` | `coalesce(first(outputs('Find_crew')?['body/value'])?['hle_crewname'], '')` |
| Text | `createdBy` | `coalesce(body('Dispatch_crew')?['createdBy'], '')` |

## Expected outputs for test inputs

| Inputs | statusCode | errorCode / message |
|---|---|---|
| OUT-2026-0433, CREW-NY-04, High | 201 | dispatchId `DSP-YYYYMMDD-NNNN`, message names Brianna Holt, estimatedArrivalMinutes 35, createdBy `anonymous` (API key mode) |
| OUT-2026-0412, CREW-ON-07, Emergency | 400 | `CREW_OFF_SHIFT` |
| OUT-2026-0433, CREW-ON-01, High | 400 | `CREW_REGION_MISMATCH` |
| OUT-2026-0405, CREW-ON-04, Normal | 409 | `OUTAGE_ALREADY_RESTORED` (restored 2026-09-29 19:20) |

Estimated arrival by priority (fixed in the mock API): Emergency 20, High 35, Normal 60, Low 120 minutes.
