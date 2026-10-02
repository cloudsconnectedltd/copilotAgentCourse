# Lab 10: Break it

Four caveats, in order. Start each from the working `HLE Front Door` at the end of the README, with the test pane's activity map on. Much of multi-agent routing behavior is not documented at a level you can assert, so most symptoms here say "Observe and record" and describe what the documented design leads you to expect. Record which agent the activity map shows for every prompt; that is the evidence.

Pace your prompts: developer environments are limited to 10 generative AI requests per minute (CS-A01), and one routed turn makes several.

---

## C-10-a: Vague descriptions misroute questions

**Caveat ID:** C-10-a

### Steps to reproduce

1. Replace the three specialist descriptions with the vague versions from `solutions/lab-10/agent-descriptions.md` section 2:

   | Agent | Vague description |
   |---|---|
   | HLE HR Assistant | `Helps employees with questions.` |
   | HLE Policy Router | `Answers questions about company policies and money.` |
   | HLE Field Ops Assistant | `Operations assistant.` |

   For the connected agents, change the description in each agent's own settings and publish it, then refresh the connection in `HLE Front Door` (or edit the description on the parent's Agents page if your UI allows). For the child agent, edit it in place.
2. Start a new test session (reset the test pane) and ask, one at a time:
   - `What is the weekly on-call stipend?`
   - `What is the hotel cap in Toronto before taxes?`
   - `Which crews are based at Kingston Service Centre?`
   - `How many days of unused annual leave can I carry over into next year?`
3. For each, record the agent the activity map shows, and the answer.

### Symptom you will see

Observe and record. Expected per the routing design:

- The on-call stipend is an HR policy (Overtime-and-On-Call.docx 4.2, CAD 300 or USD 250 per week), but "stipend" is money, and the vague Policy Router description says "money". The parent may send it to `HLE Policy Router`, which has no Overtime policy in its knowledge and either says it cannot find it or answers with an unrelated finance figure.
- "Which crews are based at Kingston Service Centre?" may go to `HLE HR Assistant` ("helps employees") instead of `HLE Field Ops Assistant`, returning no answer or a wrong one. The correct answer is 7 crews: CREW-ON-01, 02, 03, 09, 11, 15, 21 (Dataverse).
- Results may vary from run to run. Variation itself is the symptom: routing decisions that depend on weak descriptions are not stable.

### Root cause

Under generative orchestration the parent chooses among child agents, connected agents and tools from their names and descriptions. There are no trigger phrases behind them. A description that does not say what the agent covers, and what it does not cover, gives the model nothing to separate "stipend (HR pay rule)" from "per diem (finance rule)". No limits row covers description quality; routing by description is the documented design of adding agents (CS-A11 page).

### Fix

Restore the precise descriptions from `agent-descriptions.md` section 1. A good routing description:

1. Starts with the domain and the source: "HR policy questions from the HR-Policies library".
2. Lists the concrete topics, using the words users use ("on-call and storm call-out pay", "per diems", "hotel caps", "work orders", "outage status").
3. States the boundary: what it does **not** answer and which agent does.
4. Resolves known overlaps explicitly. Here: hotel caps and mileage appear in both the Travel Policy (HR) and the Expense Policy (Finance); the Expense Policy governs money, so both descriptions name `HLE Policy Router` for them.

Then re-run the four prompts and confirm the expected agents (README step 11). Keep a routing test set like `evals/lab-10-questions.csv` and re-run it after every description change.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-add-other-agents

---

## C-10-b: Authentication propagation

**Caveat ID:** C-10-b

### Steps to reproduce

1. In `HLE Front Door` > Settings > Security > Authentication, change to **No authentication** (UI labels may differ). Save and publish. Leave `HLE HR Assistant` on **Authenticate with Microsoft**.
2. Reset the test pane and ask: `How many paid days of bereavement leave do I get for an immediate family member?`
3. Ask a Field Ops question: `What is the condition score of asset TX-ON-10423?`
4. Open the activity map for both turns. Note whether the connected agent was called, whether a sign-in prompt appeared, and what came back.
5. Also try the reverse: set `HLE Front Door` back to **Authenticate with Microsoft** and set `HLE Field Ops Assistant` to **No authentication**; publish both; ask step 3 again.

### Symptom you will see

Observe and record. Expected per the docs:

- `HLE HR Assistant` answers from SharePoint, which uses tenant graph grounding and needs "Authenticate with Microsoft" (CS-K04). With an unauthenticated parent there is no signed-in user identity to hand to the connected agent. Expect one of: the connected agent is not offered or fails to connect, a sign-in prompt appears, an error in the activity map, or a "cannot find" answer where step 1 of the README got "5 paid days, plus up to 5 unpaid". Record which.
- Whether a connected agent that requires user authentication can be called at all from an unauthenticated parent is not stated in any source this course could read. Record the exact message.
- Step 5: the Field Ops Assistant's Dataverse knowledge and Lab 5 flow connections may stop working or behave differently without user authentication. Record it.

### Root cause

Each connected agent keeps its own authentication configuration; the parent does not grant it an identity. SharePoint knowledge answers with the signed-in user's permissions and requires "Authenticate with Microsoft" (CS-K04). If the parent has no authenticated user, nothing downstream can act as that user. Child agents do not have this problem in the same way because they run inside the parent with its settings and context (CS-A12). The exact propagation behavior between Copilot Studio agents is not documented in a source this course could verify (treat it as UNVERIFIED, CS-A13 for the feature's status).

