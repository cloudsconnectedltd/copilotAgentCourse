# Lab 1 solution: HLE Welcome Buddy

Finished configuration for the Agent Builder agent built in [Lab 1](../../labs/lab-01-first-agent/README.md). Agent Builder has no import for these files: you copy and paste each value into the **Configure** tab.

| File | What it is | Where it goes in Agent Builder |
|---|---|---|
| `instructions.txt` | Agent instructions, 1,673 characters (limit 8,000, AB-02) | Configure tab > **Instructions** |
| `description.txt` | Agent description, 177 characters (limit 1,000, AB-02) | Configure tab > **Description** |
| `conversation-starters.md` | Three starter prompts with titles and expected answers | Configure tab > **Starter prompts** |

Other settings:

| Setting | Value |
|---|---|
| Name | `HLE Welcome Buddy` (17 characters, limit 30, AB-02) |
| Knowledge, option A (recommended) | Upload the five `.docx` files extracted from `data/sharepoint/getting-started.zip` (5 of the 20 embedded files allowed, AB-05; `.docx` up to 512 MB each, AB-08) |
| Knowledge, option B | SharePoint URL `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Getting-Started` (only if the facilitator ran the setup scripts) |
| Capabilities | Leave at the defaults. The lab does not use them. |

Character counts were measured on the files as saved (LF line endings). The Agent Builder counter may count line breaks differently; the text stays far below the limit either way.

Limits cited here come from [reference/limits.md](../../reference/limits.md).
