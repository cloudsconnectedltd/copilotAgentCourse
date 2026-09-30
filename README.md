# Microsoft 365 Copilot Agent Building Course

A hands-on course for building Microsoft 365 Copilot agents across every build path: Agent Builder, Copilot Studio, declarative agents with the Microsoft 365 Agents Toolkit, Copilot connectors, and custom engine agents. Each lab builds a working agent, then deliberately triggers a real caveat, limit or failure mode and shows the fix.

All data belongs to a fictional company, **Harbourline Energy Co.**, a regulated electric utility with operations in Ontario and the United States and about 2,000 staff.

## Who this is for

Microsoft 365 and SharePoint architects who already know SharePoint permissions, Entra ID and PowerShell, and want practical proficiency with Copilot agents.

## Before you start

1. Read `PLAN.md` section 3 for licenses, environments, roles and tenant settings.
2. Read `reference/limits.md`. Limits change often. Re-check any row tagged SNIP or UNVERIFIED on Microsoft Learn before the lab that uses it.
3. Install PowerShell 7, PnP.PowerShell, Microsoft.Graph, ExchangeOnlineManagement, the Power Platform CLI (`pac`), Python 3.10+ (data generation only), Node.js 20+ and Azure Functions Core Tools v4, and VS Code with the Microsoft 365 Agents Toolkit extension.
4. Run the setup scripts in order. Every script takes `-TenantUrl` and `-Prefix`, is safe to re-run, and supports `-Cleanup`.

```powershell
./setup/00-prereqs-check.ps1  -TenantUrl https://contoso.sharepoint.com -Prefix HLE
./setup/01-provision-users.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE -GuestEmail someone@outlook.com
./setup/02-provision-sites.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE
./setup/03-upload-content.ps1  -TenantUrl https://contoso.sharepoint.com -Prefix HLE
./setup/04-apply-labels.ps1    -TenantUrl https://contoso.sharepoint.com -Prefix HLE
```

Lab 1 needs none of this. It runs with only a Microsoft 365 Copilot license and the files in `data/sharepoint/getting-started.zip`.

## Lab order

| # | Lab | Build path | Time |
|---|---|---|---|
| 1 | [Getting started: your first agent](labs/lab-01-first-agent/README.md) | Agent Builder | 45 min |
| 2 | [Agent Builder deeper dive](labs/lab-02-agent-builder-deep-dive/README.md) | Agent Builder | 2.5 h |
| 3 | [Copilot Studio with SharePoint and file knowledge](labs/lab-03-studio-sharepoint-knowledge/README.md) | Copilot Studio | 4 h |
| 4 | [Copilot Studio with Dataverse and topics](labs/lab-04-studio-dataverse-topics/README.md) | Copilot Studio | 3.5 h |
| 5 | [Copilot Studio actions: flows and connectors](labs/lab-05-studio-actions-flows/README.md) | Copilot Studio, Power Automate | 3.5 h |
| 6 | [Declarative agent with Agents Toolkit](labs/lab-06-declarative-agents-toolkit/README.md) | VS Code, Agents Toolkit | 4 h |
| 7 | [Copilot connector build](labs/lab-07-copilot-connector/README.md) | Microsoft Graph connectors API | 4 h |
| 8 | [Custom engine agent](labs/lab-08-custom-engine-agent/README.md) | Microsoft 365 Agents SDK | 4 h |
| 9 | [Autonomous agent with triggers](labs/lab-09-autonomous-triggers/README.md) | Copilot Studio | 2.5 h |
| 10 | [Multi-agent orchestration](labs/lab-10-multi-agent/README.md) | Copilot Studio | 2.5 h |
| 11 | [ALM and governance](labs/lab-11-alm-governance/README.md) | Power Platform, admin centers, Purview | 3.5 h |
| 12 | [Evaluation and troubleshooting capstone](labs/lab-12-eval-troubleshooting/README.md) | Copilot Studio | 3 h |
| A | [Final assessment](reference/final-assessment.md) | None | 1 h |

Lab 7 attaches a connector to the agents from Labs 2, 3 and 6, so run it after them. Lab 9 can run any time after Lab 3.

## Lab folder format

| File | Purpose |
|---|---|
| `README.md` | Objective, build path, prerequisites, time, steps, and the caveats the lab triggers |
| `break-it.md` | Reproduce each caveat: steps, symptom, root cause, fix |
| `validate.md` | Confirm the agent works using `evals/lab-NN-questions.csv` |
| `cleanup.md` | Remove what the lab created |

Lab 1 has no `break-it.md`. It adds `facilitator-notes.md` and `recap.md` for live delivery.

## Repository layout

```
reference/   limits, build-path matrix, caveats index, glossary, site map, final assessment
setup/       tenant provisioning and teardown scripts (PowerShell 7)
data/        SharePoint documents, Dataverse seed, connector source, mock REST API
tools/       data generators for bulk and oversized files (Python)
labs/        one folder per lab
evals/       test prompts with expected answers and sources, one CSV per lab
solutions/   finished artifacts per lab
```

## Teardown

```powershell
./setup/99-teardown.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE
```

Each lab's `cleanup.md` covers artifacts created outside the setup scripts, such as agents, environments and app registrations.
