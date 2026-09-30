# Lab 09 solution: HLE Field Report Triage

Finished source artifacts for [Lab 9](../../labs/lab-09-autonomous-triggers/README.md). There is no exported solution zip in this folder. Build the agent from these files, then (optionally) add it to the `HLEHarbourlineOps` solution and export it as described below.

| File | What it is | How to use it |
|---|---|---|
| `agent-instructions.txt` | Full instructions for the agent (rules 0 to 10) | Paste into the agent's Instructions field |
| `trigger-payload-instructions.txt` | Message the event trigger sends to the agent | Paste into the trigger's instructions or payload box; replace each `<insert ...>` with the matching dynamic value |
| `trigger-design.md` | Trigger scope, trigger condition, payload design, library-columns alternative, idempotency markers | Design reference for Part D and for C-09-a and C-09-d |
| `tools.md` | Names, descriptions, inputs and column mappings for the eight tools | Add each tool in Copilot Studio exactly as listed |
| `flow-hle-read-field-report.md` | Agent flow definition (trigger, actions, prompt text, JSON schema, expected outputs) | Build the flow in Copilot Studio or Power Automate in `HLE-Dev` |
| `escalation-card.json` | Adaptive Card (schema 1.4) for the Teams escalation | Paste into the Teams "Post card in a chat or channel" action; the agent fills the `${...}` values |
| `escalation-email.txt` | Email templates for Critical escalation and missing asset ID, with expected filled values | Reference for the email tool body and for validation |

## Build order

1. Build and test `HLE Read Field Report` on its own against the three files in `data/sharepoint/lab-09-drops/` (compare with the table in the flow file).
2. Create the agent, paste the instructions, add tools 2 to 8 from `tools.md`.
3. Add the trigger (`trigger-design.md` section 1 and 2, payload from `trigger-payload-instructions.txt`).
4. Publish, then drop files as in the lab README.

## Export (optional, feeds Lab 11)

In Copilot Studio, agents and agent flows created in `HLE-Dev` can be added to a solution. Open https://make.powerapps.com > `HLE-Dev` > Solutions > `HLEHarbourlineOps` > Add existing > Agent (and the flow). Connection references are created for the Dataverse, Teams, Outlook and SharePoint connections. Export as unmanaged for source control or managed for `HLE-Test`. Lab 11 covers pipelines; this lab does not require an export. The trigger condition from `trigger-design.md` section 2 should travel with the flow; check it after import.

## Facts this solution depends on

- Drops: `data/answer-keys/operations.md` section 8.
- Assets TX-ON-10423 (P-DV-01) and TX-OH-20871 (P-DV-03): `data/answer-keys/dataverse-connector.md` section 3.
- Choice values and due date rule: `data/dataverse/schema.md` sections 3.4 and 4.
- Limits: CS-A02, CS-A07, CS-A08, CS-A09, CS-A10, LIC-10, LIC-11, LIC-12 in `reference/limits.md`.
