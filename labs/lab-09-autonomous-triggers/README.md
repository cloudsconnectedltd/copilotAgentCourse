# Lab 09: Autonomous agent with triggers

| | |
|---|---|
| Build path | Copilot Studio (event trigger, generative orchestration, Dataverse, Microsoft Teams and Office 365 Outlook tools) in environment `HLE-Dev` |
| Estimated time | 2.5 hours |
| Prerequisites | [Lab 3](../lab-03-studio-sharepoint-knowledge/README.md) (Copilot Studio basics in `HLE-Dev`). Dataverse tables loaded in `HLE-Dev` by [`data/dataverse/import-dataverse.ps1`](../../data/dataverse/import-dataverse.ps1) (done in [Lab 4](../lab-04-studio-dataverse-topics/README.md); run it now if you skipped Lab 4). Setup scripts [`02-provision-sites.ps1`](../../setup/02-provision-sites.ps1) and [`03-upload-content.ps1`](../../setup/03-upload-content.ps1) (they create `Procedures/Incoming`). Copilot Studio capacity (capacity pack or pay-as-you-go, LIC-06, LIC-07). |
| Personas used | Learner (maker, duty operator), Sofia Brennan (fin, drops a file in step 9), Tom Whitfield (nolic, email recipient only) |
| Status | Contains UNVERIFIED limits: CS-A10 (GA or preview status of event triggers is not stated; **check GA/preview status on Learn** before you run this lab), LIC-12 (per-trigger rate). SNIP rows: CS-A07, CS-A08, CS-A09, LIC-10, LIC-11, LIC-12. |
| Limits referenced | [CS-A02, CS-A07, CS-A08, CS-A09, CS-A10, LIC-06, LIC-07, LIC-10, LIC-11, LIC-12, ENV-02, ENV-03](../../reference/limits.md) |

> **Check before you run.** Every Copilot Studio fact in this lab comes from search-engine summaries of Learn pages (SNIP) or was not found at all (UNVERIFIED). Before you start, open these pages and confirm the rows below. If Learn now says something different, follow Learn and tell your facilitator.
>
> | Row | What to confirm | Page |
> |---|---|---|
> | CS-A10 | Whether event triggers are GA or preview in your region and experience | https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-triggers-about |
> | CS-A07 | Event triggers need generative orchestration | https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-trigger-event |
> | CS-A08 | Event triggers run with the author's credentials only | https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-triggers-about |
> | CS-A09, LIC-11, LIC-12 | Event trigger runs consume Copilot Credits, including for licensed users; current credit rates | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-messages-management |
>
> Copilot Studio documentation could not be read from source while this course was built, so UI labels in the steps may differ from what you see. Where a step says "UI labels may differ", look for the concept, not the exact words.

## Objective

Build **HLE Field Report Triage**, an autonomous agent that wakes up when a crew's field report lands in the `Procedures/Incoming` folder of the Harbourline-Operations site, reads the report, looks up the asset in Dataverse, and then:

| Report severity | Asset ID present | What the agent does |
|---|---|---|
| Critical | Yes | Creates an Emergency work order, posts an escalation card in Teams, sends an escalation email |
| High or Moderate | Yes | Creates a High priority work order |
| Low | Yes | Creates a Routine work order |
| Any | No (blank) | Creates nothing; emails the records team to confirm the asset ID from GIS |

Then you break it four ways: a trigger payload that does not carry what the agent needs, actions that run as you instead of the person who dropped the file, runs that cost Copilot Credits even though everyone is licensed, and an agent that triggers itself in a loop.

## Concepts

- **Event trigger.** A Copilot Studio trigger that starts the agent when something happens in another system (here, a new file in SharePoint) instead of when a user types. Event triggers need generative orchestration (CS-A07).
- **Trigger payload.** The data the trigger hands the agent when it fires. For a SharePoint "file created" trigger this is file metadata (name, path, identifier, created by), not the text inside the Word document. The agent must fetch and read the content with a tool. Exact payload fields are UNVERIFIED for this course; you inspect them yourself in step 7.
- **Run-as identity.** Event-triggered runs use the agent author's credentials (CS-A08). Whoever drops the file, Dataverse rows, Teams posts and emails are created as the maker.
- **Autonomous consumption.** Autonomous runs are billable even when the users involved hold Microsoft 365 Copilot licenses (LIC-12, CS-A09). Credit rates per feature are in LIC-11. A separate per-trigger rate was not found (LIC-12, UNVERIFIED).
- **Idempotency.** A run must be safe to repeat. This agent uses the work order number `WO-<Report ID>` as its idempotency key and checks for it before creating anything.

