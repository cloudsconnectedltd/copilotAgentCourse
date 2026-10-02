# Lab 01: Cleanup

Lab 1 created only one thing in your tenant: the private agent **HLE Welcome Buddy**. It created no scripts, sites, flows, connections, app registrations or environments.

## What NOT to delete

| Item | Why keep it |
|---|---|
| **HLE Welcome Buddy** | Lab 12 (evaluation capstone) reruns `evals/lab-01-questions.csv` against it. Keep it until you finish Lab 12. If you delete it now, you can rebuild it in about 10 minutes from [`solutions/lab-01/`](../../solutions/lab-01/README.md). |
| The Getting-Started library (Option B only) | Created by the setup scripts, not by this lab. `setup/99-teardown.ps1` removes it at the end of the course. |
| The extracted `.docx` files on your computer | Not in the tenant. Delete them whenever you like; the zip stays in the repository. |

## Delete the agent (when you are finished with the course, or if you do not plan to do Lab 12)

1. Go to `https://microsoft365.com/chat`.
2. In the left pane, select the **More** (**...**) menu next to **HLE Welcome Buddy**. If it is not in the list, select **New agent** and then **View all agents**.
3. Select **Delete** and confirm.

Deleting an agent is permanent and cannot be undone. Embedded (uploaded) files are deleted with the agent. With Option B, the SharePoint files are not affected.
