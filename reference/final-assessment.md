# Final assessment

25 scenarios at Harbourline Energy Co. For each one:

1. **Pick the build path**: Agent Builder, Copilot Studio, declarative agent (Agents Toolkit), custom engine agent, or a Copilot connector attached to one of these.
2. **Predict the caveat** the team will hit first, and how to avoid it.

Answers are at the end. Caveat IDs link to [caveats-index.md](caveats-index.md). Allow about one hour. A reasonable pass mark is 20 of 25 on build path and 18 of 25 on caveat.

## Scenarios

1. An HR business partner wants a personal agent over the HR-Policies library to answer staff questions in Copilot Chat this afternoon. No IT involvement. Staff ask "How many vacation days do I get after six years?"
2. The same HR agent is shared with the whole Ops-US group. Tom Whitfield, who has no Microsoft 365 Copilot license, reports that the agent errors when he opens it.
3. Finance wants an agent that answers approval threshold questions. It is grounded on both `Approval-Matrix.docx` and `Approval-Matrix.xlsx`. A user asks who approves a CAD 120,000 consulting engagement.
4. HR wants an employee assistant published in Teams to all staff, with content moderation, analytics, and deployment from Dev to Prod through solutions. Leaders must not see answers from the `Restricted` folder unless they are in the HR group.
5. The HR assistant from scenario 4 never answers questions about the 25-year service award, which appears only in the 9 MB employee handbook. Tenant graph grounding has been switched off to test cost.
6. A field supervisor asks the HR assistant about the signed policy acknowledgement reference number. The only source is a scanned PDF.
7. Operations wants an agent that looks up transformer assets and open work orders stored in Dataverse, collects a field request through a guided form, and shows a summary card.
8. In the scenario 7 agent, a user types "ticket for TX-ON-10423" meaning a work order. The agent starts a topic about facilities tickets instead of answering from Dataverse.
9. The field ops agent must dispatch a crew by calling the internal outage REST API. The call can take up to two minutes during storms.
10. A pro developer team wants an agent in Microsoft 365 Copilot that calls the outage API, renders results as an adaptive card, lives in source control, and is scoped to exactly two SharePoint libraries.
11. The scenario 10 team imports their existing OpenAPI document. It uses `oneOf` in the dispatch request body and has one operation without an `operationId`.
12. The outage desk agent asks the customer lookup API for 200 accounts at once and shows only some of them.
13. Service tickets live in a SQL Server database outside Microsoft 365. Staff want to ask any agent about them, with results trimmed to their region.
14. After the ticket ingestion goes live, the team decides they need to filter results by ticket category and tries to make the existing `category` property refinable.
15. An Ontario field technician can see a ticket through the "everyone except guests" grant, but a deny entry for the Ops-Ontario group also exists on that ticket.
16. The grid planning team wants their own model, their own retrieval over engineering studies, and a channel on a public web page, while still being available in Teams.
17. The scenario 16 agent is deployed to Azure and works in the Playground, but in Teams it answers "I could not reach the outage service."
18. Operations wants every new field report dropped in a SharePoint folder to be read, an asset looked up, and a work order created without anyone opening a chat.
19. The scenario 18 agent writes its triage summary back into the same folder it watches. Credit consumption spikes overnight.
20. A finance analyst drops a field report into the watched folder, and the resulting work order shows the maker as the creator.
21. The organization wants one front-door agent that sends HR questions to the HR assistant and field questions to the field ops agent. Both already exist.
22. In scenario 21, "What is the carry-over rule?" is answered by the field ops agent with an unrelated reply.
23. The Dev to Test to Prod pipeline fails at the first stage, even though the solution exports cleanly.
24. A maker fixes a bug directly in Prod on top of the managed solution. After the next pipeline deployment, Prod still behaves like the hotfix instead of the new release.
25. The capstone team bulk-runs 200 evaluation prompts in the developer environment and sees throttling and failed test cases.

## Answer key

