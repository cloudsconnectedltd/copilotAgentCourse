# Lab 06 validate: run the evals

Eval file: [`evals/lab-06-questions.csv`](../../evals/lab-06-questions.csv) (19 rows).

## Before you run

- The API is running with `AUTH_MODE=apikey` behind your dev tunnel, and `OPENAPI_SERVER_URL` in `env/.env.dev` matches the tunnel.
- **HLE Outage Desk dev** is provisioned from the working project (not a break-it state).
- Restart the API host just before the run so dispatch IDs restart at `-0001`.

## Who signs in and where to type

All rows use the **learner** account, because a sideloaded agent is installed for the account that provisioned it.

1. Open https://microsoft365.com/chat and select **HLE Outage Desk dev** in the agents list.
2. Type `-developer on`. Developer mode shows the matched and executed functions, the knowledge used, and errors.
3. Start a **new chat** for every row.

Row-specific setup:

| Rows | State |
|---|---|
| L06-Q01 to L06-Q15 | Working project. |
| L06-Q16, L06-Q17 | Break-it C-06-c (run Q16 twice: with and without the 25-account instruction). |
| L06-Q18 | Break-it C-06-b throwaway project `hle-outage-desk-broken`, API in `AUTH_MODE=none`. |
| L06-Q19 | Break-it C-06-f, once with the header scheme and once with the bearer scheme. |

## How to record results

Copy the CSV to a results sheet and add: `actual_answer`, `functions_called` (from developer mode), `citations`, `result` (Pass, Fail, Observed), `notes`.

## Pass criteria

| expected_behavior | Pass when |
|---|---|
| `action_called` | Developer mode shows the expected function executed (`getOutageStatus` for `api:/api/outage-status`, `lookupCustomer` for `api:/api/customer-lookup`, `dispatchCrew` for `api:/api/crew-dispatch`), and every fact in `expected_answer` is correct. L06-Q01 must render the Adaptive Card. L06-Q06 must show the confirmation before the call. Error rows (Q07, Q08) must say no dispatch was created. L06-Q09 must also show Code Interpreter output. |
| `answer` | Correct facts and a citation to the file in `expected_source` (file name visible in the citation). |
| `conflict_flagged` | Gives the current value (v4) and mentions the conflicting older version, citing `Leave-Policy-v4-2025.pdf`. |
| `no_answer` | The agent says it does not have the information, does not cite the out-of-scope file in `expected_source`, and does not invent a value. |
| `observe` | You recorded what happened (exact error text, function status, response size where visible). Mark **Observed**. |

The lab passes when every `action_called`, `answer`, `conflict_flagged` and `no_answer` row passes and every `observe` row has a recorded observation.
