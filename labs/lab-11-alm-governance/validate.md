# Lab 11: Validate

Eval file: [`evals/lab-11-questions.csv`](../../evals/lab-11-questions.csv) (12 rows).

## How this lab's evals differ

Lab 11 builds governance, not answers, so its evals are **admin checks**. Each row asks you to open an admin surface (or run a script) and compare what you see with `expected_answer`. The format of the file is the course standard (`id,persona,prompt,expected_answer,expected_source,expected_behavior,caveat_id`), used like this:

| Column | Value in this lab | Meaning |
|---|---|---|
| `persona` | `learner` for all admin checks; `tech` or `hr` where a persona must act first | `learner` means you, signed in with the admin roles from `PLAN.md` section 3 (Power Platform Administrator, AI Administrator, audit search role). |
| `prompt` | An instruction, not a chat prompt | What to open or run. |
| `expected_answer` | What the admin surface should show | Values you must see, for example environment type, managed status, solution version, request state. |
| `expected_source` | `admin:<portal> > <path>` | The portal and menu path where the evidence lives, for example `admin:Microsoft 365 admin center > Agents > All agents > Requests` or `admin:Power Platform admin center > Manage > Environments`. A few rows use `admin:pac CLI` or `admin:Microsoft Graph` for a scripted check. Menu labels may differ from the path (several admin pages are SRC-STALE, see README). |
| `expected_behavior` | `observe` in every row | There is no agent answer to grade. You observe the admin surface and record whether it matches. |
| `caveat_id` | Blank, or the `C-11-x` the check guards against | |

The `admin:` prefix in `expected_source` is specific to this lab. `solutions/lab-12/Invoke-EvalReport.ps1` accepts it.

## When to run

Run the rows after README Part G, in order. Rows L11-Q05 and L11-Q06 must pass before you start break-it.md (they confirm a clean baseline). If you took the fallback path (README Part D2), L11-Q04 uses the `admin:pac CLI` evidence and L11-Q05 is recorded as `skipped` with the note "fallback path, no pipeline".

## Recording results

1. Copy the rows into your results sheet, or let the capstone script create it:

   ```powershell
   ./solutions/lab-12/Invoke-EvalReport.ps1 -Mode Init
   ./solutions/lab-12/Invoke-EvalReport.ps1 -Mode Record -Lab 11
   ```

2. For each row, perform the `prompt`, compare with `expected_answer`, and record:

   | Result | When |
   |---|---|
   | `pass` | Every value in `expected_answer` matches, and you found it at the `expected_source` path (or the current equivalent path, which you note). |
   | `fail` | A value differs (wrong environment type, non-managed target, unmanaged layer present, request stuck, no audit record). Note what you saw. |
   | `observed` | The row describes preview or SNIP behavior (L11-Q11, L11-Q12) and you recorded what you saw without a fixed pass value. |
   | `skipped` | The prerequisite does not exist in your tenant (for example no premium licensing, so no pipeline). Say why. |

3. Take a screenshot for every `fail` and every `observed` row. Your facilitator uses them to update the lab when admin portals change.

## Pass criteria

- All rows except L11-Q11 and L11-Q12 are `pass` (or `skipped` with a stated reason for L11-Q05).
- L11-Q11 and L11-Q12 are `observed` with the values you saw written in the notes: the pending-request output from Graph, and the `AppIdentity` / `AgentId` values from the audit record.
- Every `fail` has a matching break-it section identified in your notes, or a support note for your facilitator.
