# PLAN: Microsoft 365 Copilot Agent Building Course

Status: Phase 1 (plan). Awaiting approval before Phase 2.
Plan date: 2026-09-30.
Fictional company: Harbourline Energy Co. (regulated utility, Ontario and US operations, about 2,000 staff).

---

## 1. Verification status (read first)

Ground rule 1 requires every limit to be checked against current Microsoft Learn. At plan time the environment's network proxy **blocks learn.microsoft.com**. Facts in this plan were checked through two fallback routes:

| Tag | Meaning |
|---|---|
| SRC | Read from the public GitHub source repo that builds the Learn page (MicrosoftDocs/m365copilot-docs, microsoftgraph/microsoft-graph-docs-contrib, MicrosoftDocs/power-platform, MicrosoftDocs/msteams-docs). Repos had commits dated 2026-09-30. High confidence. |
| SRC-STALE | Read from MicrosoftDocs/microsoft-365-docs, which was last synced 2026-04-30. Possibly five months behind the live page. |
| SNIP | Only a search-engine summary of a learn.microsoft.com page was available. Copilot Studio docs are in this tier because their source repo is not public. Must be re-checked. |
| UNVERIFIED | No Learn source confirmed it. Will not be stated as fact in course content. |

In Phase 2, `reference/limits.md` will carry every limit with its Learn URL, date checked (2026-09-30) and tag. Each lab README that depends on a SNIP or UNVERIFIED value will carry a "check this limit on Learn before running" callout. See Open question Q1 for how to close this gap.

---

## 2. Course outline

| # | Module | Build path | Est. hours | Depends on | Preview flags |
|---|---|---|---|---|---|
| 0 | Tenant setup (scripts 00 to 04) | PowerShell | 3.0 | Tenant prerequisites (section 3) | None |
| 1 | Getting started: your first agent | Agent Builder | 0.75 | Copilot license only | None |
| 2 | Agent Builder deeper dive | Agent Builder | 2.5 | Module 0, Lab 1 | Agent Builder skills (PREVIEW, Frontier only; mentioned, not built) |
| 3 | Copilot Studio: SharePoint and file knowledge | Copilot Studio | 4.0 | Module 0, Lab 2 | SharePoint lists as knowledge (status to confirm) |
| 4 | Copilot Studio: Dataverse and topics | Copilot Studio | 3.5 | Lab 3, Dataverse seed | None known |
| 5 | Copilot Studio actions: flows and connectors | Copilot Studio + Power Automate | 3.5 | Lab 4, mock API running | Agent flow express mode (PREVIEW) |
| 6 | Declarative agent with M365 Agents Toolkit | VS Code, Agents Toolkit | 4.0 | Mock API + OpenAPI spec, custom app upload | Worker agents (PREVIEW, out of scope) |
| 7 | Copilot connector build | Microsoft Graph connectors API | 4.0 | Tickets SQL DB, Labs 2, 3, 6 agents | None known |
| 8 | Custom engine agent | M365 Agents SDK or Copilot Studio + Foundry model | 4.0 | Azure subscription, Lab 6 | Foundry agent connection in Copilot Studio (PREVIEW) |
| 9 | Autonomous agent with triggers | Copilot Studio event triggers | 2.5 | Lab 3, Procedures library | GA status UNVERIFIED |
| 10 | Multi-agent orchestration | Copilot Studio child and connected agents | 2.5 | Labs 3, 4, 5 | Foundry/Fabric/Agents SDK connected agents (PREVIEW) |
| 11 | ALM and governance | Solutions, pipelines, admin centers, Purview | 3.5 | Labs 4, 5, 10 | Agent Registry Graph APIs (PREVIEW) |
| 12 | Evaluation and troubleshooting capstone | Copilot Studio evaluation, analytics | 3.0 | All labs | Evaluation is GA in classic docs, PREVIEW in "new experience" docs |
| A | Final assessment (25 scenarios) | None | 1.0 | All labs | None |

Total: about 42 hours (39 hours of labs plus setup and assessment).

