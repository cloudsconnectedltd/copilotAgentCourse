# Lab 09: Validate

Eval file: [`evals/lab-09-questions.csv`](../../evals/lab-09-questions.csv) (13 rows).

## How this lab's evals differ

An autonomous agent has no chat window to type into. Most rows in this file are **actions you perform** (drop a file, open a record, open a report), not prompts. The `prompt` column says what to do; `expected_answer` says what you should find afterwards.

| Column value | Meaning in this lab |
|---|---|
| `persona` = `learner` | You, signed in as the maker account. |
| `persona` = `fin` | Sofia Brennan, signed in to SharePoint in a private browser window (row L09-Q09 only, after the C-09-b folder permission is in place). |
| `expected_behavior` = `action_called` | Pass if the listed tools ran and the listed records, messages or files exist with the listed values. |
| `expected_behavior` = `observe` | No fixed pass value. Record what you see in the notes column of your results sheet, and compare with the expected symptom. These rows cover SNIP or UNVERIFIED behavior (payload fields, consumption, loop behavior). |
| `expected_source` = `dataverse:hle_workorder` or `dataverse:hle_asset` | Check the row in the `HLE-Dev` environment (make.powerapps.com > Tables). |
| `expected_source` = a file path | The drop file the run should have read. The escalation card, email and summary file must quote values from that file. |
| `expected_source` = `none` | Evidence is in the agent activity view or the Power Platform admin center, not in a data file. |

## Order and reset

Run rows in order. Rows L09-Q01 to L09-Q08 belong to the README run; L09-Q09 to L09-Q13 belong to break-it.md. Before a row that says "after ... is deleted", delete that work order in `HLE-Dev` so the idempotency check does not stop the run. Rename a drop file before re-dropping it (for example `-b`, `-fin`, `-dup`), because a same-name upload may replace the existing file rather than create one, and whether a replace fires a "file created" trigger is not documented here.

The trigger delay is not a documented value. Allow a few minutes after each drop before you mark a row as failed, and record the delay you saw.

## Where to look

| Evidence | Where |
|---|---|
| Did the trigger fire, which tools ran, what the trigger input contained | Copilot Studio > `HLE Field Report Triage` > activity view (Activity or Runs; UI labels may differ). Open the run and expand each step. |
| Work orders | https://make.powerapps.com > `HLE-Dev` > Tables > Work Order. Add columns Work Order Number, Priority, Work Type, Region, Due Date, Created By. |
| Teams escalation | Your Teams chat with the Flow bot (Workflows app). |
| Email | The learner mailbox, and Tom Whitfield's mailbox as cc if you can sign in as him (he has a base plan, no Copilot license). |
| Summary files | `Procedures/Triaged` in the Harbourline-Operations site. |
| Consumption | https://admin.powerplatform.microsoft.com > Licensing > Copilot Studio (LIC-07). |

## Recording results

Copy the CSV into a spreadsheet and add three columns: `result` (pass, fail, observed), `run_time`, `notes`. For each row:

1. Perform the action in `prompt`.
2. Open the evidence listed above.
3. Compare every value in `expected_answer`. Values are exact: work order numbers, dates, priorities, region and currency must match. Text in emails and cards must include each quoted fact; wording can differ.
4. For `action_called` rows, also confirm that no **extra** action ran (for example, no Teams card for Kingston, no work order for Watertown).

## Pass criteria

- All `action_called` rows pass (L09-Q01 to L09-Q06, L09-Q11, L09-Q13).
- L09-Q07 passes: no Watertown work order exists. Any work order on a guessed asset is a fail, even if the rest looks right.
- Every `observe` row has notes. Your notes for L09-Q08 (payload fields), L09-Q10 (credits per run) and L09-Q12 (runs before stop) go to your facilitator, because those values are UNVERIFIED in `reference/limits.md` (CS-A10, LIC-12) or not documented.
- The escalation card and email cite the report they came from: each must contain the Report ID from `expected_source` (FR-OHN-2026-0918 for Ashtabula).

If a row fails, check in this order: the agent is published; the trigger is on; the trigger scope matches `/Procedures/Incoming`; the `HLE Read Field Report` flow run succeeded (open it in Power Automate); the idempotency row was deleted before the retest.
