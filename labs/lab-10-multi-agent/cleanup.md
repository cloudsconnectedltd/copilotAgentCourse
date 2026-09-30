# Lab 10: Clean up

Lab 11 uses `HLE Front Door` (with its child and connected agents) as the solution it moves from `HLE-Dev` to `HLE-Test` and `HLE-Prod`. **If you are continuing to Lab 11, skip the "Remove" section** and only do "Restore".

## Restore (always)

1. Put the precise descriptions back on all three specialists (`solutions/lab-10/agent-descriptions.md` section 1) if C-10-a left the vague ones in place. Publish.
2. Set authentication back to **Authenticate with Microsoft** on `HLE Front Door`, `HLE HR Assistant` and `HLE Field Ops Assistant` (C-10-b). Publish.
3. Turn conversation history back **on** for `HLE Field Ops Assistant` in `HLE Front Door` (C-10-c). Publish.
4. Stop the mock API and dev tunnel when you are done (`data/api/run-local.md`), unless Lab 11 or 12 follows right away.

## Remove (only when you finish the course, or to rebuild this lab)

1. In Copilot Studio > `HLE-Dev` > `HLE Front Door` > Agents: remove the connected agents `HLE HR Assistant` and `HLE Field Ops Assistant` from the parent. This removes the connection only; the agents themselves stay.
2. Delete the child agent `HLE Policy Router` (it is part of `HLE Front Door` and is also removed when you delete the parent).
3. Delete the agent `HLE Front Door`. Remove it from any published channel first (Teams and Microsoft 365 Copilot) if you published it there.
4. Optional: in `HLE HR Assistant` and `HLE Field Ops Assistant`, turn off the setting that lets other agents connect to them, and publish.

## Do NOT delete

| Item | Why |
|---|---|
| `HLE HR Assistant` | Built in Lab 3; used by Lab 7 (connector attached), Lab 11 and Lab 12 |
| `HLE Field Ops Assistant`, its `HLE Get Outage Status` and `HLE Dispatch Crew` flows, and the `HLE Outage API` custom connector | Built in Labs 4 and 5; used by Labs 11 and 12 |
| Environment `HLE-Dev`, the Dataverse tables and the `HLEHarbourlineOps` solution | Used by Labs 11 and 12 |
| Hub Finance library and HR-Policies files | Created by setup; used by Labs 2, 3, 12 |

## Check

- If you removed everything: Copilot Studio in `HLE-Dev` shows no `HLE Front Door`; `HLE HR Assistant` and `HLE Field Ops Assistant` still answer in their own test panes.
- If you kept everything for Lab 11: `evals/lab-10-questions.csv` rows L10-Q01 to L10-Q10 pass again.
