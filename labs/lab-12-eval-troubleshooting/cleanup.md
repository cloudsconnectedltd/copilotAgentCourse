# Lab 12: Cleanup

Lab 12 creates only test sets, local files and (optionally) evaluation runs. It is also the last lab, so this page ends with the order for removing the whole course.

## Remove what this lab created

| What | Where | How |
|---|---|---|
| Evaluation test sets (`HLE HR Assistant regression (learner)`, `hr-bulk`, `hr-fin`, and any others) | Copilot Studio > each agent > **Evaluation** (UI labels may differ) | Delete each test set. Evaluation results stored with them go too. |
| Instruction change from Part D step 17 | HLE HR Assistant > Instructions | Confirm `Do not guess and do not use general knowledge.` is back, and publish. |
| Mapping file edits (C-12-b) | `solutions/lab-12/testset-column-map.json` | Revert your local edits, or keep them and tell your facilitator the working header. |
| Local output | `./out/lab-12/` | `./solutions/lab-12/Invoke-EvalReport.ps1 -Cleanup -ResultsCsv ./out/lab-12/eval-results.csv -ReportFolder ./out/lab-12/report` removes the results and report files. `./solutions/lab-12/ConvertTo-CopilotStudioTestSet.ps1 -Cleanup` with the same filters removes the test set files it wrote. Keep a copy of `eval-results.csv` and the report if you need evidence of completion. |

## Do NOT delete (yet)

| What | Why |
|---|---|
| `evals/*.csv` | Course content. The scripts never modify them. |
| All agents and environments | The final assessment (`reference/final-assessment.md`) refers to them. Remove them afterwards, in the order below. |

## End of course: removing everything

Each lab's `cleanup.md` has the details. Recommended order, so nothing is left pointing at something already deleted:

1. Lab 11 "Remove after Lab 12": Agent Store listing, managed solutions, `HLE-Test`, `HLE-Prod`, pipeline, local deployment files.
2. Lab 10: HLE Front Door (and its child HLE Policy Router). Remove the connected-agent links before deleting the specialists.
3. Lab 9: HLE Field Report Triage (turn the trigger off first), the `Triaged` folder files.
4. Lab 8: HLE Grid Advisor app registration, Azure Bot Service, Azure resources.
5. Lab 7: connector `hleTickets` (`data/connector/ingest-tickets.ps1 -Cleanup`), then detach it from agents.
6. Lab 6: HLE Outage Desk app (Teams admin center or Agents Toolkit), dev tunnels.
7. Labs 3 to 5: HLE HR Assistant, HLE Field Ops Assistant, agent flows, custom connector `HLE Outage API`, connections, then `data/dataverse/import-dataverse.ps1 -EnvironmentUrl <HLE-Dev URL> -Cleanup` (only against `HLE-Dev`), then `HLE-Dev` itself if you no longer need it.
8. Labs 1 and 2: HLE Welcome Buddy, HLE Policy Helper (Agent Builder > agent > Delete).
9. Mock API: `data/api/deploy-azure.ps1 -Cleanup` if you deployed it.
10. Tenant: `./setup/99-teardown.ps1 -TenantUrl https://<tenant>.sharepoint.com -Prefix HLE` (sites, content, labels, users, groups).
