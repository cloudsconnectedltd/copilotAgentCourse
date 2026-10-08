# Lab 01: Validate HLE Welcome Buddy

Run the ten questions in [`evals/lab-01-questions.csv`](../../evals/lab-01-questions.csv) against the finished agent. This takes about 10 minutes.

## Who signs in and where to type

| Item | Value |
|---|---|
| Persona | learner (your own account, the one that built the agent) |
| Where | Microsoft 365 Copilot Chat (`https://microsoft365.com/chat`), with **HLE Welcome Buddy** selected in the left pane. The **Try it** tab in Agent Builder also works while you are still building. |
| Conversation | Select **New chat** before each question so earlier answers do not influence the next one. |

## How to run

1. Open the CSV in Excel or any text editor. Columns: `id, persona, prompt, expected_answer, expected_source, expected_behavior, caveat_id`.
2. Add three columns to your copy: `actual_answer`, `cited_document`, `result`.
3. For each row, paste the `prompt` exactly as written, press **Enter**, and record:
   - the key facts from the answer in `actual_answer`
   - the file name shown in the citation in `cited_document`
   - `PASS` or `FAIL` in `result`

## Pass criteria

A row passes when all three are true:

1. **Facts match.** The answer contains the facts in `expected_answer`. Wording can differ; numbers, names, phone numbers and dates must match exactly.
2. **Citation matches.** The answer cites the file named at the end of `expected_source` (for example `Vacation-Policy.docx`). If you used Option B (SharePoint), the citation is the same file in the `Getting-Started` library.
3. **Behavior matches.** Every row in this lab has `expected_behavior = answer`: a grounded answer with a citation. No row expects a refusal.

The lab passes at **10 of 10**. The Getting-Started documents are clean by design (every fact has exactly one home document), so a failure points to the build, not the data.

## If a row fails

| Symptom | Likely cause | Fix |
|---|---|---|
| Answer is correct but has no citation | Knowledge was still uploading or preparing when you asked | Wait until all five files show normally (Option A) or the **Preparing** label clears (Option B), then select **New chat** and ask again. |
| Answer comes from general knowledge (for example a generic vacation number) | A file is missing from **Knowledge** | Open the agent, select **Edit**, check that all five files are listed, then select **Update**. |
| Citation names the right file but a number is wrong | Rare model error | Ask again in a new chat. Record both results. If it repeats, add the rule "Quote numbers exactly as written in the source document" to the instructions and select **Update**. |
| Every document is cited twice | Both Option A and Option B were added | Remove one knowledge source and select **Update**. |

Keep your results. Lab 12 reruns this file as part of the capstone evaluation.
