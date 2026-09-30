# Lab 07: Break it

Each section triggers one connector caveat on purpose. Run them after Part G of the [README](README.md), in order. Record what you see in your lab notes: several symptoms here are "observe and record" because Microsoft Learn does not document them precisely.

## C-07-a: Schema changes are constrained after registration

| | |
|---|---|
| Caveat ID | C-07-a |
| Limits | GC-04, GC-05 |

**Steps to reproduce**

1. Make sure the connection is in the ready state (the ingest in Part D finished).
2. Run the break-it switch of the ingest script. It reads the registered schema, adds a new property `costCentre` with `isQueryable`, `isRetrievable` and `isRefinable`, and sends the schema update.

   ```powershell
   cd data/connector
   ./ingest-tickets.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint> -Prefix HLE -AddRefinableLater
   ```

3. Discussion step (do not run against `hleTickets`): look at `schema-design.md` section 3.2 and explain what would happen if `siteName` were registered as both searchable and refinable.

**Symptom you will see**

One of two messages from the script:

- `As expected, the schema update was rejected: ...` (the PATCH request itself fails), or
- `As expected, the schema operation failed.` (the PATCH is accepted with 202 and the long-running schema operation ends in `failed`).

If the script prints a warning that the update succeeded, record it: that would contradict GC-04 and means the documented behavior changed. Re-check Learn.

**Root cause**

Schema updates are constrained rather than impossible. You can add properties, add or remove search attributes, and change aliases and semantic labels, but you cannot add `refinable` to a property in an update (GC-04). A property also cannot be both searchable and refinable (GC-05), so the choice between "users type words from it" and "users filter on it" is made per property at design time.

**Fix**

- If a filter on cost centre is really needed: add `costCentre` without `isRefinable` (queryable still allows KQL such as `costCentre:CC-4410`), or
- Delete the connection (`./ingest-tickets.ps1 ... -Cleanup`), add the property as refinable in `ingest-tickets.ps1`, register a new schema and re-ingest all items.
- Prevention: decide refiners in the first registration, as `schema-design.md` section 3.1 does.

**Doc link**

https://learn.microsoft.com/en-us/graph/connecting-external-content-manage-schema

## C-07-b: ACL deny beats grant

| | |
|---|---|
| Caveat ID | C-07-b |
| Limits | GC-07 |

**Steps to reproduce**

1. In `data/connector/tickets.csv`, find ticket 104321. Its ACL grants `everyoneExceptGuests` and denies `{{GROUP_OPS_ONTARIO}}`.
2. Sign in to Microsoft 365 Copilot Chat as the **learner** (member of every course group, including `<Prefix>-Ops-Ontario`). Open HLE Outage Desk and type:

   ```
   What is the status of ticket 104321?
   ```

3. Repeat as Marcus Delaney (Ops-Ontario), Priya Nandakumar (HR) and Sofia Brennan (Finance).
4. Optional: run request 1 of `solutions/lab-07/search-api-checks.http` in Graph Explorer as each persona.

**Symptom you will see**

- Learner and Marcus: the agent says it cannot find ticket 104321, or answers without it. The Search API returns no hit.
- Priya and Sofia: the agent returns the safety investigation SI-2026-014 (contact with an energized conductor on 2026-09-08, Oshawa Service Centre area, status In Progress) with a link to `https://tickets.harbourline.example/t/104321`.

The learner, who can see 4,998 of the 5,000 tickets, is blocked from a ticket that "everyone except guests" can read. This surprises most admins.

**Root cause**

ACL entries are evaluated with deny overriding grant (GC-07). Membership in any denied group removes access, even when another entry (here `everyoneExceptGuests`) grants it. The source system meant "hide from Ontario operations while witness interviews are open" and the connector preserved that intent exactly.

**Fix**

This is correct behavior, not a bug. If the learner needs access for testing, either remove the learner from `<Prefix>-Ops-Ontario` (and wait for the change to take effect), or change the source ACL and re-ingest that item (`ingest-tickets.ps1` re-sends items with PUT). Never "fix" it by granting `everyone`: that would expose the ticket to Ontario operations. When you design ACL mappings, document every deny rule, because a deny on a large group hides items from admins and test accounts too.

**Doc link**

https://learn.microsoft.com/en-us/graph/api/resources/externalconnectors-acl

## C-07-c: Indexing latency after ingestion

| | |
|---|---|
| Caveat ID | C-07-c |
| Limits | None. No limits.md row documents indexing time. |

**Steps to reproduce**

1. Use the finish time you recorded in Part D, step 10 (or run `ingest-tickets.ps1 ... -Cleanup`, re-run the full ingest and record the new finish time; this takes the full schema registration time again).
2. Immediately after the finish time, sign in as Marcus and ask HLE Outage Desk:

   ```
   When is Toronto Head Office parking level P2 closed?
   ```

3. Run request 4 of `solutions/lab-07/search-api-checks.http` as Marcus.
4. Repeat steps 2 and 3 every 15 minutes until the answer appears. Record each attempt: clock time, Search API hit count, agent answer.

**Symptom you will see**

Observe and record. Expected per docs: items become searchable only after they are indexed, so for some time after the script reports `Ingestion finished` the agent may say it cannot find the parking notice (ticket 102600) and the Search API may return fewer hits than the persona's ACL allows. The course does not state how long this takes, because no Learn source in limits.md gives a number.

**Root cause**

Ingestion (the PUT calls succeeding) and indexing (the item being searchable by Microsoft Search and Copilot) are separate steps. Agents that ground on a connector query the index, not the API that received the items.

**Fix**

