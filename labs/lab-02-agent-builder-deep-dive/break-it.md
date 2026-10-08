# Lab 02: Break it

Each section reproduces one caveat, shows the symptom, explains the cause with a row from [reference/limits.md](../../reference/limits.md), and fixes it. Run them in the order given in the lab README.

Where the documentation states a limit but not the exact error message, the symptom says **Observe and record**: write down what you see, including the exact wording, in your lab notes.

Two scratch agents keep **HLE Policy Helper** clean:

| Scratch agent | Used in | Deleted in |
|---|---|---|
| HLE Limits Test | C-02-a | cleanup.md |
| HLE Scope Test | C-02-g | cleanup.md |

---

## C-02-a: Knowledge source limits

**Caveat ID:** C-02-a
**Agent:** new scratch agent **HLE Limits Test** (New agent > Skip to configure; name `HLE Limits Test`; description `Scratch agent for testing knowledge limits.`; instructions `Answer questions from the knowledge sources.`)

### Steps to reproduce

**1. A second SharePoint list**

1. In the Hub site, select **New** > **List** > **Blank list**, name it `HLE-Limits-Test`, and create it. (This is a manual, throwaway list. Cleanup removes it.)
2. In **HLE Limits Test**, add `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/Vendors` as knowledge.
3. Add a second list: `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/HLE-Limits-Test` (or pick it from **Recent lists** in the picker).

**2. A 21st uploaded file**

Upload these 21 files from your local copy of the repository, in this order (all are supported types, AB-08):

| # | File |
|---|---|
| 1 to 5 | `data/sharepoint/Harbourline-Hub/Finance/`: `Approval-Matrix.docx`, `Approval-Matrix.xlsx`, `Capital-Project-Approval.docx`, `Corporate-Card-Guidelines.pdf`, `Expense-Policy.docx` |
| 6 to 10 | The five Getting-Started `.docx` files extracted in Lab 1 |
| 11 to 17 | `data/sharepoint/Harbourline-Operations/Procedures/`: all 7 files |
| 18 to 20 | `data/sharepoint/lab-09-drops/`: all 3 files |
| 21 | `data/sharepoint/Harbourline-Hub/HR-Policies/Travel-Policy.docx` |

Do not upload `Compensation-Bands-2025.docx` or anything from `HR-Policies/Restricted/`: an uploaded file is visible to everyone who can use the agent.

**3. Public website URLs**

Under **Knowledge**, enter each URL and press **Enter**:

| # | URL | Expected per docs |
|---|---|---|
| a | `https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility` | Rejected: more than two path levels |
| b | `https://learn.microsoft.com/en-us/search?terms=agent` | Rejected: contains a query string |
| c | `https://learn.microsoft.com/en-us/sharepoint` | Accepted |
| d | `https://learn.microsoft.com/en-us/entra` | Accepted |
| e | `https://learn.microsoft.com/en-us/purview` | Accepted |
| f | `https://learn.microsoft.com/en-us/power-platform` | Accepted (fourth URL) |
| g | `https://learn.microsoft.com/en-us/microsoft-365` | Rejected: fifth URL |

If your admin has turned off web search in Copilot, web content is blocked as knowledge even though the toggle in the Knowledge pane still looks available (documented known limitation). Skip part 3 in that case.

### Symptom you will see

**Observe and record.** The documented limits are: one SharePoint list, 20 uploaded files, four public URLs, at most two path levels and no query strings. Expected per docs: the second list, the 21st file, URL a, URL b and URL g cannot be added. The exact message (a disabled button, an inline error, or a warning) is not documented.

### Root cause

- One SharePoint list per agent; 20 embedded files per agent; 100 SharePoint files, folders or sites (AB-05).
- Public websites: four URLs, at most two path levels, no query strings (AB-04).
- For the record: a list source holds up to 20,000 items and 50 MB of text (AB-06). Vendors has 2,600 items, so it is inside the limit, which is why HLE Policy Helper finds item 2,501 (Northgate Pole & Crossarm).

### Fix

- Lists: pick the one list the agent needs most. For more lists, use Copilot Studio (Lab 3) or a Copilot connector (Lab 7).
- Files: put files in a SharePoint library and add the library (one source) instead of uploading many files. SharePoint also keeps the files' permissions, which uploads do not.
- URLs: use the highest useful path (two levels at most) without query strings, and pick your four best sites.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-add-knowledge

---

## C-02-b: Instruction character limit

**Caveat ID:** C-02-b
**Agent:** HLE Policy Helper

### Steps to reproduce

