# Lab 02: Validate HLE Policy Helper

Run the 20 rows in [`evals/lab-02-questions.csv`](../../evals/lab-02-questions.csv). Allow about 20 minutes.

## Before you start

The evaluation assumes this final state:

| Item | Expected state |
|---|---|
| HLE Policy Helper instructions | Full [`solutions/lab-02/instructions.txt`](../../solutions/lab-02/instructions.txt), including `# Policy versions and conflicts` (Fix A for C-02-f) |
| HLE Policy Helper knowledge | HR-Policies library, Finance library, Vendors list, two uploaded files; **Only use specified sources** on. None showing **Preparing**. |
| Updates published | You selected **Update** after your last edit and waited a few minutes |
| Sharing | Priya (hr) **Can edit**; `<Prefix>-Finance` group **Can chat**; Tom (nolic) **Can chat** |
| HLE Scope Test | Still exists (rows L02-Q19 and L02-Q20); delete it only after validation |

## Who signs in and where to type

Use a separate InPrivate window (or browser profile) per persona, and sign out between personas.

| Rows | Persona | Account | Where |
|---|---|---|---|
| L02-Q01, Q03 to Q06, Q08, Q18 | hr (Priya Nandakumar) | `<prefix>-hr@<domain>` | `https://microsoft365.com/chat` > **HLE Policy Helper** in the left pane (or **View all agents**; Priya is a co-owner) |
| L02-Q02, Q07, Q09 to Q15 | fin (Sofia Brennan) | `<prefix>-fin@<domain>` | Open the chat link from the Share dialog, then use the agent from the left pane |
| L02-Q16, Q17 | nolic (Tom Whitfield) | `<prefix>-nolic@<domain>` | Open the chat link from the Share dialog |
| L02-Q19, Q20 | learner | your account | **HLE Scope Test** on the **Try it** tab. Q19 with the whole Operations site as knowledge; Q20 after scoping to `Archive-Bulk/2025/09` (C-02-g steps) |

Select **New chat** before every row.

## How to record

Copy the CSV and add columns `actual_answer`, `cited_document`, `result` (`PASS`, `FAIL` or `OBSERVED`), and `notes`. Paste each `prompt` exactly.

## Pass criteria by expected_behavior

| expected_behavior | Rows | PASS when |
|---|---|---|
| `answer` | Q04 to Q06, Q08 to Q15, Q20 | The answer contains the facts in `expected_answer` (numbers, names and dates exact) **and** cites the file named in `expected_source`. For `Vendors.csv` rows, the citation is the **Vendors** list. For Q15, the citation is the uploaded `IT-Help-Desk-FAQ.docx`. |
| `conflict_flagged` | Q01 to Q03 | The answer gives the version 4.0 value, cites `Leave-Policy-v4-2025.pdf`, **and** mentions that version 3.0 gives a different value and was replaced. If it gives the right value and citation but no mention of v3, record PASS with the note "not flagged" and review your instructions. If it gives the v3 value, FAIL. |
| `no_answer` | Q07, Q18 | The agent says it could not find the information and does not reveal the value. For Q07, any mention of "24 months" or a citation to a Restricted file is a FAIL: it would mean Sofia can read HR-only content. |
| `observe` | Q16, Q17, Q19 | No pass or fail. Record exactly what happened (error text, whether the agent could be added, the answer and citation). Compare with the expected behavior in the row and in break-it.md. Mark `OBSERVED`. |

If you kept **Fix B** for C-02-f (v3 removed from knowledge), score Q01 to Q03 as PASS when the version 4.0 value is given with the v4 citation; no mention of v3 is expected.

The lab passes when all 14 `answer` and `no_answer` rows pass, all 3 `conflict_flagged` rows give the version 4.0 value, and all 3 `observe` rows are recorded.

## If a row fails

| Symptom | Likely cause | Fix |
|---|---|---|
| Q01 to Q03 give v3 values (18, 10, 22) | The version rule is missing, or the update was not published | Check the instructions for `# Policy versions and conflicts`, select **Update**, wait, retry |
| Q07: Sofia sees the 24-month value | Restricted folder permissions are wrong, or the file was uploaded as an embedded file | Check the folder permissions (re-run `setup/02-provision-sites.ps1`, which re-applies them). Never upload Restricted files. |
| Q06: Priya gets no answer | Priya is not in `<Prefix>-HR`, or the source is still preparing | Check group membership (`setup/01-provision-users.ps1`), wait, retry |
| Q12 to Q14: no vendor answer | The list was added by site URL, not list URL | Remove it and add `.../Lists/Vendors` (C-02-a notes) |
| Q15: no answer for Sofia | The uploaded file was removed, or the agent was not reshared after the update | Check **Uploaded files**; reshare the agent with the same users |
| Every fin row fails with an access message | The Finance group share did not complete | Open **Share** and check `<Prefix>-Finance` is listed as **Can chat** |

Keep your results: Lab 7 reruns selected rows after attaching the HLE Tickets connector, and Lab 12 reruns the whole file.
