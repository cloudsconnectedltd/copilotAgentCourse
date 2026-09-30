# Lab 04 break-it: Dataverse, topics and tabular data caveats

All steps use **HLE Field Ops Assistant** in `HLE-Dev` and the Copilot Studio test pane unless a persona is named. Reset the test chat before each step. Limits come from [reference/limits.md](../../reference/limits.md). Topic and variable behavior has no limits row; those sections link to Learn pages that were not verified when the course was built (marked "slug not verified").

---

## C-04-a: Topic hijacks a knowledge question

**Caveat ID:** C-04-a

**Steps to reproduce**
1. Ask `How many open Emergency work orders are there?` and note the answer (expected: 4, WO-2026-01043, WO-2026-01083, WO-2026-01097, WO-2026-01099).
2. Open topic `Log Field Request`. Change its description to:
   ```text
   Use this topic for anything about work orders, emergencies, priorities, assets or crews.
   ```
   and add the trigger phrases `emergency work orders` and `open work orders`. Save.
3. Reset the test chat and ask the question from step 1 again.
4. Switch **Settings > Generative AI** to **Classic** orchestration, save, reset, and ask again. Switch back to **Generative** afterwards.

**Symptom you will see.** Instead of answering from Dataverse, the agent starts `Log Field Request` and asks "Which asset? Give the asset ID...". In generative mode the broad description wins; in classic mode the trigger phrase `emergency work orders` matches, and a matched topic always runs before the Conversational boosting (knowledge) fallback.

**Root cause.** Topics and knowledge compete for the same turn. With generative orchestration the model picks the capability whose description best fits; a vague, greedy description attracts questions it cannot answer. With classic orchestration, trigger phrase matching routes to the topic first and knowledge is only the fallback. No limits row applies (the number of topics and trigger phrases is itself undocumented, CS-A06).

**Fix.** Restore the narrow description from the lab ("Use only when the user wants to raise or report new work, not for questions about existing work orders.") and remove the two trigger phrases. Write topic descriptions that say what the topic does **and** what it does not do. Test common knowledge questions after adding any topic.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/advanced-generative-actions (not in limits.md; slug not verified, check Learn)

---

## C-04-b: Topic variable out of scope

**Caveat ID:** C-04-b

**Steps to reproduce**
1. Open topic `Crew For Asset`. Delete the condition that checks `Global.LastAssetId`, and change the generative answers input to:
   ```text
   "List the work orders for asset " & Topic.AssetId & " with work order number, status, assigned crew code and crew lead."
   ```
   The editor either flags `Topic.AssetId` as unknown or creates a new, empty topic variable with that name. Save.
2. Reset the test chat. Type `Check asset status TX-ON-10423`, then `Which crew worked on that asset?`

**Symptom you will see.** The second answer does not know the asset: it lists random work orders, says it cannot find the asset, or asks which asset you mean. `Topic.AssetId` held TX-ON-10423 only inside `Check Asset Status`.

**Root cause.** Topic variables are scoped to the topic that defines them. A variable with the same name in another topic is a different, empty variable. Only global variables (and values passed explicitly as topic inputs and outputs) cross topics. No limits row applies.

**Fix.** Restore [solutions/lab-04/topics/crew-for-asset.yaml](../../solutions/lab-04/topics/crew-for-asset.yaml): read `Global.LastAssetId`, which `Check Asset Status` and `Log Field Request` set. Expected after the fix: WO-2025-01280 and WO-2026-00953, both by CREW-ON-03 (lead Devon Achebe). Use globals sparingly: they persist for the whole conversation, so a stale value can answer the wrong question. The alternative is a topic input on `Crew For Asset` that the caller fills.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-variables (not in limits.md; slug not verified, check Learn)

---

## C-04-c: Glossary not applied yet

**Caveat ID:** C-04-c

**Steps to reproduce**
1. Before adding the glossary (README step 9), ask:
   ```text
   Is work order WO-2026-01076 about an Ohio asset?
   ```
   and
   ```text
   Show me open work orders about OH lines in Ohio.
   ```
