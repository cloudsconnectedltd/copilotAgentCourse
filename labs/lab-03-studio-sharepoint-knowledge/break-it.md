# Lab 03 break-it: SharePoint and file knowledge caveats

Each section reproduces one caveat on **HLE HR Assistant** or **HLE Knowledge Bench** in `HLE-Dev`. Limits come from [reference/limits.md](../../reference/limits.md). Rows tagged SNIP or UNVERIFIED must be re-checked on Microsoft Learn; where the behavior is not documented, the lab tells you to **observe and record** rather than asserting a result.

Use the test pane for learner tests. Use the persona's own sign-in (Teams or Microsoft 365 Copilot Chat) for anything involving permissions: the test pane always runs as you.

---

## C-03-a: Oversized file silently excluded

**Caveat ID:** C-03-a

**Steps to reproduce**
1. Confirm `Employee-Handbook-Full.docx` in `HR-Policies` is about 9.1 MB (9,574,039 bytes from `tools/generate-data/generate_oversized_handbook.py --target-mb 9`).
2. In HLE HR Assistant, ask with tenant graph grounding **on**:
   ```text
   What do employees receive for 25 years of service?
   ```
   Note the answer and citation (chapter 14.2 of the handbook).
3. Turn tenant graph grounding with semantic search **off** (Generative AI or Knowledge settings; UI labels may differ, check Learn). Save and wait a few minutes.
4. Reset the test chat and ask the same question again.

**Symptom you will see.** Expected per the docs: no grounded answer. The agent says it cannot find the information, or answers only with general award text from other sources and no handbook citation. No error or warning tells you the file was skipped. The 25-year award (3 extra days of paid leave and a crystal award) exists only in the handbook, so its absence is the signal. If the answer still appears with grounding off, record that: CS-K01 is worded as a tenant license condition, and the course could not verify how the toggle interacts with it.

**Root cause.** Without tenant graph grounding (or without a Microsoft 365 Copilot license in the tenant), generative answers use only SharePoint files under 7 MB (CS-K01). With a Copilot license and tenant graph grounding with semantic search, files up to 200 MB are used (CS-K02). PDF, PPTX and DOCX in SharePoint and connector sources are supported up to 512 MB (CS-K03). Tags: SNIP.

**Fix.** Turn tenant graph grounding back on (requires "Authenticate with Microsoft", CS-K04, and a Copilot license in the tenant). If you cannot, split the handbook into files under 7 MB, or reduce file size (the handbook is large because of embedded photos, not text).

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas and https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio

---

## C-03-b: Scanned (image-only) PDF

**Caveat ID:** C-03-b

**Steps to reproduce**
1. `Signed-Policy-Acknowledgement-Scan.pdf` is in `HR-Policies`. It is one page with a single JPEG image and no text layer.
2. In HLE HR Assistant, ask:
   ```text
   What is the re-acknowledgement period on acknowledgement ACK-2025-0457?
   ```
3. Repeat after uploading the same PDF as a file (README step 18): **Knowledge > Add knowledge > Upload file**.

**Symptom you will see.** The agent does not return the fact from **either** source. The correct value (every 24 months, next due March 2027) is visible only in the image.

| Source | Result (observed in a course tenant, 2026-10-07) |
|---|---|
| SharePoint copy in `HR-Policies` | No answer: "not found", or an answer that cites a different document (for example the Code of Conduct, whose annual attestation is a different rule) |
| Same PDF uploaded to the agent (README step 18) | No answer either. Uploading the file does not make the image text readable. |

Don't be misled by CS-K09: it says uploaded files support "images embedded in PDFs", which reads as if an uploaded scan might work. In practice the uploaded scan returned nothing.

**How to confirm the cause yourself.** Open the PDF and try to select a word or search for `ACK-2025-0457` (Cmd+F or Ctrl+F). If nothing can be selected or found, the file has no text layer, and the agent has nothing to index.

**Root cause.** Knowledge indexing works on extracted text, and a scan has no text layer. Neither SharePoint knowledge nor file upload ran OCR on this file in testing. No Microsoft Learn page states this (CS-K13 remains UNVERIFIED as a documented rule); the behaviour above is observed, not documented.

**Fix.** Run OCR before publishing (for example, save the scan as a searchable PDF from your scanning tool) and replace the file. Keep the original image-only scan out of knowledge libraries, or store scans in a library the agent does not use.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-file-upload (CS-K09). No Learn source exists for CS-K13.

---

## C-03-c: Conflicting leave policy versions

**Caveat ID:** C-03-c

