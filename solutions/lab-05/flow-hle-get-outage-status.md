# Flow definition: HLE Get Outage Status

| | |
|---|---|
| Type | Agent flow (instant cloud flow, solution-aware) |
| Environment / solution | HLE-Dev / **HLEHarbourlineOps** |
| Called by | **HLE Field Ops Assistant** (tool), and in Lab 10 through **HLE Front Door** |
| Connection references | **HLE Outage API** (custom connector) |
| Must respond within | 100 seconds (CS-A02) |

This is a description of the finished flow, not an exported package. Build it in the designer as described in the Lab 5 README Part B. UI labels may differ from what is written here; check Learn.

## Trigger: When an agent calls a flow

| # | Input type | Name | Description (the agent reads this) | Required |
|---|---|---|---|---|
| 1 | Text | `region` | Region code (ON, NY, OH), region name, or town such as Kingston. Leave empty for all regions. | No |
| 2 | Text | `outageId` | Outage ID in the form OUT-2026-0412. | No |
| 3 | Number | `delayMs` | Training only. Milliseconds of artificial delay. Use 0 unless the user asks for a delay test. | No |

## Action 1: Get outage status

Connector **HLE Outage API**, operation **getOutageStatus** ("Get current power outages and estimated restoration times"). Rename the action to `Get outage status`, so the internal name is `Get_outage_status`.

| Parameter | Value |
|---|---|
| Region or town | `region` (trigger) |
| Outage ID | `outageId` (trigger) |
| Page size | `10` |
| Delay (ms, training only) | `delayMs` (trigger); advanced parameter |
| Include restored | leave empty (API default false) |

If the connector returns a non-2xx status (400, 401, 404), the action fails. The next action is configured to run anyway, so the agent still receives the error code.

## Action 2: Respond to the agent

**Configure run after** on `Get outage status`: **is successful**, **has failed**.

| Output type | Name | Expression |
|---|---|---|
| Number | `statusCode` | `outputs('Get_outage_status')?['statusCode']` |
| Text | `summary` | `coalesce(body('Get_outage_status')?['message'], '')` |
| Number | `totalMatches` | `coalesce(body('Get_outage_status')?['totalMatches'], 0)` |
| Text | `outagesJson` | `string(coalesce(body('Get_outage_status')?['results'], json('[]')))` |
| Text | `errorCode` | `coalesce(body('Get_outage_status')?['errorCode'], '')` |

`outagesJson` is a JSON string with at most 10 outages. The agent reads it and picks the fields the user asked for.

## Expected outputs for test inputs

| Input | statusCode | summary / errorCode |
|---|---|---|
| `outageId = OUT-2026-0412` | 200 | `Outage OUT-2026-0412 in Kingston, ON: Crew On Site.` |
| `region = OH` | 200 | totalMatches 5 |
| `region = Brockville` | 200 | totalMatches 3 |
| `outageId = OUT-2026-0499` | 404 | `OUTAGE_NOT_FOUND` |
| `region = ON`, `delayMs = 120000` | none within 100 s | agent receives no response in time (C-05-b) |

## Variant for C-05-b fix (respond early)

Move **Respond to the agent** above `Get outage status`, remove its run-after settings, and set `summary` to `Outage status request accepted. Ask again in a few minutes.` Remove the other outputs. The flow keeps running after it responds. Use this only to demonstrate the pattern; restore the original order afterwards.
