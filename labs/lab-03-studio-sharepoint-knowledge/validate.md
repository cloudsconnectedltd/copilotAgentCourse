# Lab 03 validate: run the evals

Eval file: [evals/lab-03-questions.csv](../../evals/lab-03-questions.csv) (25 prompts).

## Before you start

Put the agents in their final lab state:

| Agent | Setting | Value |
|---|---|---|
| HLE HR Assistant | Orchestration | Generative |
| HLE HR Assistant | Authentication | Authenticate with Microsoft (CS-K04) |
| HLE HR Assistant | Tenant graph grounding | On (CS-K02) |
| HLE HR Assistant | Content moderation | The default, or your organization's approved level |
| HLE HR Assistant | Instructions | Full text from [solutions/lab-03/hle-hr-assistant-instructions.txt](../../solutions/lab-03/hle-hr-assistant-instructions.txt), including the conflicting-versions paragraph |
| HLE HR Assistant | Knowledge | `HR Policies library` only (remove any uploaded files from break-it) |
| HLE Knowledge Bench | Knowledge | `Procedures` library and `Vendors` list only |

Publish both agents after the last change. Rows L03-Q01 to Q19 go to **HLE HR Assistant**. Rows marked "(HLE Knowledge Bench)" in the prompt (Q20 to Q25) go to **HLE Knowledge Bench**; do not type the text in parentheses.

## Who signs in, and where

| `persona` value | Account | Where to type |
|---|---|---|
| learner | Your admin account | Copilot Studio test pane (reset the chat between rows), or Teams |
| hr | `<prefix>-hr@<domain>` (Priya) | Teams or https://microsoft365.com/chat, in a private browser window |
| tech | `<prefix>-tech@<domain>` (Marcus) | Same |
| fin | `<prefix>-fin@<domain>` (Sofia) | Same |
| nolic | `<prefix>-nolic@<domain>` (Tom) | Same |
| guest | Guest contractor account | Teams, signed in to your tenant as a guest |

Never use the test pane for rows where the persona is not `learner`: the test pane runs as you and you can see everything.

If you used the fallback in README step 15 (`HLE-Lab3-Sandbox`), run persona rows against that copy of the agent.

## How to record results

1. Copy `evals/lab-03-questions.csv` to a working file and add two columns: `result` (pass, fail, observed) and `notes`.
2. Type each `prompt` exactly as written. Start a new conversation for each row.
3. Record the answer text, whether a citation was shown and which file it pointed to.

## Pass criteria by `expected_behavior`

| Value | Pass when |
|---|---|
| answer | The answer contains the facts in `expected_answer` (numbers must match exactly) **and** a citation points to the file in `expected_source`. An answer without the citation is a fail for this lab. |
| no_answer | The agent says it could not find the information, and no fact from `expected_source` appears anywhere in the reply. Any leaked restricted fact is a fail, even with a disclaimer. For the guest, being unable to open the agent is also a pass. |
| conflict_flagged | The current value from `expected_source` (Leave Policy v4.0) is given, cited, and the reply mentions that an older version (v3.0) says something different. The current value without the conflict note is a partial pass; the v3 value alone is a fail. |
| observe | Record exactly what happened in `notes`. The row passes once the result is recorded. Compare with the correct fact in `expected_answer` and the expected symptom in [break-it.md](break-it.md). |

## Lab pass mark

- All `answer`, `no_answer` and `conflict_flagged` rows for personas `hr`, `fin`, `tech` and `guest` that test the Restricted folder or the label (Q06 to Q12) must pass. A single leak is a lab failure: stop and fix SharePoint permissions or the label before continuing.
- At least 90 percent of the remaining `answer` rows pass.
- Every `observe` row has notes.

Copilot Studio's own agent evaluation can import test sets from CSV (CS-A14), but its column format differs from this file. Lab 12 covers that.
