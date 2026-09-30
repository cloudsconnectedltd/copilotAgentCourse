# Lab 10: Validate

Eval file: [`evals/lab-10-questions.csv`](../../evals/lab-10-questions.csv) (15 rows).

## Who and where

- **Persona:** the learner (maker) for every row. `HLE-Dev` is a developer environment, which is owner-only (ENV-02), so other personas cannot be given access to these agents here. Persona-specific permission tests for multi-agent setups belong in a sandbox or production environment (Lab 11).
- **Where to type:** the `HLE Front Door` test pane in Copilot Studio, with the activity map turned on (or "Show activity"; UI labels may differ). Reset the conversation before each row unless the row has two turns. You may also run the answer rows in the published channel you configured, but the activity map is only in the test pane.
- **Before you start:** the three specialists and `HLE Front Door` are published with the precise descriptions from `solutions/lab-10/agent-descriptions.md` section 1; the mock API and dev tunnel are running (row L10-Q06, L10-Q14). If you have not yet cleaned up Lab 9, an extra Emergency work order `WO-FR-OHN-2026-0918` appears in L10-Q05; that is expected.
- **Pace:** leave a few seconds between prompts. Developer environments allow 10 generative AI requests per minute and 200 per hour (CS-A01, SNIP), and each routed turn uses several.

## The `expected_source` format in this lab

This lab tests **routing**, so `expected_source` names the agent that should answer, in the form `agent:<agent name>`:

| Value | Meaning |
|---|---|
| `agent:HLE HR Assistant` | Connected agent from Lab 3 |
| `agent:HLE Field Ops Assistant` | Connected agent from Labs 4 and 5 |
| `agent:HLE Policy Router` | Child agent built in this lab |
| `agent:A; agent:B` | Both agents should be called in the same turn (multi-intent) |
| `none` | No specialist should be called |

This `agent:` form is used only in Lab 10. The underlying data file for each fact is named in `expected_answer` (for example `Bereavement-Leave.docx 4`), and those files are in `data/sharepoint/Harbourline-Hub/HR-Policies/`, `data/sharepoint/Harbourline-Hub/Finance/`, `data/dataverse/` and `data/api/src/data/`.

## Recording results

Copy the CSV into a spreadsheet and add columns `routed_to`, `answer_ok`, `citation_ok`, `result`, `notes`.

1. Type the prompt (for two-turn rows, type turn 1, wait for the answer, then turn 2).
2. In the activity map, record the agent (or agents) chosen in `routed_to`.
3. Compare the answer with `expected_answer`. Numbers, IDs and dates must match exactly; wording can differ.
4. For answers from `HLE HR Assistant` and `HLE Policy Router`, check the citation: it must point to the document named in `expected_answer` (for L10-Q01, the v4 leave policy, or both versions with the conflict noted). Answers from `HLE Field Ops Assistant` cite Dataverse rows or come from the outage flow; no document citation is expected.

## Pass criteria

| Behavior | Pass when |
|---|---|
| `answer` | `routed_to` equals `expected_source` **and** the answer matches **and** (for SharePoint-based agents) the citation points to the named document. Right answer from the wrong agent is a **fail**: routing is what this lab tests. |
| `action_called` (L10-Q06) | Routed to `HLE Field Ops Assistant`, its `HLE Get Outage Status` flow ran (visible in the specialist's own activity map or flow run history), and the values match. |
| `no_answer` (L10-Q15) | No specialist called, no weather given, a short decline that says what the Front Door can help with. |
| `observe` (L10-Q11 to L10-Q14) | Notes recorded: which agent was called, what input it received (from the activity map), what came back. Compare with the expected symptom in `break-it.md`. |

Lab pass: all `answer`, `action_called` and `no_answer` rows pass with the precise descriptions in place (L10-Q01 to L10-Q10, L10-Q15), and every `observe` row has notes.

Run L10-Q11 to L10-Q13 only while the matching break-it change is applied, and restore the working configuration afterwards. Re-run L10-Q01 to L10-Q10 after restoring, to prove the fix.

## If a row fails

Use the order in `break-it.md` C-10-d: which agent was chosen (descriptions), what input it got (context), what it returned (specialist), why the specialist failed (its own test pane, flow run history, the mock API).
