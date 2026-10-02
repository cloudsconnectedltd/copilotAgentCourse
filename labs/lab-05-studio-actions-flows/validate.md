# Lab 05 validate: run the evals

Eval file: [`evals/lab-05-questions.csv`](../../evals/lab-05-questions.csv) (17 rows).

## Before you run

- The mock API is running with `AUTH_MODE=apikey`, the dev tunnel is up, and the tunnel host in the **HLE Outage API** connector matches the current tunnel.
- **HLE Field Ops Assistant** is published with the tools **HLE Get Outage Status** and **HLE Dispatch Crew**.
- Restart the API host (`func start`) just before the run, so dispatch IDs start again at `-0001`. Dispatches are kept in memory only.
- HLE-Dev is a developer environment. Generative AI requests are limited to 10 per minute and 200 per hour there (CS-A01, SNIP), and the Developer Plan includes 750 flow runs per month (ENV-03). Space the prompts out; if you see throttling, wait a minute and rerun the row.

## Who signs in and where to type

| Rows | Persona | Where |
|---|---|---|
| L05-Q01 to L05-Q13, L05-Q15 to L05-Q17 | Learner | Copilot Studio **Test** pane of **HLE Field Ops Assistant** (environment HLE-Dev). Start a new conversation (**Reset**) before each row. |
| L05-Q14 | Marcus Delaney (`tech`) | The channel you shared the agent to (for example Teams). If the agent is not shared with Marcus, run it as the learner in the Test pane and record "run as learner". |

Row-specific setup:

| Row | Setup before running |
|---|---|
| L05-Q13 | Normal state (flow tools on). Check the flow run output for `createdBy`. |
| L05-Q14 | Break-it C-05-a steps 3 and 4 (direct connector tool with end-user credentials, flow tool turned off). |
| L05-Q15 | Break-it C-05-b, before the fix. |
| L05-Q16 | Break-it C-05-b, after the fix. |
| L05-Q17 | Break-it C-05-d active (run once), then again after the fix. |

## How to record results

Copy the CSV to a results sheet and add four columns: `actual_answer`, `tool_called` (name of the tool from the Test pane activity map, or the flow run history), `result` (Pass, Fail, Observed) and `notes`.

## Pass criteria

| expected_behavior | Pass when |
|---|---|
| `action_called` | The activity map shows the expected tool (`HLE Get Outage Status` for `api:/api/outage-status`, `HLE Dispatch Crew` for `api:/api/crew-dispatch`), the matching flow run exists, and every fact in `expected_answer` is present and correct (numbers, IDs, times). For error rows (L05-Q08, Q10, Q11, Q12) the agent must report the API error in plain language and must not claim success or invent data. |
| `observe` | You recorded what happened, including exact error text, and it is consistent with the expected symptom. Mark **Observed**, not Pass or Fail. |

Dispatch rows pass with any dispatch ID of the form `DSP-YYYYMMDD-NNNN`; the date is the day you run the lab.

The lab passes when all `action_called` rows pass and every `observe` row has a recorded observation.
