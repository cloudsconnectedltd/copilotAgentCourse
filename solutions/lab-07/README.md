# Lab 7 solutions

The connector itself is built by `data/connector/ingest-tickets.ps1` (schema in `data/connector/schema-design.md`, app registration in `data/connector/app-registration.md`). This folder holds what Lab 7 adds to the three agents, plus break-it helpers.

| File | What it is | How to use it |
|---|---|---|
| `outage-desk-graphconnectors-capability.json` | The `GraphConnectors` capability object (declarative agent manifest v1.8, DA-01, DA-02) scoped to `connection_id` `hleTickets`. | Add it to the `capabilities` array of `appPackage/declarativeAgent.json` in the Lab 6 project `solutions/lab-06/hle-outage-desk` (each capability may appear once, DA-02). Then Provision in Agents Toolkit. |
| `outage-desk-instructions-addendum.txt` | Text to append to the HLE Outage Desk instructions. | Append to the instructions file the Lab 6 manifest references. Keep the total under 8,000 characters (DA-03). |
| `policy-helper-instructions-addendum.txt` | Text to append to the HLE Policy Helper instructions (Agent Builder). | Paste at the end of the Instructions box. Keep the total under 8,000 characters (AB-02). |
| `hr-assistant-instructions-addendum.txt` | Text to append to the HLE HR Assistant instructions (Copilot Studio). | Paste at the end of the agent's Instructions. |
| `search-api-checks.http` | Microsoft Search API requests to check what each persona can see, without an agent in between. | Paste each request body into Graph Explorer while signed in as the persona. |
| `Set-TicketLabels.ps1` | Break-it C-07-d: removes the `title` and `url` semantic labels from the registered schema; `-Cleanup` restores them. | `./Set-TicketLabels.ps1 -TenantId <tid> -ClientId <appId> -CertificateThumbprint <thumb>` |

Nothing here is an exported package. The Outage Desk change ships as a new version of the Lab 6 app package when you Provision. The Agent Builder and Copilot Studio changes are made in their UIs.
