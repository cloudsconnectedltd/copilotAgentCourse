# Lab 03 solution: HLE HR Assistant and HLE Knowledge Bench

Finished configuration for [Lab 3](../../labs/lab-03-studio-sharepoint-knowledge/README.md). Copilot Studio agents are configured in the portal; this folder holds the text you paste and the settings to match. No exported solution file is included.

## Files

| File | What it is | How to use it |
|---|---|---|
| `hle-hr-assistant-instructions.txt` | Final instructions for **HLE HR Assistant** (about 1,000 characters) | Paste into the agent's **Instructions** field (Overview page). |
| `hle-knowledge-bench-instructions.txt` | Instructions for the scratch agent **HLE Knowledge Bench** | Paste into that agent's **Instructions**. The agent is deleted in cleanup. |

## Final configuration: HLE HR Assistant (environment `HLE-Dev`)

| Area | Setting | Value |
|---|---|---|
| Overview | Name | `HLE HR Assistant` |
| Overview | Description | `Answers Harbourline Energy Co. HR policy questions for employees in Ontario, New York and Ohio, using the HR-Policies library.` |
| Generative AI | Orchestration | Generative |
| Generative AI | Use general knowledge | Off |
| Generative AI | Tenant graph grounding with semantic search | On (CS-K02) |
| Generative AI | Content moderation | Default or your approved level (setting names: check Learn) |
| Security | Authentication | Authenticate with Microsoft (CS-K04) |
| Knowledge | `HR Policies library` | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies` (no query string, CS-K06) |
| Knowledge | Source description | `Harbourline HR policies: leave, parental and bereavement leave, remote work, overtime and on-call, travel, code of conduct, harassment prevention, FMLA, performance reviews, grievances, accommodation, safety incident reporting, compensation bands and the full employee handbook.` |
| Channels | Teams and Microsoft 365 Copilot | Added and published |
| Sharing | Users | `<prefix>-hr`, `<prefix>-tech`, `<prefix>-fin`, `<prefix>-nolic` and the guest, added individually (no groups in a Developer environment, ENV-02) |

## Final configuration: HLE Knowledge Bench (deleted at the end of the lab)

| Area | Setting | Value |
|---|---|---|
| Generative AI | Orchestration | Generative; general knowledge Off |
| Security | Authentication | Authenticate with Microsoft |
| Knowledge | Vendors list | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/Vendors` (list knowledge, CS-K10; may need the new experience) |
| Knowledge | Procedures library | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Procedures` |

## Moving the agent to another environment

Copilot Studio agents move between environments inside Power Platform solutions. Lab 11 covers export and import. To bring HLE HR Assistant under solution control, add it to the unmanaged solution `HLEHarbourlineOps` (created in Lab 4 by `data/dataverse/import-dataverse.ps1`) from **Power Apps > Solutions > HLEHarbourlineOps > Add existing > Agent** (UI labels may differ; check Learn).
