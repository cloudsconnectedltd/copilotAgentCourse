# Lab 04: Copilot Studio with Dataverse and topics

| | |
|---|---|
| Build path | Copilot Studio (classic experience), environment `HLE-Dev` |
| Estimated time | 3.5 hours |
| Prerequisites | [Lab 3](../lab-03-studio-sharepoint-knowledge/README.md) (environment `HLE-Dev` exists; you know how to add knowledge and publish). Setup scripts [`02-provision-sites.ps1`](../../setup/02-provision-sites.ps1) and [`03-upload-content.ps1`](../../setup/03-upload-content.ps1) (Finance library and 2,600-row Vendors list). PowerShell 7 with the `Az.Accounts` module for [`data/dataverse/import-dataverse.ps1`](../../data/dataverse/import-dataverse.ps1). System Administrator or System Customizer in `HLE-Dev`. |
| Personas used | Learner (maker and main tester), Marcus Delaney (`tech`) for one environment-access test |
| Status | GA. Contains UNVERIFIED limits: CS-A06 |
| Limits referenced | [CS-K10, CS-K11, CS-A06, CS-A07, ENV-02, ENV-03](../../reference/limits.md) |

> **Check before you run.** This lab depends on these rows in [reference/limits.md](../../reference/limits.md). Confirm them on Microsoft Learn first:
>
> | Row | Value used here | Tag | Page |
> |---|---|---|---|
> | CS-K11 | Dataverse knowledge: up to 15 tables per source; glossary and synonym updates can take up to 15 minutes | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-dataverse |
> | CS-K10 | SharePoint list knowledge uses the first 2,048 rows | SNIP, new-experience docs | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/knowledge-sharepoint-lists |
> | CS-A06 | Topics per agent and trigger phrases per topic | UNVERIFIED (not found) | Check current limit on Microsoft Learn |
> | CS-A07 | Event triggers need generative orchestration (why this agent stays on generative) | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-triggers-about |
>
> The Copilot Studio documentation could not be read when this course was built. Menu names follow documented concepts; **UI labels may differ, check Learn**. The topic YAML in [solutions/lab-04](../../solutions/lab-04/README.md) was written from the documented code-view format but not validated against a live tenant: open the code view of a topic you built in the UI and compare before pasting.

## Objective

Build **HLE Field Ops Assistant**, a Copilot Studio agent that answers questions about Harbourline assets, work orders and crews from Dataverse, reads approval limits and vendor data from SharePoint, and runs three topics that use variables, slot filling, a regex entity, a closed-list entity and an adaptive card. Then break it: a topic that hijacks knowledge questions, a variable that is out of scope, a glossary that has not applied yet, and tabular data that disagrees with itself.

## Concepts

- **Dataverse knowledge** lets the agent answer from rows in Dataverse tables. You pick up to 15 tables per knowledge source and add **synonyms** (other words for a column) and a **glossary** (business terms). Glossary and synonym changes can take up to 15 minutes to apply (CS-K11).
- **Topics** are authored conversations: a trigger, then nodes (messages, questions, conditions, variable changes, generative answers, tool calls). With **generative orchestration** the model chooses a topic from its name and description. With **classic orchestration** trigger phrases decide, and knowledge is used only when no topic matches. This agent uses generative orchestration because Labs 5, 9 and 10 build on it (CS-A07). The number of topics per agent and trigger phrases per topic is not documented in the course's sources (CS-A06, UNVERIFIED).
- **Variables.** A **topic** variable (`Topic.AssetId`) exists only inside the topic that created it. A **global** variable (`Global.LastAssetId`) is visible to every topic in the conversation. You can also pass values between topics as topic inputs and outputs.
- **Entities and slot filling.** A question node stores the user's reply in a variable, typed by an entity. If the user already gave the value in their first message ("check TX-ON-10423"), the entity extracts it and the question is skipped. This is slot filling. You create two custom entities: a **regular expression** entity for asset IDs and a **closed list** entity for work order priority with synonyms.
- **Adaptive cards** are JSON cards rendered in Teams and Copilot. A card built in the formula (Power Fx) editor can show variable values.

## Steps

Use `<tenant>` for your SharePoint tenant name and `<Prefix>` for the course prefix (default `HLE`).

### Part A: Load Dataverse (25 minutes)

1. Get the environment URL of `HLE-Dev`: https://admin.powerplatform.microsoft.com > **Manage > Environments > HLE-Dev** > copy **Environment URL** (for example `https://org1a2b3c4d.crm.dynamics.com`).