Order stays as specified. Lab 7 must follow Labs 2, 3 and 6 because it attaches the connector to their agents. Lab 9 can run any time after Lab 3.

### Dependency graph

```
Lab 1 (standalone, no setup)
Module 0 -> Lab 2 -> Lab 3 -> Lab 4 -> Lab 5 -> Lab 10 -> Lab 11
                       |               |
                       +-> Lab 9       +-> Lab 6 -> Lab 7 -> Lab 8
All labs -> Lab 12 -> Assessment
```

### Lab caveat plan (adjusted to verified facts)

Several caveats in the brief behave differently from what the brief assumed. The lab will teach the documented behavior.

| Lab | Caveat in brief | What the docs say (tag) | How the lab will trigger it |
|---|---|---|---|
| 2 | Knowledge source limits | Agent Builder: 100 SharePoint files/folders/sites, 1 SharePoint list, 50 OneDrive files, 20 uploaded files, 4 public URLs (max 2 path levels, no query strings) (SRC) | Try to add a second list; try a 21st uploaded file; try a deep public URL |
| 2 | Instruction character limit | 8,000 characters; name 30; description 1,000 (SRC) | Paste a 9,000-character instruction set provided in the lab |
| 2 | Sharing scope | Private by default; "Can edit" or "Can chat"; groups chat-only; org-wide toggle controlled by admin setting (SRC) | Share to a group as editor, observe it is not offered |
| 2 | Unlicensed users | Unlicensed users can only use a shared agent if they hold the license its capabilities need; otherwise errors (SRC) | Unlicensed persona opens the shared SharePoint-grounded agent |
| 2 | (added) Restricted SharePoint Search | SharePoint knowledge unavailable when RSS is on (SRC) | Discussion only; toggling RSS is tenant-wide |
| 3 | File size limit | 7 MB when no M365 Copilot license in tenant; up to 200 MB with tenant graph grounding; 512 MB for PDF, PPTX, DOCX (SNIP) | See Q3. Default plan: disable tenant graph grounding on one agent and show a 9 MB file silently excluded, then enable it |
| 3 | Sensitivity label that encrypts | Encryption supported only via sensitivity labels and only on SharePoint knowledge; user needs VIEW and EXTRACT rights. Uploaded encrypted files not supported (SNIP) | Label grants EXTRACT to HR group only; finance persona gets no answer; upload same file directly and observe rejection |
| 3 | Scanned PDF | No OCR stated only in community answers (UNVERIFIED) | Lab observes behavior rather than asserting it |
| 3 | "Authenticate with Microsoft" | Default for new agents; required for tenant graph grounding (SNIP) | Switch to no auth and observe SharePoint knowledge becomes unavailable |
| 3 | SharePoint list as knowledge | Up to 15 lists, 35,000 rows each; queries use first 2,048 rows (SNIP, new-experience docs) | Vendors list with 2,600 rows; question about row 2,500 |
| 4 | Dataverse knowledge limits | 15 tables per knowledge source; glossary changes take up to 15 minutes (SNIP) | Glossary change tested immediately, then after wait |
| 5 | Flow timeout | Agent flow must respond within 100 seconds (SNIP) | Mock API `?delayMs=120000` on outage-status |
| 6 | Manifest schema version | Declarative agent manifest v1.8 current; plugin manifest v2.4 (SRC) | Start from a v1.0 manifest, add a v1.8-only capability, observe validation error |
| 6 | OpenAPI constraints | No nested request objects, no oneOf/allOf/anyOf, no circular refs; operationId expected; OpenAPI 2.0 and 3.0.x (SRC, Teams docs) | Broken spec variant |
| 6 | Response size | 25 items per plugin response, 4,096 tokens, 45 s timeout (SRC). KB/MB limit UNVERIFIED | customer-lookup returns 200 records |
| 6 | Capability scoping by URL | `items_by_url` has no count limit; Copilot searches full content of up to 20 files (SRC) | Scope to one library, ask about the other |
| 7 | Schema immutable after registration | Not fully immutable: properties can be added; search attributes can change with reingest; `refinable` cannot be added in an update; searchable and refinable cannot combine (SRC) | Lab reframes caveat as "schema changes are constrained"; learner tries to add refinable later |
| 7 | Items not appearing for guests | ACL type `everyoneExceptGuests` exists (SRC). Guest access to connector content otherwise UNVERIFIED | Tickets use both `everyone` and `everyoneExceptGuests` ACLs; guest test observed, not asserted |
| 7 | Limits (for reference) | 128 properties, 30 MB item (parsed text), 5M items per connection default (SRC/SNIP) | Documented only |
| 8 | License to use | Docs conflict: users do not need Copilot license, versus include file saying licensed or metered only (SRC, conflicting) | Flagged in lab; learner tests with unlicensed persona |
| 9 | Run-as identity | Event triggers use only the author's credentials; only with generative orchestration (SNIP) | Finance persona drops a file; flow runs as learner |
| 9 | Cost | Autonomous runs billable even for licensed users (SNIP); rate per trigger UNVERIFIED | Learner reads consumption in PPAC |
| 11 | Pipelines | Target environments must be managed environments (except developer); enforcement changes from October 2026 (SRC) | See Q6 |
| 12 | (added) Eval throttling | Generative AI rate 10 RPM / 200 RPH on trial and developer environments (SNIP) | Batch eval run in developer environment hits throttling |

