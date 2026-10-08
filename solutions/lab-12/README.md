# Lab 12 solution files

Tools for [Lab 12: Evaluation and troubleshooting capstone](../../labs/lab-12-eval-troubleshooting/README.md). Nothing here is imported into the tenant; the scripts read `evals/lab-*-questions.csv` and write local files only.

| File | What it is | How to use it |
|---|---|---|
| [`Invoke-EvalReport.ps1`](Invoke-EvalReport.ps1) | Discovers every `evals/lab-*-questions.csv` at run time (it does not depend on specific rows), keeps one results CSV, and reports pass rates. Modes: `Validate` (header, duplicate ids, persona and behavior values, `expected_source` paths that do not exist in the repo), `Init` (create or merge the results file, never overwriting recorded results), `Record` (interactive, or `-Id ... -Result ...`), `Report` (default: overall, by lab, by persona, by `caveat_id`, failures; `-ReportFolder` writes CSVs). Filters: `-Lab`, `-Persona`, `-CaveatId`. `-Cleanup` removes the results and report files, never the eval files. | `./Invoke-EvalReport.ps1 -Mode Init`, then `-Mode Record -Lab 3`, then `-ReportFolder ./out/lab-12/report` |
| [`ConvertTo-CopilotStudioTestSet.ps1`](ConvertTo-CopilotStudioTestSet.ps1) | Converts course eval rows into CSV test sets for Copilot Studio agent evaluation (CS-A14). Output columns come from the mapping file. Filters by lab, persona and `[Agent]` prompt prefix; keeps only text-gradable behaviors; can split files (`-MaxRowsPerFile`). `-Cleanup` removes the files it would write. | `./ConvertTo-CopilotStudioTestSet.ps1 -Lab 12 -Persona learner -Agent "HLE HR Assistant" -MaxRowsPerFile 10` |
| [`testset-column-map.json`](testset-column-map.json) | Column mapping for the converter: `columns` (each with `target` and either `source` or constant `value`, optional `stopAt` markers that cut troubleshooting notes out of the expected response), `includeBehaviors`, `stripAgentPrefix`, `encoding`. | Edit the `target` names to match the import template on the evaluation page. |

## Result values and pass rate

| Result | Meaning | In the pass rate? |
|---|---|---|
| `pass` | Matches `expected_answer` and `expected_behavior` | Yes |
| `fail` | Does not match | Yes |
| `observed` | Preview, SNIP or UNVERIFIED behavior recorded without a fixed pass value | No |
| `skipped` | Prerequisite missing (agent removed, lab skipped, no premium licensing) | No |
| (blank) | Not run yet | No, shown as `not_run` |

Pass rate = pass / (pass + fail).

## UNVERIFIED: test set import format

The exact CSV header, grading methods and row limit that Copilot Studio agent evaluation accepts for test set import could not be read from any Microsoft Learn source while this course was built. The default mapping (`Question`, `Expected response`) is an assumption. Before your first import, compare it with the template or example on the evaluation page and with https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-intro, and edit `testset-column-map.json`. No test data needs to change.

## Checks done

Both scripts are PowerShell 7 with `[CmdletBinding()]`, `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, `-TenantUrl`, `-Prefix` (default `HLE`), `-Cleanup` and comment-based help. They were syntax-checked with the PowerShell parser and run locally against the repository's eval files (Validate, Init, Record, Report, conversion, cleanup). They were not run against Copilot Studio.
