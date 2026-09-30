# Lab 09: Break it

Four caveats, in order. Each starts from the working agent at the end of the README steps. Several of these involve behavior that Microsoft documents only at SNIP level or not at all; where a symptom is not documented, the section says "Observe and record" and gives what the docs lead you to expect.

Before you start: keep the agent's activity view open in one tab and the Procedures library in another. For C-09-d, keep the trigger's on/off control in reach.

---

## C-09-a: Trigger payload carries metadata, not content

**Caveat ID:** C-09-a

This is design guidance first and a failure second. The trigger tells the agent that a file exists. It does not tell the agent what the file says.

### Steps to reproduce

1. Open the agent's tools and disable (or remove) `HLE Read Field Report`. Publish.
2. Drop a fresh copy of `Field-Report-2026-10-01-Kingston.docx` into `Procedures/Incoming`. Rename it first to `Field-Report-2026-10-01-Kingston-b.docx` so the file name is new.
   - Also delete the `WO-FR-EON-2026-1187` row created in the README, or the idempotency check will stop the run before you see the failure.
3. Open the run in the activity view. Look at the trigger input.
4. Re-enable `HLE Read Field Report` and publish. Drop `Field-Report-2026-10-02-Watertown.docx` again (renamed `-b`).

### Symptom you will see

Observe and record. Expected per the design of SharePoint file triggers:

- Step 3: the trigger input shows file properties such as name, path, identifier, created by and modified time. It does not show Report ID, Asset ID or Severity. The agent either stops and says it cannot read the report, or (worse) tries to infer an asset ID from the file name. Kingston's file name contains "Kingston" but no asset number, so any asset ID it produces is invented. Record which of these happened.
- Step 4 (Watertown): the Asset ID field exists in the report but is empty. A badly instructed agent will look up "Watertown" or the street name in Dataverse, pick a transformer at Watertown Depot, and create a work order on the wrong asset. With the solution instructions, it sends the records email and creates nothing.

The exact fields in the payload are **UNVERIFIED** for this course. Write down what you saw; your facilitator collects these to update the lab.

### Root cause

A SharePoint "file created" trigger is a notification about a file, and its payload is the file's metadata. The agent only knows what the payload and its tools give it. Event triggers run only under generative orchestration (CS-A07), so the model decides which tool to call from the instructions and tool descriptions; if no tool can return the content, it cannot follow rules that depend on the content. The payload field list itself is not stated in any source this course could read (no limits row; treat it as UNVERIFIED).

The missing asset ID is a data quality problem the agent must handle, not a platform limit. The Watertown crew notes say the tag was missing from the tank and records must look it up in GIS (`data/answer-keys/operations.md` section 8).

### Fix

Design the payload and the first tool call together:

1. Keep the trigger payload small and treat it as an address: pass the file identifier and path, and tell the agent in the trigger instructions to call `HLE Read Field Report` first (`solutions/lab-09/trigger-payload-instructions.txt`).
2. Make the reader tool return named fields, not a blob of text, so the instructions can test `AssetId` for blank.
3. Validate required fields before any write: Report ID, Asset ID, Severity. Missing Asset ID goes to a human (the records email), never to a lookup by location.
4. Alternative design: capture structured fields as SharePoint library columns (ReportId, AssetId, Severity) when the mobile app uploads the file. Column values are file metadata, so they can travel in the trigger payload and no document parsing is needed. See `solutions/lab-09/trigger-design.md`. Confirm on Learn whether your chosen trigger includes custom column values.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-trigger-event

---

## C-09-b: Run-as identity

**Caveat ID:** C-09-b

### Steps to reproduce

1. Sofia Brennan (fin) is a Hub member only; she has no access to Harbourline-Operations (`reference/site-map.md`). Give her temporary Edit access to the `Incoming` folder only: in the Procedures library select the `Incoming` folder > **Manage access** > grant `<prefix>-fin@<domain>` **Can edit**. (This breaks permission inheritance on the folder. `cleanup.md` restores it.)
2. Sign in as Sofia in a private browser window. Open `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Procedures/Incoming` and upload a copy of the Kingston report renamed `Field-Report-2026-10-01-Kingston-fin.docx`. Delete `WO-FR-EON-2026-1187` first if it exists.
3. As the learner, open the run and then the new Work Order row in `HLE-Dev`. Check **Created By** and **Owner**. Check the sender of the triage summary file in `Triaged`.
4. Still as Sofia, try to open `https://make.powerapps.com` > `HLE-Dev`.

### Symptom you will see

- The work order is created, and Created By and Owner are the learner, not Sofia. The summary file's Created By is the learner.
- Sofia cannot open `HLE-Dev` at all: developer environments are owner-only (ENV-02). She has no Dataverse rights there, yet her file drop caused a Dataverse write.
- The file in `Incoming` shows Sofia as Created By. That is the only trace of who started the chain.

### Root cause

Event triggers run only with the agent author's credentials, and Copilot Studio warns the maker before publishing (CS-A08, SNIP). Every connection the tools use (Dataverse, Teams, Outlook, SharePoint) is the maker's connection. The dropper's identity is only available as data (the file's Created By in the payload), not as the security context.

This is a privilege path: anyone who can write to `Incoming` can cause writes with the maker's rights in systems they cannot access themselves.

### Fix

