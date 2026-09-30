# Lab 12: Break it

Four caveats about testing itself. They start from the end of README Part D: one test set imported and run against HLE HR Assistant in `HLE-Dev`.

Copilot Studio evaluation is documented at SNIP level only (CS-A14), and the import format has no limits row at all. Where a symptom is not documented, the section says "Observe and record" and gives what the docs lead you to expect.

---

## C-12-a: Bulk evaluation throttled in a developer environment

**Caveat ID:** C-12-a

### Steps to reproduce

1. Convert a large test set without splitting, from every lab that has HLE HR Assistant rows:

   ```powershell
   ./solutions/lab-12/ConvertTo-CopilotStudioTestSet.ps1 -Lab 2,3,10,12 -Agent "HLE HR Assistant" -IncludeUntagged -Name hr-bulk
   ```

2. Import `testset-hr-bulk.csv` into HLE HR Assistant in `HLE-Dev` and run it.
3. Immediately run it a second time, and at the same time chat with the agent in the test pane.

### Symptom you will see

Observe and record. Expected per the quotas page (CS-A01): in a developer environment the agent may answer slowly, some evaluation cases may end with an error or be marked failed without a real answer, and the test pane may reply with a rate or capacity message. Write down how many cases failed with an error rather than a wrong answer, and the exact message.

### Root cause

Copilot Studio limits generative AI messages per environment type: 10 requests per minute and 200 per hour on trial and developer environments, against 100 per minute and 2,000 per hour on pay-as-you-go (CS-A01). One evaluation case can use more than one generative request (orchestration plus a generative answer), so a few dozen cases, run twice, can exhaust the hourly allowance of `HLE-Dev`.

### Fix

- Split test sets: `-MaxRowsPerFile 10`, and wait between runs in a developer environment.
- Run full regression sets in a sandbox such as `HLE-Test` (Lab 11), which uses your tenant's capacity pack or pay-as-you-go billing instead of developer limits. Deploy the agent there with the solution from Lab 11 first.
- Treat an error-only case as `skipped`, not `fail`, and re-run it; it says nothing about answer quality.
- Remember evaluation runs are agent runs: check consumption (LIC-11) in the Power Platform admin center before scheduling large runs.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas

---

## C-12-b: Course CSV rejected by the test set import

**Caveat ID:** C-12-b

### Steps to reproduce

1. Try to import the raw course file `evals/lab-03-questions.csv` directly as a test set.
2. Then open `solutions/lab-12/testset-column-map.json`, change `"target": "Question"` to `"target": "Prompt"`, convert again, and import that file.
3. Finally, convert with the unchanged mapping but set `"stopAt"` to an empty list for the expected response, and import.

### Symptom you will see

Observe and record. Expected:

- Step 1: the import rejects the file or imports nothing useful: the course file has seven columns and a `[Agent]` prefix convention that the evaluation page does not know.
- Step 2: the import rejects the file or maps no questions, because the header does not match what the page expects. Record the message.
- Step 3: the import succeeds, but the expected responses contain diagnosis notes ("Decision tree: ..."), and a similarity-based grader scores correct answers low.

### Root cause

Agent evaluation supports CSV import of test sets (CS-A14), but the exact column names, accepted grading methods and any row limit could not be verified for this course (UNVERIFIED, no limits row). The course eval format is designed for humans grading several behaviors, including `no_answer` and `action_called`, which a text comparison cannot grade.

### Fix

- Always convert with `ConvertTo-CopilotStudioTestSet.ps1`, and match the mapping file's `target` names to the template or example shown on the evaluation page.
- Keep `stopAt` markers so only the gradable part of `expected_answer` is used.
- Keep `observe` and `action_called` rows out of test sets; grade them by hand in `Invoke-EvalReport.ps1`.
- Record the working header in your notes and tell your facilitator so `testset-column-map.json` can be updated for the next cohort.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-intro

---

## C-12-c: Test pane and evaluation run as the maker

**Caveat ID:** C-12-c

### Steps to reproduce

1. In Copilot Studio open HLE HR Assistant and, in the test pane, ask: `What is the CAD midpoint for grade G7 in the 2025 compensation bands?`
2. Sign in as Sofia Brennan (fin) in a private window and ask the same question in Teams or Microsoft 365 Copilot (row L12-Q02).
3. Build a test set from the fin rows only and run it:

   ```powershell
   ./solutions/lab-12/ConvertTo-CopilotStudioTestSet.ps1 -Lab 3,12 -Persona fin -Agent "HLE HR Assistant" -IncludeUntagged -Name hr-fin
   ```

4. Open the evaluation settings and look for an option to choose the user identity or authentication used for the run (UI labels may differ).

### Symptom you will see

- Step 1: the test pane answers CAD 105,000, citing `Compensation-Bands-2025.docx`.
- Step 2: Sofia gets no answer. This is correct: row L12-Q02 passes.
- Step 3: observe and record. Expected: cases whose expected response is "no answer" fail, because the run gets the maker's answer (105,000). Whether your version lets you run the evaluation as another identity is not documented in this course; record what the settings page offers.

### Root cause

The test pane (and, unless configured otherwise, an evaluation run) uses the maker's identity. With "Authenticate with Microsoft" (CS-K04), SharePoint knowledge is trimmed to the signed-in user's permissions, and encrypted content needs VIEW and EXTRACT usage rights (CS-K08). The learner is a member of every course group, including `<Prefix>-HR`, so the learner can see what Sofia must not. The same applies to connector ACLs (GC-07, Lab 7) in reverse: the learner is denied ticket 104321 that Priya can read (rows L12-Q12 and L12-Q13).

### Fix

- Grade permission rows (`no_answer` for a persona) only as that persona in the published channel.
- Keep test sets persona-specific (`-Persona`), and only run maker-identity test sets for rows where the learner's result is the expected one.
- For regression of trimming, add a dedicated test account with the same group membership as the persona, and use it if your evaluation version supports choosing an identity.
- Use the decision tree's "Works for maker only" branch for every row that passes in the test pane and fails for a persona.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio (CS-K04); https://learn.microsoft.com/en-us/purview/ai-copilot-studio (CS-K08)

---

## C-12-d: Evaluation looks different in the classic and new experiences

**Caveat ID:** C-12-d

### Steps to reproduce

1. Open HLE HR Assistant in the Copilot Studio experience you normally use and find agent evaluation. Note the menu path and whether it carries a preview label.
2. If your tenant offers the other experience (classic or new), switch and find evaluation again.
3. Compare: test set import, multi-turn test cases, grading methods offered, version comparison.

### Symptom you will see

Observe and record. Expected per the two Learn pages (CS-A14): the classic documentation describes agent evaluation as generally available, with test sets, CSV import, multi-turn cases and version comparison; the new-experience documentation labels it preview. Menus, grading methods and limits may differ between the two, and a test set created in one may not appear in the other.

### Root cause

Microsoft documents Copilot Studio in two parallel sets of pages, and for agent evaluation they disagree on status (CS-A14 is tagged CONFLICT). The course targets the classic experience (`PLAN.md` decision Q9).

### Fix

- Record which experience and status you used next to each evaluation result.
- Do not rely on a preview feature for release gates. Keep `Invoke-EvalReport.ps1` results as the source of truth, and use evaluation runs as extra evidence.
- Re-check both pages before each cohort; if they now agree, tell your facilitator so `reference/limits.md` can be updated.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-intro and https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/analytics-agent-evaluation-intro
