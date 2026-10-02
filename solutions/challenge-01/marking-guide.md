# Challenge 01 marking guide: Procurement Desk

Read this only after you have submitted. It lists what the brief deliberately left out, a reference approach, and how to score the design note. Limit IDs refer to [reference/limits.md](../../reference/limits.md); check rows tagged SNIP or UNVERIFIED on Microsoft Learn before you rely on them.

## Hidden problems in the brief

| # | Problem | Where it hides | What a strong submission does | Objective | Limits / related caveat |
|---|---|---|---|---|---|
| 1 | Two approval matrices disagree | `Finance/Approval-Matrix.xlsx` says the Consulting services Director limit is 150,000. `Approval-Matrix.docx` says 75,000, and its revision history (v3.2, 2025-04-01) explains the change. | Identifies the docx as authoritative, removes the xlsx from knowledge or instructs the agent to prefer the docx, and tells Ingrid the xlsx is stale. Tests the CAD 120,000 consulting case. | 1 | C-04-f |
| 2 | The vendor register is larger than list knowledge can query | `Vendors` list has 2,600 items. Copilot Studio SharePoint list knowledge queries the first 2,048 rows. | Does not rely on list knowledge for lookups or totals. Uses a tool that filters the list on the server (for example an agent flow with the SharePoint "Get items" action and an OData filter), or moves the data to Dataverse. Tests a vendor past row 2,048 (Northgate, row 2,501). | 2, 3 | CS-K10 (SNIP), C-03-h, C-04-e |
| 3 | Delegations have expired | The Delegations sheet in the xlsx lists 15 delegations, all dated 2025. | Notices that every delegation has ended, so the agent should not grant authority from them, or should check the dates against today. | 1 | None |
| 4 | Unlicensed buyers | Tom Whitfield has no Microsoft 365 Copilot license. | Rules out Agent Builder for Tom, because SharePoint knowledge needs a Copilot license or pay-as-you-go (LIC-03, LIC-04, AB-11). Chooses Copilot Studio published to Teams and explains that Tom's usage consumes Copilot Credits (LIC-10, LIC-11). | 6 | C-02-d |
| 5 | HR content sits next to Finance content | The Hub site also holds HR-Policies, including `Compensation-Bands-2025.docx` and the `Restricted` folder. | Scopes knowledge to the Finance library, not the whole Hub site. Uses "Authenticate with Microsoft" so answers are trimmed to the user (CS-K04). Adds instructions that decline HR and compensation questions, and tests both. | 7 | C-03-d, C-03-e |
| 6 | Purchase requests need structure | The brief says requests arrive "with half the information missing". | Uses a topic with slot filling (or a structured form such as an adaptive card) to collect required fields, applies the approval matrix to name the approver, and sends the request to Procurement through a flow (email, Teams post, SharePoint list or Dataverse row). Handles the 100-second flow response limit (CS-A02). | 5 | C-05-b |
| 7 | Run-time identity for the flow | A flow that writes the request runs with some identity. | States whose credentials the flow uses and why, and what Procurement sees as the author. | 5 | C-05-a |
| 8 | Maintainability (stretch goal, not scored) | "Changes to Finance documents flow through without a rebuild." | Uses SharePoint knowledge (which follows document changes) rather than uploaded copies. Builds inside a solution so it can move between environments, and points Procurement to analytics for usage. | Stretch | C-05-c, ALM-01 |
| 9 | Developer environment is owner-only | If built in `HLE-Dev`, Sofia and Tom cannot use it. | Builds or publishes from an environment the personas can use. | 6 | ENV-02, C-11-g |
| 10 | Currencies | Vendor values are CAD for Ontario and USD for New York and Ohio. | Shows the currency with every value and does not compare CAD and USD as if they were equal. | 2 | None |

## Reference approach

One reasonable design. Others can score full marks if the design note justifies them.

| Component | Choice |
|---|---|
| Build path | Copilot Studio, standard harness, generative orchestration, published to Teams and Microsoft 365 Copilot |
| Environment | A sandbox or production environment shared with the personas, inside an unmanaged solution |
| Authentication | Authenticate with Microsoft |
| Knowledge | SharePoint: the Hub **Finance** library only, with `Approval-Matrix.xlsx` excluded or explained in the instructions |
| Vendor lookups | Agent flow "Find vendor": SharePoint "Get items" on `Vendors` with a filter on Title or VendorId, returning the fields needed. A second flow or a Dataverse copy for counts and rankings across all rows. |
| Purchase request | Topic with slot filling for requester, category, amount, currency, region, vendor, justification and needed-by date; a formula or flow that applies the approval matrix; an agent flow that creates an item in a Procurement list and posts to a Teams channel |
| Instructions | Scope to procurement, expense, travel and card topics; always cite; prefer the docx approval matrix; warn on Suspended, Expired or High risk vendors; decline HR and compensation questions |
| Billing | Usage by staff without a Copilot license consumes Copilot Credits (LIC-10, LIC-11) |
| Ownership (stretch) | Procurement co-owners on the agent and solution; analytics for usage |

## Scoring the design note (30 points)

| Points | Criterion |
|---|---|
| 6 | Build path justified, including why Agent Builder does not meet objective 6 |
| 6 | Identifies the stale xlsx and the vendor register size problem, with the mitigation for each |
| 6 | Security: authentication choice, knowledge scoped away from HR content, what each persona can see |
| 6 | Licensing: how staff without a Copilot license get access and how their usage is billed |
| 6 | Known limitations stated plainly, including any unverified limits the design depends on |

## Scoring your own test plan (20 points)

| Points | Criterion |
|---|---|
| 8 | Tests as at least three personas, including Tom |
| 6 | Includes at least one vendor past row 2,048 and one approval question that depends on the docx vs xlsx difference |
| 6 | Includes negative tests (HR content, out-of-scope questions, incomplete purchase requests) |
