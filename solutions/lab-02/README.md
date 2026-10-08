# Lab 2 solution: HLE Policy Helper

Finished artifacts for [Lab 2](../../labs/lab-02-agent-builder-deep-dive/README.md). Agent Builder has no file import; copy each value into the **Configure** tab. (Owners can download a `.zip` app package from **View all agents** > **...** > **Download .zip file**, but that package cannot include embedded files and is not needed for this course.)

| File | What it is | Where it goes |
|---|---|---|
| `instructions.txt` | Final instructions for HLE Policy Helper, 2,712 characters (limit 8,000, AB-02). Includes the policy-version rule that fixes caveat C-02-f. | Configure > **Instructions** |
| `instructions-9000-chars.txt` | Deliberately oversized instructions for the break step C-02-b: exactly 9,000 characters (9,000 bytes, ASCII only, 118 LF line breaks, no trailing newline). It is the final instructions plus a pasted "policy quick reference" and worked examples, a realistic anti-pattern. | Configure > **Instructions**, only during C-02-b |
| `description.txt` | Agent description, 256 characters (limit 1,000, AB-02) | Configure > **Description** |
| `conversation-starters.md` | Three starter prompts with expected answers | Configure > **Starter prompts** |
| `knowledge-sources.md` | The five knowledge sources, their URLs and the limits they count against; the optional Fix B variant | Configure > **Knowledge** |

Name: `HLE Policy Helper` (17 characters, limit 30, AB-02).

Sharing at the end of the lab:

| Who | Role |
|---|---|
| Priya Nandakumar (`<prefix>-hr`) | Can edit (co-owner) |
| `<Prefix>-Finance` group (Sofia Brennan) | Can chat (groups can only be chat users, AB-10) |
| Tom Whitfield (`<prefix>-nolic`) | Can chat (to observe the unlicensed behavior, AB-11) |

Character counts were measured on the saved files (LF line endings) with `wc -m`. If the Agent Builder counter treats a line break as two characters, `instructions-9000-chars.txt` counts as 9,118, which is still over the limit, and `instructions.txt` stays well under it.

Limits cited here come from [reference/limits.md](../../reference/limits.md).