**Steps to reproduce**
1. Both `Leave-Policy-v3-2024.docx` and `Leave-Policy-v4-2025.pdf` are in `HR-Policies`. Both have Document ID HR-POL-012 and title "Leave Policy". v3 is not marked superseded.
2. Temporarily delete the paragraph about conflicting versions from the agent instructions (the one starting "When two documents with the same Document ID disagree"). Save.
3. Ask:
   ```text
   How many vacation days does an employee with 6 years of service get?
   ```
   and
   ```text
   An employee has 9 years of service. How many vacation days do they get?
   ```

**Symptom you will see.** Answers vary between runs. You may get 18 days (v3, years 3 to 7) instead of 20 days (v4, years 5 to 9), or a blend. For 9 years, v3 says 22 and v4 says 20, so the older version is more generous and an unwary agent overstates the entitlement. Carry-over is 10 days in v3 and 5 days in v4.

**Root cause.** Content, not product: two live documents claim to be the same policy. Retrieval returns chunks from both and nothing in v3 says it is superseded (only the v4 revision history says "Replaces version 3.0"). No limits row applies.

**Fix.** Restore the instruction paragraph (it tells the agent to prefer the higher version and later effective date and to flag the conflict). The real fix is content governance: move v3 out of the knowledge library (for example to an archive library the agent does not use) or mark it superseded in the document itself. Instructions reduce the risk; they do not remove it.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-sharepoint (general SharePoint knowledge guidance; this caveat is a content issue with no limits row).

---

## C-03-d: Security trimming per persona

**Caveat ID:** C-03-d

**Steps to reproduce**
1. In the learner's test pane, ask `How long is a final written warning active?` You get 24 months from `Restricted/Disciplinary-Case-Handling.docx`, because the learner is in every group and the test pane runs as the learner.
2. Sign in as each persona (README step 16) and ask the same question, then:
   ```text
   What is the internal target for completing a workplace investigation?
   ```

**Symptom you will see.**

| Persona | Final written warning | Investigation target |
|---|---|---|
| Priya (`hr`, member of `<Prefix>-HR`) | 24 months | 45 calendar days (inside the 90-day outer target) |
| Sofia (`fin`) | Not found | Not found, or only the 90-day outer target from the public `Harassment-Prevention-Ontario.docx` |
| Marcus (`tech`) | Not found | Same as Sofia |
| Guest | Not found, or cannot open the agent | Same |

A maker who tests only in the test pane believes everyone gets the restricted answer. That is the trap.

**Root cause.** With "Authenticate with Microsoft" the agent queries SharePoint as the signed-in user (CS-K04), so broken inheritance on `HR-Policies/Restricted` (site owners and `<Prefix>-HR` only) is enforced per user. Instructions play no part in this.

**Fix.** Nothing to fix in the agent: this is the desired behavior. The lesson is procedural: always test permissions with real persona sign-ins, never the test pane. If a persona sees restricted content, fix the SharePoint permissions, not the instructions.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/configuration-end-user-authentication

---

## C-03-e: Encrypting sensitivity label

**Caveat ID:** C-03-e

**Steps to reproduce**
1. `Compensation-Bands-2025.docx` carries the label `<Prefix> HR Confidential` from `setup/04-apply-labels.ps1`. The label grants co-author rights (including VIEW and EXTRACT) only to `<Prefix>-HR` members.
2. As Priya and as Sofia (Teams or Copilot Chat), ask:
   ```text
   What is the CAD midpoint for grade G7?
   ```
3. As the learner, download `Compensation-Bands-2025.docx` from SharePoint (the downloaded copy stays encrypted) and try **Knowledge > Add knowledge > Upload file** in HLE HR Assistant.

**Symptom you will see.**
- Priya: 105,000, citing `Compensation-Bands-2025.docx`.
- Sofia: not found. She can see that the file exists in the library but cannot open it, and the agent does not use it for her.
- Upload: the file is rejected or fails to process. Observe and record the exact message.

**Root cause.** Encrypted content is supported only through sensitivity labels and only for the SharePoint knowledge source, and the user needs VIEW and EXTRACT usage rights (CS-K08). Uploaded files that are encrypted (by label or password) are not supported (CS-K09). Tags: SNIP.

**Fix.** Keep encrypted content in SharePoint knowledge and grant EXTRACT only to the people who should get answers from it. Never upload labeled files to an agent as a workaround: an uploaded file would be visible to every user of the agent even if it were accepted.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/security-faq, https://learn.microsoft.com/en-us/purview/ai-copilot-studio and https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-file-upload

---

## C-03-f: Authentication mode

**Caveat ID:** C-03-f

**Steps to reproduce**
1. In HLE HR Assistant, go to **Settings > Security > Authentication** and select **No authentication**. Save. Copilot Studio may warn you about features that will stop working; read the warning and continue.
2. Open **Knowledge** and look at the `HR Policies library` source.
3. In the test pane, ask `How many days can I carry over?`

