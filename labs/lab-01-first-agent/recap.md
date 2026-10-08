# Lab 01: Recap

One page of ideas that every later lab builds on.

## The anatomy of an agent

| Part | What it does | In HLE Welcome Buddy | Where it goes deeper |
|---|---|---|---|
| Name | How users find and pick the agent (30 characters, AB-02) | HLE Welcome Buddy | Lab 2 |
| Description | Tells users, and Copilot, what the agent is for (1,000 characters, AB-02) | New-employee questions from five guides | Labs 2, 6 |
| Instructions | Standing orders: role, scope, answer rules, fallback, boundaries (8,000 characters, AB-02) | About 1,700 characters | Lab 2 (limit), Lab 6 (manifest) |
| Knowledge | What the agent searches before it answers | Five uploaded Word files | Labs 2, 3, 4, 7 |
| Conversation starters | Show users what to ask | Three starters | Lab 6 (manifest) |
| Capabilities and actions | Extra skills and calls to other systems | Not used | Labs 5, 6 |

## Five ideas to carry forward

1. **An agent is Copilot with a job.** It does not get a new brain. It gets focus: instructions, knowledge and, later, actions.
2. **Instructions are a structure, not a paragraph.** Role, scope, numbered rules, what to do when it cannot answer, boundaries. Every later agent in this course uses that pattern.
3. **Knowledge decides what the agent knows, and who can see it.** Uploaded files are shared with everyone who can use the agent. SharePoint knowledge is answered with each user's own permissions. That difference drives Labs 2 and 3.
4. **Clean data gives clean answers.** The Getting-Started guides have one home for every fact, so every answer was right. Real content has duplicates, old versions and conflicts; Lab 2 shows what that does.
5. **No citation, no trust.** A cited answer can be checked in one click. When an answer has no citation, or cites the wrong file, start troubleshooting there (Lab 12).

## Words you will see again

| Term | Meaning |
|---|---|
| Declarative agent | An agent defined by instructions, knowledge and actions, run by Copilot's own orchestrator. Agent Builder and the Agents Toolkit both build them. |
| Embedded file | A file uploaded into the agent itself, up to 20 per agent (AB-05). |
| Grounding | Basing an answer on a knowledge source instead of the model's general knowledge. |
| Private agent | A new agent is visible only to its creator until it is shared (AB-10). |
| Eval | A list of prompts with expected answers and sources, used to check an agent (the `evals/` folder). |

## Limits you met

AB-02 (name, description, instructions), AB-03 (starter prompts), AB-05 and AB-08 (embedded files). Always check the current value in [reference/limits.md](../../reference/limits.md) and on Microsoft Learn: limits change.

Next: [Lab 2: Agent Builder deeper dive](../lab-02-agent-builder-deep-dive/README.md).