2. Add the glossary (README step 10). Note the time. Immediately reset the test chat and ask both again.
3. Wait at least 15 minutes after saving, reset, and ask both again.

**Symptom you will see.** Before the glossary, and possibly right after saving it, the agent may treat "OH line" as Ohio and describe WO-2026-01076 ("RCL lockout on OH line: RCL-ON-13307") as an Ohio issue. After the wait: WO-2026-01076 is an Ontario asset (RCL-ON-13307, Barrie Depot, feeder 44M7, High, Scheduled, CREW-ON-19, due 2026-10-01); OH means overhead. Record the answer at each of the three times; the change may appear sooner than 15 minutes.

**Root cause.** Glossary and synonym updates for Dataverse knowledge can take up to 15 minutes to apply (CS-K11, SNIP). Testing immediately after saving gives a false negative. The data itself is ambiguous: `OH` is both a region code and an abbreviation in titles (schema.md section 6.2).

**Fix.** Wait up to 15 minutes before judging a glossary or synonym change, and re-test with a fresh conversation. Write glossary entries that resolve ambiguity explicitly, as the `OH` entry does.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-dataverse

---

## C-04-d: Synonym collision

**Caveat ID:** C-04-d

**Steps to reproduce**
1. Edit the `Harbourline field data` knowledge source and add the synonym `ticket number` to Work Order Number (schema.md 6.1 lists it). Save and wait 15 minutes (CS-K11).
2. Ask:
   ```text
   What is the status of ticket 104321?
   ```
3. Ask `What tickets does CREW-OH-07 hold?`

**Symptom you will see.** Observe and record. Ticket 104321 belongs to the Lab 7 ticket system (a safety investigation), not to Dataverse. The agent may search work orders for "104321", return an unrelated work order, or say not found without explaining that tickets live elsewhere. For question 3, "tickets" is also a synonym for crew **Certifications**, so the agent may answer with certifications (CREW-OH-07 is the only crew with "Live-Line Barehand 69 kV") or with work orders. Either way the word is ambiguous.

**Root cause.** Synonyms widen what a column matches. The same word mapped to two columns, and also used by another system, makes routing unpredictable. A Dataverse knowledge source can hold up to 15 tables (CS-K11); every table you add brings more column names that can collide.

**Fix.** Remove `ticket number` from Work Order Number and `tickets` from Certifications. Add synonyms only for words your users actually use for that column and nothing else. When Lab 7 adds the ticket connector, describe that source as "IT and field tickets (numeric IDs such as 104321)" so the orchestrator can tell them apart.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-dataverse

---

## C-04-e: Tabular aggregates over the Vendors list

**Caveat ID:** C-04-e

**Steps to reproduce**
1. Ask:
   ```text
   How many vendors are High risk and Active?
   ```
2. Ask:
   ```text
   Which vendor has the largest contract value?
   ```
3. Ask `How many Engineering Consulting vendors are in Ohio?`

**Symptom you will see.** Observe and record. Correct values over all 2,600 rows: 176 High risk and Active; largest contract Northgate Pole & Crossarm Ltd. (V-02501, 7,425,000 CAD); 60 Engineering Consulting vendors in Ohio. Values over the first 2,048 rows only: 144; Mohawk Valley Meter Works LLC (V-00777, 4,850,000 USD); 43. Expect answers at or below the first-window values, often a partial count from the rows retrieved for this one question, sometimes with no warning.

**Root cause.** SharePoint list knowledge queries use the first 2,048 rows (CS-K10, SNIP, new-experience docs). On top of that, generative answers summarize retrieved rows; they do not run a database aggregate over the whole list.

**Fix.** For counts and totals, use a real query: the Dataverse tables for asset and work order data, and in Lab 5 a flow or connector action that queries the list with a filter. Keep the instruction that makes the agent say how many records it based a total on. Do not present list-knowledge counts as authoritative.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/knowledge-sharepoint-lists

