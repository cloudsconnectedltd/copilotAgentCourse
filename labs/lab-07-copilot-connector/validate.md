# Lab 07: Validate

Use `evals/lab-07-questions.csv` (20 rows) to confirm that the connector is indexed, attached to the three agents, and trimmed correctly for each persona.

## Before you start

- Ingestion finished with `5000 items sent, 0 failed` and the connector page in the admin center shows the item count at or near 5,000. If you test too early, rows fail because of indexing latency (C-07-c), not because of your build.
- The `title` and `url` labels are in place (run `Set-TicketLabels.ps1 ... -Cleanup` if you did C-07-d).
- Use a separate browser profile or InPrivate window per persona, so you never test as the wrong account.

## Which agent to use for each row

The CSV has no agent column. Use this table.

| Rows | Agent | Where to type |
|---|---|---|
| L07-Q01 to L07-Q04, L07-Q07 to L07-Q09, L07-Q14, L07-Q18 to L07-Q20 | HLE Outage Desk | Microsoft 365 Copilot Chat (https://m365.cloud.microsoft/chat), select the agent in the agent list |
| L07-Q05, L07-Q06, L07-Q17 | HLE HR Assistant | Microsoft Teams or Copilot Chat, wherever you published it in Lab 3 |
| L07-Q10 to L07-Q13 | HLE Policy Helper | Microsoft 365 Copilot Chat, agent list |
| L07-Q15, L07-Q16 | Graph Explorer, `solutions/lab-07/search-api-checks.http` request 4 (with the row's query words); any shared agent the guest can open | Guest session |

HLE Outage Desk and HLE Policy Helper must be shared with the personas who test them (Lab 2 and Lab 6 sharing steps). HLE HR Assistant must be available to Priya and Sofia.

## Personas

| CSV persona | Sign in as |
|---|---|
| learner | Your own admin account (member of every course group) |
| hr | Priya Nandakumar, `<prefix>-hr@<domain>` |
| tech | Marcus Delaney, `<prefix>-tech@<domain>` |
| fin | Sofia Brennan, `<prefix>-fin@<domain>` |
| nolic | Tom Whitfield, `<prefix>-nolic@<domain>` (no Copilot license) |
| guest | The guest contractor (address passed as `-GuestEmail`) |

Passwords for new personas are in `~/.harbourline-course/<Prefix>-initial-passwords.csv` (written by `setup/01-provision-users.ps1`).

## How to run

1. Start a new chat for every row, so earlier answers do not leak into later ones.
2. Type the `prompt` exactly.
3. Compare the answer with `expected_answer` and `expected_behavior`, and check the citation against `expected_source`. For `connector:hleTickets`, the citation must be the ticket (title and link `https://tickets.harbourline.example/t/<ticket number>`).
4. Record in a copy of the CSV (add columns `result`, `notes`, `tested_at`).

## Pass criteria per expected_behavior

| expected_behavior | Pass when |
|---|---|
| answer | The facts in `expected_answer` are present and correct, and the answer cites the ticket from `expected_source`. |
| no_answer | The agent says it cannot find the ticket or has no information, and reveals none of the ticket's contents. Any detail from the ticket (for example "SI-2026-014" for 104321) is a **fail** and a security finding. |
| observe | No pass or fail. Record exactly what happened, the time, and which surface you used. These rows cover documented gaps (GC-10 for guests, license behavior for the unlicensed persona). |

A `no_answer` row that returns another ticket with similar words is still a pass if the forbidden ticket's contents are not shown. Note it anyway.

Lab pass: every `answer` and `no_answer` row passes. If an `answer` row fails for every persona, suspect indexing (wait and retry) or a missing semantic label before suspecting the ACL.

## Troubleshooting quick checks

| Symptom | Check |
|---|---|
| Nobody sees any ticket | Connector state and item count in the admin center; `connection_id` spelled `hleTickets` in `declarativeAgent.json`; wait (C-07-c). |
| A persona sees a ticket they should not | The `Resolved ACL principals` output of `ingest-tickets.ps1`: a token may map to the wrong group. Fix `-GroupMap` and re-run (items are replaced with PUT). |
| Learner cannot see 104321 | Expected (C-07-b). |
| Citations show no title or link | Semantic labels (C-07-d). |
| Connector not offered in Agent Builder or Copilot Studio | Admin enablement and roles (C-07-f). |