---

## 3. Tenant prerequisites

### Licenses

| Item | Purpose | Needed for | Tag |
|---|---|---|---|
| Qualifying base plan (Microsoft 365 E3/E5, Business Standard/Premium, or similar) | Base for Copilot add-on | All personas | SRC-STALE |
| Microsoft 365 Copilot add-on | Agent Builder with SharePoint knowledge; declarative agents on org data; zero-rated Copilot Studio usage in M365 channels | Learner, HR manager, field technician, finance analyst | SRC / SNIP |
| No Copilot license (base plan only) | Unlicensed persona | Lab 2, 3, 8 tests | SRC |
| Copilot Studio User License (free, maker) | Author in Copilot Studio | Learner | SNIP |
| Copilot Studio capacity pack (25,000 Copilot Credits/month) **or** pay-as-you-go via Azure subscription | Copilot Studio agents in Teams/web, autonomous triggers, unlicensed-user usage | Labs 3 to 12 | SRC-STALE / SRC |
| Power Apps Developer Plan (free) | Developer environment with Dataverse (up to 3 per user; 750 flow runs/month; 2 GB DB; disabled after 30 days idle) | Labs 4, 5, 9, 10 | SRC |
| Premium Power Platform licensing for managed environments | Pipeline targets | Lab 11 | SRC |
| Azure subscription (Owner or Contributor on resource group) | Pay-as-you-go billing, Azure Functions (optional), Azure SQL (optional), Bot Service, Foundry | Labs 5, 6, 7, 8 | SRC-STALE |
| Purview: tenant supports sensitivity labels with encryption (E5 or E5 Compliance, or similar) | Encrypted label test | Lab 3 | UNVERIFIED for exact SKU |

### Power Platform environments

| Environment | Type | Use |
|---|---|---|
| `HLE-Dev` | Developer (Developer Plan) | Labs 4, 5, 9, 10 authoring |
| `HLE-Test` | Sandbox, managed environment | Lab 11 pipeline target |
| `HLE-Prod` | Production, managed environment | Lab 11 pipeline target and host |
| Default | Default | Lab 11 environment routing discussion |

Note: Developer environments cannot be assigned security groups and are owner-only (SRC).

### Admin roles

| Role | Used for | Tag |
|---|---|---|
| Global Administrator | App registration consent, initial setup (break-glass) | SNIP |
| AI Administrator | Agent settings, Integrated apps/agent inventory, approving agents, connector management, pay-as-you-go setup | SRC-STALE |
| Search Administrator | Copilot connectors under Search and Intelligence > Data sources | SNIP |
| Teams Administrator | Setup policy for custom app upload | UNVERIFIED role statement |
| Power Platform Administrator | Environments, DLP, tenant settings, pipelines | UNVERIFIED role statement |
| SharePoint Administrator | Site provisioning, external sharing, Restricted SharePoint Search | UNVERIFIED role statement |
| Compliance Administrator (Purview) | Sensitivity labels, audit search | UNVERIFIED role statement |

