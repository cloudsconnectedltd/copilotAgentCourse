# Verified limits and feature status

Every limit used in this course, with its source and the date it was checked. Limits change often. Before running a lab, re-check any row the lab depends on, starting with rows tagged SNIP or UNVERIFIED.

## How these were checked

All rows were checked on **2026-09-30**. The build environment could not reach learn.microsoft.com directly, so two routes were used:

| Tag | Meaning |
|---|---|
| SRC | Read from the public GitHub source repo that publishes the Learn page (MicrosoftDocs/m365copilot-docs, microsoftgraph/microsoft-graph-docs-contrib, MicrosoftDocs/power-platform, MicrosoftDocs/msteams-docs). Repos had commits dated 2026-09-30. |
| SRC-STALE | Read from MicrosoftDocs/microsoft-365-docs, last synced 2026-04-30. The live page may be newer. |
| SNIP | Only a search-engine summary of the learn.microsoft.com page was available. Copilot Studio documentation is in this tier because its source repo is not public. |
| UNVERIFIED | No Microsoft Learn source confirmed it. The course does not state it as fact. |
| CONFLICT | Two Learn sources disagree. Both are cited. |

Short URL bases:
- `EXT` = https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/
- `MCS` = https://learn.microsoft.com/en-us/microsoft-copilot-studio/
- `GRAPH` = https://learn.microsoft.com/en-us/graph/

---

## 1. Licensing and billing

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| LIC-01 | Microsoft 365 Copilot is an add-on that needs a qualifying base plan (for example Microsoft 365 E3/E5, Business Standard/Premium, Office 365 E1/E3/E5). | https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-licensing | SRC-STALE | Setup |
| LIC-02 | Agent Builder requires a Microsoft 365 Copilot license, or a tenant with pay-as-you-go (Copilot Credits) enabled. | https://learn.microsoft.com/en-us/microsoft-365/copilot/agent-essentials/m365-agents-admin-guide | SRC-STALE | 1, 2 |
| LIC-03 | Copilot Chat without billing: instructions, web search, code interpreter, image generator, custom actions. Not included: SharePoint, connectors, embedded files, Dataverse. | EXT prerequisites#agent-capabilities-and-licensing-models | SRC | 2 |
| LIC-04 | Copilot Chat with pay-as-you-go adds SharePoint, connectors, embedded files and Dataverse. Email, People, Teams messages and meetings still need a Copilot license. Pay-as-you-go is not supported in GCC or GCCH. | EXT prerequisites | SRC | 2 |
| LIC-05 | Users without a Copilot license "do not have access to agent authoring or advanced agent experiences." | EXT prerequisites | SRC | 2 |
| LIC-06 | A Copilot Studio capacity pack provides 25,000 Copilot Credits per month. | https://learn.microsoft.com/en-us/microsoft-365/copilot/pay-as-you-go/copilot-capacity-packs | SRC-STALE | Setup, 9 |
| LIC-07 | Pay-as-you-go bills to an Azure subscription through a Power Platform billing plan. | https://learn.microsoft.com/en-us/power-platform/admin/manage-copilot-studio-copilot-credits-capacity | SRC | Setup |
| LIC-08 | Pay-as-you-go setup needs Azure Owner or Contributor on the subscription and resource group, plus Global Admin, Billing Admin or AI Admin. | https://learn.microsoft.com/en-us/microsoft-365/copilot/pay-as-you-go/setup | SRC-STALE | Setup |
| LIC-09 | Copilot Studio User License is free and assigned to makers. | MCS billing-licensing | SNIP | Setup |
| LIC-10 | Copilot-licensed users are zero-rated for classic answers, generative answers and tenant graph grounding in Copilot Chat, Teams and SharePoint. | MCS billing-licensing; MCS requirements-messages-management | SNIP | 3, 9 |
| LIC-11 | Credit rates: classic answer 1, generative answer 2, agent action 5, tenant graph grounding 10. | MCS requirements-messages-management | SNIP | 9, 12 |
| LIC-12 | Autonomous runs (event triggers, scheduled runs) are billable even for licensed users. A separate per-trigger rate was not found. | MCS requirements-messages-management | SNIP (rate UNVERIFIED) | 9 |
| LIC-13 | Custom engine agents: users do not need a Copilot license to use one in Copilot Chat; unlicensed users can incur Copilot Credits when the agent uses tenant data. | EXT cost-considerations | CONFLICT with LIC-14 | 8 |
| LIC-14 | A docs include file says custom engine agents are available only to licensed users or tenants that allow metered usage. | m365copilot-docs repo, includes/preview-disclaimer-copilot-no-license.md (no public URL) | CONFLICT with LIC-13 | 8 |
| LIC-15 | Microsoft 365 Agents Toolkit: you can build without a Copilot license. Grounding on org data needs a Copilot license or pay-as-you-go. | EXT prerequisites | SRC | 6 |

