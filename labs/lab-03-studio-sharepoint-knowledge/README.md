# Lab 03: Copilot Studio agent with SharePoint and file knowledge

| | |
|---|---|
| Build path | Copilot Studio (classic experience), environment `HLE-Dev` |
| Estimated time | 4 hours |
| Prerequisites | [Lab 2](../lab-02-agent-builder-deep-dive/README.md); setup scripts 00 to 04 run by the setup owner (details below) |
| Personas used | Learner (maker), Priya Nandakumar (`hr`), Marcus Delaney (`tech`), Sofia Brennan (`fin`), Tom Whitfield (`nolic`), guest contractor (`guest`) |
| Status | PREVIEW: SharePoint lists as knowledge (CS-K10). Contains UNVERIFIED limits: CS-K13, CS-K14, CS-A05 |

## What you'll be able to do

By the end of this lab you can:

1. **Build a Copilot Studio agent grounded on SharePoint** and write instructions that control behaviour (sources, citations, conflicts, tone) without copying policy content into them.
2. **Explain the two orchestration modes** and predict when a topic, rather than your knowledge, will answer a question.
3. **Prove that an agent respects permissions**: each person sees only what they can open in SharePoint, including encrypted files, and know why the maker's test pane proves nothing about this.
4. **Diagnose the common reasons an agent "can't find" content that is clearly there**: file size, scanned PDFs, facts in images, merged cells, list row limits and over-wide scope.
5. **Choose between SharePoint knowledge and uploaded files** for a given requirement, and between authentication options.
6. **Tune content moderation** so legitimate sensitive policy questions still get answered.

<details>
<summary><strong>Before you start: prerequisites, limits to check, additional learners</strong></summary>

