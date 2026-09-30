# Agent flow: HLE Read Field Report

Flow definition description. Build it in Copilot Studio (agent > Tools > Add a tool > New agent flow) or in Power Automate in environment `HLE-Dev`. No exported flow package is provided; build it from this description.

## Purpose

The event trigger gives the agent file metadata only (C-09-a). This flow turns a file identifier into named report fields so the agent's rules can test them (for example "is AssetId blank?").

## Trigger

**When an agent calls the flow** (Copilot Studio skills trigger; UI name may differ).

| Input | Type | Example |
|---|---|---|
| `FileIdentifier` | Text | the identifier from the trigger payload |

## Actions

1. **SharePoint: Get file content**
   - Site Address: `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations`
   - File Identifier: `FileIdentifier`
   - Infer Content Type: Yes

2. **SharePoint: Get file properties** (optional, to return the path and Created By for the audit line)

3. **Run a prompt: `HLE Extract Field Report`** (AI prompt with a document input; in Copilot Studio this is a prompt tool, in Power Automate the AI Builder "Run a prompt" action; UI names may differ).
   - Document input: the file content from step 1.
   - Prompt text:

     ```text
     The attached document is a Harbourline Energy Co. field report. It contains a two-column table with the headings Field and Value, followed by sections "Crew notes" and "Submission".
     Return only JSON with these keys: ReportId, ReportDate, Region, CrewId, CrewLeader, AssetId, AssetDescription, Issue, Severity, RecommendedAction, CrewNotes.
     Copy each value exactly as written in the Value column. Use yyyy-MM-dd for ReportDate.
     If a Value cell is empty, return an empty string for that key. Never fill an empty value from other text in the document.
     CrewNotes is the text under the "Crew notes" heading.
     ```
   - Output: JSON.

   Status: whether prompts accept a Word document as input in your tenant and region is **UNVERIFIED** for this course. Check Learn. If the document input is not available, use the library-columns design in `trigger-design.md` instead and replace steps 1 to 3 with **Get file properties**.

4. **Parse JSON** on the prompt output with this schema:

   ```json
   {
     "type": "object",
     "properties": {
       "ReportId": { "type": "string" },
       "ReportDate": { "type": "string" },
       "Region": { "type": "string" },
       "CrewId": { "type": "string" },
       "CrewLeader": { "type": "string" },
       "AssetId": { "type": "string" },
       "AssetDescription": { "type": "string" },
       "Issue": { "type": "string" },
       "Severity": { "type": "string" },
       "RecommendedAction": { "type": "string" },
       "CrewNotes": { "type": "string" }
     }
   }
   ```

5. **Condition: required fields.** If `ReportId` is empty or `Severity` is empty, set `ReadStatus` to `Missing required field: ReportId or Severity`; otherwise `OK`. Do not test `AssetId` here: a blank asset ID is a valid report that the agent must route to the records team (rule 2).

6. **Respond to the agent** with outputs `ReportId`, `ReportDate`, `Region`, `CrewId`, `CrewLeader`, `AssetId`, `AssetDescription`, `Issue`, `Severity`, `RecommendedAction`, `CrewNotes`, `ReadStatus`.

## Expected outputs for the three drops

From `data/answer-keys/operations.md` section 8 and the files in `data/sharepoint/lab-09-drops/`.

| Output | Kingston | Watertown | Ashtabula |
|---|---|---|---|
| ReportId | FR-EON-2026-1187 | FR-NYN-2026-0442 | FR-OHN-2026-0918 |
| ReportDate | 2026-10-01 | 2026-10-02 | 2026-10-03 |
| Region | Eastern Ontario | New York North Country | Northeast Ohio |
| CrewId | CREW-ON-03 | CREW-NY-13 | CREW-OH-06 |
| CrewLeader | Devon Achebe | Colleen Brady | Hannah Voss |
| AssetId | TX-ON-10423 | (empty) | TX-OH-20871 |
| Severity | Moderate | Low | Critical |
| ReadStatus | OK | OK | OK |

Test the flow on its own with each file's identifier before you connect the trigger. If Watertown returns any AssetId, the prompt is filling it from the description; tighten the prompt.

## Time limit

An agent flow must respond within 100 seconds (CS-A02, SNIP). A single-page report is well inside that, but record the run duration you see.