## 2. Agent Builder (Microsoft 365 Copilot)

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| AB-01 | Available from microsoft365.com/chat, office.com/chat and Teams desktop and web. Not on mobile. | EXT agent-builder | SRC | 1 |
| AB-02 | Instructions: 8,000 characters. Name: 30 characters. Description: 1,000 characters. Icon: PNG, 192 x 192, 1 MB. | EXT agent-builder-build-agents | SRC | 1, 2 |
| AB-03 | Starter prompts: "no minimum". Maximum number not stated. | EXT agent-builder-build-agents | SRC (maximum UNVERIFIED) | 1 |
| AB-04 | Public websites: 4 URLs, at most two path levels deep, no query strings. | EXT agent-builder-add-knowledge | SRC | 2 |
| AB-05 | SharePoint: 100 files, folders or sites. SharePoint lists: 1. OneDrive: 50 files. Teams chats: 5. Meetings: 5. Embedded (uploaded) files: 20. Connectors and Dataverse: no documented limit. | EXT agent-builder-add-knowledge | SRC | 2 |
| AB-06 | A SharePoint list source can hold up to 20,000 items and 50 MB of text. | EXT agent-builder-add-knowledge | SRC | 2 |
| AB-07 | SharePoint knowledge is unavailable when Restricted SharePoint Search is on. | EXT agent-builder-add-knowledge | SRC | 2 |
| AB-08 | Embedded files: .doc, .docx, .pdf, .ppt, .pptx, .txt up to 512 MB each; .xls, .xlsx up to 30 MB; .html for SharePoint only. Not supported in GCC. | EXT agent-builder-add-knowledge | SRC | 1, 2 |
| AB-09 | Copilot searches the full content of up to 20 files. Above 20, it uses the 20 most relevant. | EXT optimize-content-retrieval | SRC | 2, 6 |
| AB-10 | New agents are private. Share as "Can edit" (co-owner) or "Can chat". Groups can only be added as chat users. Org-wide sharing is a toggle controlled by an admin setting. | EXT agent-builder-share-manage-agents | SRC | 2 |
| AB-11 | Users can add a shared agent only if they hold the licenses its capabilities need; otherwise "attempts to use the agent might result in an error." | EXT agent-builder-share-manage-agents | SRC | 2 |
| AB-12 | No customer-managed keys. Agents cannot be used in Teams group or one-to-one chats. | EXT agent-builder | SRC | 2 |
| AB-13 | Skills in Agent Builder are PREVIEW and limited to Frontier Program organizations. | EXT agent-builder | SRC | 2 (mention only) |

## 3. Copilot Studio knowledge

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| CS-K01 | Without a Microsoft 365 Copilot license in the same tenant, generative answers use only SharePoint files under 7 MB. | MCS requirements-quotas; MCS knowledge-add-sharepoint | SNIP | 3 |
| CS-K02 | With a Copilot license in the tenant and tenant graph grounding with semantic search on, files up to 200 MB are used. | MCS knowledge-copilot-studio | SNIP | 3 |
| CS-K03 | SharePoint and Copilot connector sources support files up to 512 MB for PDF, PPTX and DOCX. | MCS knowledge-copilot-studio | SNIP | 3 |
| CS-K04 | Tenant graph grounding requires agent authentication set to "Authenticate with Microsoft". New agents default to it. | MCS knowledge-copilot-studio; MCS configuration-end-user-authentication | SNIP | 3 |
| CS-K05 | Manual Entra app registration for SharePoint knowledge needs Sites.Read.All and Files.Read.All. | MCS nlu-generative-answers-sharepoint-onedrive | SNIP | 3 |
| CS-K06 | SharePoint URL must include the site path and no query parameters. | MCS knowledge-add-sharepoint | SNIP | 3 |
| CS-K07 | A folder source holds up to 1,000 files, 50 folders and 10 subfolder levels. Each folder counts as one source. | MCS requirements-quotas | SNIP (scope unclear) | 3 |
| CS-K08 | Encryption is supported only through sensitivity labels, and only for the SharePoint knowledge source. The user needs VIEW and EXTRACT usage rights. | MCS security-faq; https://learn.microsoft.com/en-us/purview/ai-copilot-studio | SNIP | 3 |
| CS-K09 | Uploaded files: up to 500 per agent, 512 MB each. Encrypted (label or password) files are not supported. Images, audio, video and executables are not supported, except images embedded in PDFs. | MCS knowledge-add-file-upload | SNIP | 3 |
| CS-K10 | SharePoint lists as knowledge: up to 15 lists, 35,000 rows each, 120,000 rows in total; queries use the first 2,048 rows. | MCS agents-experience/knowledge-sharepoint-lists | SNIP (new-experience docs) | 3 |
| CS-K11 | Dataverse knowledge: up to 15 tables per source. Glossary and synonym updates can take up to 15 minutes. | MCS knowledge-add-dataverse | SNIP | 4 |
| CS-K12 | Public websites: 25 with generative orchestration, 4 with classic orchestration or a topic-level generative answers node. | MCS requirements-quotas | SNIP | 3 |
| CS-K13 | Scanned or image-only PDFs are not OCR'd for knowledge. Observed in a course tenant on 2026-10-07: an image-only PDF returned no answer as SharePoint knowledge or as an uploaded file. | Community answers only; course observation | UNVERIFIED (not documented on Learn) | 3 |
| CS-K14 | Total number of SharePoint URLs per agent. | Not found | UNVERIFIED | 3 |