1. Open **HLE Policy Helper** > **Edit** > **Configure**.
2. Copy the current instructions somewhere safe (they match [`solutions/lab-02/instructions.txt`](../../solutions/lab-02/instructions.txt)).
3. Open [`solutions/lab-02/instructions-9000-chars.txt`](../../solutions/lab-02/instructions-9000-chars.txt). It is exactly 9,000 characters: the real instructions plus a "policy quick reference" and worked examples someone pasted in so the agent "always has the numbers". This is a common real-world anti-pattern.
4. Select all the text in the **Instructions** field, delete it, and paste the whole 9,000-character file.
5. Try to select **Update**.

### Symptom you will see

**Observe and record.** The documented limit is 8,000 characters. Expected per docs: the field does not accept the full text, or the agent cannot be updated until the text is shortened. Check whether the end of the text (the `# Tone` section) was cut off, and record any counter or error message.

### Root cause

Agent Builder instructions are limited to 8,000 characters (AB-02). The pasted file is 1,000 characters over. The quick-reference section is also a design problem: facts copied into instructions go stale when the policy changes, and they compete with the cited documents.

### Fix

1. Paste back the contents of `solutions/lab-02/instructions.txt` (2,712 characters).
2. Keep facts in the knowledge sources, where they are cited and updated with the document. Keep instructions for behavior: role, source routing, conflict rules, format, boundaries.
3. Select **Update**.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-build-agents

---

## C-02-c: Sharing scope

**Caveat ID:** C-02-c
**Agent:** HLE Policy Helper

### Steps to reproduce

1. Open **HLE Policy Helper** and select **Share**.
2. In **Add a name, group, or email**, add Priya Nandakumar (`<prefix>-hr@<domain>`). Set **Can edit**. Leave **Send notification** selected. Select **Add**.
3. Add the group `<Prefix>-Finance`. Open the role dropdown and try to choose **Can edit**.
4. Set the group to **Can chat** and select **Add**.
5. Look at the **Org-wide sharing for chat access** toggle. Do not turn it on; just note whether it is available or grayed out.
6. Sign in as Priya (InPrivate window) at `https://microsoft365.com/chat`. Select **New agent** > **View all agents** and look for **HLE Policy Helper**.
7. Sign in as Sofia Brennan (`<prefix>-fin`). Open the chat link (copy it from the Share dialog with **Copy chat link**). Then check whether **HLE Policy Helper** is in her **My agents** list under **New agent** > **View all agents**.

### Symptom you will see

- Step 3: **Can edit** is not offered for a group, or cannot be saved. A group can only be a chat user.
- Step 5: **Observe and record.** If your admin restricted org-wide sharing, the toggle is grayed out with a tooltip. Otherwise it is available.
- Step 6: Priya sees the agent in **My agents** and can edit it (she is an owner).
- Step 7: Sofia can chat with the agent but it is not in her **My agents** list, because that list shows only agents a user owns or can edit.

### Root cause

- New agents are private. **Can edit** makes a co-owner with the same rights as you; **Can chat** allows chat only. Groups can only be added as chat users (AB-10).
- Org-wide sharing is controlled by the admin setting in the Microsoft 365 admin center under **Agents** > **Settings** > **Sharing** (ADM-01), which applies only to Agent Builder agents (ADM-03).
- Sharing the agent does not grant access to its SharePoint knowledge. The agent answers with each user's own permissions. Here all employees can already read HR-Policies and Finance, so Sofia gets answers; the **Restricted** folder stays HR-only (see eval rows L02-Q06 and L02-Q07).

### Fix

- To give a team edit rights, add each person individually as **Can edit**. Add groups as **Can chat**.
- If you need org-wide sharing and the toggle is grayed out, ask your admin to allow your account or group in the sharing setting (ADM-03). Changes apply only to new sharing actions.
- If users do not get answers from a SharePoint source, check their SharePoint permissions on that library first. The share dialog can share selected SharePoint files and folders when you have rights to share them; whole-site access must be granted by a site admin.
- After you **Update** an agent that uses SharePoint file or folder knowledge, reshare it with the same users so the files are shared again.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-share-manage-agents
- https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings

---

## C-02-d: Unlicensed users

**Caveat ID:** C-02-d
**Agent:** HLE Policy Helper

### Steps to reproduce

1. As the learner, open **Share** on **HLE Policy Helper**, add Tom Whitfield (`<prefix>-nolic@<domain>`) as **Can chat**, and select **Add**. Copy the chat link.
2. Sign in as Tom in an InPrivate window. Tom has a base Microsoft 365 plan but no Copilot license.
3. Open the chat link. Try to add or open the agent.
4. If the agent opens, ask `How many unused vacation days can I carry over into next year?` and then `What is the IT Help Desk phone number?`
5. Still as Tom, go to `https://microsoft365.com/chat` and look for **New agent**.

### Symptom you will see

**Observe and record.** Expected per docs:

