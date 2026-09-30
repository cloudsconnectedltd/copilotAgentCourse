# Lab 07: Copilot connector build

| | |
|---|---|
| Build path | Microsoft Graph connectors API (PowerShell 7, Microsoft Graph PowerShell SDK), then Agent Builder, Copilot Studio and Agents Toolkit to attach the connector |
| Estimated time | 4 hours (plus waiting time for schema registration and indexing) |
| Prerequisites | [Lab 2](../lab-02-agent-builder-deep-dive/README.md) (HLE Policy Helper), [Lab 3](../lab-03-studio-sharepoint-knowledge/README.md) (HLE HR Assistant), [Lab 6](../lab-06-declarative-agents-toolkit/README.md) (HLE Outage Desk project); setup scripts [00 to 03](../../setup/README.md) (personas, groups `<Prefix>-Ops-Ontario`, `<Prefix>-Ops-US`, `<Prefix>-HR`, `<Prefix>-Finance`, guest); rights to register an app and grant admin consent |
| Personas used | Learner, Priya Nandakumar (hr), Marcus Delaney (tech), Sofia Brennan (fin), Tom Whitfield (nolic), guest contractor (guest) |
| Status | GA. Contains UNVERIFIED limits: GC-09, GC-10. Uses SNIP rows: GC-08, ADM-09, CS-K04 |
| Limits referenced | GC-01, GC-02, GC-03, GC-04, GC-05, GC-06, GC-07, GC-08, GC-09, GC-10, ADM-09, AB-05, AB-11, LIC-03, LIC-04, DA-01, DA-02, DA-03, CS-K04 ([limits.md](../../reference/limits.md)) |

> **Check before you run.** These rows are not fully verified. Confirm them on Microsoft Learn before the lab and note any change:
> - GC-08 (5 million items per connection by default) is SNIP: https://learn.microsoft.com/en-us/microsoftsearch/licensing
> - GC-09 (connections per tenant) is UNVERIFIED. The course creates one connection; do not rely on any number.
> - GC-10 (whether guests see items with an `everyone` ACL) is UNVERIFIED. Step 9 observes it; it does not assert it.
> - ADM-09 (AI Administrator manages connectors, Search Administrator for Data sources) is SNIP: https://learn.microsoft.com/en-us/microsoft-365/copilot/connectors/deployment-overview
> - CS-K04 (Copilot Studio "Authenticate with Microsoft") is SNIP: https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio
> - Indexing time after ingestion is not documented in any row of limits.md. Measure it (break-it C-07-c); do not quote a number.

## Objective

Build a synced Copilot connector for Harbourline's service tickets with the Microsoft Graph connectors API, ingest 5,000 tickets with per-item access control lists (ACLs), and attach the connection `hleTickets` to three agents built on three different paths:

| Agent | Built in | How the connector is attached |
|---|---|---|
| HLE Policy Helper | Lab 2, Agent Builder | Knowledge > Copilot connectors |
| HLE HR Assistant | Lab 3, Copilot Studio (environment HLE-Dev) | Knowledge > Copilot connector source |
| HLE Outage Desk | Lab 6, Agents Toolkit | `GraphConnectors` capability with `connection_id` in `declarativeAgent.json` |

Then prove, persona by persona, that the connector returns only what each person is allowed to see, and trigger the connector caveats on purpose.

## Concepts

- **Connection, schema, items.** A connection (`hleTickets`) holds one schema and many external items. Items carry `properties` (typed values described by the schema), `content` (full text used for search and for Copilot answers) and an `acl`.
- **Property attributes.** `searchable` (full-text matched), `queryable` (KQL filter), `retrievable` (returned in results), `refinable` (filter or aggregation). A property cannot be both searchable and refinable, and it must be retrievable to take a semantic label (GC-05).
- **Schema changes are constrained, not impossible.** After registration you can add properties, add or remove search attributes, and change aliases and semantic labels, but you cannot add `refinable` in an update (GC-04). Decide refiners on day one.
- **Semantic labels** tell Microsoft 365 what a property means (`title`, `url`, `iconUrl`, `createdBy`, `createdDateTime`, `lastModifiedDateTime`, GC-06). `title` is the most important label; `title`, `url` and `iconUrl` drive how results and citations look.
- **ACLs.** Types are `user`, `group`, `everyone`, `everyoneExceptGuests` and `externalGroup`; deny overrides grant (GC-07). Copilot, the agents and Microsoft Search all trim results by the item ACL of the signed-in user.
- **Limits for reference.** 128 properties per schema (GC-01; this schema uses 16), 30 MB parsed text per item (GC-02), 100,000 external groups per tenant (GC-03), 5 million items per connection by default (GC-08, SNIP).
- **Who administers connectors.** AI Administrator, with Search Administrator for the Data sources page (ADM-09, SNIP). The ingest app itself only needs `ExternalConnection.ReadWrite.OwnedBy` and `ExternalItem.ReadWrite.OwnedBy`.

