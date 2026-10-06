# Lab 03: Copilot Studio agent with SharePoint and file knowledge

| | |
|---|---|
| Build path | Copilot Studio (classic experience), environment `HLE-Dev` |
| Estimated time | 4 hours |
| Prerequisites | [Lab 2](../lab-02-agent-builder-deep-dive/README.md). Setup scripts [`00`](../../setup/00-prereqs-check.ps1), [`01`](../../setup/01-provision-users.ps1), [`02`](../../setup/02-provision-sites.ps1), [`03`](../../setup/03-upload-content.ps1) and [`04-apply-labels.ps1`](../../setup/04-apply-labels.ps1) completed (see [setup/README.md](../../setup/README.md)). Power Apps Developer Plan for the learner (ENV-03). Copilot Studio capacity pack or pay-as-you-go (LIC-06, LIC-07). Generative AI enabled in Power Platform and the Copilot Studio app deployed in the Microsoft 365 admin center (ADM-07). |
| Personas used | Learner (maker), Priya Nandakumar (`hr`), Marcus Delaney (`tech`), Sofia Brennan (`fin`), Tom Whitfield (`nolic`), guest contractor (`guest`) |
| Status | PREVIEW: SharePoint lists as knowledge (status to confirm; documented only in the new-experience docs, CS-K10). Contains UNVERIFIED limits: CS-K13, CS-K14, CS-A05 |
| Limits referenced | [CS-K01, CS-K02, CS-K03, CS-K04, CS-K05, CS-K06, CS-K07, CS-K08, CS-K09, CS-K10, CS-K12, CS-K13, CS-K14, CS-A05, LIC-10, ADM-07, ENV-02, ENV-03](../../reference/limits.md) |

> **Check before you run.** Every Copilot Studio limit in this lab is tagged SNIP or UNVERIFIED in [reference/limits.md](../../reference/limits.md), because the Copilot Studio documentation source was not readable when the course was built. Before you start, open these pages on Microsoft Learn and confirm the values:
>
> | Row | Value used here | Tag | Page |
> |---|---|---|---|
> | CS-K01 | 7 MB file limit without a Microsoft 365 Copilot license in the tenant | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
> | CS-K02 | Up to 200 MB with tenant graph grounding | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio |
> | CS-K03 | 512 MB for PDF, PPTX and DOCX | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio |
> | CS-K04 | Tenant graph grounding needs "Authenticate with Microsoft" | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/configuration-end-user-authentication |
> | CS-K05 | Manual auth needs Sites.Read.All and Files.Read.All | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/nlu-generative-answers-sharepoint-onedrive |
> | CS-K06 | SharePoint URL: site path, no query parameters | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-sharepoint |
> | CS-K07 | Folder source: 1,000 files, 50 folders, 10 levels | SNIP, scope unclear | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
> | CS-K08 | Encryption only via sensitivity labels, SharePoint only, VIEW and EXTRACT needed | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/security-faq |
> | CS-K09 | Uploaded files: encrypted files not supported | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-add-file-upload |
> | CS-K10 | SharePoint lists: queries use the first 2,048 rows | SNIP, new-experience docs | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/knowledge-sharepoint-lists |
> | CS-K12 | Public websites: 25 (generative) or 4 (classic) | SNIP | https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-quotas |
> | CS-K13 | Scanned PDFs not OCR'd | UNVERIFIED | No Learn source. The lab observes, it does not assert. |
> | CS-K14 | Total SharePoint URLs per agent | UNVERIFIED | Not found. Check current limit on Microsoft Learn. |
> | CS-A05 | Instructions limit 8,000 characters | UNVERIFIED | Community answer only. The instructions in this lab are far below it. |
>
> Copilot Studio menu labels in this lab follow the documented concepts. **UI labels may differ in your tenant; check Learn** when a menu name does not match.