## Sample data

The three drop files are in [`data/sharepoint/lab-09-drops/`](../../data/sharepoint/lab-09-drops/). They are not uploaded by setup; you drop them by hand. Facts come from [`data/answer-keys/operations.md`](../../data/answer-keys/operations.md) section 8 and [`data/answer-keys/dataverse-connector.md`](../../data/answer-keys/dataverse-connector.md) section 3.

| File | Report ID | Crew | Asset ID | Severity | Purpose |
|---|---|---|---|---|---|
| `Field-Report-2026-10-01-Kingston.docx` | FR-EON-2026-1187 | CREW-ON-03 (Devon Achebe) | TX-ON-10423 | Moderate | Clean baseline. Asset exists (Kingston Service Centre, Condition 38, installed 1987, no open work order). |
| `Field-Report-2026-10-02-Watertown.docx` | FR-NYN-2026-0442 | CREW-NY-13 (Colleen Brady) | (blank) | Low | Missing asset ID. The agent must not guess one. |
| `Field-Report-2026-10-03-Ashtabula.docx` | FR-OHN-2026-0918 | CREW-OH-06 (Hannah Voss) | TX-OH-20871 | Critical | Escalation branch. 64 customers out, permit LOTO-OHN-2026-00388. The asset number 20871 looks like a New York number; the region code OH is what counts. |

Each file has a Field/Value table (Report ID, Date, Region, Crew ID, Crew leader, Asset ID, Asset description, Issue, Severity, Recommended action), then "Crew notes" and "Submission".

## Steps

### Part A: prepare (15 min)

1. Confirm the Dataverse data is in `HLE-Dev`. Go to https://make.powerapps.com, pick environment `HLE-Dev`, open **Tables > Asset**, and search for `TX-ON-10423`. You should see Kingston Service Centre, Condition Score 38. If the table is missing, run:

   ```powershell
   ./data/dataverse/import-dataverse.ps1 -EnvironmentUrl https://<yourorg>.crm.dynamics.com -Prefix <Prefix>
   ```

2. In the Harbourline-Operations site, open the **Procedures** library at `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Procedures`. Confirm the `Incoming` folder exists and is empty. Create a second folder at the library root named `Triaged`. The agent writes its summaries there, never into `Incoming` (see C-09-d).

   Note: `Triaged` sits in the same library as `Incoming` on purpose. Part E shows why the trigger must be scoped to the folder, not the library.

3. Confirm you know where consumption is reported (you use it in Part E): https://admin.powerplatform.microsoft.com > **Licensing** > **Copilot Studio** (LIC-07). Your account needs Power Platform admin rights to see it.

### Part B: create the agent (20 min)

4. Go to https://copilotstudio.microsoft.com, select environment `HLE-Dev`, and create a new agent (skip the conversational setup and configure it directly). Set:

   | Field | Value |
   |---|---|
   | Name | `HLE Field Report Triage` |
   | Description | `Autonomous agent. Triages field reports dropped into Harbourline-Operations Procedures/Incoming: reads the report, looks up the asset in Dataverse, creates a work order, and escalates Critical reports by Teams and email.` |
   | Orchestration | Generative (Settings > Generative AI > Orchestration; UI labels may differ). Event triggers do not work with classic orchestration (CS-A07). |
   | Authentication | Keep the default (Authenticate with Microsoft). |

   Remove any default knowledge sources and turn off web search. This agent works only from the report and Dataverse.

