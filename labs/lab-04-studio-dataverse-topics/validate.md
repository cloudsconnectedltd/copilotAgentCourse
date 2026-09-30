# Lab 04 validate: run the evals

Eval file: [evals/lab-04-questions.csv](../../evals/lab-04-questions.csv) (20 prompts).

## Before you start

| Check | Value |
|---|---|
| Agent | `HLE Field Ops Assistant` in `HLE-Dev`, published |
| Orchestration | Generative |
| Knowledge | `Harbourline field data` (Dataverse: Asset, Work Order, Crew), Finance library, Vendors list |
| Glossary | Saved **at least 15 minutes ago** (CS-K11) |
| Synonyms | As in [solutions/lab-04/dataverse-synonyms-glossary.md](../../solutions/lab-04/dataverse-synonyms-glossary.md), **without** `ticket number` (remove it if you added it in break-it C-04-d) |
| Topics | `Check Asset Status`, `Log Field Request` (narrow description, no broad trigger phrases), `Crew For Asset` (fixed version using `Global.LastAssetId`) |
| Instructions | Full text from [solutions/lab-04/hle-field-ops-assistant-instructions.txt](../../solutions/lab-04/hle-field-ops-assistant-instructions.txt), including the approval-matrix paragraph |

## Who signs in, and where

All rows use persona `learner`. Type them in the Copilot Studio **test pane** or in Teams as the learner. Persona rows are not used in this lab because `HLE-Dev` is a Developer environment and is owner-only (ENV-02, break-it C-04-g).

Reset the conversation before every row, **except** L04-Q15, which must be sent in the same conversation right after L04-Q14. Do not type the text in parentheses.

Open the test pane's activity map (or conversation trace) for topic rows (Q11 to Q15) so you can see which topic ran and which questions were skipped.

## How to record results

Copy the CSV to a working file and add `result` (pass, fail, observed) and `notes`. For each row record the answer, the citation (table or file), and for topic rows which topic ran.

## Pass criteria by `expected_behavior`

| Value | Pass when |
|---|---|
| answer (knowledge rows) | The facts in `expected_answer` are present and exact (IDs, numbers, dates), and the citation points to the Dataverse table named in `expected_source` (`dataverse:hle_asset`, `dataverse:hle_workorder`, `dataverse:hle_crew`) or to the file path given. |
| answer (topic rows Q11, Q12, Q14, Q15) | The named topic ran, the questions that should be skipped were skipped (slot filling), and the output matches. For Q12 the adaptive card shows asset SW-OH-30110, priority Emergency and your description. `expected_source: none` means no citation is required. |
| answer (Q13) | The reply gives 4 from Dataverse. If `Log Field Request` starts instead, that is a fail: C-04-a is still in place. |
| conflict_flagged | The docx value (VP for Q16, 75,000 for Q17) is given and cited, and the reply mentions that the xlsx shows a different value. The docx value without the note is a partial pass; the xlsx value is a fail. |
| observe | Record exactly what happened. Compare with the correct values in `expected_answer`. The row passes once recorded. |

## Lab pass mark

- Q11 to Q15 all pass (topics, slot filling, global variable, no hijack).
- At least 90 percent of the other `answer` and `conflict_flagged` rows pass.
- Every `observe` row has notes.
