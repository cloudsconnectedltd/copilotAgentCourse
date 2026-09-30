# Lab 02: Agent Builder deeper dive

| | |
|---|---|
| Build path | Agent Builder in Microsoft 365 Copilot Chat |
| Estimated time | 2.5 hours |
| Prerequisites | [Lab 1](../lab-01-first-agent/README.md); setup scripts [00 to 03](../../setup/README.md) (`00-prereqs-check.ps1`, `01-provision-users.ps1`, `02-provision-sites.ps1`, `03-upload-content.ps1`, which also generates Archive-Bulk); sign-in details for the hr, fin and nolic personas (the password file written by `01-provision-users.ps1`); a second browser profile or InPrivate window for persona sign-ins |
| Personas used | learner (builder), hr (Priya Nandakumar), fin (Sofia Brennan), nolic (Tom Whitfield) |
| Status | GA. Agent Builder skills are PREVIEW (Frontier Program only, AB-13): mentioned, not built. |
| Limits referenced | [LIC-02, LIC-03, LIC-04, LIC-05, AB-02, AB-03, AB-04, AB-05, AB-06, AB-07, AB-08, AB-09, AB-10, AB-11, AB-12, AB-13, ADM-01, ADM-03](../../reference/limits.md) |

## Objective

Build **HLE Policy Helper**, an Agent Builder agent that answers Harbourline Energy Co. policy questions from several SharePoint sources plus uploaded files. Then edit it, share it with different roles, and deliberately hit the limits and behaviors that matter in a real rollout:

- knowledge source limits (lists, uploaded files, public URLs)
- the instruction character limit
- sharing roles and what groups can and cannot be
- what happens for a user without a Copilot license
- Restricted SharePoint Search (discussion)
- two conflicting versions of the same leave policy
- how the scope of a SharePoint source changes whether a single buried fact is found

## Concepts

| Concept | Summary |
|---|---|
| Multiple knowledge sources | One agent can combine SharePoint libraries, folders, files, one SharePoint list, uploaded (embedded) files, public websites and more. Each type has its own limit (AB-04, AB-05, AB-06). |
| SharePoint vs embedded | SharePoint knowledge is answered with the signed-in user's permissions. Embedded files are available to everyone who can use the agent (AB-08; see the embedded file caution on Learn). |
| Scope | A site or folder URL includes everything below it. When many files are in scope, Copilot relies on search ranking: it reads the full content of up to 20 files and, above 20, uses the 20 most relevant (AB-09). Narrow scope helps buried facts surface. |
| Editing | Changes save automatically in the builder, but users see them only after you select **Update**. |
| Sharing | New agents are private. **Can edit** makes a co-owner; **Can chat** makes a user. Groups can only be chat users. Org-wide sharing is a toggle an admin can turn off (AB-10, ADM-03). |
| Licensing | Users can use a shared agent only if they hold the licenses its capabilities need (AB-11). SharePoint and embedded file knowledge are not included in Copilot Chat without a Copilot license or pay-as-you-go billing (LIC-03, LIC-04). |

## Steps

### Part A: Check the tenant content (10 minutes)

1. Open `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub`. Confirm the libraries **HR-Policies** (18 files plus a **Restricted** folder), **Finance** (5 files) and the list **Vendors** (2,600 items).
2. Open `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Archive-Bulk`. Confirm 12 folders `2025/01` to `2025/12`. If the library is empty, re-run `setup/03-upload-content.ps1`.
3. Keep the Getting-Started files you extracted in Lab 1. You need `Benefits-At-a-Glance.docx` and `IT-Help-Desk-FAQ.docx`.

### Part B: Build HLE Policy Helper (35 minutes)

1. Go to `https://microsoft365.com/chat`, select **New agent**, then **Skip to configure**.
2. **Name**: `HLE Policy Helper`
3. **Description**: paste the contents of [`solutions/lab-02/description.txt`](../../solutions/lab-02/description.txt):

   ```text
   Answers Harbourline Energy Co. policy questions: leave and other HR policies, expenses, corporate cards, approval limits, capital projects, the vendor register, benefits and IT help. Cites the current policy version and flags older versions that disagree.
   ```

