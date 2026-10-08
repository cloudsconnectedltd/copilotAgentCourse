# Lab 04 solution: HLE Field Ops Assistant

Finished artifacts for [Lab 4](../../labs/lab-04-studio-dataverse-topics/README.md). No exported solution file is included: the Dataverse tables are created by [data/dataverse/import-dataverse.ps1](../../data/dataverse/import-dataverse.ps1), and the agent is built in the Copilot Studio portal from the files below. Lab 11 exports the solution `HLEHarbourlineOps`.

## Files

| File | What it is | How to use it |
|---|---|---|
| `hle-field-ops-assistant-instructions.txt` | Agent instructions | Paste into **Instructions** on the agent's Overview page. |
| `entities.md` | Definitions of the custom entities `HLE Asset ID` (regex) and `HLE Priority` (closed list), with test values and the Dataverse option values for Lab 5 | Create in **Settings > Entities**. |
| `dataverse-synonyms-glossary.md` | Column synonyms and glossary for the Dataverse knowledge source (copied from data/dataverse/schema.md section 6) | Enter in the Dataverse knowledge source's synonyms and glossary steps. |
| `topics/check-asset-status.yaml` | Topic with slot filling, a topic variable, a global variable and a generative answers node over Dataverse | Topic code view (see below). |
| `topics/log-field-request.yaml` | Topic with three questions (regex entity, closed list entity, free text), a condition, and an adaptive card built in Power Fx | Topic code view. |
| `topics/crew-for-asset.yaml` | Fixed version of the variable-scope break-it (C-04-b): reads `Global.LastAssetId` | Topic code view. |
| `cards/field-request-summary.json` | Static adaptive card design with sample values (TX-ON-10423, High) | Paste into an adaptive card node's JSON editor to preview; the live version is the Power Fx card in `log-field-request.yaml`. |

## Importing a topic from YAML

> **Unverified schema.** The Copilot Studio documentation was not available when this course was built, so the YAML was written from the documented code-view format (`kind: AdaptiveDialog`, `OnRecognizedIntent`, `Question`, `SetVariable`, `ConditionGroup`, `SearchAndSummarizeContent`, `SendActivity`) and checked only for YAML syntax. It was not pasted into a live tenant. Before pasting, build one small topic in the canvas, open its code view, and compare property names and variable prefixes (`init:`). Where they differ, trust your code view.

1. Create the two custom entities first (`entities.md`).
2. Open any topic that uses each entity in a question node, open **... > Open code editor**, and copy the entity name the code view shows. Replace `ENTITY_HLE_ASSET_ID` and `ENTITY_HLE_PRIORITY` in the YAML with those names.
3. **Topics > Add a topic > From blank**, then **... > Open code editor**, select all, paste the YAML, and **Save**. If the editor reports errors, fix them from what the canvas generates, or build the topic in the canvas from the node list in the lab README.
4. In each generative answers node, open the properties and limit data sources to `Harbourline field data`.
5. For `Global.LastAssetId`, open the variable in the Variables pane and confirm its scope is **Global** (any topic can read it).

## Adaptive card notes

- `version: "1.5"` is assumed. Check Learn for the highest Adaptive Card version Copilot Studio and your channel render.
- JSON mode in the adaptive card node shows static content only. To show variables, use the formula (Power Fx) editor, as in `log-field-request.yaml`.
- `Text(Topic.Priority)` converts the closed list value to its label. If Copilot Studio generates a different expression when you build the condition in the canvas, use that.
