# Trigger design for HLE Field Report Triage

Design guidance for the event trigger. Payload field names and trigger names below are **not verified** against Microsoft Learn for this course (Copilot Studio docs were available only as search summaries). Treat them as patterns and confirm the exact names in your tenant.

## 1. Choose the scope

| Option | Fires for | Loop risk (C-09-d) | Use |
|---|---|---|---|
| Folder-scoped file trigger on `/Procedures/Incoming` | New files in that folder | Low, if output goes elsewhere | Preferred, if the trigger offers a folder setting |
| Library-wide file trigger on `Procedures` plus a trigger condition on the path | Every new file in the library, filtered before the agent runs | Low, if the condition is kept | Use when the trigger has no folder setting |
| Library-wide file trigger with no condition | Every new file in the library, including `Triaged` | High | Do not use (this is the C-09-d break) |

## 2. Trigger condition (library-wide trigger)

Event triggers in Copilot Studio are built on Power Automate connector triggers. If the trigger exposes its underlying flow or settings, add a trigger condition so the run never starts for other folders or for the agent's own files. Pattern:

```text
@and(
  contains(triggerOutputs()?['body/{Path}'], 'Procedures/Incoming/'),
  startsWith(triggerOutputs()?['body/{FilenameWithExtension}'], 'Field-Report-'),
  endsWith(triggerOutputs()?['body/{FilenameWithExtension}'], '.docx')
)
```

The property names `{Path}` and `{FilenameWithExtension}` are the usual SharePoint trigger output names in Power Automate, but check the trigger's raw outputs from one run and adjust. Keep rule 0 in the agent instructions as a second check: a trigger condition that is not visible in the agent is easy to lose when the solution is exported (Lab 11).

## 3. Payload: pass an address, not content

The payload message the trigger sends to the agent should contain:

| Field | Why |
|---|---|
| File identifier | Input to `HLE Read Field Report` |
| File name | Rule 0 filter |
| Folder path | Rule 0 filter |
| Created by | Audit trail, because actions run as the maker (C-09-b) |

Do not try to put the document text in the payload. The file-created trigger carries metadata, and a .docx is a zip package.

## 4. Alternative: structured library columns

If a document-input prompt is not available (see `flow-hle-read-field-report.md` step 3), move the structure out of the document and into SharePoint metadata:

1. Add columns to the Procedures library: `ReportId` (single line of text), `AssetId` (single line of text), `Severity` (Choice: Critical, High, Moderate, Low), `CrewId` (single line of text), `ReportDate` (Date only).
2. The submitting app (in real life, the mobile workforce application named in each report's "Submission" section) fills the columns on upload. In the lab, fill them by hand in the library's details pane right after you drop the file: Kingston `FR-EON-2026-1187`, `TX-ON-10423`, Moderate, `CREW-ON-03`, 2026-10-01; Watertown `FR-NYN-2026-0442`, blank, Low, `CREW-NY-13`, 2026-10-02; Ashtabula `FR-OHN-2026-0918`, `TX-OH-20871`, Critical, `CREW-OH-06`, 2026-10-03.
3. Replace the reader flow's content steps with **Get file properties** and return the column values.

Trade-offs:

- Column values are metadata, so they may be available in the trigger payload itself (confirm whether your trigger includes custom columns; the "properties only" style triggers are designed around this).
- A file-created trigger can fire before a person finishes typing the columns. With hand-filled columns, expect runs that see blank values. That is the same failure as the Watertown report and must be handled the same way: no work order, ask a human. In production the uploading app sets columns in the same request as the file.
- Validation moves to the data entry side: a required `AssetId` column would stop the Watertown submission entirely, which is not what Harbourline wants (the crew legitimately could not read the tag). Keep it optional and let the agent route blanks to records.

## 5. Idempotency

| Marker | Where | Checked by |
|---|---|---|
| Work order number `WO-<Report ID>` | Dataverse `hle_workordernumber` | Rule 1, tool `Find work order by number` |
| Output file name `Triage-<Report ID>.txt` | `Procedures/Triaged` | Never matches the input pattern `Field-Report-*.docx` |

A stronger production design adds a library column `TriageStatus` that the agent sets to `Done` on the source file. Note that updating a file's properties is not a "file created" event, but it is a "file modified" event: do not pair this with a created-or-modified trigger.