**Symptom you will see.** Expected per the plan: the SharePoint knowledge source is flagged as unavailable or disabled, and the question gets no grounded answer. Observe and record the exact warning text, which is not recorded in limits.md.

**Root cause.** Tenant graph grounding requires "Authenticate with Microsoft" (CS-K04). SharePoint knowledge needs to know who the user is so it can search as that user; with no authentication there is no user identity.

**Fix.** Set authentication back to **Authenticate with Microsoft** and save. For a custom channel (for example a public website) where you need manual authentication instead, register an Entra app with the Microsoft Graph permissions Sites.Read.All and Files.Read.All (CS-K05) and configure it under **Authenticate manually**. That path is not needed in this course.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/configuration-end-user-authentication and https://learn.microsoft.com/en-us/microsoft-copilot-studio/nlu-generative-answers-sharepoint-onedrive

---

## C-03-g: Content moderation too strict

**Caveat ID:** C-03-g

**Steps to reproduce**
1. Note the current position of **Settings > Generative AI > Moderation > Content moderation level** (README step 14). At that setting, ask:
   ```text
   If a harassment complaint is about a Director, who investigates it?
   ```
   Expected: an external investigator (`Harassment-Prevention-Ontario.docx`, 5.2).
2. Drag **Content moderation level** to the right-hand end (highest moderation) and select **Save**.
3. Reset the test chat and ask again. Also try `How often is a workplace violence risk assessment done at each location?` (expected: every 3 years, `Harassment-Prevention-Ontario.docx`, 5.4).

**Symptom you will see.** Observe and record. A plausible result at the highest level is that the agent returns the flagged-response message instead of an answer. Unless you changed it, that is the default text `I can't help with that. Is there something else I can help with?`, which gives the user no clue that a filter, not missing content, stopped the answer. At **Low** (the left end), more gets through, including responses you might not want.

**Root cause.** Content moderation filters generated responses by a sensitivity threshold. HR and safety policy text legitimately discusses harassment, violence and injury, so a high threshold can block real policy answers. No limits row covers the setting; the level names (other than **Low**) and the default must be checked on Learn.

**Fix.**
1. Move the slider back to the level your organization approves (the reset arrow restores the default) and select **Save**.
2. Replace the flagged-response message with one that tells users where to go, for example:
   ```text
   I can't answer that here. For harassment, workplace violence or other sensitive HR matters, contact your HR business partner or People and Culture.
   ```
3. Re-test with the Lab 3 evals, which include harassment and safety questions (L03-Q16).

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio (general knowledge settings; the content moderation setting is not in limits.md, check Learn for its own page).

---

## C-03-h: SharePoint list 2,048-row window

**Caveat ID:** C-03-h

**Steps to reproduce**
1. In HLE Knowledge Bench, with the Vendors list added (README step 20), ask:
   ```text
   Who is the primary contact for Mohawk Valley Meter Works?
   ```
   (row 777, inside the window)
2. Ask:
   ```text
   Who is the primary contact for Northgate Pole & Crossarm?
   ```
   (row 2,501, outside)
3. Ask `Who is the primary contact for Buckeye Substation Engineering Group?` (row 2,049, the first row past the window) and `Which vendor has the largest contract value?`

**Symptom you will see.**
- Mohawk Valley: Desmond Achterberg (correct).
- Northgate and Buckeye: not found, even though the rows are in the list (correct answers: Renata Kowalczyk; Ignatius Pemberton).
- Largest contract: likely Mohawk Valley Meter Works, 4,850,000 USD (largest in the first 2,048 rows) instead of Northgate Pole & Crossarm, 7,425,000 CAD (row 2,501).

**Root cause.** SharePoint list knowledge queries use the first 2,048 rows of a list, although a list may hold up to 35,000 rows (up to 15 lists, 120,000 rows in total) (CS-K10). The Vendors list has 2,600 rows. CS-K10 is SNIP and comes from the new-experience docs; how "first" is ordered (item ID, view order) is not stated in limits.md. Check Learn.

**Fix.** Options, in order of preference:
1. Keep lists used as knowledge under 2,048 rows: move Expired vendors (378 rows) and other inactive rows into an archive list. Check the row order your tenant uses before relying on this.
2. Load large tabular data into Dataverse and use Dataverse knowledge instead (Lab 4).
3. Index it through a Copilot connector (Lab 7).

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/knowledge-sharepoint-lists

---

## C-03-i: Image-only slide content

**Caveat ID:** C-03-i

**Steps to reproduce**
1. In HLE Knowledge Bench, with the Operations `Procedures` library added, ask:
   ```text
   Where does the Eastern Ontario region stage crews this winter storm season (2026 to 2027)?
   ```
