# Lab 04 cleanup

Lab 4 builds things that Labs 5, 9, 10 and 11 need. Cleanup here only removes break-it leftovers.

## Remove or revert now

| Item | Where | How |
|---|---|---|
| Broad description and trigger phrases on `Log Field Request` (C-04-a) | Topics > Log Field Request | Restore the description `Log a new field request for one specific asset, with a priority and a description of the problem. Use only when the user wants to raise or report new work, not for questions about existing work orders.` Remove `emergency work orders` and `open work orders`. |
| Broken `Crew For Asset` (C-04-b) | Topics > Crew For Asset | Replace with [solutions/lab-04/topics/crew-for-asset.yaml](../../solutions/lab-04/topics/crew-for-asset.yaml) or rebuild the `Global.LastAssetId` condition. Delete any orphan topic variable `Topic.AssetId` the editor created. |
| Synonyms `ticket number` and `tickets` (C-04-d) | Knowledge > Harbourline field data > synonyms | Remove `ticket number` from Work Order Number. Removing `tickets` from Certifications is recommended before Lab 7. |
| Temporary instruction edits (C-04-f) | Overview > Instructions | Paste [solutions/lab-04/hle-field-ops-assistant-instructions.txt](../../solutions/lab-04/hle-field-ops-assistant-instructions.txt) again. |
| Orchestration switched to Classic (C-04-a step 4) | Settings > Generative AI | Set back to **Generative** (Labs 9 and 10 need it, CS-A07). |
| Sharing with Marcus (C-04-g) | Share | Remove Marcus unless you plan to test with him later. |
| Test security role or user added to `HLE-Dev` (C-04-g) | Power Platform admin center > HLE-Dev > Users | Remove anything you added. |

Publish the agent after reverting.

## Do NOT delete

| Item | Needed by |
|---|---|
| Agent `HLE Field Ops Assistant` | Lab 5 adds the custom connector `HLE Outage API` and the agent flows `HLE Get Outage Status` and `HLE Dispatch Crew`; Lab 10 connects it to `HLE Front Door`; Lab 11 exports it |
| Topics `Check Asset Status`, `Log Field Request`, `Crew For Asset`; entities `HLE Asset ID`, `HLE Priority`; global variable `Global.LastAssetId` | Lab 5 (Log Field Request calls HLE Dispatch Crew) |
| Dataverse tables `hle_Asset`, `hle_WorkOrder`, `hle_Crew`, their data, and solution `HLEHarbourlineOps` | Labs 5, 9, 10, 11 |
| Environment `HLE-Dev` | Labs 5, 9, 10, 11 |
| `Approval-Matrix.xlsx` with the stale value | Lab 12 regression tests. If you fixed cell D8 as the C-04-f fix, set it back to 150,000 or re-run `setup/03-upload-content.ps1` after deleting the file. |

## End of course only

After Lab 11 no longer needs them:

```powershell
./data/dataverse/import-dataverse.ps1 -EnvironmentUrl https://<org>.crm.dynamics.com -Prefix HLE -Cleanup
```

This deletes all rows, the three tables, the solution and (if the script created it) the publisher. Delete the agent in Copilot Studio first, then the `HLE-Dev` environment from the Power Platform admin center.