## 4. Copilot Studio authoring, actions, triggers, multi-agent

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| CS-A01 | Generative AI message rate: 100 RPM / 2,000 RPH on pay-as-you-go; 10 RPM / 200 RPH on trial and developer environments. | MCS requirements-quotas | SNIP | 12 |
| CS-A02 | An agent flow must return a response within 100 seconds. | MCS flow-agent; MCS advanced-flow-create | SNIP | 5 |
| CS-A03 | Express mode for agent flows is PREVIEW; needs the "When an agent calls a flow" trigger; no delay or webhook actions. | MCS agent-flow-express-mode | SNIP | 5 |
| CS-A04 | Asynchronous flow response lets long flows call back after the time limit. | MCS flow-asynchronous-response | SNIP (status UNVERIFIED) | 5 |
| CS-A05 | Agent instructions limit 8,000 characters. | Community answer only | UNVERIFIED | 3 |
| CS-A06 | Topics per agent and trigger phrases per topic. | Not found | UNVERIFIED | 4 |
| CS-A07 | Event triggers work only with generative orchestration. | MCS authoring-triggers-about; MCS authoring-trigger-event | SNIP | 9 |
| CS-A08 | Event triggers run only with the agent author's credentials. Makers are warned before publishing. | MCS authoring-triggers-about | SNIP | 9 |
| CS-A09 | Event triggers consume Copilot Credits. | MCS authoring-triggers-about | SNIP | 9 |
| CS-A10 | GA or preview status of event triggers. | Not stated | UNVERIFIED | 9 |
| CS-A11 | Connecting agents over A2A is GA. Connecting Foundry, Fabric and Agents SDK agents is PREVIEW. | MCS authoring-add-other-agents; MCS add-agent-foundry-agent | SNIP | 10 |
| CS-A12 | Child agents always receive the parent's context. Connected agents have a context-inclusion setting. | MCS add-agent-child-agent | SNIP | 10 |
| CS-A13 | GA status of child agents and Copilot Studio to Copilot Studio connected agents. | Not stated | UNVERIFIED | 10 |
| CS-A14 | Agent evaluation is GA in the classic docs (test sets, CSV import, multi-turn, version comparison). The new-experience docs label it PREVIEW. | MCS analytics-agent-evaluation-intro; MCS agents-experience/analytics-agent-evaluation-intro | SNIP, CONFLICT | 12 |
| CS-A15 | Bring your own Foundry model for prompts is GA. | MCS bring-your-own-model-prompts | SNIP | 8 |
| CS-A16 | Selecting a Foundry model as the agent's primary model. | MCS authoring-select-agent-model | SNIP (status UNVERIFIED) | 8 |

