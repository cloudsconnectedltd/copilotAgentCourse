# Lab 01: Facilitator notes

Use these notes to run Lab 1 as a live session, for example in a team meeting. Everyone builds the same agent, **HLE Welcome Buddy**, on their own account. Nothing breaks on purpose, so you can keep the pace steady and spend the spare time on questions.

## Before the session

| Check | How |
|---|---|
| Every attendee has a Microsoft 365 Copilot license | Ask attendees to open `https://microsoft365.com/chat` and confirm they see **New agent** in the left pane (LIC-02). Without the license, uploaded files cannot be used as knowledge (LIC-03). |
| Attendees are on a desktop browser or Teams desktop/web | Agent Builder is not on mobile (AB-01). |
| Everyone has the five documents | Send `data/sharepoint/getting-started.zip` in the meeting invite and ask attendees to extract it before joining. |
| Knowledge option chosen | Use **Option A (upload)** unless you ran the setup scripts and want to show SharePoint. Option A needs no setup. |
| Your own copy is built | Build the agent once before the session, so you can demo it if an attendee is stuck. |

## Timed agenda (45 minutes)

| Time | Minutes | Segment | Lab step |
|---|---|---|---|
| 0:00 to 0:05 | 5 | Welcome and "what is an agent" | Concepts |
| 0:05 to 0:08 | 3 | Open Agent Builder, Skip to configure | Steps 1 and 2 |
| 0:08 to 0:12 | 4 | Name and description | Step 3 |
| 0:12 to 0:17 | 5 | Instructions | Step 4 |
| 0:17 to 0:22 | 5 | Knowledge: upload the five documents | Step 5 |
| 0:22 to 0:26 | 4 | Three conversation starters | Step 6 |
| 0:26 to 0:34 | 8 | Test with prompts on the Try it tab | Step 7 |
| 0:34 to 0:38 | 4 | Citations | Step 8 |
| 0:38 to 0:40 | 2 | Create, open from the left pane | Step 9 |
| 0:40 to 0:45 | 5 | What's next (slides below) and questions | |
| | **45** | | |

**30-minute version:** skip the talking points marked (optional), run only three of the Step 7 prompts, and show the "What's next" slides in two minutes. Timing: 3 + 3 + 3 + 4 + 4 + 3 + 5 + 2 + 1 + 2 = 30.

## Talking points

### What is an agent? (0:00)

- An agent is Microsoft 365 Copilot pointed at one job. Same Copilot, plus three things you control: **instructions** (how it behaves), **knowledge** (what it can look up), and **capabilities** (extra skills such as creating documents or images).
- Agent Builder builds *declarative agents*: you declare the job, Copilot runs it. No code, no admin settings.
- Today's job: help new employees at Harbourline Energy Co. (our fictional utility) find answers in five onboarding guides.
- (optional) The same agent could be built in Copilot Studio or with the Agents Toolkit. Later labs show when you need those.

### Name and description (0:08)

- The name is what users pick from a list: short and specific. Limit 30 characters (AB-02).
- The description is read by users and by Copilot. Say what the agent covers and where its answers come from. Limit 1,000 characters (AB-02).

### Instructions (0:12)

- Instructions are the agent's standing orders. Show the five parts in the pasted text: role, scope, answer rules, what to do when it cannot answer, boundaries.
- The fallback line matters most for trust: an agent that says "I could not find that" is better than one that guesses.
- Limit 8,000 characters (AB-02). Ours is about 1,700. Lab 2 shows what happens when you go over.

### Knowledge (0:17)

- Knowledge is what the agent searches before it answers. We upload five small Word files: up to 20 uploaded files per agent (AB-05), Word files up to 512 MB each (AB-08).
- Uploaded files become part of the agent: anyone who can use the agent can get answers from them. SharePoint knowledge is different: the agent answers with each user's own permissions. Lab 2 and Lab 3 go deeper.
- If an attendee's files stay gray, wait: they are still uploading.

### Conversation starters (0:22)

- Starters teach users what to ask. Pick the three questions new employees ask most.
- There is no minimum (AB-03).

### Testing (0:26)

- Test with real questions, and with one question the agent should *not* answer. The "pets" prompt checks the fallback.
- If the pets prompt gets a generic answer instead of the fallback, point out that it has no citation: that is how you spot an ungrounded answer. Lab 2 shows the **Only use specified sources** setting.

### Citations (0:34)

- Every factual answer should cite a document. Selecting the citation opens the source.
- Rule of thumb for later labs: no citation, no trust.

## Exact prompts and expected answers

Source for every answer: `data/answer-keys/hub-general.md`, section 1 (Getting-Started library).