> **Additional learners:** the setup scripts listed in Prerequisites are run once by the setup owner. If you are not the setup owner, skip them; the setup owner gives you access with `05-add-learner.ps1` (see [Two or more learners](../../setup/README.md#two-or-more-learners)).

## Objective

Build **HLE HR Assistant**, a Copilot Studio agent that answers Harbourline HR policy questions from the `HR-Policies` SharePoint library, and learn exactly where SharePoint and file knowledge stops working: file size, scanned PDFs, conflicting versions, permissions, encryption, authentication, content moderation, list size, image-only content, merged cells and scoping. A second scratch agent, **HLE Knowledge Bench**, is used for the list, Operations and scoping experiments so that HLE HR Assistant stays clean for Labs 7 and 10.

## Concepts

- **Classic vs new experience.** This course uses the classic Copilot Studio experience (PLAN.md decision Q9). Where [reference/limits.md](../../reference/limits.md) says a fact comes from the new-experience docs (CS-K10), this lab says so.
- **Generative orchestration vs classic orchestration.** With generative orchestration the model reads the descriptions of topics, knowledge and tools and decides what to use for each turn. With classic orchestration, trigger phrases route the user to a topic, and knowledge is used only as a fallback when no topic matches (the Conversational boosting system topic). Some limits differ by mode: an agent can have 25 public websites with generative orchestration but only 4 with classic orchestration or a topic-level generative answers node (CS-K12). Event triggers in Lab 9 need generative orchestration (CS-A07).
- **SharePoint knowledge is security trimmed.** The agent searches SharePoint as the signed-in user, which is why the agent must use "Authenticate with Microsoft" (CS-K04). The Copilot Studio test pane runs as you, the maker, and the learner is in every course group, so the test pane is never a permission test.
- **Tenant graph grounding** uses Microsoft 365 semantic search over SharePoint. It raises the usable file size from 7 MB (no Microsoft 365 Copilot license in the tenant, CS-K01) to 200 MB (CS-K02). SharePoint and connector sources support PDF, PPTX and DOCX up to 512 MB (CS-K03).
- **SharePoint knowledge vs uploaded files.** A SharePoint source stays in SharePoint and keeps its permissions and labels. An uploaded file is copied into the agent (up to 500 files, 512 MB each), is visible to every user of the agent, and cannot be encrypted (CS-K09).
- **Licensing for the people who chat.** Copilot-licensed users are zero-rated for classic answers, generative answers and tenant graph grounding in Copilot Chat, Teams and SharePoint (LIC-10). Tom Whitfield (`nolic`) has no Copilot license, so his usage consumes Copilot Credits.

## Steps

Use `<tenant>` for your SharePoint tenant name and `<Prefix>` for the course prefix (default `HLE`).

### Part A: Environment and agent (45 minutes)

1. **Confirm setup.** Open `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies` and check that:
   - `Employee-Handbook-Full.docx` is present and about 9.1 MB (generated by `tools/generate-data/generate_oversized_handbook.py` during `03-upload-content.ps1`). If it is missing, run `python3 tools/generate-data/generate_oversized_handbook.py` and re-run `03-upload-content.ps1`.
   - `Compensation-Bands-2025.docx` shows the sensitivity label **`<Prefix> HR Confidential`**. If not, re-run `04-apply-labels.ps1` or apply it manually (the script prints the steps).
   - The `Restricted` folder shows "Has unique permissions" and only the site owners and `<Prefix>-HR` have access.

2. **Create environment `HLE-Dev`** (skip if it already exists). Go to https://admin.powerplatform.microsoft.com, open **Manage > Environments > New**, and set:
   - Name: `HLE-Dev`
   - Type: **Developer**
   - Region: your tenant's default
   - Dataverse: included (Developer environments include Dataverse, ENV-03)

   Labs 4, 5, 9, 10 and 11 all use `HLE-Dev`. Do not delete it in cleanup. Note that a Developer environment is owner-only and cannot be assigned security groups (ENV-02). Step 15 explains what this means for persona testing.

3. Go to https://copilotstudio.microsoft.com and select **HLE-Dev** in the environment picker (top right).

4. Select **Create > New agent**, then choose to skip the conversational setup and configure the agent directly. Set:
   - Name: `HLE HR Assistant`
   - Description: `Answers Harbourline Energy Co. HR policy questions for employees in Ontario, New York and Ohio, using the HR-Policies library.`
   - Instructions: paste the text below (also in [solutions/lab-03/hle-hr-assistant-instructions.txt](../../solutions/lab-03/hle-hr-assistant-instructions.txt)). It is about 1,000 characters, far below the unverified 8,000-character figure (CS-A05).

   ```text
   You are HLE HR Assistant for Harbourline Energy Co. employees in Ontario, New York and Ohio.

   Answer only from the HR Policies knowledge source. If the knowledge does not contain the answer, say that you could not find it in the HR policies and suggest the user contact their HR Business Partner (see Employee Relations Contacts). Do not guess and do not use general knowledge.

   Always cite the policy document and the section number you used.

   When two documents with the same Document ID disagree, use the one with the higher version number and the later effective date. Say which version you used and mention that an older version exists with a different value.

   When a rule differs by location, state which location it applies to (Ontario, New York or Ohio).

   Do not give legal advice. For individual cases (discipline, investigations, accommodation, grievances), explain the published process and direct the user to their HR Business Partner.

   Keep answers under 150 words unless the user asks for more detail.
   ```

5. Select **Create**. When the agent opens, go to **Settings > Generative AI** and set:
   - Orchestration: **Generative** (use generative AI orchestration).
   - Use general knowledge (the model's own knowledge): **Off**.
   - Leave content moderation at its default for now (Part C).

   Save. UI labels may differ; check Learn.

6. Go to **Settings > Security > Authentication** and confirm **Authenticate with Microsoft** is selected. New agents default to it, and tenant graph grounding requires it (CS-K04).

7. Go to **Knowledge > Add knowledge > SharePoint** and enter:

   ```text
   https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/HR-Policies
   ```

   The URL must include the site path and no query parameters (CS-K06). Do not paste a view URL such as `.../HR-Policies/Forms/AllItems.aspx?...`. Name the source `HR Policies library` and give it this description (the orchestrator reads it):

   ```text
   Harbourline HR policies: leave, parental and bereavement leave, remote work, overtime and on-call, travel, code of conduct, harassment prevention, FMLA, performance reviews, grievances, accommodation, safety incident reporting, compensation bands and the full employee handbook.
   ```

8. Confirm tenant graph grounding is on. In the classic experience it is a toggle for tenant graph grounding with semantic search in the Generative AI or Knowledge settings area. UI labels may differ; check Learn. With a Microsoft 365 Copilot license in the tenant and this toggle on, files up to 200 MB are used (CS-K02).

9. Wait for the knowledge source to show as ready, then open the **Test** pane and type:

   ```text
   How many days can I carry over?
   ```

   You should get 5 days, to be used by March 31, citing `Leave-Policy-v4-2025.pdf`, ideally with a note that version 3.0 said 10 days. Then type:

   ```text
   What do employees receive for 25 years of service?
   ```

   Expected: 3 extra days of paid leave (one time) and a crystal award, presented at the Service Recognition Dinner in October, citing `Employee-Handbook-Full.docx` (chapter 14.2). This proves the 9 MB file is in use under CS-K02. Break-it C-03-a turns the toggle off.

### Part B: Orchestration modes (20 minutes)

10. Still in the test pane, type `What is the on-call stipend in Ontario?`. Expected: CAD 300 per full week (`Overtime-and-On-Call.docx`, 4.2). Open the activity map or conversation trace in the test pane and note that the orchestrator chose the `HR Policies library` knowledge source directly.

11. Go to **Settings > Generative AI** and switch orchestration to **Classic**. Save, reset the test chat, and ask the same question. The answer now arrives through the **Conversational boosting** system topic (the classic fallback that runs generative answers when no topic trigger phrase matches). Open **Topics > System > Conversational boosting** to see the generative answers node.

12. In classic mode, type `Hello`. The **Greeting** topic fires from its trigger phrases, not from knowledge. This is how topics take precedence in classic mode, which Lab 4 exploits in break-it C-04-a.

13. Switch orchestration back to **Generative** and save. Keep it on generative for the rest of the course (Labs 9 and 10 need it, CS-A07).

### Part C: Content moderation (10 minutes)

14. Go to **Settings > Generative AI** and scroll to the **Moderation** section (observed in the classic experience on 2026-10-06; UI labels may change). It has two settings:
    - **Content moderation level**: a slider. The left end is **Low**, which lets more through; moving right raises moderation. The panel text says: "Lower moderation increases the risk of harmful content in your agent's responses. Higher moderation lowers that risk, but may reduce the number of responses." The arrow icon next to the slider resets it to the default.
    - **When potential responses get flagged by content moderation, send:** the message users see when a response is blocked. If you leave it empty, the grey placeholder text is shown: `I can't help with that. Is there something else I can help with?`

    Note the current slider position. Only the **Low** label was observed; check Learn for the names of the other levels and for which level is the default. Break-it C-03-g moves the slider to the right-hand end and tests a legitimate harassment-policy question.

### Part D: Publish, share and test as personas (60 minutes)

15. **Publish and share.**
    1. Select **Publish**, then **Channels > Teams and Microsoft 365 Copilot**, and add the channel. Select **Make available in Microsoft 365 Copilot** if offered.
    2. Select **Share** and add the persona users individually: `<prefix>-hr@<domain>`, `<prefix>-tech@<domain>`, `<prefix>-fin@<domain>`, `<prefix>-nolic@<domain>`, and the guest contractor's account. Do not add groups: Developer environments cannot be assigned security groups (ENV-02).
    3. **If sharing fails or a persona gets an access error** because `HLE-Dev` is a Developer environment (ENV-02): create a Sandbox environment named `HLE-Lab3-Sandbox`, rebuild HLE HR Assistant there with steps 3 to 9 and 13, and run steps 16 to 18 against that copy. Record which path you used. Cleanup removes `HLE-Lab3-Sandbox`.

16. **Security trimming test.** Open an InPrivate or guest browser window for each persona, sign in, go to Teams (https://teams.microsoft.com) or Microsoft 365 Copilot Chat (https://microsoft365.com/chat), open **HLE HR Assistant**, and type:

    ```text
    How long is a final written warning active?
    ```

    | Persona | Expected |
    |---|---|
    | Priya (`hr`) | 24 months, citing `Restricted/Disciplinary-Case-Handling.docx` |
    | Sofia (`fin`) | Not found. No restricted fact appears. |
    | Marcus (`tech`) | Not found. |
    | Guest | Not found, or the guest cannot open the agent at all. Either result is a pass: guests have no Hub access. |

    Then, as Priya and as Sofia, type `What is the CAD midpoint for grade G7?`. Priya gets 105,000 (encrypted file, HR has VIEW and EXTRACT, CS-K08). Sofia gets no answer. Details are in break-it C-03-d and C-03-e.

17. As Tom (`nolic`), type `How many days can I carry over?` and **observe and record** what happens. Tom has no Copilot license, so any usage consumes Copilot Credits rather than being zero-rated (LIC-10).

18. As the learner, upload a file to see the difference between SharePoint and uploaded knowledge: **Knowledge > Add knowledge > Upload file**, upload `data/sharepoint/Harbourline-Hub/HR-Policies/Signed-Policy-Acknowledgement-Scan.pdf`. Break-it C-03-b uses it.

### Part E: HLE Knowledge Bench (list, Operations content and scoping) (60 minutes)

These experiments add content that does not belong in an HR agent, so use a scratch agent.

19. In `HLE-Dev`, create a second agent with **Create > New agent** (skip conversational setup):
    - Name: `HLE Knowledge Bench`
    - Description: `Scratch agent for Lab 3 knowledge experiments. Deleted at the end of the lab.`
    - Instructions: paste [solutions/lab-03/hle-knowledge-bench-instructions.txt](../../solutions/lab-03/hle-knowledge-bench-instructions.txt).
    - Orchestration: Generative. General knowledge: Off. Authentication: Authenticate with Microsoft.

20. **SharePoint list.** Add the Vendors list as knowledge:

    ```text
    https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub/Lists/Vendors
    ```

    In the classic experience, adding a SharePoint list may appear under a different option (or only in the new experience), because the list-knowledge documentation in [reference/limits.md](../../reference/limits.md) comes from the new-experience docs (CS-K10). UI labels may differ; check Learn. If your tenant does not offer list knowledge in the classic experience, open the new experience for this step and record that you did. Test with break-it C-03-h.

21. **Operations content.** Add the Operations Procedures library:

    ```text
    https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations/Procedures
    ```

    Test with break-it C-03-i (image-only slides in `Crew-Briefing-Deck.pptx`) and C-03-j (merged cells in `Transformer-Equipment-Specs.xlsx`).

22. **Scoping.** Follow break-it C-03-k to compare a whole-site source with library sources, using the 1,200-file `Archive-Bulk` library. End with the Knowledge Bench scoped to the `Procedures` library and the `Vendors` list only.

23. Run the validation in [validate.md](validate.md), then work through [break-it.md](break-it.md), then [cleanup.md](cleanup.md).

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