5. Paste the instructions from [`solutions/lab-09/agent-instructions.txt`](../../solutions/lab-09/agent-instructions.txt) into **Instructions**. The core rules are:

   ```text
   You are HLE Field Report Triage, an autonomous agent for Harbourline Energy Co. field operations.
   You are started by a trigger when a file is created in the Procedures library of the Harbourline-Operations SharePoint site. Nobody is chatting with you. Never ask questions; act on the rules below and stop.

   The trigger gives you file metadata only (for example file name, path, identifier, created by). It does not contain the report. Always call "HLE Read Field Report" with the file identifier to get the report fields before you decide anything.

   RULES (follow in order, stop as soon as a rule says stop)

   0. File filter. Only continue if the file name starts with "Field-Report-", ends with ".docx", and the folder path is Procedures/Incoming. For any other file (including files named "Triage-" or anything in Procedures/Triaged), stop and do nothing. Do not call any other tool.

   1. Read and idempotency. Call "HLE Read Field Report". Build the key WO-<ReportId>, for example WO-FR-EON-2026-1187. Call "Find work order by number" with that key. If a row is returned, stop and do nothing: this report was already triaged.

   2. Missing asset ID. If AssetId is blank, missing, or not in the pattern <TYPE>-<REGION>-<5 digits> (for example TX-ON-10423), do not create a work order and never guess or look up an asset by location, street, depot or crew. Call "Send email" with subject "Asset ID needed: <ReportId>" asking the records team to confirm the asset ID from GIS. Include ReportId, ReportDate, Region, CrewId, CrewLeader, AssetDescription, Issue, Severity and RecommendedAction. Then call "Write triage summary" with Outcome "No work order created: asset ID missing" and stop.
   ...
   ```

   The full text (work type rules, due date rule, escalation content, summary file format) is in the solution file.

### Part C: add the tools (40 min)

Tool names and descriptions matter: with generative orchestration the agent picks tools by their description. Use the exact names below. Full descriptions and input mappings are in [`solutions/lab-09/tools.md`](../../solutions/lab-09/tools.md).

6. Add these tools (Tools > Add a tool; UI labels may differ). Create connections as the learner.

   | Tool name | Type | Purpose |
   |---|---|---|
   | `HLE Read Field Report` | Agent flow (build it from [`solutions/lab-09/flow-hle-read-field-report.md`](../../solutions/lab-09/flow-hle-read-field-report.md)) | Takes the file identifier, gets the file content from SharePoint and returns the Field/Value table as named outputs (ReportId, ReportDate, Region, CrewId, CrewLeader, AssetId, AssetDescription, Issue, Severity, RecommendedAction). |
   | `Find asset by number` | Dataverse connector, List rows | Table Assets, filter `hle_assetnumber eq '<AssetId>'`. |
   | `Find crew by code` | Dataverse connector, List rows | Table Crews, filter `hle_crewcode eq '<CrewId>'`. |
   | `Find work order by number` | Dataverse connector, List rows | Table Work Orders, filter `hle_workordernumber eq '<key>'`. |
   | `Create work order` | Dataverse connector, Add a new row | Table Work Orders. Field mapping in `tools.md`. |
   | `Post escalation card` | Microsoft Teams connector, Post card in a chat or channel | Post as Flow bot, to Chat with Flow bot, recipient: the learner (acting duty operator). Card JSON: [`solutions/lab-09/escalation-card.json`](../../solutions/lab-09/escalation-card.json). |
   | `Send email` | Office 365 Outlook connector, Send an email (V2) | To: the learner. Cc: Tom Whitfield (`<prefix>-nolic@<domain>`, Ops-US clerk). Template: [`solutions/lab-09/escalation-email.txt`](../../solutions/lab-09/escalation-email.txt). |
   | `Write triage summary` | SharePoint connector, Create file | Site `<Prefix>-Harbourline-Operations`, folder path `/Procedures/Triaged`, file name `Triage-<ReportId>.txt`. |

   Why an agent flow for reading the file: the trigger passes metadata only (C-09-a), and a .docx is a zip package, not plain text. The flow design in the solution uses a prompt with a document input to pull the table out. Whether a prompt accepts a Word document as input in your tenant is **UNVERIFIED** for this course; check Learn. If it does not, use the library-columns alternative in `solutions/lab-09/trigger-design.md`.

### Part D: add the event trigger (20 min)