- Tom may not be able to add the agent, or attempts to use it may result in an error (AB-11).
- If the agent opens, answers from the HR-Policies library and from the uploaded IT-Help-Desk-FAQ.docx are expected to be missing, because SharePoint and embedded file knowledge are not included in Copilot Chat without billing (LIC-03). If your tenant has pay-as-you-go billing connected to the SharePoint agents service, Tom may get grounded answers and the tenant is billed (LIC-04).
- Tom has no **New agent** entry or cannot author agents (LIC-05).

### Root cause

- Users can add a shared agent only if they hold the licenses its capabilities need; otherwise using it might result in an error (AB-11).
- Copilot Chat without billing includes instructions, web search, code interpreter, image generator and custom actions, but not SharePoint, connectors, embedded files or Dataverse (LIC-03).
- Pay-as-you-go adds SharePoint and embedded files (LIC-04). Users without a Copilot license do not have access to agent authoring (LIC-05).
- Agent Builder itself requires a Copilot license or pay-as-you-go (LIC-02).

### Fix

Choose one, based on who needs the agent:

- Assign a Microsoft 365 Copilot license to users who need a SharePoint-grounded agent.
- Or enable pay-as-you-go (Copilot Credits) and connect the billing policy to the SharePoint agents service, then put the users in the billing policy's security group (LIC-04). Not available in GCC or GCCH.
- Or, for unlicensed audiences, build an agent that uses only capabilities in the "no billing" column (instructions, public web, custom actions). Policy content could be published to a public-facing site instead of SharePoint, which is rarely acceptable for HR content.

Record which option your organization would choose. Leave Tom shared as **Can chat** so the evaluation rows L02-Q16 and L02-Q17 can be run.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-share-manage-agents
- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/prerequisites#agent-capabilities-and-licensing-models

---

## C-02-e: Restricted SharePoint Search (discussion only)

**Caveat ID:** C-02-e
**Agent:** none. Do not change the tenant setting: Restricted SharePoint Search is tenant-wide and would affect every user and every other lab.

### Steps to reproduce

Discussion only. Check the state instead of changing it:

1. Look at the Restricted SharePoint Search line in the output of `setup/00-prereqs-check.ps1` (PASS means it is off). If the script reported MANUAL, a SharePoint admin can check it with `Get-SPOTenantRestrictedSearchMode` in the SharePoint Online Management Shell.
2. Discuss these questions:
   - Your organization turns on Restricted SharePoint Search to reduce oversharing during a Copilot rollout. What happens to HLE Policy Helper's HR-Policies, Finance and Vendors sources? What still works?
   - Which of today's sources would survive: the two uploaded files?
   - What would you change to keep the agent useful: fix permissions on the sites, then turn Restricted SharePoint Search off; or move content into uploaded files (and accept that everyone who can use the agent sees it)?

### Symptom you will see

Not reproduced. Per docs: when Restricted SharePoint Search is on, you cannot use SharePoint as a knowledge source in Agent Builder. Expected: SharePoint sources cannot be added or produce no grounded answers, while uploaded files keep working.

### Root cause

SharePoint knowledge is unavailable when Restricted SharePoint Search is on (AB-07).

### Fix

Fix oversharing at its source (site permissions, sensitivity labels), then turn Restricted SharePoint Search off. Until then, only non-SharePoint knowledge works in Agent Builder agents.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-add-knowledge

---

## C-02-f: Conflicting leave policy versions

**Caveat ID:** C-02-f
**Agent:** HLE Policy Helper

The HR-Policies library holds two versions of the same Leave Policy, both with Document ID HR-POL-012:

| Item | `Leave-Policy-v3-2024.docx` | `Leave-Policy-v4-2025.pdf` |
|---|---|---|
| Version, effective date | 3.0, 2024-01-01 | 4.0, 2025-04-01 |
| Annual leave | 15 days (years 1 to 2), 18 (years 3 to 7), 22 (year 8+) | 15 days (years 1 to 4), 20 (years 5 to 9), 25 (year 10+) |
| Carry-over cap | 10 days | 5 days |
| Marked as superseded? | No | Revision history says "Replaces version 3.0." |

Current and correct: version 4.0.

### Steps to reproduce

1. Open **HLE Policy Helper** > **Edit** > **Configure**.
2. In **Instructions**, delete the whole `# Policy versions and conflicts` section (the heading and its four numbered rules). Select **Update**.
3. On **Try it** (select **New chat** before each), ask:
   - `How many vacation days does an employee with 6 years of service get?`
   - `How many unused vacation days can I carry over?`
   - `How many vacation days does someone with 9 years of service get?`
4. For each answer, record the number and which file is cited: v3 (`.docx`), v4 (`.pdf`), or both.