Wait and re-test. In a real deployment, plan acceptance tests with a waiting period, check the item count on the connector's page in the admin center before testing, and never judge ACLs or relevance from a test run right after a bulk load. Write down the latency you measured; it is useful when stakeholders ask "why is my new ticket not in Copilot yet".

**Doc link**

https://learn.microsoft.com/en-us/graph/connecting-external-content-manage-items

## C-07-d: Missing title and url semantic labels

| | |
|---|---|
| Caveat ID | C-07-d |
| Limits | GC-06, GC-05, GC-04 |

**Steps to reproduce**

1. As Marcus, ask HLE Outage Desk `Summarize ticket 100420.` Note how the answer cites the ticket: the citation text and the link to `https://tickets.harbourline.example/t/100420`.
2. Remove the `title` and `url` semantic labels from the registered schema. Labels can be changed after registration (GC-04), so this is allowed:

   ```powershell
   cd solutions/lab-07
   ./Set-TicketLabels.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint>
   ```

3. Wait until the script reports `completed`, then allow time for the index to pick up the change (see C-07-c; record how long you waited).
4. Ask the same question again as Marcus. Also run request 1 of `search-api-checks.http` as Priya and compare the result shape with the earlier run.

**Symptom you will see**

Observe and record. Expected per docs: without the `title` label the connection no longer participates in the result cluster experience and no default result type is created, and without the `url` label results and citations have nothing to link back to. In Copilot you may see a citation with a generic or missing title, a citation that does not open the ticket, or the ticket not being used at all. The exact rendering is not documented.

**Root cause**

Semantic labels tell Microsoft 365 which property holds the title, the link, the icon and the dates (GC-06). `title` is the most important label; `title`, `url` and `iconUrl` should be applied whenever the schema has them. Only retrievable properties can take a label (GC-05), so a label mistake is often a retrievable mistake.

**Fix**

Restore the labels, then wait for the change to be indexed and re-test:

```powershell
./Set-TicketLabels.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint> -Cleanup
```

Prevention: map every label your data supports at first registration and keep the mapping in a design record like `schema-design.md` section 3.4.

**Doc link**

https://learn.microsoft.com/en-us/graph/connecting-external-content-manage-schema

## C-07-e: Items not appearing for guests

| | |
|---|---|
| Caveat ID | C-07-e |
| Limits | GC-07, GC-10 (UNVERIFIED), AB-11, LIC-03 |

**Steps to reproduce**

1. Sign in as the guest contractor (the address you passed as `-GuestEmail`). The guest has no Copilot license and is only a member of the Operations Microsoft 365 group.
2. Try each test surface available to the guest and record what happens:
   - Graph Explorer, request 4 (parking P2, ticket 102600, ACL `everyone`) and the same request with query string `VPN client 6.2` (ticket 103115, ACL `everyoneExceptGuests`).
   - Any agent the learner shared with the guest, if the tenant lets the guest open it.
3. Compare with Marcus, who sees both tickets.

**Symptom you will see**

- Ticket 103115 (`everyoneExceptGuests`): expected not visible to the guest. That ACL type exists to exclude guests (GC-07).
- Ticket 102600 (`everyone`): **observe and record**. Whether guests see connector items with an `everyone` ACL is not documented (GC-10, UNVERIFIED). Do not treat either result as proof of the rule.
- Agents: the guest has no Copilot license, so an agent grounded on the connector may not be usable at all. Users can add a shared agent only if they hold the licenses its capabilities need (AB-11), and connectors are not part of Copilot Chat without billing (LIC-03).

**Root cause**

`everyoneExceptGuests` is an explicit ACL type that excludes guest accounts; `everyone` has no documented guest behavior. Licensing is a separate gate on top of the ACL.

**Fix**

If guests must not see an item, use `everyoneExceptGuests` or group grants that do not contain guests. Do not rely on `everyone` to include or exclude guests until Microsoft documents it. Treat guest access to connector content as something you test in your own tenant and write down.

**Doc link**

https://learn.microsoft.com/en-us/graph/api/resources/externalconnectors-acl

## C-07-f: Admin roles for connectors

| | |
|---|---|
| Caveat ID | C-07-f |
| Limits | ADM-09 (SNIP) |

**Steps to reproduce**

1. Sign in to the Microsoft 365 admin center as Marcus Delaney (no admin role) and try to open **Copilot > Connectors** (or **Search and intelligence > Data sources**).
2. Sign in as a user with only the Search Administrator role (if you can assign one in your tenant) and repeat. Then try the same with the AI Administrator role.
3. As the learner in Agent Builder, open HLE Policy Helper > Configure > Knowledge and check whether **HLE Tickets** is offered.

**Symptom you will see**

- Marcus: no access to the admin page.
- Search Administrator or AI Administrator: access to the connector pages. Record exactly which pages each role can open in your tenant, because the split between AI Administrator and Search Administrator is SNIP in limits.md.
- If the connector is missing in Agent Builder's knowledge picker, an admin has not enabled it for the organization. Agent Builder's own documentation says the administrator must enable connectors.

**Root cause**

Connector administration is an admin-center task: AI Administrator manages connectors, with Search Administrator for Data sources (ADM-09). Creating a connection with the Graph API (app-only, `ExternalConnection.ReadWrite.OwnedBy`) does not give any user rights in the admin center.

**Fix**

Assign AI Administrator (or Search Administrator for the Data sources page) to the people who operate connectors, using least privilege and PIM where available. Keep the ingest app's permissions at `.OwnedBy` scope. If the connector is not offered to makers, have the admin enable it in the admin center.

**Doc link**

https://learn.microsoft.com/en-us/microsoft-365/copilot/connectors/deployment-overview
