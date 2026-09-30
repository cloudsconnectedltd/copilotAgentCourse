# Lab 10 solution: HLE Front Door

Finished source artifacts for [Lab 10](../../labs/lab-10-multi-agent/README.md). There is no exported solution zip in this folder. Build from these files; Lab 11 then adds the agents to the `HLEHarbourlineOps` solution and exports it.

| File | What it is | How to use it |
|---|---|---|
| `front-door-instructions.txt` | Instructions for the parent agent `HLE Front Door` (routing rules, multi-intent, out-of-scope decline, self-contained handoffs) | Paste into HLE Front Door > Instructions |
| `policy-router-instructions.txt` | Instructions for the child agent `HLE Policy Router` (which finance document governs) | Paste into the child agent's instructions |
| `agent-descriptions.md` | Precise routing descriptions for all three specialists, the vague break-it set, and the overlap table | Section 1 for the build, section 2 for C-10-a |
| `conversation-start-topic.yaml` | Conversation Start topic in Copilot Studio code-view YAML | Optional; paste in the topic's code editor |

## Agent map

```
HLE Front Door (parent, HLE-Dev, generative orchestration, Authenticate with Microsoft)
  +-- HLE Policy Router      child agent     knowledge: Hub/Finance, Hub/HR-Policies/Travel-Policy.docx
  +-- HLE HR Assistant       connected agent (Lab 3)     knowledge: Hub/HR-Policies
  +-- HLE Field Ops Assistant connected agent (Labs 4, 5) knowledge: Dataverse hle_Asset, hle_WorkOrder, hle_Crew; tools: HLE Get Outage Status, HLE Dispatch Crew
```

## Export notes for Lab 11

- The child agent is part of `HLE Front Door` and moves with it.
- Connected agents are separate components. Add `HLE HR Assistant` and `HLE Field Ops Assistant` (and Lab 5's flows and the `HLE Outage API` custom connector) to the same solution, or the parent will reference agents that do not exist in the target environment.
- Re-check each connected agent's "let other agents connect" setting and authentication after import.

## Facts used by the routing tests

HR: `data/answer-keys/hr-policies.md` (Leave v4 4.2, Bereavement 4, Overtime 4.2). Finance: `data/answer-keys/hub-general.md` section 2 (Expense Policy 3 and 4, Approval Matrix). Field Ops: `data/answer-keys/dataverse-connector.md` sections 2 and 3 (P-DV-01, P-DV-04, open Emergency work orders, Kingston crews) and `data/answer-keys/api.md` (OUT-2026-0412, OUT-2026-0427).