- Treat write access to the watched folder as equivalent to the agent's rights. Restrict `Incoming` to the crews and systems that should submit reports, and remove Sofia's access (cleanup does this).
- Run production triggers under a dedicated service account that owns the agent and its connections, with least-privilege Dataverse security roles (only the Work Order and Asset tables), rather than a personal admin account.
- Record the dropper: pass the file's Created By from the payload into the work order description ("Submitted by: <name>") so the audit trail survives. The solution instructions do this.
- Re-read the publish-time warning; do not dismiss it by habit.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-triggers-about

---

## C-09-c: Cost and message consumption

**Caveat ID:** C-09-c

### Steps to reproduce

1. Note the time. Count the runs from the README and C-09-a and C-09-b (typically 5 to 7).
2. Sign in to https://admin.powerplatform.microsoft.com > **Licensing** > **Copilot Studio** > **Environments** tab > select `HLE-Dev` > **Copilot Credits capacity** tab (LIC-07). Find the **Copilot credit consumption details** grid.
3. Select **Download** and generate a report for the current month. Filter it to agent `HLE Field Report Triage`. Look at the **Billed credits** and **Non-billed credits** columns and the product or feature column.
4. For comparison, filter to `HLE HR Assistant` (Lab 3), which you tested in the Teams or Copilot channel as a licensed user.

### Symptom you will see

Observe and record. Expected per the docs:

- `HLE Field Report Triage` shows billed Copilot Credits, even though the learner and Sofia both hold Microsoft 365 Copilot licenses. Autonomous runs are billable even for licensed users (LIC-12, CS-A09).
- Each run bills more than one item. Each tool call is an agent action (5 credits each in LIC-11) and generative answers are 2 each (LIC-11). A single Kingston run makes about six tool calls. Record the credits per run you actually see; the per-trigger rate is UNVERIFIED (LIC-12).
- `HLE HR Assistant` usage by licensed users in Microsoft 365 channels shows as non-billed (zero-rated, LIC-10).
- Consumption data may not appear immediately. The admin page reports daily data; record how long it took to show.

Rates are SNIP. Check the current table on the Learn page below before you estimate anything.

### Root cause

Licensed-user zero-rating (LIC-10) applies to users chatting with agents in Copilot Chat, Teams and SharePoint. An autonomous run has no licensed user in the conversation; it is started by an event and runs as the maker, so its generative answers and agent actions draw from Copilot Studio capacity (LIC-06) or pay-as-you-go (LIC-07). Developer environments also cap flow runs at 750 per month (ENV-03), which a busy trigger can reach.

### Fix

- Estimate before you deploy: expected reports per day x tool calls per run x LIC-11 rates, plus a margin for retries. Re-check LIC-11 on Learn.
- Cut tool calls: stop early (rule 0 file filter, rule 1 idempotency check) before any expensive step, and avoid "look up everything" instructions.
- Allocate capacity to the environment deliberately and watch the environment and agent reports weekly.
- Filter the trigger so it fires only for the files you mean (C-09-d fix also saves credits).

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-messages-management

---

## C-09-d: Self-triggering loop

**Caveat ID:** C-09-d

Warning: this section makes the agent run repeatedly and consume credits (C-09-c). Stop it after three extra runs.

### Steps to reproduce

1. Break the design in three places at once, which is how this usually happens in real projects:
   - Change the trigger to watch the whole `Procedures` library (remove the folder setting or the trigger condition).
   - Change `Write triage summary` to write into `/Procedures/Incoming` instead of `/Procedures/Triaged`, with file name `Field-Report-Triage-<ReportId>.docx`. (The name matters: it passes a lazy "starts with Field-Report-" check.)
   - In the instructions, delete rule 0 (file filter) and rule 1 (idempotency check).
2. Publish. Delete `WO-FR-EON-2026-1187` if it exists. Drop `Field-Report-2026-10-01-Kingston.docx` (renamed `-loop`).
3. Watch the activity view for a few minutes. After the third extra run, turn the trigger off (or unpublish the agent).

### Symptom you will see

Observe and record. Expected:

- Run 1 processes the report and writes `Field-Report-Triage-FR-EON-2026-1187.docx` into `Incoming`.
- That new file fires the trigger again. Run 2 reads the summary (no Field/Value table, or a partial one), and either creates a second work order with a slightly different key, sends a records email about a "missing asset ID", or writes another summary file, which fires run 3.
- Credits climb in the consumption report (C-09-c). Dataverse may show duplicate or junk work orders. Teams and email recipients receive repeated messages if the loop reaches the Critical branch.

No platform loop limit is documented in the sources this course could read. Do not rely on one; stop the trigger yourself.

### Root cause

The agent writes output to the scope it watches, so every run creates the event that starts the next run. Without a file filter and an idempotency key, the agent has no way to tell its own output from new work. This is a design error, not a platform limit (no limits row). Because triggers run as the maker (CS-A08), the loop's writes are indistinguishable from yours.

### Fix

Apply all three; each one alone has gaps.

1. **Write somewhere else.** Output goes to `/Procedures/Triaged` (or another library), never to `Incoming`.
2. **Filter the trigger by folder.** Scope the trigger to `/Procedures/Incoming`, or add a trigger condition on the file path (see `solutions/lab-09/trigger-design.md`). The instructions' rule 0 repeats the check inside the agent, because a trigger condition you cannot see in the agent is easy to lose on export.
3. **Idempotency marker.** Use `WO-<Report ID>` as the work order number and check for it before creating (rule 1). Name output files `Triage-<Report ID>.txt` so they never match `Field-Report-*.docx`.

Then restore the solution configuration, publish, delete any duplicate work orders (`cleanup.md` step 2), and confirm one drop produces one run.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-trigger-event