2. Ask `What is the storm call-out phone bridge number and conference ID?`
3. Ask `What is the maximum interval between lone worker check-ins?`

**Symptom you will see.** Observe and record. The correct answers exist only as pixels in `Crew-Briefing-Deck.pptx` (slides 4, 5 and 6): Napanee Fairgrounds, 4 York Road East (the Kingston yard is closed for repaving); bridge 1-844-555-0162, conference ID 4471 902 #; 45 minutes. Expected symptom if images are not read: for question 1 the agent answers **Kingston Service Centre, 1450 Sydenham Road** from the text of `Storm-Restoration-Playbook.pdf`, which is confidently wrong for this season. Questions 2 and 3 get "not found".

**Root cause.** Knowledge retrieval works on text. The deck's key values are in PNG pictures with neutral alt text. No limits row states how Copilot Studio treats images inside PPTX files in SharePoint (CS-K09 only covers uploaded files).

**Fix.** Put key values in slide text or speaker notes, or add descriptive alt text to each picture, then wait for re-indexing and ask again. Treat image-only decks as unsupported knowledge until you have tested them.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio (no limits row covers images in PPTX; observed behavior).

---

## C-03-j: Merged-cell spreadsheet

**Caveat ID:** C-03-j

**Steps to reproduce**
1. In HLE Knowledge Bench, ask:
   ```text
   What is the impedance and oil volume of pad-mount transformer model CG-PAD500-3P-27?
   ```
2. Ask:
   ```text
   How many CG-PAD500-3P-27 spares are on hand at Whitby, and is that below the reorder point?
   ```

**Symptom you will see.** Observe and record. Correct: 4.6 %Z and 1,135 L (Pad-Mount sheet, row 23); Whitby has 1 on hand against a reorder point of 2, so yes, below. Likely failure modes: values from a near-identical model (CG-PAD500-3P-27W: 3.23 %Z, 1,069 L; or CG-PAD500-3P-13), or depot columns mixed up because the depot names are merged header cells spanning "On Hand" and "Reorder Point" columns.

**Root cause.** `Transformer-Equipment-Specs.xlsx` has merged title rows, merged group headers, a units row and merged vertical group labels. Text extraction of such sheets can lose which header applies to which column. No limits row covers spreadsheet structure; treat as observed behavior.

**Fix.** Publish a flat table for knowledge: one header row, no merged cells, one row per model, model number in the first column. Or load the specs into Dataverse (Lab 4 pattern).

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio (no limits row covers merged cells; observed behavior).

---

## C-03-k: Whole-site vs library scoping

**Caveat ID:** C-03-k

**Steps to reproduce**
1. In HLE Knowledge Bench, remove the `Procedures` source and add the whole Operations site instead:
   ```text
   https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations
   ```
2. Ask:
   ```text
   Which pole was flagged for woodpecker damage in inspection memo IM-2025-0873?
   ```
   and
   ```text
   What is the qualified minimum approach distance for 27.6 kV?
   ```
3. Try adding the source with a copied view URL such as `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Archive-Bulk/Forms/AllItems.aspx?id=...`.
4. Try adding `Archive-Bulk` as its own library source (`.../sites/<Prefix>-Harbourline-Operations/Archive-Bulk`).
5. Replace everything with the `Procedures` library only and ask both questions again.

**Symptom you will see.**
- Whole site: the woodpecker question may be answered (pole P-44817 on Concession Road 9, in `Archive-Bulk/2025/09/Inspection-Memo-IM-2025-0873.docx`) because the planted memo is 1 of 1,200 files. Observe whether it is found. Procedure questions (0.85 m, 2 ft 10 in, from `Lockout-Tagout-Safety-Manual.pdf`) may pick up noise from 1,200 meter reading notes and inspection memos.
- View URL with a query string: rejected or not resolved (CS-K06).
- `Archive-Bulk` as a folder source: 1,200 files and 12 folders under a year folder, which is more files than the 1,000-file folder figure in CS-K07. Observe whether Copilot Studio warns, truncates, or accepts it (the scope of CS-K07 is unclear).
- `Procedures` only: the approach-distance answer is clean; the woodpecker question is "not found", which is correct for that scope.

**Root cause.** A whole-site source indexes everything the user can see on the site, including bulk archives, so relevant procedure content competes with volume. The URL must be a site or library path without query parameters (CS-K06). Folder sources have documented size limits (CS-K07, SNIP, scope unclear). The total number of SharePoint URLs per agent is not documented (CS-K14, UNVERIFIED).

**Fix.** Scope knowledge to the libraries that answer the agent's job (here `Procedures`), give each source a clear description, and keep bulk archives in a separate agent or out of knowledge. Use clean library URLs.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-sharepoint and https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas
