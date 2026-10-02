# Microsoft 365 Copilot Agent Building Course

A hands-on course for building Microsoft 365 Copilot agents across every build path: Agent Builder, Copilot Studio, declarative agents with the Microsoft 365 Agents Toolkit, Copilot connectors, and custom engine agents. Each lab builds a working agent, then deliberately triggers a real caveat, limit or failure mode and shows the fix.

All data belongs to a fictional company, **Harbourline Energy Co.**, a regulated electric utility with operations in Ontario and the United States and about 2,000 staff.

## Who this is for

Microsoft 365 and SharePoint architects who already know SharePoint permissions, Entra ID and PowerShell, and want practical proficiency with Copilot agents.

## Before you start

1. Read `PLAN.md` section 3 for licenses, environments, roles and tenant settings.
2. Read `reference/limits.md`. Limits change often. Re-check any row tagged SNIP or UNVERIFIED on Microsoft Learn before the lab that uses it.
3. Install the tools for the setup scripts (see [Tools to install](#tools-to-install)). Install the rest before the lab that needs them.
4. Run the setup scripts in order. Every script takes `-TenantUrl` and `-Prefix`, is safe to re-run, and supports `-Cleanup`.

```powershell
./setup/00-prereqs-check.ps1  -TenantUrl https://contoso.sharepoint.com -Prefix HLE
./setup/01-provision-users.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE -GuestEmail someone@outlook.com
./setup/02-provision-sites.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE
./setup/03-upload-content.ps1  -TenantUrl https://contoso.sharepoint.com -Prefix HLE
./setup/04-apply-labels.ps1    -TenantUrl https://contoso.sharepoint.com -Prefix HLE
```

Lab 1 needs none of this. It runs with only a Microsoft 365 Copilot license and the files in `data/sharepoint/getting-started.zip`.

## Tools to install

Lab 1 needs only a browser and a Microsoft 365 Copilot license. Install the rest when you reach the step that needs it. `setup/00-prereqs-check.ps1` reports missing PowerShell modules.

### Windows

| Tool | Needed for | When | Install |
|---|---|---|---|
| PowerShell 7 | All setup scripts | Before setup | `winget install Microsoft.PowerShell` |
| PnP.PowerShell | Scripts 00, 02, 03, 04 (SharePoint). Needs your own Entra app registration (see [setup/README.md](setup/README.md)) | Before setup | `Install-Module PnP.PowerShell -Scope CurrentUser` |
| Microsoft.Graph | Scripts 00, 01; Lab 7 connector ingestion | Before setup | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| ExchangeOnlineManagement | Script 04 (sensitivity labels); Lab 11 audit search | Before script 04 | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` |
| Python 3.10+ and the libraries in [requirements.txt](requirements.txt) | Script 03 only: generates the 9 MB handbook and the 1,200 archive files | Before script 03 | `winget install Python.Python.3.12`, then `pip install -r requirements.txt` |
| Azure CLI | Lab 4 Dataverse import (`az login`); optional Azure deploy of the mock API | Before Lab 4 | `winget install Microsoft.AzureCLI` |
| Node.js 22 | Mock API (Labs 5, 6, 8, 10); Lab 8 agent code | Before Lab 5 | `winget install OpenJS.NodeJS.LTS` |
| Azure Functions Core Tools v4 | Runs the mock API locally (`func start`) | Before Lab 5 | `npm install -g azure-functions-core-tools@4` |
| Dev tunnels CLI | Lets Copilot and Copilot Studio reach your local API | Before Lab 5 | `winget install Microsoft.devtunnel` |
| VS Code and Microsoft 365 Agents Toolkit | Labs 6 and 8 | Before Lab 6 | `winget install Microsoft.VisualStudioCode`, then install "Microsoft 365 Agents Toolkit" from the Extensions view |
| Power Platform CLI (`pac`) | Lab 11 solution export and import | Before Lab 11 | "Power Platform Tools" VS Code extension, or see [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) |
| SQL Server (Developer or Express) | Lab 7 SQL source | Optional: `ingest-tickets.ps1` can read `tickets.csv` | Skip unless you want the SQL path |
| MicrosoftTeams module | Script 00 automatic check of the custom app upload policy | Optional: otherwise a manual check is printed | `Install-Module MicrosoftTeams -Scope CurrentUser` |

### macOS

Install [Homebrew](https://brew.sh) first. Run `Install-Module` commands inside `pwsh`.

| Tool | Needed for | When | Install |
|---|---|---|---|
| PowerShell 7 | All setup scripts | Before setup | `brew install --cask powershell`, then start it with `pwsh` |
| PnP.PowerShell | Scripts 00, 02, 03, 04 (SharePoint). Needs your own Entra app registration (see [setup/README.md](setup/README.md)) | Before setup | `Install-Module PnP.PowerShell -Scope CurrentUser` |
| Microsoft.Graph | Scripts 00, 01; Lab 7 connector ingestion | Before setup | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| ExchangeOnlineManagement | Script 04 (sensitivity labels); Lab 11 audit search | Before script 04 | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` |
| Python 3.10+ and the libraries in [requirements.txt](requirements.txt) | Script 03 only: generates the 9 MB handbook and the 1,200 archive files | Before script 03 | `brew install python`, then use a virtual environment (below) |
| Azure CLI | Lab 4 Dataverse import (`az login`); optional Azure deploy of the mock API | Before Lab 4 | `brew install azure-cli` |
| Node.js 22 | Mock API (Labs 5, 6, 8, 10); Lab 8 agent code | Before Lab 5 | `brew install node@22`, then add it to your PATH as the brew output describes |
| Azure Functions Core Tools v4 | Runs the mock API locally (`func start`) | Before Lab 5 | `brew tap azure/functions`, then `brew install azure-functions-core-tools@4` |
| Dev tunnels CLI | Lets Copilot and Copilot Studio reach your local API | Before Lab 5 | `brew install --cask devtunnel` |
| VS Code and Microsoft 365 Agents Toolkit | Labs 6 and 8 | Before Lab 6 | `brew install --cask visual-studio-code`, then install "Microsoft 365 Agents Toolkit" from the Extensions view |
| Power Platform CLI (`pac`) | Lab 11 solution export and import | Before Lab 11 | "Power Platform Tools" VS Code extension, or see [Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) |
| SQL Server | Lab 7 SQL source | Optional: `ingest-tickets.ps1` can read `tickets.csv` | No native macOS version; use the CSV path |
| MicrosoftTeams module | Script 00 automatic check of the custom app upload policy | Optional: otherwise a manual check is printed | `Install-Module MicrosoftTeams -Scope CurrentUser` |

Homebrew's Python blocks system-wide `pip install`. From the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Run `setup/03-upload-content.ps1` from a terminal where `.venv` is active, or pass `-PythonPath ./.venv/bin/python3`.

The setup scripts are written for PowerShell 7 on any platform but have not yet been run against a live tenant on either operating system. Report errors from the first run so they can be fixed.

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
| C1 | [Challenge 01: Procurement Desk](labs/challenge-01-procurement-desk/README.md) (objectives only, no steps) | Your choice | 6 h |
| A | [Final assessment](reference/final-assessment.md) | None | 1 h |

The challenge gives you a business request and objectives only, like a real engagement. Attempt it after Lab 5; its acceptance tests and marking guide are in `evals/` and `solutions/challenge-01/`, to open only after you submit.

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

## Reference

| Document | Use it for |
|---|---|
| [limits.md](reference/limits.md) | Every limit with source, date checked and verification tag |
| [agent-types-matrix.md](reference/agent-types-matrix.md) | Choosing a build path |
| [caveats-index.md](reference/caveats-index.md) | Every caveat, linked to the lab that triggers it |
| [site-map.md](reference/site-map.md) | Sites, libraries, permissions and personas |
| [glossary.md](reference/glossary.md) | Terms used in the course |
| [final-assessment.md](reference/final-assessment.md) | 25 scenarios: pick the build path, predict the caveat |

## Maintaining the course

```bash
python3 tools/build_caveats_index.py   # regenerate the caveats index from labs/*/caveats.csv
python3 tools/self-check.py            # inventory, caveat links, eval sources, Markdown links, no-dash rule
```

## Teardown

```powershell
./setup/99-teardown.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE
```

Each lab's `cleanup.md` covers artifacts created outside the setup scripts, such as agents, environments and app registrations.
