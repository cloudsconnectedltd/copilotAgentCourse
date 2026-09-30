# Lab 03 cleanup

## Remove now

| Item | Where | How |
|---|---|---|
| Agent `HLE Knowledge Bench` | Copilot Studio, environment `HLE-Dev` | Open **Agents**, select the agent's menu (...), **Delete**. This removes its SharePoint list, Procedures and Operations site knowledge sources. |
| Uploaded files on HLE HR Assistant | HLE HR Assistant > **Knowledge** | Delete any uploaded file source (for example `Signed-Policy-Acknowledgement-Scan.pdf`, and `Compensation-Bands-2025.docx` if the upload was accepted). Keep the `HR Policies library` source. |
| Downloaded encrypted copy | Your local Downloads folder | Delete the downloaded `Compensation-Bands-2025.docx` from break-it C-03-e. |
| Environment `HLE-Lab3-Sandbox` (only if you used the fallback in README step 15) | https://admin.powerplatform.microsoft.com > **Manage > Environments** | Select the environment, **Delete**. This also deletes the copy of HLE HR Assistant in it. |

## Restore settings on HLE HR Assistant

Break-it changes settings. Put them back and publish:

| Setting | Final value |
|---|---|
| Orchestration | Generative |
| Use general knowledge | Off |
| Authentication | Authenticate with Microsoft |
| Tenant graph grounding with semantic search | On |
| Content moderation | Default (or your approved level) |
| Instructions | Full text from [solutions/lab-03/hle-hr-assistant-instructions.txt](../../solutions/lab-03/hle-hr-assistant-instructions.txt) |

## Do NOT delete

| Item | Needed by |
|---|---|
| Environment `HLE-Dev` | Labs 4, 5, 9, 10, 11 |
| Agent `HLE HR Assistant` (with its Teams and Microsoft 365 Copilot channel and persona sharing) | Lab 7 attaches the `HLE Tickets` connector; Lab 10 connects it to `HLE Front Door`; Lab 12 runs these evals again |
| Sites, libraries, Vendors list, the `<Prefix> HR Confidential` label, persona users | Later labs. They are removed only by `setup/99-teardown.ps1` at the end of the course. |
| `Leave-Policy-v3-2024.docx`, the scan, the oversized handbook | Lab 12 regression tests use the same defects. If you archived v3 as a fix in C-03-c, move it back to `HR-Policies`. |
| All 2,600 rows of the Vendors list | Lab 4 break-it C-04-e relies on rows past 2,048. If you moved rows out as a fix in C-03-h, re-run `setup/03-upload-content.ps1` (it re-imports missing Vendors rows by VendorId) or move them back. |

## End of course only

When you finish the whole course, delete HLE HR Assistant, then the `HLE-Dev` environment (after Lab 11 no longer needs it), then run:

```powershell
./setup/99-teardown.ps1 -TenantUrl https://<tenant>.sharepoint.com -Prefix <Prefix>
```
