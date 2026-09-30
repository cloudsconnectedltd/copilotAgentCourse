# Lab 01: Getting started: your first agent

| | |
|---|---|
| Build path | Agent Builder in Microsoft 365 Copilot Chat |
| Estimated time | 30 to 45 minutes (45 minutes with the full facilitated agenda in [facilitator-notes.md](facilitator-notes.md)) |
| Prerequisites | A Microsoft 365 Copilot license (LIC-02); a desktop browser or Teams desktop/web (not mobile, AB-01); the file [`data/sharepoint/getting-started.zip`](../../data/sharepoint/getting-started.zip). No setup scripts, no admin settings, no earlier labs. |
| Personas used | learner (your own account) |
| Status | GA |
| Limits referenced | [LIC-02, LIC-03, AB-01, AB-02, AB-03, AB-05, AB-08, AB-10, AB-12](../../reference/limits.md) |

## Objective

Build **HLE Welcome Buddy**, an onboarding agent for new Harbourline Energy Co. employees. It answers questions from five short Getting-Started guides and shows where each answer came from. By the end you will have:

- created an agent in Agent Builder with a name, description and instructions
- added one knowledge source (five documents)
- added three conversation starters
- tested the agent with prompts and checked the citations in its answers

Everything in this lab is designed to work the first time. There are no deliberate defects. Lab 2 is where things break on purpose.

## Concepts

| Concept | What it means in this lab |
|---|---|
| Agent | A version of Microsoft 365 Copilot that you point at one job. It uses the same Copilot model, plus your **instructions**, your **knowledge** and optional capabilities. Agent Builder builds a type of agent called a *declarative agent*: you declare what it should do, and Copilot does the rest. |
| Name and description | The name is what users see and pick (30 characters max, AB-02). The description tells users, and Copilot, what the agent is for (1,000 characters max, AB-02). |
| Instructions | Plain-language rules the agent follows every time: its role, what it covers, how to format answers, what to do when it cannot answer. 8,000 characters max (AB-02). |
| Knowledge source | Content the agent searches before it answers. Here: five Word documents. |
| Conversation starters | Ready-made prompts shown to users so they know what to ask. Agent Builder calls them *starter prompts*. |
| Citation | A reference in the answer that links to the document the fact came from. It is how you and your users check that an answer is grounded. |

## Steps

### Step 1: Get the five Getting-Started documents (3 minutes)

1. Download `data/sharepoint/getting-started.zip` from this repository to your computer.
2. Extract it. You get five files:
   - `Welcome-to-Harbourline.docx`
   - `Vacation-Policy.docx`
   - `IT-Help-Desk-FAQ.docx`
   - `Office-Locations.docx`
   - `Benefits-At-a-Glance.docx`

Agent Builder uploads individual files, not folders or zip files, so the extract step matters.

### Step 2: Open Agent Builder (2 minutes)

1. In a desktop browser, go to `https://microsoft365.com/chat` (or `https://office.com/chat`, or open Copilot in Teams desktop or web). Agent Builder is not available on mobile (AB-01).
2. Sign in with your work account.
3. In the left pane, select **New agent**.
4. On the **New agent** page, select **Skip to configure**. The **Configure** tab opens.

> The **Describe** tab lets you build an agent by chatting with Agent Builder, and it fills in the fields for you. In this lab you fill in each field yourself so you can see what each one does. UI labels can change; if a label differs, look for the closest match and check the Agent Builder page on Microsoft Learn.

### Step 3: Name and description (3 minutes)

1. **Name**: type

   ```text
   HLE Welcome Buddy
   ```

2. **Description**: paste

   ```text
   Answers new-employee questions about Harbourline Energy Co.: first-week steps, vacation days, IT help desk, office locations and benefits, using the five Getting-Started guides.
   ```

The name is 17 characters (limit 30) and the description is 177 characters (limit 1,000), per AB-02. Leave the icon and **Model** (default response mode **Auto**) as they are.

### Step 4: Instructions (5 minutes)

Paste this into **Instructions** (1,673 characters; limit 8,000, AB-02). The same text is in [`solutions/lab-01/instructions.txt`](../../solutions/lab-01/instructions.txt).

```text
# Role
You are HLE Welcome Buddy, a friendly onboarding assistant for new employees of Harbourline Energy Co., a regulated electric utility with offices in Ontario, New York and Ohio.

# What you help with
Answer new-employee questions about:
- the company, its values, leadership and the first-week checklist (Welcome to Harbourline)
- vacation days, booking time off and carry-over (Vacation Policy: Quick Guide for New Employees)
- the IT Help Desk, passwords, multi-factor authentication, VPN, equipment and Wi-Fi (IT Help Desk FAQ)
- office addresses, building hours, parking and desk booking (Office Locations)
- benefits, enrolment and the Employee Assistance Program (Benefits at a Glance)

# How to answer
1. Answer only from the five Getting-Started documents in your knowledge.
2. Start with the direct answer in one or two sentences, then add up to three short bullet points with the key details (numbers, dates, phone numbers, links).
3. Always cite the document you used.
4. Where a benefit differs between Ontario and the US (New York and Ohio), give both and label each region.
5. Keep a warm, welcoming tone. Use plain language and avoid jargon.

# When you cannot answer
If the answer is not in the Getting-Started documents, say: "I could not find that in the new employee guides." Then suggest who to ask: your manager, your onboarding buddy, or the People and Culture service portal in Workday. Do not guess and do not use information about other companies.

# Boundaries
You give general onboarding information only. For personal situations (for example, your own benefit elections or a leave request), point the employee to Workday or their manager.
```