### Settings to enable

| Setting | Where | Tag |
|---|---|---|
| Upload custom apps = On | Teams admin center > Teams apps > Setup policies > Global (Org-wide default) | SRC |
| Agent user access (All users or a course group) | Microsoft 365 admin center > Agents > Settings > User access | SRC-STALE |
| Agent sharing (allow course group to share org-wide) | Microsoft 365 admin center > Agents > Settings > Sharing | SRC |
| Deploy Copilot Studio app to users | Microsoft 365 admin center (Integrated apps) | SRC |
| Generative AI features enabled | Power Platform admin center | SRC |
| Copilot Studio authors security group | Power Platform admin center > Tenant settings | SNIP |
| Pay-as-you-go billing policy (if used) | Microsoft 365 admin center + Azure subscription | SRC |
| Restricted SharePoint Search = Off | SharePoint admin | SRC |
| External sharing on `Harbourline-Operations`, B2B guest invites allowed | SharePoint admin + Entra External Identities | UNVERIFIED |
| Sensitivity labels enabled for SharePoint and OneDrive files | Purview / SharePoint | UNVERIFIED |
| Audit (Standard) on | Purview | UNVERIFIED |
| Update channel: Current Channel or Monthly Enterprise Channel | Microsoft 365 Apps | SRC |

`setup/00-prereqs-check.ps1` will check what Graph and PnP can read (licenses assigned, role membership, site sharing settings, Teams app setup policy where exposed) and print manual checks for the rest.

---

## 4. Data sources and files to generate

### 4.1 SharePoint

Mirrored locally as `data/sharepoint/<site>/<library>/`.

**Site 1: `Harbourline-Hub` (communication site, owner: learner)**

| Library / list | Files (planned) | Deliberate defect | Permissions | Labs |
|---|---|---|---|---|
| `Getting-Started` | `Welcome-to-Harbourline.docx`, `Vacation-Policy.docx`, `IT-Help-Desk-FAQ.docx`, `Office-Locations.docx`, `Benefits-At-a-Glance.docx`; plus `getting-started.zip` | None (clean) | Inherited, all employees read | 1 |
| `HR-Policies` | 18 files, including: `Leave-Policy-v3-2024.docx` and `Leave-Policy-v4-2025.pdf` (conflicting annual leave days and carry-over caps); `Code-of-Conduct.pdf`; `Remote-Work-Policy.docx`; `Harassment-Prevention-Ontario.docx`; `FMLA-Guidance-US.docx`; `Overtime-and-On-Call.docx`; `Travel-Policy.docx`; `Parental-Leave.pdf`; `Bereavement-Leave.docx`; `Performance-Review-Process.docx`; `Safety-Incident-Reporting.pdf`; `Workplace-Accommodation.docx`; `Grievance-Procedure.docx`; `Employee-Handbook-Full.docx` (large file, see Q3); `Signed-Policy-Acknowledgement-Scan.pdf` (image-only); `Compensation-Bands-2025.docx` (encrypted sensitivity label) | Conflict, scan, large, label | Inherited plus `Restricted` folder | 2, 3 |
| `HR-Policies/Restricted` | `Disciplinary-Case-Handling.docx`, `Executive-Compensation-Review.docx`, `Investigation-Protocol.pdf` | Broken inheritance | HR group only | 3 |
| `Finance` | `Expense-Policy.docx`, `Approval-Matrix.docx` (table), `Approval-Matrix.xlsx` (same matrix, one threshold differs for a tabular reasoning check), `Corporate-Card-Guidelines.pdf`, `Capital-Project-Approval.docx` | Table-in-docx vs xlsx | Finance group edit, all read | 2, 3, 4 |
| List `Vendors` | 2,600 items: vendor name, category, region (ON/US state), contract value, status, renewal date, contact, risk rating | Row count exceeds 2,048 query window | All read | 3, 4 |

