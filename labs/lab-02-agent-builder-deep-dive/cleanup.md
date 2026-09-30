# Lab 02: Cleanup

Lab 2 created agents and one throwaway list. It did not create flows, connections, app registrations, environments or tunnels, and it changed no tenant settings.

## Remove

| Item | How |
|---|---|
| Scratch agent **HLE Limits Test** | `https://microsoft365.com/chat` > **New agent** > **View all agents** > **...** next to the agent > **Delete**. Deletion is permanent and removes its 20 uploaded files. |
| Scratch agent **HLE Scope Test** | Same steps. Delete it after you finish validation rows L02-Q19 and L02-Q20. |
| List **HLE-Limits-Test** in the Hub site | Hub site > **Site contents** > **...** next to `HLE-Limits-Test` > **Delete**. Then empty it from the site recycle bin if you want it gone at once. |
| Tom Whitfield's access to HLE Policy Helper (optional) | **Share** > role dropdown next to Tom > **Remove**. Keep it if you plan to rerun L02-Q16 and L02-Q17 in Lab 12. |

## Do NOT delete

| Item | Why |
|---|---|
| **HLE Policy Helper** | Lab 7 attaches the HLE Tickets Copilot connector to it. Lab 12 reruns `evals/lab-02-questions.csv` against it. Keep Priya as co-owner and the Finance group as chat users. |
| **HLE Welcome Buddy** (Lab 1) | Lab 12 reruns `evals/lab-01-questions.csv`. |
| `Leave-Policy-v3-2024.docx` in HR-Policies | Lab 3 uses the same conflict. Fix B only removed it from the agent's knowledge, not from SharePoint. |
| Hub and Operations sites, libraries, Vendors list, Archive-Bulk | Created by the setup scripts and used by Labs 3, 4 and 9. Removed at the end of the course by `setup/99-teardown.ps1`. |
| Persona accounts and groups | Used in every later lab. |

## Check

- **View all agents** lists **HLE Policy Helper** and **HLE Welcome Buddy**, and no scratch agents.
- The Hub **Site contents** page has no `HLE-Limits-Test` list.