Notice the structure: a role, a scope, numbered answer rules, a fallback and a boundary. Later labs reuse this pattern.

### Step 5: Add one knowledge source (5 minutes)

Choose **one** option. Do not use both, or the agent sees every document twice.

**Option A: upload the files (recommended, no setup needed)**

1. In the **Knowledge** section of the **Configure** tab, select the upload (arrow) icon, or drag the five `.docx` files from Step 1 onto the tab.
2. The files appear under **Uploaded files**. They stay gray until the upload finishes; wait until all five are shown normally.

Five files is well inside the 20 embedded files an agent can hold (AB-05), and Word files can be up to 512 MB each (AB-08). Uploaded (embedded) files become part of the agent: anyone who can use the agent can get answers from them.

**Option B: point to the SharePoint library (only if your facilitator ran the setup scripts)**

1. In the **Knowledge** section, paste this URL into the search/URL box and press **Enter**:

   ```text
   https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Getting-Started
   ```

   Replace `<tenant>` with your tenant name and `<Prefix>` with the prefix your facilitator used (default `HLE`).
2. The library appears in the **Knowledge** section. If it shows **Preparing**, you can keep going; the agent uses the source once it is ready.

With SharePoint knowledge, the agent answers with each user's own SharePoint permissions. All employees can read this library, so everyone gets the same answers.

### Step 6: Add three conversation starters (5 minutes)

In **Starter prompts**, add three prompts. Each has a title and the prompt text.

| Title | Prompt text |
|---|---|
| `My vacation days` | `How many vacation days do I get in my first year, and how many can I carry over?` |
| `Get IT help` | `How do I contact the IT Help Desk, and what are its hours?` |
| `My first week` | `What should I do during my first week at Harbourline?` |

Agent Builder has no minimum number of starter prompts (AB-03). Three is enough to show users what the agent is for.

### Step 7: Test on the Try it tab (8 minutes)

The **Try it** tab turns on once the agent has a name, description and instructions.

1. Select the **Try it** tab. Your three starters appear as suggested prompts.
2. Select **My vacation days**. Expected: 15 days in the first year; up to 5 unused days can be carried over and must be used by March 31.
3. Type each of these prompts and compare with the expected answer:

   | Prompt to type | Expected answer | Source document |
   |---|---|---|
   | `What is the IT Help Desk phone number?` | 1-800-555-0142 | IT-Help-Desk-FAQ.docx |
   | `Where is the head office?` | 1450 Harbourfront Drive, Toronto, ON M5J 2X9 | Office-Locations.docx |
   | `How long do I have to enrol in benefits?` | 31 days from the start date; if you do not enrol you get single coverage only | Benefits-At-a-Glance.docx |
   | `Who is the CEO of Harbourline?` | Eleanor Voss, President and Chief Executive Officer | Welcome-to-Harbourline.docx |
   | `What is the company's policy on pets in the office?` | The agent says it could not find that in the new employee guides and suggests who to ask | none (not in the documents) |

4. Select **New chat** to clear the conversation and see the starters again.

### Step 8: Check the citations (4 minutes)

1. Ask: `What should I do during my first week at Harbourline?`
2. In the answer, find the citation markers (small numbered references) and the list of references under the answer.
3. Select a reference. It should point to `Welcome-to-Harbourline.docx`.
4. Ask one more question and check that the citation names the document you expect (use the table in Step 7).

A cited answer lets a user check the source in one click. An answer with no citation, or with a citation to the wrong document, is the first thing to investigate when an agent misbehaves. Lab 12 builds on this.

### Step 9: Create the agent (2 minutes)

1. Select **Create** (top right).
2. Agent Builder confirms that the agent is created and that it is **private**: only you can use it. Do not share it in this lab; sharing is covered in Lab 2.
3. Close the dialog. **HLE Welcome Buddy** now appears in the left pane of Copilot Chat.
4. Open it from the left pane and select one starter to confirm it works outside the builder.

### Step 10: Run the evaluation

Follow [validate.md](validate.md) to run the ten questions in [`evals/lab-01-questions.csv`](../../evals/lab-01-questions.csv).

Then read [recap.md](recap.md), a one-page summary of the ideas later labs build on. Clean up with [cleanup.md](cleanup.md) (short version: keep the agent if you plan to do Lab 12).

## Caveats this lab triggers

None, by design. Lab 1 has no `break-it.md`. Caveats start in [Lab 2](../lab-02-agent-builder-deep-dive/README.md).

| Caveat ID | Name | Where in break-it.md |
|---|---|---|
| (none) | Lab 1 is a clean first build | not applicable |

## Check before you run

> All limits in this lab are tagged SRC in [reference/limits.md](../../reference/limits.md) (checked 2026-09-30 against the source of the Microsoft Learn pages). One detail is UNVERIFIED: the **maximum** number of starter prompts (AB-03). The lab uses three, which is safe. If you want to add more, confirm the current maximum on [Build agents in Agent Builder](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-build-agents) first. Agent Builder UI labels change often; if a button name differs from this lab, use the Learn page as the reference.