**Site 2: `Harbourline-Operations` (team site, Microsoft 365 group, guest access on)**

| Library | Files (planned) | Deliberate defect | Permissions | Labs |
|---|---|---|---|---|
| `Procedures` | `Outage-Response-Procedure.docx`, `Storm-Restoration-Playbook.pdf`, `Lockout-Tagout-Safety-Manual.pdf`, `Substation-Switching-Procedure.docx`, `Vegetation-Management.docx`, `Crew-Briefing-Deck.pptx` (key values only in images), `Transformer-Equipment-Specs.xlsx` (4 sheets, merged header cells) | Image-only content, merged cells | Group members, guest member | 3, 9 |
| `Procedures/Incoming` | Empty folder; Lab 9 drops `Field-Report-*.docx` here | Trigger target | Group members | 9 |
| `Archive-Bulk` | 1,200 small generated files (meter reading notes, inspection memos) across 12 year/month folders | Volume, scope | Group members | 2, 3 |

`reference/site-map.md` (Phase 3) will present this as the required table.

### 4.2 Dataverse (`data/dataverse/`)

| File | Rows | Notes |
|---|---|---|
| `schema.md` + `solution/` (unmanaged solution XML) | n/a | Tables `hle_Asset`, `hle_WorkOrder`, `hle_Crew`; WorkOrder N:1 Asset, WorkOrder N:1 Crew; choice column `hle_Priority` (Emergency, High, Routine, Deferred) |
| `Assets.csv` | 1,200 | Asset ID, type, region, site, install year, condition score |
| `WorkOrders.csv` | 3,000 | Linked to assets and crews, status, priority, dates |
| `Crews.csv` | 60 | Crew name, region, lead, certifications |
| `import-dataverse.ps1` | n/a | See Q5 on module choice |

Labs: 4, 5, 10, 11.

### 4.3 Copilot connector source (`data/connector/`)

| File | Notes |
|---|---|
| `tickets-seed.sql` | Tables Region, Site, Asset, Ticket, TicketAcl; about 5,000 tickets; ACL rows map to Entra groups (`HLE-Ops-Ontario`, `HLE-Ops-US`, `HLE-HR`, `everyone`, `everyoneExceptGuests`) |
| `tickets.csv` | Flat export for learners without SQL |
| `schema-design.md` | Property attribute plan (searchable, queryable, retrievable, refinable), semantic labels (title, url, iconUrl, lastModifiedDateTime, createdBy), refinable/searchable exclusivity |
| `ingest-tickets.ps1` | Creates connection, registers schema, pushes items with ACLs via Microsoft.Graph SDK; `-Cleanup` deletes the connection |

Labs: 7, then 2, 3, 6 re-tested.

### 4.4 Mock REST API (`data/api/`)

| Item | Notes |
|---|---|
| Azure Functions project (see Q4 for language) | `GET /outage-status`, `POST /crew-dispatch`, `GET /customer-lookup`; `?delayMs=` for timeout tests; `?pageSize=` for oversized responses |
| `openapi.yaml` | OpenAPI 3.0.3, compliant |
| `openapi-broken.yaml` | Missing operationId, `oneOf` in request body, nested request object, unbounded response |
| Auth variants | none, API key (header), Entra ID OAuth (auth code); selected by function app setting |
| `run-local.md`, `deploy-azure.ps1` | Local run with Functions Core Tools; optional Azure deploy with `-Cleanup` |

Labs: 5, 6, 8, 10.

### 4.5 Personas (`setup/01-provision-users.ps1`)