7. On the agent's **Overview** page, under **Triggers**, select **Add trigger** and choose the SharePoint trigger that fires when a file is created (for example "When a file is created (properties only)"). The list of available triggers and their names may differ; check the event trigger page on Learn. Configure:

   | Setting | Value |
   |---|---|
   | Site address | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations` |
   | Library name | `Procedures` |
   | Folder | `/Procedures/Incoming` if the trigger offers a folder setting. If it does not, add the trigger condition in [`solutions/lab-09/trigger-design.md`](../../solutions/lab-09/trigger-design.md) (C-09-d). |
   | Instructions sent with the trigger (payload message) | Paste from [`solutions/lab-09/trigger-payload-instructions.txt`](../../solutions/lab-09/trigger-payload-instructions.txt) |

   Copilot Studio warns you that the trigger runs with your credentials (CS-A08). Read the warning and accept it. You break this on purpose in C-09-b.

8. Publish the agent. Event triggers run only against the published agent.

### Part E: run it (40 min)

9. Drop `Field-Report-2026-10-01-Kingston.docx` into `Procedures/Incoming` (drag it into the browser, or `Add-PnPFile -Path ./data/sharepoint/lab-09-drops/Field-Report-2026-10-01-Kingston.docx -Folder "Procedures/Incoming"`). Within a few minutes the trigger should fire. The delay is not a documented value; record what you see.

   Open the agent's activity view (Activity or Runs on the agent page; UI labels may differ) and open the run. Check:

   - The trigger input contains file properties (name, path, identifier). Record exactly which fields appear. This is your answer to "what does the payload carry?" (C-09-a).
   - Tools called in order: `HLE Read Field Report`, `Find work order by number`, `Find asset by number`, `Find crew by code`, `Create work order`, `Write triage summary`. No Teams card, no email.
   - In Dataverse, a new Work Order row:

     | Column | Expected |
     |---|---|
     | Work Order Number | `WO-FR-EON-2026-1187` |
     | Asset | TX-ON-10423 |
     | Assigned Crew | CREW-ON-03 |
     | Priority | High (Moderate maps to High) |
     | Work Type | Replacement (recommended action says "planned replacement") |
     | Status | New |
     | Region | Ontario (from the asset row) |
     | Opened On | 2026-10-01 |
     | Due Date | 2026-10-08 (High is +7 days, schema.md 4.1) |
     | Currency | CAD |

   - A file `Triaged/Triage-FR-EON-2026-1187.txt`.

10. Drop `Field-Report-2026-10-03-Ashtabula.docx`. Expected: an Emergency, Emergency Restoration work order `WO-FR-OHN-2026-0918` on TX-OH-20871, region Ohio, crew CREW-OH-06, due 2026-10-04, currency USD; a Teams card in your Flow bot chat and an email, both quoting FR-OHN-2026-0918, 64 customers out, permit LOTO-OHN-2026-00388, the pole P-51260 and about 40 L of oil to soil.

11. Drop `Field-Report-2026-10-02-Watertown.docx`. Expected: no work order, an email asking the records team to confirm the asset ID from GIS (Arsenal Street near Coffeen Street, Watertown NY, CREW-NY-13), and a summary file that says "No work order created: asset ID missing".

12. Run [`validate.md`](validate.md), then work through [`break-it.md`](break-it.md) in order.

## Caveats this lab triggers

| Caveat ID | Name | Where |
|---|---|---|
| C-09-a | Trigger payload carries file metadata, not report content; missing asset ID | [break-it.md#c-09-a](break-it.md#c-09-a-trigger-payload-carries-metadata-not-content) |
| C-09-b | Run-as identity: actions run as the maker, not the person who dropped the file | [break-it.md#c-09-b](break-it.md#c-09-b-run-as-identity) |
| C-09-c | Autonomous runs consume Copilot Credits even for licensed users | [break-it.md#c-09-c](break-it.md#c-09-c-cost-and-message-consumption) |
| C-09-d | Agent writes into the folder it watches and re-triggers itself | [break-it.md#c-09-d](break-it.md#c-09-d-self-triggering-loop) |

All four are also in [`caveats.csv`](caveats.csv).

## Files for this lab

| File | Purpose |
|---|---|
| [`break-it.md`](break-it.md) | Reproduce and fix each caveat |
| [`validate.md`](validate.md) | Run [`evals/lab-09-questions.csv`](../../evals/lab-09-questions.csv) |
| [`cleanup.md`](cleanup.md) | Remove what this lab created |
| [`../../solutions/lab-09/`](../../solutions/lab-09/README.md) | Finished instructions, tool definitions, flow design, card, email template |