**Prerequisites**
- Setup scripts [`00`](../../setup/00-prereqs-check.ps1) to [`04-apply-labels.ps1`](../../setup/04-apply-labels.ps1) completed by the setup owner (see [setup/README.md](../../setup/README.md)). Additional learners skip them; the setup owner runs `05-add-learner.ps1` for you (see [Two or more learners](../../setup/README.md#two-or-more-learners)).
- Power Apps Developer Plan for the learner (ENV-03).
- Copilot Studio capacity pack or pay-as-you-go (LIC-06, LIC-07).
- Generative AI enabled in Power Platform, and the Copilot Studio app deployed in the Microsoft 365 admin center (ADM-07).

**Limits used in this lab.** Every Copilot Studio limit here is tagged SNIP or UNVERIFIED in [reference/limits.md](../../reference/limits.md), because the Copilot Studio documentation source was not readable when the course was built. Confirm these on Microsoft Learn:

| Row | Value used here | Tag | Page |
|---|---|---|---|
| CS-K01 | 7 MB file limit without a Microsoft 365 Copilot license in the tenant | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
| CS-K02 | Up to 200 MB with tenant graph grounding | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio |
| CS-K03 | 512 MB for PDF, PPTX and DOCX | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio |
| CS-K04 | Tenant graph grounding needs "Authenticate with Microsoft" | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/configuration-end-user-authentication |
| CS-K05 | Manual auth needs Sites.Read.All and Files.Read.All | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/nlu-generative-answers-sharepoint-onedrive |
| CS-K06 | SharePoint URL: site path, no query parameters | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-sharepoint |
| CS-K07 | Folder source: 1,000 files, 50 folders, 10 levels | SNIP, scope unclear | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
| CS-K08 | Encryption only via sensitivity labels, SharePoint only, VIEW and EXTRACT needed | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/security-faq |
| CS-K09 | Uploaded files: encrypted files not supported | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-file-upload |
| CS-K10 | SharePoint lists: queries use the first 2,048 rows | SNIP, new-experience docs | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/knowledge-sharepoint-lists |
| CS-K12 | Public websites: 25 (generative) or 4 (classic) | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
| CS-K13 | Scanned PDFs not OCR'd | UNVERIFIED | No Learn source. The lab observes, it does not assert. |
| CS-K14 | Total SharePoint URLs per agent | UNVERIFIED | Not found. Check current limit on Microsoft Learn. |
| CS-A05 | Instructions limit 8,000 characters | UNVERIFIED | Community answer only. The instructions in this lab are far below it. |

Also referenced: LIC-10, ADM-07, ENV-02, ENV-03. Copilot Studio menu labels follow the documented concepts and were partly confirmed in a live tenant on 2026-10-06. **UI labels may differ in your tenant; check Learn** when a menu name does not match.

</details>

## Scenario

Harbourline's People and Culture team wants **HLE HR Assistant**, an agent in Teams and Microsoft 365 Copilot that answers policy questions from the `HR-Policies` library. HR insists on three things: answers must cite the policy, nobody may see the confidential `Restricted` folder or compensation bands unless they are in HR, and the agent must cope with the messy real library (old versions, scans, a huge handbook).

You build it, then deliberately find every point where SharePoint knowledge stops working. A second scratch agent, **HLE Knowledge Bench**, carries the experiments that don't belong in an HR agent, so HLE HR Assistant stays clean for Labs 7 and 10.

## Concepts

| Concept | What to understand |
|---|---|
| Generative vs classic orchestration | **Generative:** the model reads the descriptions of your topics, knowledge and tools and decides what to use on each turn. **Classic:** trigger phrases route to a topic; knowledge is only a fallback when no topic matches (the Conversational boosting system topic). Some limits differ by mode (25 vs 4 public websites, CS-K12), and autonomous triggers need generative (CS-A07). |
| Security trimming | SharePoint knowledge is searched as the signed-in user, so the agent must use "Authenticate with Microsoft" (CS-K04). The test pane runs as you, the maker, and you are in every course group, so **the test pane never proves permissions**. Only signing in as another person does. |
| Tenant graph grounding | Microsoft 365 semantic search over SharePoint. It raises the usable file size from 7 MB (CS-K01) to 200 MB (CS-K02); PDF, PPTX and DOCX up to 512 MB (CS-K03). |
| SharePoint knowledge vs uploaded files | SharePoint knowledge stays in SharePoint and keeps its permissions and labels. An uploaded file is copied into the agent, is visible to every user of the agent, and cannot be encrypted (CS-K09). |
| Who pays | Copilot-licensed users are zero-rated in Copilot Chat, Teams and SharePoint (LIC-10). Tom (`nolic`) has no Copilot license, so his usage consumes Copilot Credits. |

## Steps

Use `<tenant>` for your SharePoint tenant name and `<Prefix>` for the course prefix (default `HLE`).

### Part A: Build the agent (45 minutes)

<details>
<summary>1. Confirm the setup content (5 minutes, admin check)</summary>

Open `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies` and check that:
- `Employee-Handbook-Full.docx` is present and about 9.1 MB. If it is missing, run `python3 tools/generate-data/generate_oversized_handbook.py` and re-run `03-upload-content.ps1`.
- `Compensation-Bands-2025.docx` shows the sensitivity label **`<Prefix> HR Confidential`**. If not, re-run `04-apply-labels.ps1` or apply it manually (the script prints the steps).
- The `Restricted` folder shows "Has unique permissions" and only the site owners and `<Prefix>-HR` have access.

</details>

<details>
<summary>2. Create environment <code>HLE-Dev</code> (5 minutes, admin task; skip if it exists)</summary>

Go to https://admin.powerplatform.microsoft.com, open **Manage > Environments > New**, and set:
- Name: `HLE-Dev`
- Type: **Developer**
- Region: your tenant's default
- Dataverse: included (ENV-03)

Labs 4, 5, 9, 10 and 11 use `HLE-Dev`; don't delete it. **Know this now:** a Developer environment is owner-only (ENV-02), so other people can't use agents built in it. Part D handles this for the persona tests.

</details>

3. Go to https://copilotstudio.microsoft.com and select **HLE-Dev** in the environment picker (top right). If you are offered a choice of harness, use **Standard**, not GitHub Copilot (see [agent-types-matrix.md](../../reference/agent-types-matrix.md)).

4. Select **Create > New agent**, skip the conversational setup, and configure it directly:
   - Name: `HLE HR Assistant`
   - Description: `Answers Harbourline Energy Co. HR policy questions for employees in Ontario, New York and Ohio, using the HR-Policies library.`
   - Instructions: paste the text below (also in [solutions/lab-03/hle-hr-assistant-instructions.txt](../../solutions/lab-03/hle-hr-assistant-instructions.txt)).

   ```text
   You are HLE HR Assistant for Harbourline Energy Co. employees in Ontario, New York and Ohio.

   Answer only from the HR Policies knowledge source. If the knowledge does not contain the answer, say that you could not find it in the HR policies and suggest the user contact their HR Business Partner (see Employee Relations Contacts). Do not guess and do not use general knowledge.

   Always cite the policy document and the section number you used.

   When two documents with the same Document ID disagree, use the one with the higher version number and the later effective date. Say which version you used and mention that an older version exists with a different value.

   When a rule differs by location, state which location it applies to (Ontario, New York or Ohio).

   Do not give legal advice. For individual cases (discipline, investigations, accommodation, grievances), explain the published process and direct the user to their HR Business Partner.

   Keep answers under 150 words unless the user asks for more detail.
   ```

   > **Why this matters:** every line is a *behaviour* rule: which source, how to cite, what to do with conflicting versions, when to refer to a person. There are no policy values in it. Values belong in SharePoint, where they stay current and permission-trimmed (Lab 2, C-02-b).

5. Select **Create**. Go to **Settings > Generative AI** and set orchestration to **Generative** and general knowledge to **Off**. Leave moderation alone for now (Part C). Save.

   > **Why this matters:** with general knowledge on, the agent can answer from the model's training data when your documents don't cover a question. That produces plausible answers with no Harbourline source, the exact thing HR asked you to prevent.

6. Go to **Settings > Security > Authentication** and confirm **Authenticate with Microsoft** is selected.

   > **Why this matters:** this is what makes the agent search SharePoint *as the person asking*. Without it there is no security trimming and no tenant graph grounding (CS-K04). Break-it C-03-f shows what happens when you turn it off.

7. Go to **Knowledge > Add knowledge > SharePoint** and enter:

   ```text
   https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies
   ```

   Name it `HR Policies library` and give it this description:

   ```text
   Harbourline HR policies: leave, parental and bereavement leave, remote work, overtime and on-call, travel, code of conduct, harassment prevention, FMLA, performance reviews, grievances, accommodation, safety incident reporting, compensation bands and the full employee handbook.
   ```

   > **Why this matters:** the URL points at one library, not the whole site, so finance and operations content can't leak into HR answers (C-03-k). It must be the library path with no query string (CS-K06); a copied view URL like `.../Forms/AllItems.aspx?...` fails. The description is what the generative orchestrator reads to decide when to use this source, so write it like a table of contents.

8. Confirm tenant graph grounding is on (a toggle in the Generative AI or Knowledge settings; UI labels may differ).

9. When the knowledge source shows as ready, test in the **Test** pane:

   | Prompt | Expected | What it proves |
   |---|---|---|
   | `How many days can I carry over?` | 5 days, used by March 31, citing `Leave-Policy-v4-2025.pdf`, ideally noting version 3.0 said 10 | Your version-conflict instruction works (C-03-c) |
   | `What do employees receive for 25 years of service?` | 3 extra paid leave days (one time) and a crystal award, citing `Employee-Handbook-Full.docx`, 14.2 | The 9 MB handbook is indexed under tenant graph grounding (CS-K02). Break-it C-03-a turns the toggle off. |

### Part B: Orchestration modes (20 minutes)

The point of this part is to see *how* the agent decides what to use, because in classic mode a topic can hijack a question your knowledge would have answered correctly.

10. Ask `What is the on-call stipend in Ontario?` (expected: CAD 300 per full week, `Overtime-and-On-Call.docx`, 4.2). Open the activity map or conversation trace in the test pane: the orchestrator went straight to `HR Policies library`, with no topic involved.

11. Go to **Settings > Generative AI**, switch orchestration to **Classic**, save, and **start a new test conversation** (the test pane keeps the old setting until you do). Ask the same question.

    **The answer will probably look the same.** In classic mode, a question that matches no topic falls back to the **Conversational boosting** system topic, which searches the same knowledge. The difference is in the trace: it now shows **Conversational boosting** firing (turn on **Track between topics** if your test pane offers it). Open **Topics > System > Conversational boosting** to see its generative answers node.

12. **Make the difference visible.** Still in classic mode:
    1. Create a topic named `On-call test` with the trigger phrase `on-call stipend` and a single message node: `Please contact Payroll.` Save.
    2. Start a new test conversation and ask `What is the on-call stipend in Ontario?` You get **"Please contact Payroll."**: the trigger phrase matched, so the topic won and your knowledge was never searched.
    3. Switch to **Generative**, save, start a new conversation and ask again. Observe and record: the orchestrator now chooses by description and may answer from the policy instead.
    4. Delete the `On-call test` topic.

    > **Why this matters:** topics take priority over knowledge in classic mode. A carelessly broad trigger phrase silently replaces correct, cited answers. Lab 4 (C-04-a) builds on this.

13. Make sure orchestration is back on **Generative** and saved. Keep it there for the rest of the course (Labs 9 and 10 need it, CS-A07).

### Part C: Content moderation (10 minutes)

14. Go to **Settings > Generative AI** and scroll to **Moderation** (observed in the classic experience on 2026-10-06; UI labels may change):
    - **Content moderation level**: a slider. The left end is **Low**, which lets more through; moving right raises moderation. The arrow icon resets it to the default.
    - **When potential responses get flagged by content moderation, send:** the message shown when a response is blocked. If empty, users see `I can't help with that. Is there something else I can help with?`

    Note the current slider position. Only the **Low** label was observed; check Learn for the other level names and the default.

    > **Why this matters:** HR and safety policies legitimately discuss harassment, violence and injury. Set moderation too high and those answers get blocked with a generic message that hides why. Break-it C-03-g tests this and has you write a better flagged-response message.

### Part D: Prove the permissions as real users (60 minutes)

15. **Publish and share.**
    1. Select **Publish**, then **Channels > Teams and Microsoft 365 Copilot**, and add the channel. Select **Make available in Microsoft 365 Copilot** if offered.
    2. Select **Share** and add each persona individually (not groups): `<prefix>-hr@<domain>`, `<prefix>-tech@<domain>`, `<prefix>-fin@<domain>`, `<prefix>-nolic@<domain>`, and the guest.
    3. In the Teams channel settings, copy the agent's link (under **Availability options**; UI labels may differ). You'll open it as each persona; it's more reliable than hoping the agent shows up in their app list.

    <details>
    <summary>If a persona can't see or open the agent</summary>

    Check in this order:

    | Check | What to do |
    |---|---|
    | Environment type | `HLE-Dev` is a Developer environment and owner-only (ENV-02), so personas can't use agents in it. Create a **Sandbox** environment `HLE-Lab3-Sandbox`, rebuild HLE HR Assistant there with steps 3 to 9 and 13, publish and share it, and run steps 16 to 18 against that copy. Cleanup removes it. |
    | Published | Select **Publish** again after any change; personas only see the published version. |
    | Channel | **Channels > Teams and Microsoft 365 Copilot** shows the channel as added. |
    | Shared individually | Each persona added by name, not through a group. |
    | Time | Wait a few minutes after publishing, then sign the persona out and back in. |
    | Copilot Studio app | Microsoft 365 admin center > **Integrated apps**: the Copilot Studio app is deployed to users (ADM-07). |

    </details>

16. **Security trimming test.** In an InPrivate window per persona, sign in, open the agent link (Teams or https://microsoft365.com/chat) and ask:

    ```text
    How long is a final written warning active?
    ```

    | Persona | Expected |
    |---|---|
    | Priya (`hr`) | 24 months, citing `Restricted/Disciplinary-Case-Handling.docx` |
    | Sofia (`fin`) | Not found. No restricted fact appears. |
    | Marcus (`tech`) | Not found. |
    | Guest | Not found, or can't open the agent. Both pass. |

    Then, as Priya and as Sofia, ask `What is the CAD midpoint for grade G7?`. Priya gets 105,000 from the encrypted file (HR has VIEW and EXTRACT rights, CS-K08); Sofia gets nothing.

    > **Why this matters:** this is the test HR actually cares about, and it can only be done as real users. Same agent, same question, different answers, because SharePoint permissions and sensitivity labels are enforced at query time. Details: break-it C-03-d and C-03-e.

17. As Tom (`nolic`), ask `How many days can I carry over?` and record what happens. Tom has no Copilot license, so his usage consumes Copilot Credits (LIC-10).

18. Back as yourself, add an uploaded file: **Knowledge > Add knowledge > Upload file**, `data/sharepoint/Harbourline-Hub/HR-Policies/Signed-Policy-Acknowledgement-Scan.pdf`. Break-it C-03-b uses it to compare uploaded and SharePoint knowledge.

### Part E: Where knowledge breaks (60 minutes)

These experiments add content that doesn't belong in an HR agent, so use a scratch agent.

19. In `HLE-Dev`, create **HLE Knowledge Bench** (**Create > New agent**, skip conversational setup):
    - Description: `Scratch agent for Lab 3 knowledge experiments. Deleted at the end of the lab.`
    - Instructions: [solutions/lab-03/hle-knowledge-bench-instructions.txt](../../solutions/lab-03/hle-knowledge-bench-instructions.txt)
    - Orchestration Generative, general knowledge Off, Authenticate with Microsoft.

20. **A list too big to search.** Add the Vendors list as knowledge:

    ```text
    https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/Vendors
    ```

    List knowledge may appear under a different option, or only in the new experience (CS-K10); if so, use the new experience for this step and note it. Then run break-it C-03-h: vendors past row 2,048 can't be found.

21. **Facts the indexer can't read.** Add the Operations Procedures library:

    ```text
    https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Procedures
    ```

    Run break-it C-03-i (key values only in slide images) and C-03-j (merged cells in a spreadsheet).

22. **Scope too wide.** Follow break-it C-03-k to compare a whole-site source with library sources using the 1,200-file `Archive-Bulk` library. Finish with the Knowledge Bench scoped to `Procedures` and `Vendors` only.

23. Run [validate.md](validate.md), work through the rest of [break-it.md](break-it.md), then [cleanup.md](cleanup.md).

## Key takeaways

You should now be able to explain these to a client:

1. **Instructions control behaviour; SharePoint holds the facts.** Put sources, citation rules and conflict rules in instructions, and never paste policy values into them.
2. **"Authenticate with Microsoft" is what makes an agent safe on SharePoint.** Answers are trimmed to what each person can open, sensitivity labels included. The maker's test pane can't show this; only testing as real users can.
3. **In classic orchestration, topics beat knowledge.** A broad trigger phrase can silently replace a correct, cited answer. Generative orchestration chooses by description, so descriptions matter.
4. **"It can't find it" usually means the indexer can't read it,** not that the agent is broken: files over the size limit, scans, facts inside images, merged cells, lists past the row window, or a scope so wide that the right file never ranks.
5. **Uploaded files are visible to everyone who uses the agent** and can't be encrypted. Use SharePoint knowledge for anything permission-sensitive.

## Caveats this lab triggers

| Caveat ID | Name | Where |
|---|---|---|
| C-03-a | Oversized file silently excluded when tenant graph grounding is off | [break-it.md#c-03-a](break-it.md#c-03-a-oversized-file-silently-excluded) |
| C-03-b | Scanned (image-only) PDF not answerable | [break-it.md#c-03-b](break-it.md#c-03-b-scanned-image-only-pdf) |
| C-03-c | Conflicting policy versions | [break-it.md#c-03-c](break-it.md#c-03-c-conflicting-leave-policy-versions) |
| C-03-d | Security trimming on the Restricted folder | [break-it.md#c-03-d](break-it.md#c-03-d-security-trimming-per-persona) |
| C-03-e | Encrypting sensitivity label: SharePoint works, upload fails | [break-it.md#c-03-e](break-it.md#c-03-e-encrypting-sensitivity-label) |
| C-03-f | Authentication: "Authenticate with Microsoft" vs no authentication | [break-it.md#c-03-f](break-it.md#c-03-f-authentication-mode) |
| C-03-g | Content moderation blocks legitimate HR content | [break-it.md#c-03-g](break-it.md#c-03-g-content-moderation-too-strict) |
| C-03-h | SharePoint list knowledge uses only the first 2,048 rows | [break-it.md#c-03-h](break-it.md#c-03-h-sharepoint-list-2048-row-window) |
| C-03-i | Key facts only in slide images | [break-it.md#c-03-i](break-it.md#c-03-i-image-only-slide-content) |
| C-03-j | Merged cells and near-duplicate rows in xlsx | [break-it.md#c-03-j](break-it.md#c-03-j-merged-cell-spreadsheet) |
| C-03-k | Whole-site vs library scoping with a bulk library | [break-it.md#c-03-k](break-it.md#c-03-k-whole-site-vs-library-scoping) |

## What later labs reuse

| Artifact | Used by |
|---|---|
| Environment `HLE-Dev` | Labs 4, 5, 9, 10, 11 |
| Agent `HLE HR Assistant` in `HLE-Dev` | Lab 7 (connector `HLE Tickets` attached), Lab 10 (connected agent under `HLE Front Door`), Lab 12 (evals) |