### Expected visibility per persona

This table comes from `data/answer-keys/dataverse-connector.md` section 6. Deny beats grant. Counts assume full ingestion and indexing.

| Persona (groups) | Can see planted tickets | Cannot see planted tickets | Items allowed by ACL |
|---|---|---|---|
| Priya Nandakumar, HR Manager (`<Prefix>-HR`, AllStaff) | 102050, 102600, 103115, 104321 | 100420, 101776, 101999, 102777, 103900, 104700, 104862 | 1,498 |
| Marcus Delaney, Field Technician (`<Prefix>-Ops-Ontario`, AllStaff) | 100420, 101999, 102600, 103115 | 104321 (denied), 101776, 102777, 104862, 102050, 103900, 104700 | 2,802 |
| Sofia Brennan, Finance Analyst (`<Prefix>-Finance`, AllStaff) | 103900, 104700, 102600, 103115, 104321 | 100420, 101776, 101999, 102050, 102777, 104862 | 1,469 |
| Tom Whitfield, Operations Clerk, no Copilot license (`<Prefix>-Ops-US`, AllStaff) | ACL allows 101776, 101999, 102777, 104862, 102600, 103115, 104321 | 100420, 102050, 103900, 104700 | 2,813 by ACL. No Copilot license: do not assert what he sees in Copilot. |
| Guest contractor (Operations Microsoft 365 group only) | At most 102600 (`everyone`). Not asserted: GC-10 is UNVERIFIED. | 103115 and 104321 (`everyoneExceptGuests`), all group-granted tickets, 104700 | 0 to 400: observe |
| Learner (all course groups) | Everything except the two on the right | 104321 (denied through Ops-Ontario membership), 104700 (user-only) | 4,998 |

## Steps

### Part A: Design review (20 minutes)

1. Open `data/connector/schema-design.md`. Read sections 2 and 3.
2. Answer these three questions in your lab notes before you ingest anything, because some answers cannot be changed later:
   - Which properties are refinable, and why must they be refinable now? (Answer: `status`, `priority`, `category`, `region`, `assetType`, `tags`, `createdDateTime`, `lastModified`; refinable cannot be added in a schema update, GC-04.)
   - Why is `siteName` searchable but not a refiner? (GC-05: a property cannot be both.)
   - Which semantic labels are used, and on which properties? (`title`, `url`, `iconUrl`, `createdBy`, `createdDateTime`, and `lastModifiedDateTime` on `lastModified`, GC-06.)
3. Open `data/connector/tickets.csv` and find ticket 104321. Read its `AclJson`: a grant to `everyoneExceptGuests` and a deny to `{{GROUP_OPS_ONTARIO}}`. Predict whether you, the learner, will see it. (You are in `<Prefix>-Ops-Ontario`.)

### Part B: App registration (30 minutes)

4. Follow `data/connector/app-registration.md` sections 1 to 3 exactly:
   - Create the certificate (section 2).
   - Register the app `HLE-Tickets-Connector` (single tenant, no redirect URI).
   - Add Microsoft Graph application permissions `ExternalConnection.ReadWrite.OwnedBy` and `ExternalItem.ReadWrite.OwnedBy`, plus `Group.Read.All` and `User.Read.All` only if you want the script to resolve the ACL groups by name.
   - Select **Grant admin consent for <tenant>**.
5. Write down the tenant ID, the application (client) ID and the certificate thumbprint.