## 5. Declarative agents and API plugins

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| DA-01 | Current declarative agent manifest schema is v1.8. v1.8 adds EmailActions and MeetingActions. | EXT declarative-agent-manifest-1.8 | SRC | 6 |
| DA-02 | v1.8 capabilities: WebSearch, OneDriveAndSharePoint, GraphConnectors, GraphicArt, CodeInterpreter, Dataverse, TeamsMessages, Email, EmailActions, People, ScenarioModels, Meetings, MeetingActions, EmbeddedKnowledge. Each may appear once. | EXT declarative-agent-manifest-1.8 | SRC | 6 |
| DA-03 | `instructions` up to 8,000 characters; `name` up to 100; `description` up to 1,000. | EXT declarative-agent-manifest-1.8 | SRC | 6 |
| DA-04 | `conversation_starters` up to 12. | EXT declarative-agent-manifest-1.8 | SRC | 6 |
| DA-05 | `actions`: 1 to 10 plugins. WebSearch `sites`: up to 4. EmbeddedKnowledge: up to 10 files of 1 MB. Disclaimer: up to 500 characters. | EXT declarative-agent-manifest-1.8 | SRC | 6 |
| DA-06 | `worker_agents` is PREVIEW. | EXT declarative-agent-manifest-1.8 | SRC | 6 (mention only) |
| DA-07 | Runtime limits: 50 grounding records, 25 items per plugin response, 4,096 tokens, 45-second timeout. | EXT declarative-agent-architecture | SRC | 6 |
| DA-08 | Current plugin manifest schema is v2.4. v2.4 adds the RemoteMCPServer runtime and file-based `static_template`. | EXT plugin-manifest-2.4 | SRC | 6 |
| DA-09 | Plugin auth types: None, OAuthPluginVault, ApiKeyPluginVault. Supported methods: Entra SSO, OAuth 2.0 authorization code (with PKCE), API key, none. | EXT plugin-manifest-2.4; EXT plugin-authentication | SRC | 6 |
| DA-10 | API keys can be sent as bearer token, custom header or query parameter. | EXT plugin-authentication-api-key | SRC, CONFLICT with DA-11 | 6 |
| DA-11 | Known issues page states API keys in custom headers, query parameters or cookies are not supported. | EXT known-issues | SRC, CONFLICT with DA-10 | 6 |
| DA-12 | Not supported: nested objects in request bodies or parameters; oneOf, allOf, anyOf, circular references; OAuth flows other than authorization code; multiple auth types on one endpoint; multiple response semantics per function. | EXT known-issues | SRC | 6 |
| DA-13 | Each operation should have an `operationId`. | EXT openapi-document-guidance | SRC | 6 |
| DA-14 | No hard limit on functions per plugin; quality may drop above 10. Up to 5 plugins are injected per turn; beyond that, semantic matching selects them. | EXT overview-plugins | SRC | 6 |
| DA-15 | OpenAPI 2.0 and 3.0.x supported and `operationId` required for API message extensions built with Agents Toolkit. | https://learn.microsoft.com/en-us/microsoftteams/platform/messaging-extensions/create-api-message-extension | SRC (Copilot plugin OpenAPI 3.1 support UNVERIFIED) | 6 |
| DA-16 | Response size limit in KB or MB. | Not found | UNVERIFIED | 6 |
| DA-17 | Custom app upload must be On (Teams admin center > Teams apps > Setup policies). | EXT prerequisites | SRC | 6 |

## 6. Copilot connectors (Microsoft Graph connectors API)

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| GC-01 | Up to 128 properties per schema. | GRAPH connecting-external-content-api-limits | SRC | 7 |
| GC-02 | Maximum item size 30 MB, measured as parsed text. | GRAPH connecting-external-content-api-limits | SRC | 7 |
| GC-03 | 100,000 external groups per tenant; 10,000 external group memberships per user in a query. | GRAPH connecting-external-content-api-limits | SRC | 7 |
| GC-04 | Schema updates: properties can be added (reingest recommended); search attributes can be added or removed (reingest required); aliases and semantic labels can change. `refinable` cannot be added in an update. | GRAPH connecting-external-content-manage-schema | SRC | 7 |
| GC-05 | A property cannot be both searchable and refinable. A property must be retrievable to take a semantic label. | GRAPH connecting-external-content-manage-schema | SRC | 7 |
| GC-06 | Semantic labels (v1.0 property resource): title, url, createdBy, lastModifiedBy, authors, createdDateTime, lastModifiedDateTime, fileName, fileExtension, containerName, containerUrl, iconUrl, and the evolvable values assignedTo, dueDate, closedDate, closedBy, reportedBy, sprintName, severity, state, priority, secondaryId, itemParentId, parentUrl, tags, itemType, itemPath, numReactions. The course uses the first group only. | GRAPH api/resources/externalconnectors-property; GRAPH connecting-external-content-manage-schema | SRC | 7 |
| GC-07 | ACL types: user, group, everyone, everyoneExceptGuests, externalGroup. Deny overrides grant. | GRAPH api/resources/externalconnectors-acl | SRC | 7 |
| GC-08 | Default 5 million items per connection, expandable to 50 million on request. | https://learn.microsoft.com/en-us/microsoftsearch/licensing | SNIP | 7 |
| GC-09 | Number of connections per tenant. | Not found | UNVERIFIED | 7 |
| GC-10 | Whether guests can see connector items with `everyone` ACL. | Not found | UNVERIFIED | 7 |
| GC-11 | Schema creation can take 5 to 15 minutes; poll the operation URL in the Location header. | GRAPH api/externalconnectors-externalconnection-patch-schema | SRC | 7 |