2. In PowerShell 7, from the repository root:

   ```powershell
   Install-Module Az.Accounts -Scope CurrentUser   # once
   Connect-AzAccount -TenantId <your-tenant-id>
   ./data/dataverse/import-dataverse.ps1 -EnvironmentUrl https://<org>.crm.dynamics.com -Prefix HLE
   ```

   The script creates publisher `hleharbourline`, unmanaged solution `HLEHarbourlineOps`, tables `hle_Asset`, `hle_Crew`, `hle_WorkOrder`, the choice columns, the two lookups, and loads 1,200 assets, 60 crews and 3,000 work orders. It is safe to re-run. Details: [data/dataverse/schema.md](../../data/dataverse/schema.md).

3. Verify: https://make.powerapps.com > environment `HLE-Dev` > **Tables > Asset** > search `TX-ON-10423`. You should see Kingston Service Centre, Condition Score 38, installed 1987.

4. (Recommended for Lab 11.) In **Solutions**, open the menu on `HLEHarbourlineOps` and select **Set preferred solution**, so new components land in it. If your Copilot Studio version does not honor the preferred solution for agents, Lab 11 adds the agent to the solution by hand. Check Learn.

### Part B: Create the agent (15 minutes)

5. Go to https://copilotstudio.microsoft.com, select environment **HLE-Dev**, **Create > New agent**, skip the conversational setup, and set:
   - Name: `HLE Field Ops Assistant`
   - Description: `Answers Harbourline field operations questions about assets, work orders, crews, vendors and approval limits, and logs field requests.`
   - Instructions: paste [solutions/lab-04/hle-field-ops-assistant-instructions.txt](../../solutions/lab-04/hle-field-ops-assistant-instructions.txt):

   ```text
   You are HLE Field Ops Assistant for Harbourline Energy Co. field and operations staff in Ontario, New York and Ohio.

   Use the Dataverse tables Asset, Work Order and Crew for questions about specific assets, work orders and crews. Use the Finance library for spending approval limits. Use the Vendors list for vendor details.

   For approval thresholds, Approval-Matrix.docx (document HLE-FIN-102) is the authoritative source. If Approval-Matrix.xlsx shows a different value, give the value from the docx and say that the spreadsheet differs.

   For counts, totals and "largest" or "smallest" questions, say how many records your answer is based on, and say so if you may not have seen every row.

   Always cite the table or document you used. If you cannot find the answer, say so. Never invent asset IDs, work order numbers or crew codes.

   Ontario amounts are in CAD. New York and Ohio amounts are in USD.
   ```

6. **Settings > Generative AI**: orchestration **Generative**, general knowledge **Off**. **Settings > Security > Authentication**: **Authenticate with Microsoft**. Save.

### Part C: Dataverse knowledge, synonyms and glossary (40 minutes)

7. **Knowledge > Add knowledge > Dataverse**. Select the tables **Asset** (`hle_asset`), **Work Order** (`hle_workorder`) and **Crew** (`hle_crew`). That is 3 of the up to 15 tables allowed per source (CS-K11). Continue to the review step.

8. On the synonyms step, add the column synonyms from [data/dataverse/schema.md section 6.1](../../data/dataverse/schema.md) (also in [solutions/lab-04/dataverse-synonyms-glossary.md](../../solutions/lab-04/dataverse-synonyms-glossary.md)), **except** the synonym `ticket number` on Work Order Number. Break-it C-04-d adds it later on purpose. Do not add any glossary entries yet. Name the source `Harbourline field data` with the description:

   ```text
   Harbourline assets (poles, transformers, switches, breakers, reclosers, regulators), work orders (priority, status, due dates, costs, assigned crew) and field crews (lead, depot, specialty, certifications) for Ontario, New York and Ohio.
   ```

   Add the source and wait until it shows as ready.

9. In the test pane, run these baseline questions and write down the answers:

   ```text
   What is the condition score of asset TX-ON-10423?
   ```
   (Expected 38, Kingston Service Centre, installed 1987.)

   ```text
   Is work order WO-2026-01076 about an Ohio asset?
   ```
   Record the answer. Its title is "RCL lockout on OH line: RCL-ON-13307". The asset is in Ontario; OH means overhead.

