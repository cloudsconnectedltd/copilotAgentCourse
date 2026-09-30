# Agent types matrix: which build path to use

Row IDs in brackets refer to [limits.md](limits.md). Rows tagged SNIP or UNVERIFIED there need a check on Microsoft Learn before you rely on them.

## Comparison

| Dimension | Agent Builder | Copilot Studio | Declarative agent (Agents Toolkit) | Custom engine agent |
|---|---|---|---|---|
| Who builds | Any licensed user, in Copilot Chat | Makers in Power Platform environments | Developers in VS Code | Developers (code) |
| Licensing to build | Microsoft 365 Copilot license, or pay-as-you-go tenant [LIC-02] | Copilot Studio User License (free) plus capacity or pay-as-you-go [LIC-06, LIC-07, LIC-09] | No Copilot license needed to build; org grounding needs Copilot license or pay-as-you-go [LIC-15] | Azure subscription for hosting and model; Copilot Credits may apply for unlicensed users [LIC-13, LIC-14 conflict] |
| Licensing to use | Users need the licenses the agent's capabilities require [AB-11, LIC-03, LIC-04] | Licensed users zero-rated in Microsoft 365 channels; others consume credits [LIC-10, LIC-11] | Same as Agent Builder (both are declarative agents) [LIC-03, LIC-04] | See LIC-13 and LIC-14 (docs conflict) |
| Orchestrator and model | Microsoft 365 Copilot orchestrator | Copilot Studio orchestrator (generative or classic); model selection options [CS-A15, CS-A16] | Microsoft 365 Copilot orchestrator | Yours |
| Knowledge sources | SharePoint (100), 1 list, OneDrive (50), 20 uploaded files, 4 public URLs, Teams chats and meetings, connectors, Dataverse [AB-04, AB-05] | SharePoint, uploaded files (500), public websites (25 generative), Dataverse (15 tables per source), SharePoint lists, connectors [CS-K01 to CS-K12] | Capabilities: OneDriveAndSharePoint, GraphConnectors, WebSearch, Dataverse, Email, TeamsMessages, People, Meetings, EmbeddedKnowledge and others [DA-02] | Whatever you implement |
| Actions | Custom actions [LIC-03] | Connectors, agent flows, custom connectors; event triggers for autonomy [CS-A02, CS-A07] | API plugins from OpenAPI (1 to 10 per agent), MCP runtime in plugin v2.4 [DA-05, DA-08] | Anything your code calls |
| Autonomy | None | Event triggers run as the author [CS-A07, CS-A08] | None | Yours to build |
| Auth to data | Signed-in user; security trimming by SharePoint and connector ACLs | "Authenticate with Microsoft" default; manual Entra app option [CS-K04, CS-K05] | Signed-in user for knowledge; plugin auth None, API key, OAuth, Entra SSO [DA-09] | Bot registration and SSO you configure [CE-02] |
| Instruction limit | 8,000 characters [AB-02] | Check Learn [CS-A05 UNVERIFIED] | 8,000 characters [DA-03] | Not applicable |
| ALM | None beyond sharing and copying; download zip for Teams sideload [AB-10] | Solutions, connection references, environment variables, pipelines [ALM-01, ENV-01] | Source control, Agents Toolkit environments, app package | Your CI/CD |
| Distribution | Share with users or groups; org-wide toggle; org catalog submission [AB-10, ADM-03] | Publish to Teams and Microsoft 365 Copilot; admin deployment [ADM-07] | Sideload (custom app upload) or admin deployment [DA-17, ADM-04] | Teams, Microsoft 365 Copilot, web and other channels [CE-02] |
| Governance | Microsoft 365 admin center Agents settings [ADM-01, ADM-02] | Power Platform admin center, DLP, managed environments, plus Microsoft 365 admin center | Microsoft 365 admin center | Azure and Microsoft 365 admin centers |
| Best for | Personal or team agents over existing content | Business process agents with topics, flows, triggers and ALM | Pro-dev agents with API actions, source control and precise manifest control | Full control of model, orchestration or non-Microsoft channels |
| Course labs | 1, 2 | 3, 4, 5, 9, 10, 11, 12 | 6, 7 | 8 |

## Decision guide

1. Does the agent need its own model, orchestration or channels outside Microsoft 365? Use a **custom engine agent** (Lab 8).
2. Does it need to act on its own (event triggers), run multi-step business logic, or move through Dev, Test and Prod with solutions? Use **Copilot Studio** (Labs 3 to 5, 9 to 11).
3. Does it call your own API, need source control, or need exact capability scoping in a manifest? Use a **declarative agent with Agents Toolkit** (Lab 6).
4. Is it a knowledge agent over content the builder already has access to, for a person or team? Use **Agent Builder** (Labs 1 and 2).
5. Is the content outside Microsoft 365? Ingest it with a **Copilot connector** (Lab 7) and attach it to any of the above.
