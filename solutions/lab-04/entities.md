# Lab 04 custom entities

Create both in Copilot Studio under **Settings > Entities > New entity** (classic experience; UI labels may differ, check Learn).

## HLE Asset ID (regular expression entity)

| Property | Value |
|---|---|
| Name | `HLE Asset ID` |
| Type | Regular expression (regex) |
| Pattern | `\b(POLE\|TX\|SW\|BRK\|RCL\|REG)-(ON\|NY\|OH)-\d{5}\b` |

Type the pattern without the backslashes before the pipes (those only escape the table): `\b(POLE|TX|SW|BRK|RCL|REG)-(ON|NY|OH)-\d{5}\b`

Why this pattern: asset numbers are `<TYPE>-<REGION>-<5 digits>` (data/dataverse/schema.md 3.1 and 4.3). The type and region codes are fixed lists, so the pattern rejects look-alikes such as ticket IDs (`104321`), work order numbers (`WO-2026-01043`) and crew codes (`CREW-OH-07`).

Test values:

| Input | Should match |
|---|---|
| `TX-ON-10423` | Yes |
| `SW-OH-30110` | Yes |
| `POLE-NY-20017` | Yes |
| `RCL-ON-13307` | Yes |
| `WO-2026-01076` | No |
| `CREW-OH-07` | No |
| `tx-on-10423` | Case behavior not documented in the course sources. Break-it C-04-h tests it. |
| `TX ON 10423` | No (spaces). Break-it C-04-h. |

## HLE Priority (closed list entity)

| Item | Synonyms | Dataverse `hle_Priority` value (for Lab 5) | Due target |
|---|---|---|---|
| Emergency | urgent, critical, immediate, right now, wires down, public safety | 714800000 | Next day |
| High | important, high priority, soon, this week | 714800001 | 7 days |
| Routine | normal, standard, planned, regular, when possible | 714800002 | 30 days |
| Deferred | defer, later, can wait, next outage window, low priority | 714800003 | 120 days |

Item labels match the Dataverse choice labels exactly (data/dataverse/schema.md 4.1), so a flow in Lab 5 can map them without a lookup table. Leave any "smart matching" option at its default and observe how close misspellings (for example "urgnt") are handled.