4. **Instructions**: paste the full contents of [`solutions/lab-02/instructions.txt`](../../solutions/lab-02/instructions.txt) (2,712 characters, limit 8,000, AB-02). Read the section `# Policy versions and conflicts`: it is the fix for caveat C-02-f, and you will remove it temporarily in break-it.md to see why it is needed.
5. **Knowledge**: add these five sources. For each SharePoint URL, paste it in the **Knowledge** box and press **Enter**, or use the **Attach cloud files** picker.

   | # | Source | Value |
   |---|---|---|
   | 1 | HR-Policies library | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies` |
   | 2 | Finance library | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Finance` |
   | 3 | Vendors list | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/Vendors` |
   | 4 | Uploaded file | `Benefits-At-a-Glance.docx` |
   | 5 | Uploaded file | `IT-Help-Desk-FAQ.docx` |

   Notes:
   - A site URL does not include the site's lists. The list must be added by its own URL, or from **Recent lists** in the picker. Use the list's **Copy link** URL without any query string, not a filtered or grouped view.
   - URLs must include the site path and no query parameters. A URL copied from a browser folder view (`...AllItems.aspx?id=...`) does not work.
   - The picker may not show communication sites such as the Hub unless you visited them recently. Pasting the URL avoids this.
   - SharePoint sources can show **Preparing** for several minutes. You can continue, but answers do not use a source until it is ready.

6. Turn on **Only use specified sources**. This makes the agent prioritize your sources and reply with a fallback message when they have no answer. It does not fully block general knowledge (Agent Builder does not support that; Copilot Studio does, Lab 3).
7. **Starter prompts**: add the three in [`solutions/lab-02/conversation-starters.md`](../../solutions/lab-02/conversation-starters.md):

   | Title | Prompt text |
   |---|---|
   | `Leave carry-over` | `How many unused vacation days can I carry over into next year?` |
   | `Meal per diems` | `What are the meal per diem rates for a business trip in Ontario?` |
   | `Find a vendor` | `Who is the primary contact for Mohawk Valley Meter Works, and when does the contract renew?` |

8. On the **Try it** tab, run the three starters and these prompts:

   | Prompt to type | Expected answer | Source |
   |---|---|---|
   | `How many paid bereavement days do I get for an immediate family member?` | 5 paid days plus up to 5 unpaid days | Bereavement-Leave.docx |
   | `What are the limits on a travel corporate card?` | 5,000 per transaction, 15,000 per month | Corporate-Card-Guidelines.pdf |
   | `What is the IT Help Desk phone number?` | 1-800-555-0142 | IT-Help-Desk-FAQ.docx (uploaded) |
   | `Who is the contact for Northgate Pole & Crossarm?` | Renata Kowalczyk (V-02501, Active, High risk, CAD 7,425,000, renews 2027-03-31) | Vendors list, item 2,501 |

   The Northgate item is number 2,501 of 2,600. Agent Builder list knowledge covers up to 20,000 items (AB-06), so it should be found. Compare this with Lab 3, where Copilot Studio documents a smaller query window.

9. Select **Create**. The agent is private to you.

### Part C: Edit the agent (10 minutes)

1. In the left pane, open the **More** (**...**) menu next to **HLE Policy Helper** and select **Edit**. (Or **New agent** > **View all agents**.)
2. On the **Configure** tab, change the second starter's prompt text to `What are the meal per diem rates in Ontario and in the US?`
3. Test it on **Try it**. Expected: Ontario CAD breakfast 20, lunch 25, dinner 45, full day 90; US USD breakfast 18, lunch 22, dinner 40, full day 80 (Expense-Policy.docx).
4. Open the agent from the left pane in a normal chat (outside the builder) and look at the starters. Edits save automatically in the builder, but the documented behavior is that users do not see them until you select **Update**. Record what the chat shows before you update.
5. Back in the builder, select **Update** (top right). Changes can take several minutes to reach users.

### Part D: Break it and fix it (75 minutes)

Work through [break-it.md](break-it.md) in this order. Each section says which agent to use.

| Order | Caveat | Time |
|---|---|---|
| 1 | C-02-f Conflicting leave policy versions | 15 min |
| 2 | C-02-b Instruction character limit | 10 min |
| 3 | C-02-c Sharing scope | 15 min |
| 4 | C-02-d Unlicensed users | 10 min |
| 5 | C-02-a Knowledge source limits (scratch agent **HLE Limits Test**) | 10 min |
| 6 | C-02-g Whole-site vs specific-library scoping (scratch agent **HLE Scope Test**) | 10 min |
| 7 | C-02-e Restricted SharePoint Search (discussion) | 5 min |

Agent Builder skills (AB-13) are in preview for Frontier Program organizations only. This lab does not use them.

### Part E: Validate (20 minutes)

Follow [validate.md](validate.md) to run [`evals/lab-02-questions.csv`](../../evals/lab-02-questions.csv) as the hr, fin, nolic and learner personas. Then clean up with [cleanup.md](cleanup.md). Keep **HLE Policy Helper**: Lab 7 attaches the HLE Tickets connector to it, and Lab 12 reruns this evaluation.

## Caveats this lab triggers

| Caveat ID | Name | Where in break-it.md |
|---|---|---|
| C-02-a | Knowledge source limits (list, uploaded files, public URLs) | [C-02-a](break-it.md#c-02-a-knowledge-source-limits) |
| C-02-b | Instruction character limit | [C-02-b](break-it.md#c-02-b-instruction-character-limit) |
| C-02-c | Sharing scope: owners, chat users, groups, org-wide | [C-02-c](break-it.md#c-02-c-sharing-scope) |
| C-02-d | Unlicensed users and shared agents | [C-02-d](break-it.md#c-02-d-unlicensed-users) |
| C-02-e | Restricted SharePoint Search (discussion only) | [C-02-e](break-it.md#c-02-e-restricted-sharepoint-search-discussion-only) |
| C-02-f | Conflicting leave policy versions | [C-02-f](break-it.md#c-02-f-conflicting-leave-policy-versions) |
| C-02-g | Whole-site vs specific-library scoping (Archive-Bulk) | [C-02-g](break-it.md#c-02-g-whole-site-vs-specific-library-scoping) |

## Check before you run

> Every Agent Builder limit in this lab (AB-02 to AB-13) and the licensing rows LIC-03 to LIC-05 are tagged SRC in [reference/limits.md](../../reference/limits.md), read from the source of the Microsoft Learn pages on 2026-09-30. Rows used here that are not SRC: **LIC-02** and **ADM-01** are SRC-STALE (source synced 2026-04-30), and the **maximum** number of starter prompts (AB-03) is UNVERIFIED. Before you run the lab, confirm these on Microsoft Learn:
>
> - [Build agents in Agent Builder](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-build-agents) (AB-02, AB-03)
> - [Add knowledge sources in Agent Builder](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-add-knowledge) (AB-04 to AB-08)
> - [Share and manage agents built in Agent Builder](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-share-manage-agents) (AB-10, AB-11)
> - [Agent settings in the Microsoft 365 admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings) (ADM-01, ADM-03)
> - [Agent capabilities and licensing models](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/prerequisites#agent-capabilities-and-licensing-models) (LIC-03 to LIC-05)
>
> Error messages for exceeding a limit are not documented. Where break-it.md says "Observe and record", write down the exact message you see.
