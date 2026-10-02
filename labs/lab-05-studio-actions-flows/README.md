# Lab 05: Copilot Studio actions: Power Automate flows and connectors

| | |
|---|---|
| Build path | Copilot Studio (classic experience) + Power Automate agent flows + Power Platform custom connector |
| Estimated time | 3.5 hours |
| Prerequisites | [Lab 4](../lab-04-studio-dataverse-topics/README.md) (agent **HLE Field Ops Assistant** in environment **HLE-Dev**); Dataverse seed loaded with `data/dataverse/import-dataverse.ps1` (creates solution **HLEHarbourlineOps**); mock API running with `AUTH_MODE=apikey` and reachable through a dev tunnel ([`data/api/run-local.md`](../../data/api/run-local.md)); setup scripts 00 to 03 ([`setup/README.md`](../../setup/README.md)) |
| Personas used | Learner (maker, owner of HLE-Dev); Marcus Delaney, Field Technician (`tech`, optional, only if HLE Field Ops Assistant is shared with him) |
| Status | PREVIEW: agent flow express mode (CS-A03). Contains UNVERIFIED limits: CS-A04 (asynchronous response status) |
| Limits referenced | [CS-A01, CS-A02, CS-A03, CS-A04, ENV-02, ENV-03](../../reference/limits.md) |

> **Check before you run.** Every Copilot Studio limit in this lab is tagged SNIP in `reference/limits.md`, because the Copilot Studio documentation source is not public. Before you start, confirm on Microsoft Learn:
> - **CS-A02** (agent flow must respond within 100 seconds): https://learn.microsoft.com/en-us/microsoft-copilot-studio/flow-agent
> - **CS-A03** (express mode is PREVIEW, needs the "When an agent calls a flow" trigger, no delay or webhook actions): https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-flow-express-mode
> - **CS-A04** (asynchronous flow response; GA or preview status UNVERIFIED): https://learn.microsoft.com/en-us/microsoft-copilot-studio/flow-asynchronous-response
> - **CS-A01** (10 RPM / 200 RPH generative AI rate on developer environments, which can slow your eval run)
>
> UI labels in Copilot Studio and Power Automate change often. Where this lab names a button or setting that could not be checked against a public source, it says "(label may differ; check Learn)".