| Persona | UPN prefix | Copilot license | Groups | Purpose |
|---|---|---|---|---|
| Learner (existing account) | n/a | Yes | All course groups, site owner | Maker |
| Priya Nandakumar, HR Manager | `hle-hr` | Yes | HLE-HR | Restricted folder, labeled file |
| Marcus Delaney, Field Technician | `hle-tech` | Yes | HLE-Ops-Ontario | Ops content, triggers |
| Sofia Brennan, Finance Analyst | `hle-fin` | Yes | HLE-Finance | Finance, denied HR content |
| Guest contractor | external email (Q2) | No | Operations group member | Guest behavior |
| Tom Whitfield, Operations Clerk | `hle-nolic` | No | HLE-Ops-US | Unlicensed behavior |

### 4.6 Evals (`evals/`)

One CSV per lab (Labs 1 to 12, excluding 11 where evals are admin checks). Columns: `id, persona, prompt, expected_answer, expected_source, expected_behavior` where `expected_behavior` is `answer`, `no_answer`, `refuse`, or `answer_without_citation`. Lab 1: 10 questions, each with one clean answer in one Getting-Started document. Other labs: 12 to 25 questions.

### 4.7 Full file inventory (Phases 2 to 5)

```
README.md
PLAN.md
reference/limits.md
reference/agent-types-matrix.md
reference/caveats-index.md
reference/glossary.md
reference/site-map.md
reference/final-assessment.md
setup/00-prereqs-check.ps1
setup/01-provision-users.ps1
setup/02-provision-sites.ps1
setup/03-upload-content.ps1
setup/04-apply-labels.ps1
setup/99-teardown.ps1
setup/common.psm1                     # shared params, logging, idempotency helpers
tools/generate-data/                  # generators for bulk and large files (see Q7)
data/sharepoint/Harbourline-Hub/Getting-Started/*.docx (5) + getting-started.zip
data/sharepoint/Harbourline-Hub/HR-Policies/* (18) + Restricted/* (3)
data/sharepoint/Harbourline-Hub/Finance/* (5)
data/sharepoint/Harbourline-Hub/Vendors.csv
data/sharepoint/Harbourline-Operations/Procedures/* (7)
data/sharepoint/Harbourline-Operations/Archive-Bulk/  (generated at setup)
data/dataverse/{schema.md,Assets.csv,WorkOrders.csv,Crews.csv,import-dataverse.ps1,solution/}
data/connector/{tickets-seed.sql,tickets.csv,schema-design.md,ingest-tickets.ps1}
data/api/{src/,openapi.yaml,openapi-broken.yaml,run-local.md,deploy-azure.ps1}
labs/lab-01-first-agent/{README.md,validate.md,cleanup.md,facilitator-notes.md,recap.md}
labs/lab-02-agent-builder-deep-dive/{README.md,break-it.md,validate.md,cleanup.md}
labs/lab-03-studio-sharepoint-knowledge/...
labs/lab-04-studio-dataverse-topics/...
labs/lab-05-studio-actions-flows/...
labs/lab-06-declarative-agents-toolkit/...
labs/lab-07-copilot-connector/...
labs/lab-08-custom-engine-agent/...
labs/lab-09-autonomous-triggers/...
labs/lab-10-multi-agent/...
labs/lab-11-alm-governance/...
labs/lab-12-eval-troubleshooting/{...,troubleshooting-decision-tree.md}
evals/lab-01-questions.csv ... evals/lab-12-questions.csv
solutions/lab-02/ ... solutions/lab-12/  (manifests, exported solutions, agent YAML)
```

Lab 1 has no `break-it.md`, per the brief.

---

## 5. Open questions and decisions

Decisions recorded 2026-09-30 (plan approved):

| Q | Decision |
|---|---|
| Q1 | learn.microsoft.com enabled by the user, but still blocked from the build container. Facts remain tagged in `reference/limits.md`; re-check SNIP and UNVERIFIED rows. |
| Q2 | Guest address is a script parameter (`-GuestEmail`). |
| Q3 | 9 MB DOCX generated at setup; lab toggles tenant graph grounding off to show the 7 MB exclusion. |
| Q4 | Node.js (Azure Functions v4). |
| Q5 | `pac` CLI, Dataverse Web API and ExchangeOnlineManagement are allowed in addition to PnP.PowerShell and Microsoft.Graph. |
| Q6 | Hands-on pipelines where managed environments exist; the lab includes a documented fallback path. |
| Q7 | Curated documents committed; bulk and oversized files generated at setup with Python. |
| Q8 | Repository root is the course root. |
| Q9 | Classic Copilot Studio experience, with notes where the new experience differs. |
| Q10 | Every persona that needs a Copilot license has one. Copilot Studio billing via capacity pack or pay-as-you-go; labs work with either. |
| Q11 | Microsoft 365 Agents SDK as the main path; Copilot Studio with a Foundry model as an optional extension. |