## 7. Custom engine agents

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| CE-01 | Custom engine agents own orchestration, model and data. Build with Copilot Studio, Microsoft 365 Agents SDK, Teams SDK or Microsoft Foundry. | EXT overview-custom-engine-agent | SRC | 8 |
| CE-02 | Agents SDK agents deploy to Azure through Azure Bot Service. Use the Agents Toolkit proxy-app path when you need SSO. | EXT create-deploy-agents-sdk | SRC | 8 |
| CE-03 | GA label of the Microsoft 365 Agents SDK. | https://learn.microsoft.com/en-us/microsoft-365/agents-sdk/agents-sdk-overview | UNVERIFIED | 8 |

## 8. Administration, environments, ALM, audit

| ID | Limit or fact | Source | Tag | Used in |
|---|---|---|---|---|
| ADM-01 | Microsoft 365 admin center > Agents > Settings: agent management rules, allowed agent types, security templates, sharing, user access. | https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings | SRC-STALE | Setup, 11 |
| ADM-02 | User access: All users (default), No users, or specific users and groups. | same | SRC-STALE | Setup, 11 |
| ADM-03 | Sharing setting applies only to agents built in Agent Builder. | same; EXT agent-builder-share-manage-agents | SRC | 2, 11 |
| ADM-04 | Agent inventory (publish, deploy, block, remove) is under Integrated apps. | https://learn.microsoft.com/en-us/microsoft-365/admin/manage/manage-copilot-agents-integrated-apps | SRC-STALE | 11 |
| ADM-05 | Agent Registry at Agents > All agents > Registry. Its Graph APIs are PREVIEW. | https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-registry | SRC | 11 |
| ADM-06 | AI Administrator manages agents; Global Reader is read-only. | manage-copilot-agents-integrated-apps | SRC-STALE | Setup, 11 |
| ADM-07 | Copilot Studio agents in Microsoft 365 need generative AI enabled in Power Platform and the Copilot Studio app deployed in the Microsoft 365 admin center. | EXT prerequisites | SRC | 3 |
| ADM-08 | "Copilot Studio authors" tenant setting takes a security group. | https://learn.microsoft.com/en-us/troubleshoot/power-platform/copilot-studio/licensing/authors-access | SNIP | Setup, 11 |
| ADM-09 | Connector administration: AI Admin; Search Admin for Data sources. | https://learn.microsoft.com/en-us/microsoft-365/copilot/connectors/deployment-overview | SNIP | 7 |
| ENV-01 | Environment types: Default, Production, Sandbox, Trial (30 days), Developer, Dataverse for Teams. Zero or one Dataverse database each. | https://learn.microsoft.com/en-us/power-platform/admin/environments-overview | SRC | Setup, 11 |
| ENV-02 | Developer environments are owner-only; security groups cannot be assigned. | same | SRC | 4, 11 |
| ENV-03 | Developer Plan: free, includes Dataverse, up to 3 developer environments per user, 750 flow runs per month, 2 GB database; disabled after 30 days of inactivity. | https://learn.microsoft.com/en-us/power-platform/developer/plan | SRC | Setup, 4 |
| ALM-01 | Pipelines: target environments other than developer environments must be managed environments. From October 2026 admins get 30 days to approve managed-environment enablement before deployments to unmanaged targets are blocked. | https://learn.microsoft.com/en-us/power-platform/alm/pipelines | SRC | 11 |
| AUD-01 | Copilot interactions are audited as `CopilotInteraction` records carrying `AppIdentity` and `AgentId`. | https://learn.microsoft.com/en-us/purview/audit-copilot | SNIP | 11 |