| # | Prompt to type | Expected answer | Cited document |
|---|---|---|---|
| 1 | Starter **My vacation days** | 15 vacation days in the first year (years 1 to 4); up to 5 unused days carried over, used by March 31 or forfeited | Vacation-Policy.docx |
| 2 | Starter **Get IT help** | Phone 1-800-555-0142, portal https://helpdesk.harbourline.example, email helpdesk@harbourline.example; Monday to Friday 7:00 a.m. to 7:00 p.m. Eastern; 24/7 for outage-critical systems (press 1) | IT-Help-Desk-FAQ.docx |
| 3 | Starter **My first week** | Day 1 badge, laptop, buddy, MFA; Day 2 Safety Orientation; Day 3 benefits; Day 4 vacation guide and Workday balance; Day 5 New Employee Welcome Session | Welcome-to-Harbourline.docx |
| 4 | `What is the IT Help Desk phone number?` | 1-800-555-0142 | IT-Help-Desk-FAQ.docx |
| 5 | `Where is the head office?` | 1450 Harbourfront Drive, Toronto, ON M5J 2X9 | Office-Locations.docx |
| 6 | `How long do I have to enrol in benefits?` | 31 days from the start date; otherwise single coverage only | Benefits-At-a-Glance.docx |
| 7 | `Who is the CEO of Harbourline?` | Eleanor Voss, President and Chief Executive Officer | Welcome-to-Harbourline.docx |
| 8 | `What is the company's policy on pets in the office?` | Fallback: "I could not find that in the new employee guides", plus who to ask | none |
| 9 | `What should I do during my first week at Harbourline?` (citation check) | Same as row 3 | Welcome-to-Harbourline.docx |

Spare prompts if attendees finish early:

| Prompt | Expected answer | Cited document |
|---|---|---|
| `What are Harbourline's values?` | SAFE: Safety first, Accountability, Fairness, Excellence | Welcome-to-Harbourline.docx |
| `How much is the wellness allowance?` | CAD 500 per year (Ontario); USD 400 per year (New York and Ohio) | Benefits-At-a-Glance.docx |
| `Which Wi-Fi network should my laptop use?` | HLE-Corp (automatic for company laptops); HLE-Guest for visitors and personal devices, with a daily code from reception | IT-Help-Desk-FAQ.docx |
| `How many offices does Harbourline have?` | 7: 3 in Ontario (Toronto, Hamilton, Sudbury), 2 in New York (Albany, Syracuse), 2 in Ohio (Columbus, Akron) | Office-Locations.docx |
| `How much of my retirement savings does the company match?` | Group RRSP up to 5 percent (Ontario); 401(k) up to 6 percent (US) | Benefits-At-a-Glance.docx |

## Common questions

| Question | Answer |
|---|---|
| Can I share my agent with my team? | Yes, from **Share** after **Create**. Lab 2 covers sharing roles and what happens for people without a Copilot license. |
| Why not point at the whole intranet? | More content means more chances of conflicting or outdated answers. Lab 2 shows a real conflict between two versions of a leave policy. |
| Where do the files live? | Uploaded files are stored with the agent. SharePoint files stay in SharePoint and keep their permissions. |
| Can I use this in a Teams group chat? | No. Agent Builder agents cannot be used in Teams group or one-to-one chats (AB-12). |

## What's next (slides)

Show these three slides at 0:40.

---

**Slide 1: You just built a declarative agent**

- Instructions + knowledge + starters = an agent in under 30 minutes
- Private until you share it
- Every answer cites its source
- Next: Lab 2 "Agent Builder deeper dive" ([labs/lab-02-agent-builder-deep-dive](../lab-02-agent-builder-deep-dive/README.md))

Speaker note: Lab 2 uses real SharePoint libraries, a list, sharing, and deliberately hits the limits.

---

**Slide 2: When Agent Builder is not enough**

- More control over knowledge, topics and actions: Copilot Studio (Labs 3, 4, 5)
- Code-first, version-controlled agents and API plugins: Agents Toolkit (Lab 6)
- Your own line-of-business data in Copilot: Copilot connectors (Lab 7)
- Your own model and orchestration: custom engine agents (Lab 8)

Speaker note: the build-path matrix in [reference/agent-types-matrix.md](../../reference/agent-types-matrix.md) compares them side by side.

---

**Slide 3: Running agents for real**

- Agents that act on events without a prompt (Lab 9)
- Several agents working together (Lab 10)
- Environments, solutions, admin controls and audit (Lab 11)
- Test sets and troubleshooting, including today's ten questions (Lab 12)

Speaker note: keep HLE Welcome Buddy; Lab 12 reruns today's evaluation.

---
