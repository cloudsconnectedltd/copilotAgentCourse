# Lab 12: Evaluation and troubleshooting capstone

| | |
|---|---|
| Build path | Copilot Studio (test pane, activity map, analytics, agent evaluation), Microsoft 365 Copilot, Teams, PowerShell 7 |
| Estimated time | 3 hours |
| Prerequisites | Labs [1](../lab-01-first-agent/README.md) to [11](../lab-11-alm-governance/README.md), with the artifacts each lab's `cleanup.md` says to keep: HLE Welcome Buddy, HLE Policy Helper, HLE HR Assistant, HLE Field Ops Assistant (in `HLE-Dev`, and published from `HLE-Prod` in Lab 11), HLE Outage Desk, the `HLE Tickets` connector, HLE Grid Advisor, HLE Field Report Triage, HLE Front Door. Mock API reachable ([`data/api/run-local.md`](../../data/api/run-local.md)). Persona accounts from [`setup/01-provision-users.ps1`](../../setup/01-provision-users.ps1). A lab you skipped simply produces `skipped` rows. |
| Personas used | All: learner, Priya Nandakumar (hr), Marcus Delaney (tech), Sofia Brennan (fin), Tom Whitfield (nolic), guest contractor (guest) |
| Status | PREVIEW: agent evaluation in the Copilot Studio new experience (GA in the classic docs; the two sources conflict, CS-A14). Contains UNVERIFIED items: the exact CSV columns and any row limit for evaluation test set import (no limits row). SNIP rows: CS-A01, CS-A14. |
| Limits referenced | [CS-A01, CS-A14, CS-K01, CS-K02, CS-K04, CS-K08, CS-K10, CS-K11, CS-K13, CS-A02, CS-A08, AB-06, AB-11, GC-07, DA-07, ENV-02, LIC-05, LIC-11](../../reference/limits.md) |

> **Check before you run.** Confirm these on Microsoft Learn before class. If Learn now says something different, follow Learn and tell your facilitator.
>
> | Item | Tag | What to confirm | Page |
> |---|---|---|---|
> | CS-A14 | SNIP, CONFLICT | Whether agent evaluation is GA or preview in the experience you use; test sets, CSV import, multi-turn, version comparison | https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-intro and https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/analytics-agent-evaluation-intro |
> | Test set CSV columns and row limit | UNVERIFIED | The exact header the import accepts and the maximum rows per test set. Download the template from the evaluation page if one is offered. The course converter assumes `Question` and `Expected response`; change [`solutions/lab-12/testset-column-map.json`](../../solutions/lab-12/testset-column-map.json) to match. | Same pages |
> | CS-A01 | SNIP | Generative AI message rate: 10 RPM / 200 RPH on trial and developer environments, 100 RPM / 2,000 RPH on pay-as-you-go | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
> | LIC-11 | SNIP | Credit rates, because evaluation runs are agent runs and may consume Copilot Credits (the course did not find a statement either way) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-messages-management |
>
> Copilot Studio documentation could not be read from source for this course. Where a step says "UI labels may differ", look for the concept, not the exact words.

## Objective

Run every eval in the course against the agents you built, record the results in one place, explain every failure with a named caveat, and use Copilot Studio's own tools (test pane, activity map, analytics, agent evaluation) to prove the fix. You finish with:

- `eval-results.csv`: one row per eval in `evals/lab-*-questions.csv`, with pass, fail, observed or skipped.
- A pass-rate summary by lab, persona and caveat from [`solutions/lab-12/Invoke-EvalReport.ps1`](../../solutions/lab-12/Invoke-EvalReport.ps1).
- At least one Copilot Studio evaluation test set built from the course CSVs, run, and compared across two agent versions.
- A diagnosis for every failed row, using [`troubleshooting-decision-tree.md`](troubleshooting-decision-tree.md).

## Concepts

