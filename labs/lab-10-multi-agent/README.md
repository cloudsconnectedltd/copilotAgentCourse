# Lab 10: Multi-agent orchestration

| | |
|---|---|
| Build path | Copilot Studio (parent agent with a child agent and two connected Copilot Studio agents) in environment `HLE-Dev` |
| Estimated time | 2.5 hours |
| Prerequisites | [Lab 3](../lab-03-studio-sharepoint-knowledge/README.md) (`HLE HR Assistant`, published, in `HLE-Dev`). [Lab 4](../lab-04-studio-dataverse-topics/README.md) and [Lab 5](../lab-05-studio-actions-flows/README.md) (`HLE Field Ops Assistant` with Dataverse knowledge and the `HLE Get Outage Status` flow, published, in `HLE-Dev`). Mock API running and reachable ([`data/api/run-local.md`](../../data/api/run-local.md)). Setup scripts [`02-provision-sites.ps1`](../../setup/02-provision-sites.ps1) and [`03-upload-content.ps1`](../../setup/03-upload-content.ps1) (Hub Finance library). |
| Personas used | Learner (maker and tester). Other personas are not used: `HLE-Dev` is a developer environment and is owner-only (ENV-02). |
| Status | Contains UNVERIFIED limits: CS-A13 (GA status of child agents and of Copilot Studio to Copilot Studio connected agents is not stated; **check GA/preview status on Learn**). GA per SNIP: connecting agents over A2A (CS-A11). PREVIEW, not built here: connecting Microsoft Foundry, Fabric and Agents SDK agents (CS-A11). |
| Limits referenced | [CS-A11, CS-A12, CS-A13, CS-K04, CS-K06, CS-A01, ENV-02, AB-02, DA-03](../../reference/limits.md) |

> **Check before you run.** All Copilot Studio rows used here are SNIP or UNVERIFIED. Confirm them on Learn before you start, and follow Learn if it differs.
>
> | Row | What to confirm | Page |
> |---|---|---|
> | CS-A13 | Whether child agents and Copilot Studio connected agents are GA or preview | https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-add-other-agents |
> | CS-A11 | A2A GA; Foundry, Fabric, Agents SDK connections PREVIEW | https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-add-other-agents and https://learn.microsoft.com/en-us/microsoft-copilot-studio/add-agent-foundry-agent |
> | CS-A12 | Child agents always get the parent's context; connected agents have a context-inclusion setting | https://learn.microsoft.com/en-us/microsoft-copilot-studio/add-agent-child-agent |
> | CS-K04 | Tenant graph grounding needs "Authenticate with Microsoft" | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio |
> | CS-A01 | Developer environments are limited to 10 generative AI requests per minute and 200 per hour | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
>
> Copilot Studio docs could not be read from source while this course was built. UI labels may differ; look for the concept.

## Objective

Build **HLE Front Door**, one agent that Harbourline staff talk to, which hands each question to the right specialist:

| Specialist | Kind | Answers | Built in |
|---|---|---|---|
| `HLE Policy Router` | Child agent (lives inside HLE Front Door) | Finance, expense, travel spending and approval authority policy (Hub Finance library, plus the HR Travel Policy) | This lab |
| `HLE HR Assistant` | Connected agent (separate Copilot Studio agent) | HR policies: leave, bereavement, on-call, conduct, and the rest of HR-Policies | Lab 3 |
| `HLE Field Ops Assistant` | Connected agent | Assets, work orders and crews (Dataverse), live outage status (mock API flow) | Labs 4 and 5 |

Then you show that routing is only as good as the descriptions, that authentication and conversation context do not flow the way you might assume, and how to find where a handoff went wrong.

## Concepts

- **Child agent.** A lightweight agent defined inside the parent. It shares the parent's settings and always receives the parent's conversation context (CS-A12). Good for a scoped job that no other agent needs.
- **Connected agent.** A separate, independently published agent that the parent calls. It keeps its own knowledge, tools, authentication and lifecycle, and it can be reused by several parents. The parent decides whether to pass conversation history (CS-A12). Connecting over A2A is GA; connecting Foundry, Fabric and Agents SDK agents is PREVIEW (CS-A11). The status of Copilot Studio to Copilot Studio connections is UNVERIFIED (CS-A13).
- **Routing.** With generative orchestration, the parent picks a child or connected agent the same way it picks a tool: from its **name and description**. There are no trigger phrases to fall back on.
- **Activity map.** The test pane shows each step of a turn (which agent or tool was chosen, with what input, and what came back). It is your main debugging tool for handoffs.

## Steps

### Part A: check the specialists (15 min)

