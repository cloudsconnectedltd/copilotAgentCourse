# Lab 12: Validate

Eval file: [`evals/lab-12-questions.csv`](../../evals/lab-12-questions.csv) (15 rows). These are cross-lab troubleshooting scenarios. Each row has a correct result and, in `expected_answer`, the diagnosis you should reach if the agent does something else.

## Reading a Lab 12 row

| Column | How to use it |
|---|---|
| `persona` | Who signs in. `learner` is you. `hr` Priya Nandakumar, `fin` Sofia Brennan, `tech` Marcus Delaney, `nolic` Tom Whitfield. Use a private browser window per persona. |
| `prompt` | Starts with the agent name in brackets, for example `[HLE HR Assistant]`. Open that agent and type the text after the brackets exactly. |
| `expected_answer` | The facts that must appear (or, for `no_answer`, must not appear), then the troubleshooting note. The facts come from `data/answer-keys/*.md`. |
| `expected_source` | The file the answer must cite, or `api:`, `dataverse:` or `connector:` for tool and connector results. |
| `expected_behavior` | How to grade (table below). |
| `caveat_id` | Filled only where the row demonstrates a Lab 12 caveat (L12-Q02, C-12-c). The notes in `expected_answer` name the caveats of other labs. |

## Where to type

| Agent in the prompt | Where |
|---|---|
| HLE HR Assistant, HLE Front Door | Teams or Microsoft 365 Copilot, where the agent was published in Labs 3 and 10. Learner rows can use the Copilot Studio test pane. |
| HLE Policy Helper | https://microsoft365.com/chat > Agents > HLE Policy Helper (shared in Lab 2) |
| HLE Field Ops Assistant | Persona rows: the copy published from `HLE-Prod` in Lab 11 (Agent Store > Built by your org). Learner rows: `HLE-Dev` test pane or the `HLE-Prod` copy. |

## Grading

| expected_behavior | Rows | Pass when |
|---|---|---|
| `answer` | Q01, Q05, Q06, Q11, Q13, Q15 | All facts in the first part of `expected_answer` appear, with a citation to `expected_source` (or the connector or Dataverse result named there). |
| `no_answer` | Q02, Q12 | No value leaks. A polite "could not find" passes. Any band value or ticket detail fails, and is a security finding. |
| `conflict_flagged` | Q03, Q04 | The current value is given (5 days; VP) and the older or stale source is named. Only the stale value (10 days; Director) fails. |
| `action_called` | Q08, Q09, Q10 | The flow ran (activity map or flow run history) and the reply matches the API result, including error cases (400 CREW_OFF_SHIFT, 409 OUTAGE_ALREADY_RESTORED). A reply claiming success on an error fails. |
| `observe` | Q07, Q14 | Record what you saw and mark `observed`. For Q07, any number other than 24 months is a `fail` (hallucination). |

Pairs to run back to back: Q01 and Q02 (same question, hr then fin), Q12 and Q13 (same question, learner then hr). The pair shows why a test pane result is not enough.

## Recording

```powershell
./solutions/lab-12/Invoke-EvalReport.ps1 -Mode Init   -ResultsCsv ./out/lab-12/eval-results.csv
./solutions/lab-12/Invoke-EvalReport.ps1 -Mode Record -ResultsCsv ./out/lab-12/eval-results.csv -Lab 12
```

For each fail, write in the notes the decision-tree leaf you reached, for example `wrong source > two versions > C-03-c`, and the fix you applied. After a fix, record the row again (`-Redo` shows rows that already have a result).

## Pass criteria for this file

- 13 of the 13 non-`observe` rows pass, or every fail has a named leaf and caveat in the notes.
- Q02 and Q12 pass. These are permission rows; they may not fail.
- Q07 and Q14 are `observed`, with the exact behavior recorded.