- **Eval row.** Every lab ships `evals/lab-NN-questions.csv` with `id, persona, prompt, expected_answer, expected_source, expected_behavior, caveat_id`. `expected_behavior` says what "correct" looks like: `answer`, `no_answer` (the agent must not reveal it), `refuse`, `answer_without_citation`, `conflict_flagged` (the agent must point out two sources disagree), `action_called` (a tool must run), or `observe` (preview, SNIP or UNVERIFIED behavior: record what you see). Lab 11 uses `observe` with `admin:` sources for admin checks. Lab 12 prompts start with `[Agent name]` so you know which agent to ask.
- **Pass rate.** pass / (pass + fail). `observed` and `skipped` rows are counted but excluded from the rate.
- **Test pane and activity map.** The Copilot Studio test pane runs the agent as **you, the maker**. The activity map (or conversation trace) shows which topic, knowledge source or tool the orchestrator chose and what it returned. It is the fastest way to tell "no source was searched" from "a source was searched and returned nothing".
- **Analytics.** Aggregated sessions, outcomes and knowledge or tool use for a published agent. Use it to find patterns, not single conversations. The delay before a conversation appears is not documented in this course; check Learn.
- **Agent evaluation (CS-A14).** Test sets of questions with expected responses, imported from CSV or written in the UI, run against the agent, graded, and compared between versions. GA in the classic docs, PREVIEW in the new-experience docs.
- **Throttling (CS-A01).** Developer and trial environments allow 10 generative AI requests per minute and 200 per hour. A bulk evaluation of even 20 questions, run twice, can hit the hourly cap in a developer environment.

## Steps

### Part A: Inventory and results file (20 min)

1. Validate every eval file in the repo:

   ```powershell
   ./solutions/lab-12/Invoke-EvalReport.ps1 -Mode Validate
   ```

   It lists row counts per lab and warns about bad persona or behavior values, duplicate IDs, and `expected_source` paths that do not exist. Warnings are for your facilitator; they do not stop you.

2. Create your results file (safe to re-run; it only adds new rows and never overwrites a recorded result):

   ```powershell
   ./solutions/lab-12/Invoke-EvalReport.ps1 -Mode Init -ResultsCsv ./out/lab-12/eval-results.csv
   ```