If you are not a Global Administrator, see section 5 of `app-registration.md` for delegated consent to AI Administrators (ADM-09).

### Part C: Choose the source (10 minutes, optional SQL)

6. Default: the script reads `data/connector/tickets.csv`. Nothing to do.
7. Optional: load `data/connector/tickets-seed.sql` into a SQL Server or Azure SQL database named `HarbourlineTickets`, then pass `-SqlConnectionString "Server=<server>;Database=HarbourlineTickets;..."` in Part D. The view `dbo.vTicketIndex` has the same columns as the CSV.

### Part D: Create the connection, register the schema, ingest (45 minutes plus waiting)

8. Smoke test with 50 items. Record the time the command finishes.

   ```powershell
   Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
   cd data/connector
   ./ingest-tickets.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint> -Prefix HLE -MaxItems 50
   ```

   The script creates connection `hleTickets` (display name "Harbourline Tickets (HLE)"), registers the 16-property schema and polls the schema operation every 30 seconds. The Graph reference for the schema PATCH says creation can take between 5 and 15 minutes (https://learn.microsoft.com/en-us/graph/api/externalconnectors-externalconnection-patch-schema; not a limits.md row, confirm on Learn).
9. Check the output line `Resolved ACL principals:`. Every token (`{{GROUP_OPS_ONTARIO}}`, `{{GROUP_OPS_US}}`, `{{GROUP_HR}}`, `{{GROUP_FINANCE}}`, `{{USER_FIN}}`, `{{TENANT_ID}}`) must map to an object ID. If a group is missing, run `setup/01-provision-users.ps1` or pass `-GroupMap` (see `app-registration.md` section 1).
10. Ingest all 5,000 tickets. Items are sent with PUT, so re-running is safe.

    ```powershell
    ./ingest-tickets.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint> -Prefix HLE
    ```

    Expected last line: `Ingestion finished: 5000 items sent, 0 failed.` Record the finish time in your lab notes. You need it for break-it C-07-c.

### Part E: Confirm the connection (20 minutes)

11. Sign in to the Microsoft 365 admin center as a user with AI Administrator or Search Administrator (ADM-09). Go to **Copilot > Connectors** (the script's closing message) or **Search and intelligence > Data sources** in older tenants. UI labels may differ; check Learn. Find **Harbourline Tickets (HLE)** with connection ID `hleTickets` and confirm its state is ready and its item count is rising toward 5,000.
12. Sign in as the learner and as a persona that has no admin role (for example Marcus). Try to open the same admin page as Marcus. You should be blocked. That is break-it C-07-f.
13. Run request 1 in `solutions/lab-07/search-api-checks.http` in Graph Explorer, signed in as the learner, then as Priya. The learner gets no result for `ticketId:104321`; Priya gets one. If both get nothing, indexing may not be finished: record the time and retry later (C-07-c).

### Part F: Attach `hleTickets` to the three agents (60 minutes)

14. **HLE Outage Desk (Lab 6, Agents Toolkit).** Open the Lab 6 project `solutions/lab-06/hle-outage-desk` (or your own copy) in VS Code.
    - In `appPackage/declarativeAgent.json` (schema v1.8, DA-01), add this object to the `capabilities` array. `GraphConnectors` may appear only once (DA-02). The object is also in `solutions/lab-07/outage-desk-graphconnectors-capability.json`.

      ```json
      {
        "name": "GraphConnectors",
        "connections": [
          { "connection_id": "hleTickets" }
        ]
      }
      ```

      If you omit `connections`, the agent can use every Copilot connector in the organization. Scoping it to `hleTickets` keeps the agent focused.
    - Append the text in `solutions/lab-07/outage-desk-instructions-addendum.txt` to the agent's instructions. Keep the total under 8,000 characters (DA-03).
    - In the Agents Toolkit **Lifecycle** pane, select **Provision**. Open HLE Outage Desk in Microsoft 365 Copilot Chat.
15. **HLE Policy Helper (Lab 2, Agent Builder).** In Microsoft 365 Copilot Chat, open HLE Policy Helper > **Edit** > **Configure**.
    - Under **Knowledge**, choose **Copilot connectors** (or "Choose other data sources", depending on the UI) and select **Harbourline Tickets (HLE)**. Agent Builder has no documented number limit for connectors (AB-05). If the connector is not listed, your admin has not enabled it for your organization (see break-it C-07-f).
    - Append `solutions/lab-07/policy-helper-instructions-addendum.txt` to the instructions (limit 8,000 characters, AB-02).
    - Select **Update**.
16. **HLE HR Assistant (Lab 3, Copilot Studio, environment HLE-Dev).** Open the agent in Copilot Studio.
    - Go to **Knowledge > Add knowledge** and choose the Copilot connectors source, then select **Harbourline Tickets (HLE)**. UI labels may differ; check Learn.
    - Keep **Settings > Security > Authentication** on "Authenticate with Microsoft" (CS-K04, SNIP). Connector results are trimmed per signed-in user, so the agent must know who the user is.
    - Append `solutions/lab-07/hr-assistant-instructions-addendum.txt` to the instructions. Save and **Publish**.

### Part G: Persona tests (45 minutes)

17. Type these prompts in HLE Outage Desk, in order, signed in as the persona shown. Record each answer.

    | Persona | Prompt | Expected |
    |---|---|---|
    | Marcus (tech) | `What is the status of ticket 104321?` | No ticket found or no access (denied through `<Prefix>-Ops-Ontario`) |
    | Priya (hr) | `What is the status of ticket 104321?` | In Progress, safety investigation SI-2026-014, with a link to `https://tickets.harbourline.example/t/104321` |
    | Learner | `What is the status of ticket 104321?` | No ticket found. You are in Ops-Ontario too: deny beats grant (C-07-b) |
    | Marcus (tech) | `What did ticket 100420 find on TX-ON-10423?` | Light oil film at the tank lid gasket, Resolved, WO-2026-00953, CREW-ON-03 |
    | Sofia (fin) | `What did ticket 100420 find on TX-ON-10423?` | No ticket found |

18. In HLE HR Assistant, as Priya then as Sofia, type `Who owns HR case HR-2026-0381 and when is the next review?` Priya gets Priya Nandakumar and 2026-11-16; Sofia gets nothing.
19. In HLE Policy Helper, as Sofia, type `What is the status of my duplicate hotel charge dispute?` Expected: Pending, CAD 412.60, reference CD-88213. Then try it as the learner: no result (ticket 104700 is granted to Sofia's user object only).
20. Guest and unlicensed checks: follow `validate.md` rows L07-Q15, L07-Q16 and L07-Q19. These are "observe" rows.
21. Run the full eval in `validate.md`.
22. Work through `break-it.md`.

## Caveats this lab triggers

| Caveat ID | Name | Where in break-it.md |
|---|---|---|
| C-07-a | Schema changes are constrained after registration (refinable cannot be added) | [C-07-a](break-it.md#c-07-a-schema-changes-are-constrained-after-registration) |
| C-07-b | ACL deny beats grant (ticket 104321) | [C-07-b](break-it.md#c-07-b-acl-deny-beats-grant) |
| C-07-c | Indexing latency after ingestion | [C-07-c](break-it.md#c-07-c-indexing-latency-after-ingestion) |
| C-07-d | Missing `title` and `url` semantic labels | [C-07-d](break-it.md#c-07-d-missing-title-and-url-semantic-labels) |
| C-07-e | Items not appearing for guests (`everyoneExceptGuests`, GC-10) | [C-07-e](break-it.md#c-07-e-items-not-appearing-for-guests) |
| C-07-f | Admin roles for connectors | [C-07-f](break-it.md#c-07-f-admin-roles-for-connectors) |

## Files for this lab

- `data/connector/`: `tickets-seed.sql`, `tickets.csv`, `schema-design.md`, `ingest-tickets.ps1`, `app-registration.md`
- `solutions/lab-07/`: capability snippet, instruction addenda, Search API checks, `Set-TicketLabels.ps1`
- `evals/lab-07-questions.csv`
- [break-it.md](break-it.md), [validate.md](validate.md), [cleanup.md](cleanup.md)

Later labs: Lab 10 connects HLE HR Assistant to HLE Front Door, and Lab 12 re-runs `evals/lab-07-questions.csv`. Keep the connection until the capstone is done.