Original questions:

**Q1. Verification gap.** learn.microsoft.com is blocked from this environment. Options: (a) accept SRC-tagged facts and flag SNIP/UNVERIFIED items in `limits.md` for you to confirm; (b) you allow learn.microsoft.com in the environment's network policy so I can re-verify in Phase 2. I recommend (b), with (a) as fallback.

**Q2. Guest persona.** Guests need a real external mailbox to redeem an invitation. Can you provide an external address (for example, a personal Outlook.com account)?

**Q3. Oversized file.** With an M365 Copilot license in the tenant, the SharePoint limit rises to 200 MB, and 512 MB for PDF, PPTX and DOCX. A file over those sizes is impractical to generate and upload. Proposed approach: generate a 9 MB DOCX, which exceeds the 7 MB limit that applies when tenant graph grounding is off, and have the lab toggle grounding off to show the exclusion. Alternative: a 210 MB XLSX (not in the 512 MB type list). Which do you prefer?

**Q4. Mock API language.** Node.js (JavaScript, Azure Functions v4) or C# (.NET isolated)? I recommend Node.js for faster local setup.

**Q5. Dataverse import tooling.** The brief limits scripts to PnP.PowerShell and Microsoft.Graph. Dataverse import needs the Dataverse Web API or `Microsoft.PowerApps.Administration.PowerShell` / `pac` CLI. Is using `pac` CLI plus the Dataverse Web API acceptable? Sensitivity labels have the same issue: creating labels needs `ExchangeOnlineManagement` (Security and Compliance PowerShell). OK to add that module?

**Q6. Managed environments for Lab 11.** Pipelines need managed target environments, which require premium licensing for the users of those environments. Does your tenant have this, or should Lab 11 treat pipelines as a walkthrough with described steps instead of a hands-on build?

**Q7. Committed binaries vs generators.** Proposal: commit the curated documents (about 40 docx, pdf, xlsx, pptx files), and generate `Archive-Bulk` (1,200 files) and the oversized file at setup time with a script. Generators need Python (python-docx, openpyxl, reportlab) or .NET (OpenXML SDK). Is Python acceptable for data generation only, with PowerShell for all tenant operations?

**Q8. Repository root.** The brief shows a `copilot-agent-course/` folder. This repository is empty, so I plan to use the repository root as the course root. Confirm.

**Q9. Copilot Studio experience.** Microsoft now documents a classic Copilot Studio experience and a "new experience" with separate pages and sometimes different limits and statuses. Which one should Labs 3 to 12 target? I recommend the classic experience, since most limits and GA statuses were found there, with notes where the new experience differs.

**Q10. Copilot license count.** The plan assumes 4 Copilot licenses (learner plus three personas). Confirm how many you can assign, and whether Copilot Studio will be billed through a capacity pack or pay-as-you-go.

**Q11. Lab 8 build path.** Build the custom engine agent with the M365 Agents SDK (code, Azure Bot Service, SSO) or Copilot Studio with a Foundry model? The brief allows either. I recommend the Agents SDK as the main path, since it shows the "no Copilot orchestrator" caveat most clearly, with Copilot Studio + Foundry as an optional extension.

---

## 6. Next steps after approval

- Phase 2: repository structure, README, `reference/limits.md` with all facts above plus sources and tags.
- Phase 3: data generation and setup scripts.
- Phase 4: labs, evals, solutions, then the self-check.
- Phase 5: reference material and final assessment.
- One commit per phase.