### Fix

- Use the same authentication mode, "Authenticate with Microsoft", on the parent and every connected agent that reads user-permissioned data.
- Decide per connected agent whether it should act as the user (SharePoint, Dataverse knowledge with user permissions) or as a service connection (flows with maker connections, as in Lab 5), and document it. Mixed identities inside one conversation are hard to audit.
- Test with a non-owner persona in a sandbox or production environment before release. `HLE-Dev` is owner-only (ENV-02), so everything in this lab runs as the owner and hides permission differences.
- Restore: set both agents back to Authenticate with Microsoft and publish.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/configuration-end-user-authentication

---

## C-10-c: Conversation context across the handoff

**Caveat ID:** C-10-c

### Steps to reproduce

1. In `HLE Front Door` > Agents > `HLE Field Ops Assistant`, turn **off** the setting that passes conversation history (context) to the connected agent (UI labels may differ). Save and publish.
2. Reset the test pane and ask two turns:
   - `Tell me about switch SW-OH-30110.`
   - `Does it have any open work orders?`
3. Open the activity map for the second turn and read the exact input the parent sent to `HLE Field Ops Assistant`.
4. Turn the setting back **on**, publish, and repeat.
5. Compare with the child agent: ask `What is the full-day per diem in Ontario?` then `And in the US?` The child always receives the parent's context (CS-A12).

### Symptom you will see

Observe and record. Expected per CS-A12:

- With history off, the second turn may reach the Field Ops Assistant as "Does it have any open work orders?" with no asset. It then asks which asset, or answers about work orders in general. Whether the parent rewrites "it" into "SW-OH-30110" before handing off is not documented; the activity map shows you.
- With history on, the answer is: yes, WO-2026-01043, Emergency, "SW stuck open during restoration", Scheduled, CREW-OH-07, due 2026-09-19 (overdue as of 2026-09-30). SW-OH-30110 is a 27.6 kV motorized switch at Lima Depot, Condition Score 34, with 9 work orders in total.
- The child agent answers the follow-up correctly either way: US per diem full day USD 80 (Expense-Policy.docx 3).

### Root cause

Child agents always receive the parent's conversation context. Connected agents have a setting that controls whether conversation history is included (CS-A12, SNIP). Turning it off is sometimes right (privacy, or a connected agent owned by another team), but then the parent's input to the connected agent must be self-contained.

### Fix

- Leave history on for connected agents you own and trust, when follow-up questions are expected.
- If history must be off, add a line to the parent's instructions: "When you call a connected agent, rewrite the user's request so it is complete on its own, including any asset, work order or outage ID mentioned earlier." (Already in `front-door-instructions.txt`, rule 5.) Then check the input in the activity map.
- Put a data-sharing note in each connected agent's documentation: what context it receives, and who owns it.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/add-agent-child-agent

---

## C-10-d: Debugging a failed handoff

**Caveat ID:** C-10-d

### Steps to reproduce

1. Stop the mock API (`Ctrl+C` in the `func start` window, or stop the dev tunnel). Leave everything else as in the README.
2. Reset the test pane and ask: `What is the status of outage OUT-2026-0412?`
3. The answer is wrong or missing. Find out where it failed using only the activity map and the connected agent's own test pane:
   1. In `HLE Front Door`'s activity map, which agent was chosen? (Expected: `HLE Field Ops Assistant`.) If it was another agent, this is a routing problem: go to C-10-a.
   2. What input did the parent pass? If the outage ID is missing, this is a context problem: go to C-10-c.
   3. What did the connected agent return? An error or "cannot retrieve" message points inside the specialist.
   4. Open `HLE Field Ops Assistant` on its own and ask the same question in its test pane. Its activity map shows the `HLE Get Outage Status` flow call and the failing HTTP action.
4. Restart the mock API and dev tunnel, and ask again.

### Symptom you will see

- Step 2: the Front Door says it cannot get outage status right now, or returns an error summary. The parent's activity map shows the call to `HLE Field Ops Assistant` and its response, but not the flow's internal steps.
- Step 3.4: the specialist's own activity map (and the flow run history in Power Automate) shows the `HLE Get Outage Status` flow failing to reach the API.
- After the restart: Crew On Site, 3,214 customers, ETR 2026-09-30 14:30 EDT, CREW-ON-03 (Devon Achebe), feeder KGN-44-F7.

How much of the connected agent's inner activity the parent's activity map shows is not documented in a source this course could read. Record what you could see from the parent and what needed the specialist's own pane.

### Root cause

A handoff has four places to fail: the routing decision (description), the input passed (context), the specialist's own reasoning and tools, and the downstream system. Each connected agent is a separate agent with its own runtime, so the parent's view of it is a call and a result, not its internal trace. No limits row applies.

### Fix

Debug from the outside in, one hop at a time:

| Check | Where | Points to |
|---|---|---|
| Which agent was chosen | Parent activity map | C-10-a descriptions |
| What input it received | Parent activity map, agent call input | C-10-c context |
| What it returned | Parent activity map, agent call output | Specialist |
| Why the specialist failed | Specialist test pane activity map; Power Automate flow run history | Tools, flows, API, knowledge |
| Pattern over many conversations | Each agent's Analytics page | Recurring misroutes or failures |

Also keep each specialist's own eval set (Labs 3, 4, 5) and run it before blaming the parent. Lab 12 builds on this.

### Doc link

https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-add-other-agents