---

## C-04-f: Approval matrix docx vs xlsx

**Caveat ID:** C-04-f

**Steps to reproduce**
1. Temporarily delete the instruction paragraph starting "For approval thresholds, Approval-Matrix.docx..." Save.
2. Ask:
   ```text
   Who must approve a CAD 120,000 consulting engagement?
   ```
   and
   ```text
   What is the Director approval limit for consulting services?
   ```
3. Restore the paragraph, save, and ask again.

**Symptom you will see.** Without the paragraph, answers vary: "Director" (from `Approval-Matrix.xlsx`, cell D8 = 150,000) or "VP" (from `Approval-Matrix.docx`, Director limit 75,000). With the paragraph: VP, because 120,000 is above the Director's 75,000; the reply notes that the spreadsheet shows 150,000.

**Root cause.** Content, not product: the xlsx working copy is stale. The docx revision history (v3.2, 2025-04-01) says "Consulting services Director limit reduced from 150,000 to 75,000." Retrieval sees both files and nothing in the xlsx marks it as outdated. No limits row applies.

**Fix.** Keep the instruction, and fix the content: update cell D8 in the xlsx to 75,000 or remove the xlsx from the knowledge library. One authoritative source per fact.

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-sharepoint (general SharePoint knowledge guidance; content issue with no limits row)

---

## C-04-g: Developer environment is owner-only

**Caveat ID:** C-04-g

**Steps to reproduce**
1. Publish the agent, add the Teams and Microsoft 365 Copilot channel, and share it with Marcus (`<prefix>-tech@<domain>`) as an individual user.
2. Sign in as Marcus in a private browser window, open the agent in Teams, and ask:
   ```text
   What is the condition score of asset TX-ON-10423?
   ```
3. Try to give Marcus a security role in `HLE-Dev` (Power Platform admin center > HLE-Dev > Users), or to add the `<Prefix>-Ops-Ontario` group to the environment.

**Symptom you will see.** Observe and record. Expected per the docs: sharing or role assignment is blocked or limited, and Marcus cannot get Dataverse answers (an access error, or "not found"). The learner gets 38 for the same question.

**Root cause.** Developer environments are owner-only and security groups cannot be assigned (ENV-02). The Developer Plan environment is free and includes Dataverse (ENV-03), which suits a single maker, not multi-user testing.

**Fix.** Author in `HLE-Dev`, but test and run multi-user scenarios in a Sandbox or Production environment where users have a security role that can read the three tables. Lab 11 deploys the solution `HLEHarbourlineOps` to `HLE-Test` and `HLE-Prod` for exactly this reason. For this lab, persona rows are not used in the Lab 4 evals.

**Doc link.** https://learn.microsoft.com/en-us/power-platform/admin/environments-overview

---

## C-04-h: Regex entity misses variants

**Caveat ID:** C-04-h

**Steps to reproduce**
Reset the test chat and type each of these:
```text
check asset status tx-on-10423
```
```text
check asset status TX ON 10423
```
```text
check asset status TX-ON-1042
```

**Symptom you will see.** Observe and record. With the pattern from the lab, the spaced ID and the 4-digit ID do not match, so the question node asks for the asset ID again (or re-prompts after you answer). Whether lowercase matches depends on how Copilot Studio evaluates the pattern; the course sources do not document case sensitivity.

**Root cause.** A regex entity matches exactly what the pattern allows. The pattern requires uppercase type and region codes, hyphens, and exactly 5 digits. No limits row applies.

**Fix.** Decide which variants to accept. For lowercase, try the inline option `(?i)` at the start of the pattern, or use character classes such as `[Tt][Xx]`; check Learn for the supported regex syntax. Keep rejecting wrong lengths: a 4-digit ID is not a valid asset. Improve the question's re-prompt message to show the format (`TX-ON-10423`).

**Doc link.** https://learn.microsoft.com/en-us/microsoft-copilot-studio/advanced-entities-slot-filling (not in limits.md; slug not verified, check Learn)