### Symptom you will see

**Observe and record** which version Agent Builder cites. The agent has no rule for choosing, so it may answer from v3 (18 days, 10 days carry-over, 22 days at 9 years), from v4 (20, 5, 20), or mix the two, and it may not mention that a second version exists. Any v3 answer is wrong for employees today.

### Root cause

Both versions are in scope because the whole HR-Policies library is a knowledge source, and v3 is not marked as superseded. The agent retrieves whichever passages rank as most relevant; nothing tells it that effective dates matter. With 18 files in the library plus more in Finance, the agent works from the most relevant files, not all of them (AB-09).

### Fix

**Fix A (instructions, keeps the library as one source):**

1. Paste the full [`solutions/lab-02/instructions.txt`](../../solutions/lab-02/instructions.txt) back into **Instructions**. Its `# Policy versions and conflicts` section tells the agent to use the latest effective date, name the version, and mention the older value.
2. Select **Update** and ask the three questions again. Expected: 20 days, 5 days (used by March 31), 20 days, each citing `Leave-Policy-v4-2025.pdf`, with a note that version 3.0 said 18, 10 or 22 and has been replaced.

**Fix B (scope, removes v3 from the agent's view):**

1. In **Knowledge**, remove the HR-Policies library source.
2. With **Attach cloud files**, select the HR-Policies files individually, leaving out `Leave-Policy-v3-2024.docx`: the 17 other files at the library root and the 3 files in `Restricted/` (20 files; within the 100 SharePoint items of AB-05, and at 20 or fewer files Copilot reads each one in full, AB-09).
3. Select **Update** and ask again. Expected: v4 values, with no mention of v3.

Trade-off: Fix B does not pick up new files added to the library later. Fix A depends on the model following the rule. In production, fix the content too: mark v3 as superseded or move it to an archive library the agent does not use.

Do not delete or move v3 in SharePoint during this course: Lab 3 uses the same conflict. [validate.md](validate.md) assumes Fix A; it also explains how to score if you kept Fix B.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-add-knowledge
- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/optimize-content-retrieval

---

## C-02-g: Whole-site vs specific-library scoping

**Caveat ID:** C-02-g
**Agent:** new scratch agent **HLE Scope Test** (name `HLE Scope Test`; description `Scratch agent for testing knowledge scope.`; instructions `Answer questions about Harbourline field operations records. Always cite the file you used.`)

The Operations site holds the Procedures library (7 files) and the Archive-Bulk library: 1,200 short meter-reading notes and inspection memos in 12 month folders. Exactly one file, `Archive-Bulk/2025/09/Inspection-Memo-IM-2025-0873.docx`, mentions pole P-44817 and woodpecker damage.

### Steps to reproduce

1. In **HLE Scope Test**, add the whole Operations site as knowledge:

   ```text
   https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations
   ```

2. Wait until the source is no longer **Preparing**.
3. On **Try it**, ask (new chat each time):
   - `Which pole was flagged for woodpecker damage on Concession Road 9, and what action was recommended?`
   - `What is inspection memo IM-2025-0873 about?`
4. Record the answer and the cited file for each.

### Symptom you will see

**Observe and record.** Expected per docs: with more than 20 files in scope, Copilot works from the most relevant files found by search, so a single short memo among about 1,200 similar files may be missed, answered from the wrong memo, or answered without a citation. It may also be found; retrieval depends on ranking. Record which.

### Root cause

A site URL includes every library and folder below it. Copilot searches the full content of up to 20 files; above that, it uses the 20 most relevant (AB-09). The archive files are near-duplicates (same template, different numbers), so relevance ranking has little to separate them. The source counts as one of 100 SharePoint items (AB-05), so the limit is not what fails: scope is.

### Fix

1. In **Knowledge**, remove the site source.
2. Add the specific folder instead. Use **Attach cloud files** and browse to **Archive-Bulk** > **2025** > **09**, or paste:

   ```text
   https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Archive-Bulk/2025/09
   ```

3. Wait for **Preparing** to clear, then ask the same two questions.
4. Expected: pole P-44817 at 1180 Concession Road 9, three woodpecker cavities, flagged for replacement within 30 days with woodpecker wrap on adjacent poles, citing `Inspection-Memo-IM-2025-0873.docx`.

The folder still holds 100 files, more than 20, but the competing near-duplicates drop from about 1,200 to 100. If the memo is still missed, add the single file `Inspection-Memo-IM-2025-0873.docx` as the source to confirm the content itself is readable, then record both results.

Lesson: scope knowledge to the library or folder that holds the answer. Use the whole site only when the questions really span it, and keep archives out of the scope of agents that answer day-to-day questions.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/optimize-content-retrieval
- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-add-knowledge