10. Now add the glossary from [data/dataverse/schema.md section 6.2](../../data/dataverse/schema.md) (TX, WO, SW, BRK, RCL, REG, OH, ON and NY, ROW, LOTO, DGA, Open work order, Overdue, Poor condition, Mutual assistance). Edit the knowledge source to find the glossary step; UI labels may differ, check Learn. Save and **note the time**. Follow [break-it C-04-c](break-it.md#c-04-c-glossary-not-applied-yet) to test it immediately and again after 15 minutes.

### Part D: SharePoint knowledge for tabular reasoning (15 minutes)

11. **Knowledge > Add knowledge > SharePoint**:

    ```text
    https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Finance
    ```

    Description: `Harbourline finance policies: expense policy, delegation of financial authority (approval matrix), corporate cards and capital project approval.`

12. Add the Vendors list as knowledge (as in Lab 3 step 20; list knowledge is documented in the new-experience docs, CS-K10):

    ```text
    https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/Vendors
    ```

    Description: `Harbourline vendor register: vendor name, VendorId, category, region, contract value, status, renewal date, primary contact and risk rating.`

13. Test: `Who approves a CAD 80,000 operating expense?` (Director, `Approval-Matrix.docx`) and `Who is the primary contact for Lakeshore Arborist Collective, and should we use them?` (Genevieve Marchetti; Suspended, High risk).

### Part E: Custom entities (15 minutes)

14. Go to **Settings > Entities** (classic experience; UI labels may differ, check Learn) and select **New entity**.

    **Regular expression entity**
    - Name: `HLE Asset ID`
    - Pattern:

      ```text
      \b(POLE|TX|SW|BRK|RCL|REG)-(ON|NY|OH)-\d{5}\b
      ```

    **Closed list entity**
    - Name: `HLE Priority`
    - Items and synonyms:

      | Item | Synonyms |
      |---|---|
      | Emergency | urgent, critical, immediate, right now, wires down, public safety |
      | High | important, high priority, soon, this week |
      | Routine | normal, standard, planned, regular, when possible |
      | Deferred | defer, later, can wait, next outage window, low priority |

    The items match the Dataverse choice labels for `hle_Priority` (schema.md 4.1), so Lab 5 can map them to option values 714800000 to 714800003. Full definitions: [solutions/lab-04/entities.md](../../solutions/lab-04/entities.md).

### Part F: Topics with variables, slot filling and an adaptive card (60 minutes)

Build each topic in the canvas using the node list below. If you prefer, create the topic, open **... > Open code editor**, and paste the YAML from [solutions/lab-04/topics](../../solutions/lab-04/topics/). Before pasting, replace the entity placeholders as described in [solutions/lab-04/README.md](../../solutions/lab-04/README.md), and compare the YAML with the code view of a topic you built in the canvas. The YAML schema could not be verified against Copilot Studio documentation.

15. **Topic `Check Asset Status`** ([check-asset-status.yaml](../../solutions/lab-04/topics/check-asset-status.yaml))
    - Description (generative orchestration uses this): `Look up the current status, condition and open work orders of one specific asset when the user gives or asks about an asset ID such as TX-ON-10423.`
    - Trigger phrases: `check asset status`, `asset status`, `look up an asset`, `what is the condition of asset TX-ON-10423`, `is POLE-NY-20017 in service`
    - Question node: `Which asset? Give the asset ID, for example TX-ON-10423.` Identify: **HLE Asset ID**. Save response as `Topic.AssetId`. Question behavior: allow the question to be skipped when the value is already known (slot filling).
    - Set variable: `Global.LastAssetId` = `Topic.AssetId` (create the variable and set its scope to **Global**, in the variable properties pane).
    - Create generative answers node: input (formula) `"Give the asset type, site, region, install year, condition score, operational status and last inspection date for asset " & Topic.AssetId & ", then list its open work orders."` Data sources: only `Harbourline field data`.

16. **Topic `Log Field Request`** ([log-field-request.yaml](../../solutions/lab-04/topics/log-field-request.yaml))
    - Description: `Log a new field request for one specific asset, with a priority and a description of the problem. Use only when the user wants to raise or report new work, not for questions about existing work orders.`
    - Trigger phrases: `log a field request`, `raise a field request`, `report a problem with an asset`, `request crew work on an asset`, `new field request`
    - Question: asset ID (HLE Asset ID) into `Topic.AssetId`, skippable.
    - Question: `What priority is this? Emergency, High, Routine or Deferred.` Identify: **HLE Priority**. Save as `Topic.Priority`, skippable.
    - Question: `Describe the problem in one or two sentences.` Identify: **User's entire response**. Save as `Topic.Description`.
    - Set variable `Global.LastAssetId` = `Topic.AssetId`.
    - Condition: if `Topic.Priority` is **Emergency**, send `If anyone is in danger or wires are down, call the Distribution System Operator now. Do not wait for this request.`
    - Send a message with an **adaptive card**. Paste [cards/field-request-summary.json](../../solutions/lab-04/cards/field-request-summary.json) to see the design, then switch the card to the formula editor and use the Power Fx version in the YAML so the card shows `Topic.AssetId`, `Topic.Priority` and `Topic.Description`.
    - Final message: `Your request is summarised above. It is not saved yet: in Lab 5 this topic calls the HLE Dispatch Crew flow.`

17. **Topic `Crew For Asset`** ([crew-for-asset.yaml](../../solutions/lab-04/topics/crew-for-asset.yaml))
    - Description: `Tell the user which crews worked on, or are assigned to, the asset discussed earlier in the conversation.`
    - Trigger phrases: `which crew worked on that asset`, `who worked on this asset`, `crew for this asset`, `which crew is assigned to that asset`
    - Condition: if `Global.LastAssetId` is blank, ask for the asset ID (HLE Asset ID) into `Topic.AssetId` and set `Global.LastAssetId` from it.
    - Generative answers node: input `"List the work orders for asset " & Global.LastAssetId & " with work order number, status, assigned crew code and crew lead."` Data sources: only `Harbourline field data`.

18. Save all topics and test slot filling in a fresh test chat:

    | Type | Expected |
    |---|---|
    | `check asset status` | The agent asks for the asset ID. |
    | `Check asset status TX-OH-20871` | No question: the ID is extracted. Ashtabula Depot, Ohio, installed 1992, condition 44, In Service. |
    | `I need to log an urgent field request for SW-OH-30110` | Only the description question is asked (asset and priority Emergency extracted from "urgent"), then the safety message and the card. |
    | then `Which crew worked on that asset?` | `Crew For Asset` uses `Global.LastAssetId` (SW-OH-30110) without asking; answer lists crews such as CREW-OH-03, CREW-OH-01 and CREW-OH-07. |

19. Publish the agent. Add the **Teams and Microsoft 365 Copilot** channel as in Lab 3.

20. Run [validate.md](validate.md), then [break-it.md](break-it.md), then [cleanup.md](cleanup.md).

## Caveats this lab triggers

| Caveat ID | Name | Where |
|---|---|---|
| C-04-a | A topic hijacks a knowledge question | [break-it.md#c-04-a](break-it.md#c-04-a-topic-hijacks-a-knowledge-question) |
| C-04-b | Topic variable not available in another topic | [break-it.md#c-04-b](break-it.md#c-04-b-topic-variable-out-of-scope) |
| C-04-c | Glossary not applied yet (up to 15 minutes) | [break-it.md#c-04-c](break-it.md#c-04-c-glossary-not-applied-yet) |
| C-04-d | Synonym collision and table count | [break-it.md#c-04-d](break-it.md#c-04-d-synonym-collision) |
| C-04-e | Vendors list aggregates wrong past row 2,048 | [break-it.md#c-04-e](break-it.md#c-04-e-tabular-aggregates-over-the-vendors-list) |
| C-04-f | Approval matrix docx vs xlsx disagree | [break-it.md#c-04-f](break-it.md#c-04-f-approval-matrix-docx-vs-xlsx) |
| C-04-g | Personas cannot use Dataverse in a Developer environment | [break-it.md#c-04-g](break-it.md#c-04-g-developer-environment-is-owner-only) |
| C-04-h | Regex entity misses variant asset ID formats | [break-it.md#c-04-h](break-it.md#c-04-h-regex-entity-misses-variants) |

## What later labs reuse

| Artifact | Used by |
|---|---|
| Agent `HLE Field Ops Assistant` in `HLE-Dev` | Lab 5 (custom connector `HLE Outage API`, agent flows `HLE Get Outage Status` and `HLE Dispatch Crew`), Lab 10 (connected agent under `HLE Front Door`), Lab 11 (solution export) |
| Topics `Check Asset Status`, `Log Field Request`, `Crew For Asset`; entities `HLE Asset ID`, `HLE Priority`; variable `Global.LastAssetId` | Lab 5 wires `Log Field Request` to `HLE Dispatch Crew` |
| Dataverse tables and solution `HLEHarbourlineOps` | Labs 5, 9, 10, 11 |
