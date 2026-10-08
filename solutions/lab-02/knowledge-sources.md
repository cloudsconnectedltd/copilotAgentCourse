# HLE Policy Helper: knowledge sources

Final knowledge configuration after Lab 2 (Fix A for the leave conflict: the whole HR-Policies library plus the version rule in the instructions).

| # | Type | Source | How to add | Counts against |
|---|---|---|---|---|
| 1 | SharePoint library | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies` | Knowledge > paste URL > Enter, or **Attach cloud files** picker | 100 SharePoint files, folders or sites (AB-05) |
| 2 | SharePoint library | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Finance` | as above | AB-05 |
| 3 | SharePoint list | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/Vendors` (use the list's own **Copy link**, no query string, not a filtered view) | paste URL, or picker > **Recent lists** | 1 SharePoint list (AB-05); 20,000 items and 50 MB of text per list (AB-06). Vendors has 2,600 items. |
| 4 | Embedded file | `Benefits-At-a-Glance.docx` (from `data/sharepoint/getting-started.zip`) | Upload | 20 embedded files (AB-05); `.docx` up to 512 MB (AB-08) |
| 5 | Embedded file | `IT-Help-Desk-FAQ.docx` (from `data/sharepoint/getting-started.zip`) | Upload | as above |

Setting: **Only use specified sources** = On. It makes the agent prioritize these sources and give a fallback message when nothing is found. It does not block general knowledge completely (see the Agent Builder knowledge page on Microsoft Learn).

## Fix B variant (optional)

Instead of source 1, select the HR-Policies files individually with the picker and leave out `Leave-Policy-v3-2024.docx`: the 17 remaining files at the library root plus the 3 files in `Restricted/` (20 files). Twenty or fewer files means Copilot searches the full content of each (AB-09). The trade-off: files added to the library later are not picked up until you add them to the agent.

Do not delete or move `Leave-Policy-v3-2024.docx` in SharePoint. Lab 3 uses the same conflict.
