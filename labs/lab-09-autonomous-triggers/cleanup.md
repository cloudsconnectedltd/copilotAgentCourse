# Lab 09: Clean up

Remove what this lab created. Do the steps in order: stop the trigger first so cleanup itself does not start new runs.

## Remove

1. **Turn off the trigger and unpublish.** Copilot Studio > `HLE-Dev` > `HLE Field Report Triage` > Overview > Triggers: turn the trigger off or delete it. This stops new runs and new Copilot Credit consumption (C-09-c).
2. **Delete work orders the lab created.** make.powerapps.com > `HLE-Dev` > Tables > Work Order. Filter Work Order Number begins with `WO-FR-`. Delete `WO-FR-EON-2026-1187`, `WO-FR-OHN-2026-0918`, and any duplicates or junk rows from the C-09-d loop (sort by Created On for today). Do not delete rows whose numbers follow the seed pattern `WO-<year>-<5 digits>`; they are seed data used by Labs 4, 5, 10 and 11.
   - Alternative: re-running `data/dataverse/import-dataverse.ps1` does not remove extra rows; it only upserts seed rows. Delete lab rows by hand.
3. **Delete the agent.** Copilot Studio > Agents > `HLE Field Report Triage` > Delete.
4. **Delete the agent flow.** Copilot Studio > Flows (or Power Automate > `HLE-Dev` > My flows) > `HLE Read Field Report` > Delete. Also delete the prompt the flow used (`HLE Extract Field Report`) if you created one.
5. **Remove connections created only for this lab.** Power Automate > `HLE-Dev` > Data > Connections. Remove the Microsoft Teams and Office 365 Outlook connections if no other lab uses them. Keep the SharePoint and Dataverse connections if Lab 5 flows use them (check "Used by" before deleting).
6. **Empty the folders.** In `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Procedures`:
   - Delete every file in `Incoming` (the drops and their renamed copies, and any `Field-Report-Triage-*` files from C-09-d).
   - Delete the `Triaged` folder.
7. **Remove Sofia's folder access (C-09-b).** Select `Incoming` > Manage access > Advanced settings (or the permissions page) > **Delete unique permissions** so the folder inherits from the library again. Confirm Sofia Brennan no longer appears.
8. **Delete the Flow bot chat and emails** if your tenant keeps test mail; optional.

## Do NOT delete

| Item | Why |
|---|---|
| The `Procedures/Incoming` folder | Created by `setup/02-provision-sites.ps1`. Re-running this lab and `setup/99-teardown.ps1` expect it. |
| Asset, Crew and seed Work Order rows in `HLE-Dev` | Used by Labs 4, 5, 10, 11 and 12. |
| Environment `HLE-Dev` | Used by Labs 4, 5, 10, 11. |
| `HLE HR Assistant` (Lab 3) and `HLE Field Ops Assistant` (Labs 4 and 5) | Lab 10 connects them to `HLE Front Door`. |
| Files in `data/sharepoint/lab-09-drops/` | Local course data, not tenant objects. |

## Check

- Copilot Studio shows no `HLE Field Report Triage` agent.
- Work Order table has no rows starting `WO-FR-`.
- Dropping a file into `Incoming` starts nothing (then delete that file).
- A few days later, the Copilot Studio consumption report for `HLE-Dev` shows no new rows for `HLE Field Report Triage`.
