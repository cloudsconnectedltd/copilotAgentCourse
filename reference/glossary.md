# Glossary

| Term | Meaning in this course |
|---|---|
| Agent | A configured assistant with a name, instructions, knowledge and optionally actions, used inside Microsoft 365 Copilot, Teams or another channel. |
| Agent Builder | The no-code authoring experience inside Microsoft 365 Copilot Chat. Produces declarative agents. Formerly Copilot Studio agent builder. |
| Declarative agent | An agent that uses the Microsoft 365 Copilot orchestrator, model and security. You declare instructions, knowledge (capabilities) and actions in a manifest. |
| Custom engine agent | An agent that brings its own orchestrator and model. You own grounding, safety and hosting. |
| Copilot Studio | Low-code platform for building agents on Power Platform, with topics, knowledge, tools, triggers and ALM through solutions. |
| Generative orchestration | Copilot Studio mode where the model chooses which topics, knowledge and tools to use. Required for event triggers. |
| Classic orchestration | Copilot Studio mode where trigger phrases route to topics, with generative answers as fallback. |
| Topic | A Copilot Studio conversation unit with triggers, nodes, variables and conditions. |
| Knowledge source | Content an agent grounds on: SharePoint, uploaded files, public websites, Dataverse, Copilot connectors. |
| Grounding | Supplying retrieved content to the model so answers are based on that content. |
| Tenant graph grounding | Copilot Studio option that uses Microsoft 365 semantic search over SharePoint. Needs "Authenticate with Microsoft". |
| Citation | A reference in an answer that links to the source used. |
| Conversation starter | A suggested prompt shown when a user opens an agent. Called "starter prompt" in Agent Builder. |
| Security trimming | Returning only content the signed-in user can already access. |
| Sensitivity label | Purview classification that can encrypt content and restrict usage rights such as VIEW and EXTRACT. |
| Copilot connector | Formerly Microsoft Graph connector. Ingests external content into the Microsoft 365 index with a schema and ACLs. |
| External item | One record pushed through a Copilot connector, with properties, content and an ACL. |
| Semantic label | A mapping from a connector property to a well-known meaning such as title or url. |
| API plugin | An action for a declarative agent, described by an OpenAPI document and a plugin manifest. |
| Response semantics | Plugin manifest settings that tell Copilot how to read an API response and render it, for example as an adaptive card. |
| Adaptive card | JSON-defined card UI rendered in Teams and Copilot. |
| Microsoft 365 Agents Toolkit | VS Code extension for building agents and apps for Microsoft 365. Formerly Teams Toolkit. |
| Microsoft 365 Agents SDK | SDK for building custom engine agents that run in Copilot, Teams and other channels. |
| Agent flow | A Power Automate flow called from a Copilot Studio agent. |
| Custom connector | A Power Platform connector you define from an OpenAPI description. |
| Connection reference | A solution component that points a flow or agent at a connection, so the connection can differ per environment. |
| Environment variable | A solution component that holds a per-environment value such as a URL. |
| Managed environment | A Power Platform environment with extra governance features. Required for pipeline targets. |
| Pipeline | Power Platform deployment of solutions between environments. |
| Event trigger | A Copilot Studio trigger that starts an agent autonomously when something happens, such as a new file. |
| Child agent | An agent defined inside a parent Copilot Studio agent. |
| Connected agent | A separate agent the parent calls. |
| DLP policy | Power Platform data loss prevention policy that groups connectors and can block combinations. |
| Copilot Credits | The billing unit for Copilot Studio and metered agent usage. Formerly messages. |
| PREVIEW | Feature in public preview. Behavior and limits may change. |