3. Fill in this inventory before you start. Mark any agent you no longer have; its rows will be `skipped`.

   | Lab | Agent or artifact | Where it lives | How a persona reaches it |
   |---|---|---|---|
   | 1 | HLE Welcome Buddy | Agent Builder (learner's agents) | Learner only |
   | 2 | HLE Policy Helper | Agent Builder, shared in Lab 2 | https://microsoft365.com/chat > Agents |
   | 3 | HLE HR Assistant | Copilot Studio, `HLE-Dev` (or `HLE-Lab3-Sandbox` if Lab 3 used it) | Teams and Microsoft 365 Copilot channel |
   | 4, 5 | HLE Field Ops Assistant | `HLE-Dev` (maker), `HLE-Prod` (published and approved in Lab 11) | Agent Store > Built by your org |
   | 6, 7 | HLE Outage Desk, connector `HLE Tickets` | Agents Toolkit app; connector in the Microsoft 365 admin center | Microsoft 365 Copilot |
   | 8 | HLE Grid Advisor | Azure Bot Service, Teams app | Teams |
   | 9 | HLE Field Report Triage | Copilot Studio, `HLE-Dev` | No chat: drop files in `Procedures/Incoming` |
   | 10 | HLE Front Door (child HLE Policy Router) | Copilot Studio, `HLE-Dev` | Teams and Microsoft 365 Copilot channel |
   | 11 | Solution, environments, admin settings | Power Platform and Microsoft 365 admin centers, Purview | Admin portals |

### Part B: Run the evals (60 min)

4. Work lab by lab. For each lab open its `validate.md` for lab-specific rules (for example Lab 9 rows are actions, Lab 11 rows are admin checks), then record:

   ```powershell
   ./solutions/lab-12/Invoke-EvalReport.ps1 -Mode Record -ResultsCsv ./out/lab-12/eval-results.csv -Lab 3 -Persona fin
   ```

   The script shows each unrecorded row (prompt, expected answer, source) and saves after every answer (`p` pass, `f` fail, `o` observed, `s` skipped, `n` next, `q` quit).

5. Sign in as the right persona. Use one private browser window per persona so sessions do not mix: `hle-hr@<domain>`, `hle-tech@<domain>`, `hle-fin@<domain>`, `hle-nolic@<domain>`, and the guest's external address. `learner` rows use your own account.

6. Type the prompt where that build path is used:

   | Build path | Where to type | Maker shortcut (learner rows only) |
   |---|---|---|
   | Agent Builder (Labs 1, 2) | https://microsoft365.com/chat > select the agent | Agent Builder **Try it** tab |
   | Copilot Studio (Labs 3, 4, 5, 10) | Teams or Microsoft 365 Copilot, after the agent is published to that channel | Copilot Studio test pane |
   | Declarative agent (Labs 6, 7) | Microsoft 365 Copilot | none |
   | Custom engine agent (Lab 8) | Teams chat with HLE Grid Advisor | Agents Toolkit local debug |
   | Autonomous (Lab 9) | No prompt: perform the action in the `prompt` column | none |
   | Admin checks (Lab 11) | The portal path in `expected_source` | none |

   Never grade a persona row in the test pane: the test pane is the maker's identity (break-it C-12-c).

7. Grade each row:

   | expected_behavior | Pass when |
   |---|---|
   | `answer` | The answer contains the facts in `expected_answer` and cites the file in `expected_source` (or shows the API, Dataverse or connector result named there). |
   | `no_answer` | The agent does not reveal the fact. A polite "I could not find that" passes; any leaked value fails. |
   | `refuse` | The agent declines as the instructions require. |
   | `answer_without_citation` | Correct facts; no citation expected (for example tool output). |
   | `conflict_flagged` | Current value given, and the older or conflicting source named. Giving only the stale value fails. |
   | `action_called` | The tool or flow ran (check the activity map, run history or target system) and the reply matches its result. |
   | `observe` | Record what you saw in notes and mark `observed`. |

8. Run all 15 rows of [`evals/lab-12-questions.csv`](../../evals/lab-12-questions.csv) last. They are cross-lab troubleshooting scenarios: each `expected_answer` gives the correct result and the diagnosis to reach if the agent behaves differently.

### Part C: Diagnose failures with the test pane and activity map (30 min)

9. Print the failures:

   ```powershell
   ./solutions/lab-12/Invoke-EvalReport.ps1 -ResultsCsv ./out/lab-12/eval-results.csv
   ```

10. Take the first failed row for a Copilot Studio agent. Open https://copilotstudio.microsoft.com, choose the environment where the agent lives, open the agent, and open the test pane. Type the same prompt. Open the activity map (UI labels may differ; look for the map or trace view of the last turn) and answer three questions:
    - Did the orchestrator choose a knowledge source, a topic, a tool, or nothing?
    - If a knowledge source: which one, and did it return content? If a tool: what were the inputs and the output or error?
    - Does the maker get the right answer here when the persona did not?

11. Walk [`troubleshooting-decision-tree.md`](troubleshooting-decision-tree.md) from the matching symptom (does not answer, wrong source, no citation, works for maker only) to a leaf. Each leaf links to the break-it section that reproduces it. Apply the fix, re-run the row as the original persona, and record the new result with a note such as `fixed: C-03-a, grounding re-enabled`.

12. Worked example, row L12-Q02: Sofia gets no answer about grade G7 (correct), but you want to prove the agent is healthy. In the test pane you get CAD 105,000, because the learner is in every course group, including `<Prefix>-HR`, and so holds EXTRACT rights on the label (CS-K08). The test pane cannot prove Sofia's behavior. The decision tree sends you to "Works for maker only" > "persona lacks rights on the content" > Lab 3 C-03-e.

### Part D: Agent evaluation with a converted test set (40 min)

13. Convert course rows into a test set. Start small: one agent, one persona, rows that can be graded by comparing text.

    ```powershell
    ./solutions/lab-12/ConvertTo-CopilotStudioTestSet.ps1 -Lab 3,12 -Persona learner -Agent "HLE HR Assistant" -IncludeUntagged -MaxRowsPerFile 10
    ```

    The converter keeps `answer`, `conflict_flagged`, `no_answer`, `refuse` and `answer_without_citation` rows, drops `observe` and `action_called` rows, strips the `[Agent]` prefix, cuts troubleshooting notes out of the expected response (the `stopAt` markers in the mapping file), and writes `./out/lab-12/testsets/testset-*.csv`.

14. Check the columns. Open the agent in Copilot Studio (`HLE-Dev`) > **Evaluation** (in the classic experience it may sit under **Analytics**; UI labels may differ) > create a test set > import from file. If the page offers a template, download it and compare its header row with the converter output. If they differ, edit `target` values in [`testset-column-map.json`](../../solutions/lab-12/testset-column-map.json) and convert again. The column names are **UNVERIFIED** in this course.

15. Import the file, name the test set `HLE HR Assistant regression (learner)`, and run it. While it runs, watch for throttling: `HLE-Dev` is a developer environment, limited to 10 generative AI requests per minute and 200 per hour (CS-A01). Keep test sets to about 10 rows here, and run bigger sets in `HLE-Test`, which is a sandbox billed through your capacity or pay-as-you-go (100 RPM / 2,000 RPH on pay-as-you-go, CS-A01).

16. Read the results. For each failed case, open its details and compare with the course row. Expect some mismatches that are not agent defects:
    - `no_answer` rows: the evaluation grader compares text, and "I could not find that" is a correct outcome that a similarity grader may score low. Judge these yourself.
    - `conflict_flagged` rows: the expected response names both documents; an answer that gives the right value but omits the older document may still be scored as a pass. Check citations yourself.

17. Make one deliberate change: in HLE HR Assistant remove the sentence `Do not guess and do not use general knowledge.` from the instructions, publish, and run the same test set again. Use the version comparison (CS-A14) to see which cases changed. Put the sentence back, publish, and run a third time to confirm the regression is gone.

### Part E: Analytics (15 min)

18. Open HLE HR Assistant > **Analytics**, and then HLE Field Ops Assistant > **Analytics** in `HLE-Prod`. For the last 7 days note: number of sessions, how many ended resolved or escalated or abandoned (labels may differ), the most used knowledge sources or tools, and any errors. Compare with what you graded in Part B.
19. Observe and record whether your test pane conversations and evaluation runs appear in analytics. This course could not confirm how Copilot Studio counts them; do not assume.

### Part F: Report and sign-off (15 min)

20. Produce the summary and keep the files:

    ```powershell
    ./solutions/lab-12/Invoke-EvalReport.ps1 -ResultsCsv ./out/lab-12/eval-results.csv -ReportFolder ./out/lab-12/report
    ```

    Output: overall pass rate, and pass rates by lab, by persona and by `caveat_id`, plus `failures.csv`.

21. Capstone pass criteria:
    - Lab 1: every row `pass` (10 of 10, clean single-source questions).
    - Every other lab: pass rate of 80% or higher on rows that were run, not counting `observed` and `skipped`.
    - Every persona with rows run has a pass rate, and `fin`, `tech` and `hr` rows that test permission trimming (`no_answer`) are all `pass`. A leaked fact is a security finding, not a quality finding.
    - Every remaining `fail` has a note naming its decision-tree leaf and caveat ID, and either a fix or a reason it cannot be fixed (for example a documented limit such as CS-K10).
    - At least one evaluation test set run twice with a version comparison.

Now run [`validate.md`](validate.md), then [`break-it.md`](break-it.md), then [`cleanup.md`](cleanup.md).

## Caveats this lab triggers

| Caveat ID | Name | Where in break-it.md |
|---|---|---|
| C-12-a | Bulk evaluation throttled in a developer environment | [C-12-a](break-it.md#c-12-a-bulk-evaluation-throttled-in-a-developer-environment) |
| C-12-b | Course CSV rejected by the test set import | [C-12-b](break-it.md#c-12-b-course-csv-rejected-by-the-test-set-import) |
| C-12-c | Test pane and evaluation run as the maker | [C-12-c](break-it.md#c-12-c-test-pane-and-evaluation-run-as-the-maker) |
| C-12-d | Evaluation looks different in the classic and new experiences | [C-12-d](break-it.md#c-12-d-evaluation-looks-different-in-the-classic-and-new-experiences) |

## Files

| File | Purpose |
|---|---|
| [`troubleshooting-decision-tree.md`](troubleshooting-decision-tree.md) | Four symptoms, Mermaid flowchart and text, each leaf linked to a lab's break-it section |
| [`validate.md`](validate.md) | Run `evals/lab-12-questions.csv` |
| [`break-it.md`](break-it.md) | Reproduce the four evaluation caveats |
| [`cleanup.md`](cleanup.md) | What to remove at the end of the course |
| [`caveats.csv`](caveats.csv) | Caveat register rows for this lab |
| [`../../solutions/lab-12/`](../../solutions/lab-12/README.md) | `Invoke-EvalReport.ps1`, `ConvertTo-CopilotStudioTestSet.ps1`, `testset-column-map.json` |