> **Additional learners:** the setup scripts listed in Prerequisites are run once by the setup owner. If you are not the setup owner, skip them; the setup owner gives you access with `05-add-learner.ps1` (see [Two or more learners](../../setup/README.md#two-or-more-learners)).

## Objective

Give **HLE Field Ops Assistant** two real actions against the Harbourline mock API:

1. Answer "what is happening with outage X" by calling the API through an agent flow, **HLE Get Outage Status**.
2. Dispatch a field crew to an outage through a second agent flow, **HLE Dispatch Crew**, which also reads the crew record from Dataverse.

Both flows use a solution-aware custom connector, **HLE Outage API**, that authenticates with an API key. You then break the setup four ways: whose credentials the API sees, the 100-second flow limit, flows without connection references, and a data policy (DLP) that blocks the connector.

## Concepts

| Concept | What you need to know for this lab |
|---|---|
| Custom connector | A Power Platform wrapper around a REST API, described by an OpenAPI (Swagger) definition. Each operation becomes an action in flows and a possible tool in Copilot Studio. |
| Connection | A stored credential for a connector. For **HLE Outage API** the connection holds the API key. |
| Connection reference | A solution component that points at a connection. Flows created inside a solution bind to connection references, so the solution can move to another environment and be re-pointed at a different connection. Flows created outside a solution use connections directly and are not upgraded automatically. |
| Agent flow | A Power Automate flow that starts with the trigger **When an agent calls a flow** and returns values with **Respond to the agent**. The agent must receive the response within 100 seconds (CS-A02). |
| Maker credentials vs end-user credentials | A tool can run with the credentials the author (maker) configured, so every chat user acts through the author's connection, or with each end user's own credentials, so each user must create a connection the first time. An agent flow runs with the connections set in the flow by its author. |
| Data policy (DLP) | An admin policy that groups connectors into **Business**, **Non-Business** and **Blocked**. Connectors in different groups cannot be used together in one flow, and Blocked connectors cannot be used at all. Custom connectors can be classified by name in an environment-level policy. |

## Before you start

1. Start the mock API in API key mode. In `data/api/local.settings.json` set `"AUTH_MODE": "apikey"` and choose your own `API_KEY` value (do not keep the sample value if your tunnel is reachable by others). Then run `func start` and start your dev tunnel as described in `data/api/run-local.md` section 5.
2. Record two values. You use them several times:
   - **Tunnel host**: the host name only, for example `abcd1234-7071.use.devtunnels.ms` (no `https://`, no path).
   - **API key**: the value of `API_KEY`.
3. Check the API through the tunnel:

   ```powershell
   $h = @{ 'X-API-Key' = '<your API key>' }
   Invoke-RestMethod -Headers $h "https://<tunnel host>/api/outage-status?outageId=OUT-2026-0412"
   ```

   Expected: one result, Kingston, 3,214 customers, status Crew On Site, ETR `2026-09-30T14:30:00-04:00`.
4. Sign in to Power Automate (https://make.powerautomate.com) and Copilot Studio (https://copilotstudio.microsoft.com) as the learner and select environment **HLE-Dev** in both.

## Steps

### Part A: Create the custom connector inside the solution (30 min)

The connector must be created inside solution **HLEHarbourlineOps** so it can travel with the solution in Lab 11.

> **OpenAPI version.** `data/api/openapi-apikey.yaml` is OpenAPI 3.0.3. The Power Platform custom connector import has historically expected an OpenAPI 2.0 (Swagger) definition; this could not be verified against Learn at build time (UNVERIFIED). The course therefore ships a hand-converted OpenAPI 2.0 copy of the same file with the same operationIds and the same `X-API-Key` scheme: [`solutions/lab-05/hle-outage-api.swagger.json`](../../solutions/lab-05/hle-outage-api.swagger.json). Try `openapi-apikey.yaml` first if you like; if the wizard rejects it, use the 2.0 file.

1. In Power Automate, go to **Solutions** and open **HLEHarbourlineOps**.
2. Select **New** > **Automation** > **Custom connector** (label may differ; check Learn).
3. Choose **Import an OpenAPI file**. Connector name: `HLE Outage API`. Select `solutions/lab-05/hle-outage-api.swagger.json` (or `data/api/openapi-apikey.yaml`).
4. On **General**:
   - Scheme: `HTTPS`
   - Host: your **tunnel host**
   - Base URL: `/api`
   - Description: `Harbourline Energy Co. outage operations API (course mock). Get outage status and dispatch field crews.`
5. On **Security**: Authentication type **API Key**. Parameter label `API key`, parameter name `X-API-Key`, parameter location **Header**. (These come from the file. Check that they were imported exactly.)
6. On **Definition**, confirm there are two actions: **getOutageStatus** (summary "Get current power outages and estimated restoration times") and **dispatchCrew** (summary "Dispatch a field crew to an outage"). If you imported `openapi-apikey.yaml`, delete **lookupCustomer**; it is not used in this lab.
7. Select **Create connector**.
8. On **Test**, select **New connection**, paste your **API key**, and create the connection. Back on **Test**, choose **getOutageStatus**, set `outageId` to `OUT-2026-0412`, and select **Test operation**. Expected: status `200` and a body whose `message` is `Outage OUT-2026-0412 in Kingston, ON: Crew On Site.`

### Part B: Build the agent flow "HLE Get Outage Status" inside the solution (40 min)

Full definition, including expressions: [`solutions/lab-05/flow-hle-get-outage-status.md`](../../solutions/lab-05/flow-hle-get-outage-status.md).

1. In **HLEHarbourlineOps**, select **New** > **Automation** > **Cloud flow** > **Instant**. Name: `HLE Get Outage Status`.
2. Trigger: **When an agent calls a flow** (Copilot Studio connector; the trigger name in your build may differ; check Learn). Add inputs:

   | Input type | Name | Description | Required |
   |---|---|---|---|
   | Text | `region` | Region code (ON, NY, OH), region name, or town such as Kingston. Leave empty for all regions. | No |
   | Text | `outageId` | Outage ID in the form OUT-2026-0412. | No |
   | Number | `delayMs` | Training only. Milliseconds of artificial delay. Use 0 unless the user asks for a delay test. | No |

3. Add action **HLE Outage API** > **Get current power outages and estimated restoration times**. When prompted for a connection, pick the connection you created in Part A. Rename the action to `Get outage status`. Map `region`, `outageId` and `delayMs` from the trigger. Set `pageSize` to `10`.
4. Add action **Respond to the agent** (label may differ; check Learn). Select **Configure run after** and tick both **is successful** and **has failed**. Add outputs:

   | Output type | Name | Value (expression) |
   |---|---|---|
   | Number | `statusCode` | `outputs('Get_outage_status')?['statusCode']` |
   | Text | `summary` | `coalesce(body('Get_outage_status')?['message'], '')` |
   | Number | `totalMatches` | `coalesce(body('Get_outage_status')?['totalMatches'], 0)` |
   | Text | `outagesJson` | `string(coalesce(body('Get_outage_status')?['results'], json('[]')))` |
   | Text | `errorCode` | `coalesce(body('Get_outage_status')?['errorCode'], '')` |

5. Save. Open the flow details page and confirm the **Connection references** panel lists one reference for **HLE Outage API**. If it lists a connection instead, stop and read break-it C-05-c.

### Part C: Build the agent flow "HLE Dispatch Crew" (40 min)

Full definition: [`solutions/lab-05/flow-hle-dispatch-crew.md`](../../solutions/lab-05/flow-hle-dispatch-crew.md).

1. In **HLEHarbourlineOps**, create another instant cloud flow named `HLE Dispatch Crew` with trigger **When an agent calls a flow** and inputs:

   | Input type | Name | Description | Required |
   |---|---|---|---|
   | Text | `outageId` | Active outage to send the crew to, for example OUT-2026-0433. | Yes |
   | Text | `crewId` | Crew code, for example CREW-NY-04. Must be in the same region as the outage. | Yes |
   | Text | `priority` | One of Low, Normal, High, Emergency. | Yes |
   | Text | `notes` | Optional instructions for the crew, up to 500 characters. | No |

2. Add **Microsoft Dataverse** > **List rows**. Rename to `Find crew`. Table name **Crews**. Filter rows: `hle_crewcode eq '@{triggerBody()?['text_1']}'` (use the dynamic content token for `crewId`; the internal key such as `text_1` depends on input order). Select columns: `hle_crewcode,hle_crewname,hle_crewlead,hle_certifications`. Row count: `1`.
3. Add **HLE Outage API** > **Dispatch a field crew to an outage**. Rename to `Dispatch crew`. Map `outageId`, `crewId`, `priority`, `notes` from the trigger.
4. Add **Respond to the agent** with **Configure run after** set to **is successful** and **has failed** on `Dispatch crew`. Outputs:

   | Output type | Name | Value (expression) |
   |---|---|---|
   | Number | `statusCode` | `outputs('Dispatch_crew')?['statusCode']` |
   | Text | `dispatchId` | `coalesce(body('Dispatch_crew')?['dispatchId'], '')` |
   | Text | `message` | `coalesce(body('Dispatch_crew')?['message'], '')` |
   | Number | `estimatedArrivalMinutes` | `coalesce(body('Dispatch_crew')?['estimatedArrivalMinutes'], 0)` |
   | Text | `errorCode` | `coalesce(body('Dispatch_crew')?['errorCode'], '')` |
   | Text | `crewName` | `coalesce(first(outputs('Find_crew')?['body/value'])?['hle_crewname'], '')` |
   | Text | `createdBy` | `coalesce(body('Dispatch_crew')?['createdBy'], '')` |

5. Save. Confirm the flow details page lists two connection references: **HLE Outage API** and **Microsoft Dataverse**.

### Part D: Add the flows to HLE Field Ops Assistant (30 min)

1. In Copilot Studio, open **HLE Field Ops Assistant**.
2. Go to **Tools** (older builds: **Actions**) > **Add a tool** > **Flow**, and select **HLE Get Outage Status**. Set the tool description:

   ```text
   Gets current Harbourline power outages from the outage operations system: customers affected, status, cause, assigned crew and estimated restoration time (ETR). Use it when the user asks about a power outage, an outage ID such as OUT-2026-0412, a town or region (ON, NY, OH), or when power will be restored. Pass delayMs only when the user explicitly asks for a delay test.
   ```

3. Add **HLE Dispatch Crew** the same way, with description:

   ```text
   Dispatches a Harbourline field crew to an active outage and returns a dispatch ID and estimated arrival time. Use it only when the user asks to send, assign or dispatch a crew. Always confirm the outage ID, crew ID and priority with the user before calling it.
   ```

4. Open **Overview** > **Instructions** and append the text in [`solutions/lab-05/agent-instructions-addendum.txt`](../../solutions/lab-05/agent-instructions-addendum.txt) to the instructions you wrote in Lab 4. Keep the Lab 4 text.
5. Confirm **Settings** > **Generative AI** uses generative orchestration (label may differ; check Learn). The flows are chosen by their descriptions, which only works with generative orchestration.
6. Open the **Test** pane and run:

   ```text
   What is the status of outage OUT-2026-0412?
   ```

   Expected: Kingston, Ontario; 3,214 customers; Crew On Site; cause "Tree contact on 44 kV feeder during high winds"; ETR 2:30 PM EDT on September 30, 2026; crew CREW-ON-03.

7. Then run:

   ```text
   Dispatch crew CREW-NY-04 to outage OUT-2026-0433 with High priority. Notes: Customer reports sparking at pole behind 415 Lyell Avenue.
   ```

   Expected: the agent confirms the details, calls **HLE Dispatch Crew**, and reports a dispatch ID in the form `DSP-YYYYMMDD-NNNN`, crew lead Brianna Holt, and an estimated arrival of 35 minutes. The date part of the dispatch ID is the date you run the lab, and the sequence resets when the API host restarts.

8. Try the two planted refusals from the API. The agent should explain the error in plain language and not claim success:

   ```text
   Dispatch CREW-ON-07 to OUT-2026-0412 as an Emergency.
   ```

   Expected: `400 CREW_OFF_SHIFT` ("CREW-ON-07 is off shift and cannot be dispatched."). A good answer suggests an available Ontario crew; the only one is CREW-ON-08.

   ```text
   Send CREW-ON-04 to OUT-2026-0405 with Normal priority.
   ```

   Expected: `409 OUTAGE_ALREADY_RESTORED`; OUT-2026-0405 (Belleville) was restored at 2026-09-29 19:20.

9. Publish the agent.

### Part E: Break it (60 min)

Work through [break-it.md](break-it.md): C-05-a (credentials), C-05-b (100-second limit), C-05-c (connection references), C-05-d (data policy).

### Part F: Validate

Run [validate.md](validate.md) with `evals/lab-05-questions.csv`.

## Caveats this lab triggers

| Caveat ID | Name | Where in break-it.md |
|---|---|---|
| C-05-a | Maker credentials vs end-user credentials | [C-05-a](break-it.md#c-05-a-maker-credentials-vs-end-user-credentials) |
| C-05-b | Agent flow 100-second response limit | [C-05-b](break-it.md#c-05-b-agent-flow-100-second-response-limit) |
| C-05-c | Flows created outside a solution have no connection references | [C-05-c](break-it.md#c-05-c-flows-created-outside-a-solution-have-no-connection-references) |
| C-05-d | Data policy (DLP) blocks the custom connector | [C-05-d](break-it.md#c-05-d-data-policy-dlp-blocks-the-custom-connector) |

## What later labs reuse

- **HLE Outage API**, **HLE Get Outage Status** and **HLE Dispatch Crew** in solution **HLEHarbourlineOps** (Lab 10 connected agents, Lab 11 ALM).
- **HLE Field Ops Assistant** with the two flow tools (Lab 10 connects it to **HLE Front Door**).
- The dev tunnel and API key (Labs 6, 8, 10).