| # | Build path | Primary caveat | Why and how to avoid it |
|---|---|---|---|
| 1 | Agent Builder | [C-02-f](caveats-index.md#lab-02-lab-02-agent-builder-deep-dive) conflicting leave versions | v3 and v4 give different day counts for year 6. Add a version rule to the instructions or scope out v3. |
| 2 | Agent Builder | [C-02-d](caveats-index.md#lab-02-lab-02-agent-builder-deep-dive) unlicensed users | SharePoint knowledge needs a Copilot license or pay-as-you-go (LIC-03, LIC-04, AB-11). |
| 3 | Agent Builder or Copilot Studio | [C-04-f](caveats-index.md#lab-04-lab-04-studio-dataverse-topics) docx vs xlsx | The xlsx still shows the old Director threshold (150,000 vs 75,000). Remove the stale source or state which one governs. |
| 4 | Copilot Studio | [C-03-d](caveats-index.md#lab-03-lab-03-studio-sharepoint-knowledge) security trimming | Needs "Authenticate with Microsoft" so answers are trimmed per user (CS-K04). Test with personas outside the developer environment ([C-11-g](caveats-index.md#lab-11-lab-11-alm-governance)). |
| 5 | Copilot Studio | [C-03-a](caveats-index.md#lab-03-lab-03-studio-sharepoint-knowledge) oversized file excluded | Without tenant graph grounding the documented SharePoint limit is 7 MB (CS-K01). Re-enable grounding or split the file. |
| 6 | Copilot Studio | [C-03-b](caveats-index.md#lab-03-lab-03-studio-sharepoint-knowledge) scanned PDF | Image-only content may not be extracted (CS-K13 UNVERIFIED). OCR the file or publish a text version. |
| 7 | Copilot Studio | [C-04-g](caveats-index.md#lab-04-lab-04-studio-dataverse-topics) developer environment is owner-only | Topics, slot filling, entities and adaptive cards fit Copilot Studio; plan a shared environment for persona testing (ENV-02). |
| 8 | Copilot Studio | [C-04-d](caveats-index.md#lab-04-lab-04-studio-dataverse-topics) synonym collision (with [C-04-a](caveats-index.md#lab-04-lab-04-studio-dataverse-topics)) | "Ticket" maps to two meanings. Fix synonyms and topic trigger phrases. |
| 9 | Copilot Studio | [C-05-b](caveats-index.md#lab-05-lab-05-studio-actions-flows) 100-second flow limit | Use an asynchronous response pattern (CS-A04) or make the API return quickly. |
| 10 | Declarative agent (Agents Toolkit) | [C-06-d](caveats-index.md#lab-06-lab-06-declarative-agents-toolkit) sideloading policy | Custom app upload must be allowed to test (DA-17). Scope OneDriveAndSharePoint by URL. |
| 11 | Declarative agent | [C-06-b](caveats-index.md#lab-06-lab-06-declarative-agents-toolkit) OpenAPI constraints | `oneOf` and missing `operationId` are not supported (DA-12, DA-13). Flatten the schema and add IDs. |
| 12 | Declarative agent | [C-06-c](caveats-index.md#lab-06-lab-06-declarative-agents-toolkit) response limits | Plugin responses are limited to 25 items (DA-07). Page on the server and ask narrower questions. |
| 13 | Copilot connector attached to agents | [C-07-e](caveats-index.md#lab-07-lab-07-copilot-connector) and [C-07-b](caveats-index.md#lab-07-lab-07-copilot-connector) ACL design | Map region groups to ACLs at ingestion (GC-07). Decide guest visibility deliberately. |
| 14 | Copilot connector | [C-07-a](caveats-index.md#lab-07-lab-07-copilot-connector) schema constraints | `refinable` cannot be added in a schema update (GC-04). Plan refiners before registering, or recreate the connection. |
| 15 | Copilot connector | [C-07-b](caveats-index.md#lab-07-lab-07-copilot-connector) deny beats grant | Deny entries override grants (GC-07). The technician does not see the ticket. |
| 16 | Custom engine agent | [C-08-a](caveats-index.md#lab-08-lab-08-custom-engine-agent) you own grounding | No Copilot orchestrator. Retrieval, safety ([C-08-b](caveats-index.md#lab-08-lab-08-custom-engine-agent)) and citations are yours. |
| 17 | Custom engine agent | [C-08-e](caveats-index.md#lab-08-lab-08-custom-engine-agent) tool endpoint still localhost | Move the API base URL to configuration and set it per environment. |
| 18 | Copilot Studio (autonomous) | [C-09-a](caveats-index.md#lab-09-lab-09-autonomous-triggers) trigger payload | The trigger passes file metadata, so the agent must fetch content and handle missing fields such as the asset ID. |
| 19 | Copilot Studio (autonomous) | [C-09-d](caveats-index.md#lab-09-lab-09-autonomous-triggers) self-triggering loop | Write output to a different folder, filter the trigger, and add an idempotency key. |
| 20 | Copilot Studio (autonomous) | [C-09-b](caveats-index.md#lab-09-lab-09-autonomous-triggers) run-as identity | Event triggers run with the author's credentials (CS-A08). Audit and authorize accordingly. |
| 21 | Copilot Studio (multi-agent) | [C-10-b](caveats-index.md#lab-10-lab-10-multi-agent) authentication propagation | Connected agents that need user sign-in must be configured consistently with the parent. |
| 22 | Copilot Studio (multi-agent) | [C-10-a](caveats-index.md#lab-10-lab-10-multi-agent) vague descriptions | Routing follows agent descriptions. Write precise, scoped descriptions. |
| 23 | Copilot Studio ALM | [C-11-a](caveats-index.md#lab-11-lab-11-alm-governance) target not managed | Pipeline targets must be managed environments (ALM-01). |
| 24 | Copilot Studio ALM | [C-11-b](caveats-index.md#lab-11-lab-11-alm-governance) hotfix in managed target | Changes in Prod create an unmanaged layer on top. Fix in Dev and redeploy; remove the active layer. |
| 25 | Copilot Studio evaluation | [C-12-a](caveats-index.md#lab-12-lab-12-eval-troubleshooting) throttling in developer environments | Generative AI rate is 10 RPM on developer environments (CS-A01). Batch smaller or evaluate elsewhere. |
