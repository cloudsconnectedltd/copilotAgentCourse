# Lab 06 break-it: manifests, OpenAPI, limits and policy

Back up your working project (or commit it to your own source control) before you start. Restore the working state after each section.

Agents Toolkit and Copilot messages change between releases. Where Learn does not describe the exact tooling behavior, the section says **Observe and record** and gives the expected symptom that the docs support.

Keep developer mode on in Copilot (`-developer on`) for every test. It shows which functions were matched and executed.

---

## C-06-a: Manifest schema version

**Caveat ID:** C-06-a

### Steps to reproduce

1. Copy `appPackage/declarativeAgent.json` to a backup.
2. Replace it with [`solutions/lab-06/break-it/declarativeAgent.v1.0-broken.json`](../../solutions/lab-06/break-it/declarativeAgent.v1.0-broken.json). It declares `"version": "v1.0"` and the v1.0 schema URL, but still uses `WebSearch.sites` and the `CodeInterpreter` capability.
3. Look at the editor problems list in VS Code (the file's `$schema` drives validation), then run **Lifecycle** > **Provision**.
4. Optional second variant: set `"version": "v1.8"` again but add `{ "name": "MeetingActions" }` while `$schema` still points at v1.7. Observe the editor.

### Symptom you will see

**Observe and record.** Expected per the schema documents: validation flags `sites` on the web search object and the `CodeInterpreter` capability as not allowed in v1.0, and the app package validation step in provision fails or warns. Record the exact messages and which step (`teamsApp/validateManifest`, `teamsApp/validateAppPackage` or upload) reported them.

### Root cause

DA-01: the current declarative agent schema is v1.8. Capabilities and properties are added per version: `WebSearch.sites`, `GraphicArt` and `CodeInterpreter` arrived in v1.2; `behavior_overrides` and `disclaimer` in v1.4; `EmailActions` and `MeetingActions` in v1.8 (DA-02). A manifest must use only what its declared version supports. Samples copied from older blog posts are the usual cause.

### Fix

Restore the backup. Keep `$schema` and `version` in step: `https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v1.8/schema.json` and `"version": "v1.8"`. When you upgrade an old manifest, read the "Changes from previous version" section of each schema page between the two versions.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/declarative-agent-manifest-1.8

---

## C-06-b: OpenAPI constraints (broken spec)

**Caveat ID:** C-06-b

### Steps to reproduce

1. Set the API to `AUTH_MODE=none` for this section (restart `func start`). The broken file has no security scheme.
2. In VS Code, create a second, throwaway project: **Create a New Agent/App** > **Declarative Agent** > **Add an Action** > **Start with an OpenAPI Description Document**, and browse to `data/api/openapi-broken.yaml`. Name it `hle-outage-desk-broken`.
3. Record which operations the operation picker offers and whether any are flagged.
4. If the project is generated, set its server URL to your tunnel, **Provision**, and ask the agent: `What is the status of outage OUT-2026-0412?` and `Dispatch CREW-NY-04 to OUT-2026-0433 with High priority.`
5. Repeat step 2 with `data/api/openapi.yaml` and compare.

### Symptom you will see

**Observe and record** for each defect (full list in `data/api/openapi-broken-NOTES.md`):

| Defect | Expected symptom per docs |
|---|---|
| 1. `GET /outage-status` has no `operationId` | The operation is missing from, or flagged in, the picker. If it is not offered, the agent cannot answer the outage question and falls back to "I can't help with that" or general text. |
| 2. `oneOf` in the dispatch body | Flagged or rejected at generation; if generated, Copilot cannot build a valid `assignment` value. |
| 3. Nested `siteContact` object in the dispatch body | Flagged at generation. At runtime any object value is rejected by the API with `400 NESTED_VALUE_NOT_SUPPORTED`; a missing `crewId` gives `400 MISSING_FIELD`. |
| 4. `GET /customers` returns a bare array of 300 accounts | See C-06-c: only part of the data is used, or the call fails. |

### Root cause

- DA-12: nested objects in request bodies or parameters, and `oneOf`, `allOf`, `anyOf` and circular references are not supported for API plugins.
- DA-13 and DA-15: each operation should have an `operationId`; Agents Toolkit requires it, and the plugin function `name` must match it.
- DA-07: unbounded responses exceed the 25-item and 4,096-token limits.

### Fix

Use `data/api/openapi.yaml` (or `openapi-apikey.yaml`). The fix checklist in `openapi-broken-NOTES.md`: add `operationId: getOutageStatus`; replace `assignment` with a flat `crewId` string; remove or flatten `siteContact` into a single `notes` string; replace `/customers` with `/customer-lookup` and its `pageSize` and `page` parameters. Delete the throwaway project (see cleanup) and set the API back to `AUTH_MODE=apikey`.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/known-issues (DA-12)
- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/openapi-document-guidance (DA-13)
- https://learn.microsoft.com/en-us/microsoftteams/platform/messaging-extensions/create-api-message-extension (DA-15)

---

## C-06-c: Plugin response limits (items, tokens, timeout)

**Caveat ID:** C-06-c

### Steps to reproduce

1. **Items.** In HLE Outage Desk, run:

   ```text
   Look up customer accounts with pageSize 200 and tell me how many accounts are on the medical priority list.
   ```

   The instructions tell the agent never to request more than 25 accounts, so first record whether it refuses or lowers `pageSize` (that is the instruction working). Then temporarily delete the sentence "Never request more than 25 accounts in one call." from `instructions`, and the `pageSize` rule from `lookupCustomer` `states.reasoning.instructions`, **Provision**, and run the prompt again.
2. Compare with the ground truth: `GET /api/customer-lookup?pageSize=200` returns 200 accounts; the whole data set has 13 medical priority accounts out of 300.
3. **Timeout.** Run:

   ```text
   Run a delay test: get Ontario outages with delayMs 60000.
   ```

   Confirm in the API console that the request arrived and was delayed 60,000 ms (`X-HLE-Delay-Applied-Ms`).

### Symptom you will see

- Step 1, **Observe and record.** Expected per DA-07: the plugin response is limited to 25 items and the agent to 4,096 tokens, so the answer covers only part of the 200 accounts (for example a count that is too low, or a statement that only some accounts were checked), is truncated, or the call fails. Developer mode shows the function call and its status. Any byte-size limit is undocumented (DA-16, UNVERIFIED): record the response size you observe, do not quote a number as a rule.
- Step 3, **Observe and record.** Expected per DA-07: the call exceeds the 45-second timeout and the agent reports it could not get the data.

### Root cause

DA-07: 25 items per plugin response, 4,096 tokens, 45-second timeout. DA-16: no documented KB or MB limit.

### Fix

Design the API and the plugin for small pages: keep `pageSize` defaults small (the API defaults to 5 customers and 10 outages), ask the user to narrow the search, return totals (`totalMatches`, `customersAffectedTotal`) so the agent does not have to count, and keep the "never more than 25" instruction. For aggregates across many records, add a summary endpoint rather than returning raw rows. Keep calls well under 45 seconds. Restore the instructions and provision again.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/declarative-agent-architecture (DA-07)

---

## C-06-d: Sideloading (custom app upload) policy

**Caveat ID:** C-06-d

You need the Teams Administrator role (or Global Administrator) for this section. If you do not have it, read the steps and skip the reproduction.

### Steps to reproduce

1. Teams admin center > **Teams apps** > **Setup policies**. Create a policy `HLE Lab 6 No Upload` with **Upload custom apps** = **Off**, and assign it to the learner account. (Alternatively, test with a colleague's account that has upload turned off.)
2. Wait for the policy to apply (it is not instant; Observe and record how long it took).
3. In Agents Toolkit, sign out and in again in the **Accounts** pane, then run **Provision**.

### Symptom you will see

**Observe and record.** Expected per docs: the **Accounts** pane no longer shows **Custom App Upload Enabled**, and provision fails at the sideloading step with a message that custom app upload is not allowed. The agent does not appear in Copilot.

### Root cause

DA-17: to build and test agents with Agents Toolkit, custom app upload must be enabled (Teams admin center > **Teams apps** > **Setup policies** > **Upload custom apps**). Admins can block sideloading in production tenants.

### Fix

Remove the `HLE Lab 6 No Upload` assignment (the learner returns to the Global policy with upload on), wait for it to apply, sign in again and provision. In production, use a developer tenant or a policy that allows upload only for a developer group, and publish finished agents through the admin-approved catalog instead of sideloading.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/prerequisites (DA-17)

---

## C-06-e: Capability scoping by URL

**Caveat ID:** C-06-e

### Steps to reproduce

1. HLE Outage Desk is scoped to two libraries: HR-Policies (18 files plus 3 in `Restricted`) and Procedures (7 files), so about 28 files in scope.
2. Ask about content you can open but which is **outside** the scoped URLs:

   ```text
   What is the full-day per diem for business travel in Ontario?
   ```

   (The answer, CAD 90, is in `Finance/Expense-Policy.docx`, outside the scope.)

   ```text
   What is the Harbourline IT help desk phone number?
   ```

   (Getting-Started library, outside the scope.)
3. Ask about content inside the scope: `How many days of annual leave does an employee with 6 years of service get?`
4. Temporarily remove `items_by_url` (keep `"name": "OneDriveAndSharePoint"`), provision, and ask the per diem question again. Restore afterwards.

### Symptom you will see

- Step 2: the agent says it cannot find the information, or answers only from in-scope documents (the Travel Policy defers money matters to the Expense Policy). It does not cite `Expense-Policy.docx`, even though you have access to it.
- Step 3: 20 days, citing `Leave-Policy-v4-2025.pdf`; a good answer flags that `Leave-Policy-v3-2024.docx` says 18.
- Step 4: **Observe and record.** Expected per the manifest reference: without `items_by_url` and `items_by_sharepoint_ids`, the agent can use all SharePoint and OneDrive content you can access, so the per diem answer (CAD 90) can now appear with a Finance citation.
- Throughout, **Observe and record** retrieval quality: with more than 20 files in scope, Copilot searches the full content of only the 20 most relevant files (AB-09), so a detail deep in a less relevant file can be missed.

### Root cause

`items_by_url` limits grounding to the listed URLs; omitting both scoping properties means all content the user can access (declarative agent manifest v1.8, OneDrive and SharePoint object). Scoping does not grant access: the user's own SharePoint permissions still apply. AB-09: full-content search covers up to 20 files; above 20, the 20 most relevant.

### Fix

Scope deliberately. Add a URL for every library the agent should answer from (for example `.../sites/<Prefix>-Harbourline-Hub/Finance`) and nothing else. For precise answers from a few documents, reference 20 or fewer specific files (by URL or with `items_by_sharepoint_ids`) so Copilot searches their full content. Restore `items_by_url` and provision.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/optimize-content-retrieval (AB-09)
- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/declarative-agent-manifest-1.8

---

## C-06-f: API key in custom header vs bearer

**Caveat ID:** C-06-f

### Steps to reproduce

1. The working project sends the API key in the `X-API-Key` custom header (`type: apiKey`, `in: header`). Run `What is the status of outage OUT-2026-0412?` and check the API console: the request arrives with a valid key and returns 200. Record the result.
2. To see what failure looks like, point the auth config at a wrong key: Teams Developer Portal > **Tools** > **API key registration** > your registration > update the secret to `wrong-key`. Ask again.
3. Switch the scheme to bearer: replace the `ApiKeyAuth` block in `appPackage/apiSpecificationFile/openapi.yaml` with [`variants/openapi.bearer-securityScheme.yaml`](../../solutions/lab-06/hle-outage-desk/variants/openapi.bearer-securityScheme.yaml) (`type: http`, `scheme: bearer`). Clear `APIKEYAUTH_REGISTRATION_ID` in `env/.env.dev` so a new registration is created, **Provision**, and ask again.

### Symptom you will see

- Step 1, **Observe and record.** DA-10 says custom headers are supported and DA-11 says they are not. Record which one your tenant shows: 200 with the key, or `401 UNAUTHORIZED` in the API console (`errorCode` `UNAUTHORIZED`) and an agent that says it could not get the data.
- Step 2: `401 UNAUTHORIZED`. Developer mode shows the function call failing.
- Step 3: calls arrive with `Authorization: Bearer <key>` and succeed. The mock API accepts both forms (`data/api/src/lib/auth.js`).

### Root cause

CONFLICT between DA-10 (API key authentication page: bearer token, custom header or query parameter) and DA-11 (known issues: API keys in custom headers, query parameters or cookies are not supported). Copilot decides how to send the key from the OpenAPI `securitySchemes` entry.

### Fix

Prefer the bearer form for API keys when you control the API, since both pages support it. If you must use a custom header, test it in your tenant and keep a bearer fallback. Put the correct key back in the registration (or provision again), restore the file you prefer, and provision.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/plugin-authentication-api-key (DA-10)
- https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/known-issues (DA-11)