1. In Copilot Studio (https://copilotstudio.microsoft.com), environment `HLE-Dev`, open `HLE HR Assistant`. Confirm it is published, its authentication is **Authenticate with Microsoft** (Lab 3 default, CS-K04), and test: `How many paid days of bereavement leave do I get for an immediate family member?` Expected: 5 paid days, plus up to 5 unpaid (Bereavement-Leave.docx).
2. Open `HLE Field Ops Assistant`. Confirm it is published and test: `What is the condition score of asset TX-ON-10423?` Expected: 38 (Kingston Service Centre, installed 1987). Then `What is the status of outage OUT-2026-0412?` Expected: Crew On Site, 3,214 customers, ETR 2026-09-30 14:30 EDT. If the outage question fails, start the mock API and dev tunnel first (`data/api/run-local.md`).
3. In each of the two agents, open **Settings** and turn on the option that lets other agents connect to and use this agent (name may differ, for example "Let other agents connect to and use this one"). Publish again.
4. Replace each agent's **description** with the precise text from [`solutions/lab-10/agent-descriptions.md`](../../solutions/lab-10/agent-descriptions.md) section 1, and publish. For example, for `HLE HR Assistant`:

   ```text
   Answers Harbourline Energy Co. HR policy questions from the HR-Policies library: annual leave and carry-over, bereavement, parental leave, FMLA (US), overtime, on-call and storm call-out pay, remote work, code of conduct, harassment prevention, performance reviews, accommodation, grievances and safety incident reporting. Does not answer expense limits, per diems, hotel caps or approval authority (use HLE Policy Router), or assets, work orders, crews and outages (use HLE Field Ops Assistant).
   ```

### Part B: build the parent (20 min)

5. Create a new agent in `HLE-Dev`:

   | Field | Value |
   |---|---|
   | Name | `HLE Front Door` |
   | Description | `Single entry point for Harbourline Energy Co. staff. Routes HR, finance policy and field operations questions to specialist agents.` |
   | Orchestration | Generative |
   | Authentication | Authenticate with Microsoft |
   | Knowledge | None. Turn off web search and the option to use general knowledge (names may differ). The parent must not answer from its own knowledge. |

6. Paste the instructions from [`solutions/lab-10/front-door-instructions.txt`](../../solutions/lab-10/front-door-instructions.txt). They start:

   ```text
   You are HLE Front Door, the single entry point for Harbourline Energy Co. staff questions.
   You do not answer questions from your own knowledge. You route each question to exactly one specialist agent, or to more than one only when the user clearly asks two separate things.
   ```

7. Optional: replace the Conversation Start topic with [`solutions/lab-10/conversation-start-topic.yaml`](../../solutions/lab-10/conversation-start-topic.yaml) in the topic's code editor, so users see what the Front Door covers.

### Part C: add the child agent (20 min)

8. In `HLE Front Door` > **Agents** > **Add** > create a new child agent (UI labels may differ; it may be called "New child agent" or "Add an agent > Create"). Set:

   | Field | Value |
   |---|---|
   | Name | `HLE Policy Router` |
   | Description (when to use) | Precise text from `agent-descriptions.md` section 1 |
   | Instructions | [`solutions/lab-10/policy-router-instructions.txt`](../../solutions/lab-10/policy-router-instructions.txt) |
   | Knowledge | SharePoint: `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Finance` and `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies/Travel-Policy.docx` (site path included, no query string, CS-K06) |

   If your UI does not let a child agent own knowledge, add the two sources to the parent and select them for the child. The name says "Router" because its job is to decide which policy governs: the Travel Policy (HR-POL-050) defers to the Expense Policy (HLE-FIN-101) for money matters, and the child must answer from the governing document.

### Part D: add the connected agents (15 min)

9. In `HLE Front Door` > **Agents** > **Add** > **Copilot Studio agent** (connect an existing agent). Select `HLE HR Assistant`. Check the description the parent shows; it must be the precise one from step 4. Leave the conversation history (context) setting **on**.
10. Repeat for `HLE Field Ops Assistant`.

### Part E: test routing in the test pane (30 min)

11. Open the test pane and turn on the activity map (or "Show activity"; UI labels may differ). Type each prompt and record which agent handled it:

    | Prompt | Expected agent | Expected answer |
    |---|---|---|
    | `How many days of unused annual leave can I carry over into next year?` | HLE HR Assistant | 5 days, used by March 31 (Leave Policy v4, HR-POL-012) |
    | `What is the weekly on-call stipend?` | HLE HR Assistant | CAD 300 or USD 250 per full week (Overtime-and-On-Call.docx 4.2) |
    | `Who has to approve an operating expense of CAD 80,000?` | HLE Policy Router | Director (Approval-Matrix.docx) |
    | `What is the hotel cap in Toronto before taxes?` | HLE Policy Router | CAD 275; above cap needs Director approval before booking (Expense-Policy.docx 4) |
    | `Which Emergency work orders are still open?` | HLE Field Ops Assistant | WO-2026-01043, WO-2026-01083, WO-2026-01097, WO-2026-01099 |
    | `What is the status of outage OUT-2026-0412?` | HLE Field Ops Assistant | Crew On Site, 3,214 customers, ETR 14:30 EDT, CREW-ON-03 |
    | `What will the weather be in Toledo tomorrow?` | None | Polite decline: outside what the Front Door covers |

    Pace yourself: every routed turn makes several generative calls across parent and specialist, and developer environments are limited to 10 per minute and 200 per hour (CS-A01).

12. Publish `HLE Front Door`. Run [`validate.md`](validate.md), then [`break-it.md`](break-it.md).

## Caveats this lab triggers

| Caveat ID | Name | Where |
|---|---|---|
| C-10-a | Description quality drives routing; vague descriptions misroute | [break-it.md#c-10-a](break-it.md#c-10-a-vague-descriptions-misroute-questions) |
| C-10-b | Authentication does not propagate the way you expect | [break-it.md#c-10-b](break-it.md#c-10-b-authentication-propagation) |
| C-10-c | Connected agents only see the context you pass them | [break-it.md#c-10-c](break-it.md#c-10-c-conversation-context-across-the-handoff) |
| C-10-d | Debugging a failed handoff | [break-it.md#c-10-d](break-it.md#c-10-d-debugging-a-failed-handoff) |

All four are also in [`caveats.csv`](caveats.csv).

## Files for this lab

| File | Purpose |
|---|---|
| [`break-it.md`](break-it.md) | Reproduce and fix each caveat |
| [`validate.md`](validate.md) | Run [`evals/lab-10-questions.csv`](../../evals/lab-10-questions.csv) |
| [`cleanup.md`](cleanup.md) | Remove what this lab created, and what to keep for Lab 11 |
| [`../../solutions/lab-10/`](../../solutions/lab-10/README.md) | Instructions, descriptions, topic YAML |
