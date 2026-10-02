# Lab 05 break-it: flows, connectors, credentials and policies

Each section breaks the working setup from the README on purpose, shows what you see, and fixes it. Run them in order. Restore the working state at the end of each section before starting the next.

Where a behavior is not described in a public Microsoft Learn source, the section says **Observe and record** and gives only the expected symptom the docs support. Write down what you actually see; exact messages vary by build.

---

## C-05-a: Maker credentials vs end-user credentials

**Caveat ID:** C-05-a

**Why it matters:** An API key is a shared secret, not a user identity. Whoever owns the connection that a tool uses is who the API "sees". With maker credentials every chat user acts through your connection; with end-user credentials every user needs their own connection, which for an API key means every user needs the key.

### Steps to reproduce

1. **Flow path (maker credentials).** In the Copilot Studio **Test** pane of **HLE Field Ops Assistant**, run:

   ```text
   Dispatch CREW-NY-04 to OUT-2026-0433 with Normal priority.
   ```

   Look at the flow run in Power Automate (**HLEHarbourlineOps** > **HLE Dispatch Crew** > **Run history**) and open the `Dispatch crew` action output. Note `createdBy`.
2. If **HLE Field Ops Assistant** is shared with Marcus Delaney (`tech`) and published to a channel he can use (for example Teams), sign in as Marcus and run the same prompt. HLE-Dev is a developer environment, which is owner-only (ENV-02), so if you cannot share the agent with Marcus, skip this step and record "not shared".
3. **Direct connector path (end-user credentials).** In **Tools** > **Add a tool** > **Connector**, search for **HLE Outage API** and add the action **Get current power outages and estimated restoration times** directly as a tool (no flow). In the tool's settings, find the authentication or credentials option and choose the end-user option (the concept Microsoft documents as the user's own credentials versus maker-provided credentials; the exact label may differ; check Learn). Save.
4. Temporarily turn off the **HLE Get Outage Status** flow tool so the orchestrator picks the direct connector tool. In a new Test conversation, run:

   ```text
   What is the status of outage OUT-2026-0412?
   ```

### Symptom you will see

- Step 1: the dispatch succeeds with no sign-in or key prompt. The API response shows `"createdBy": "anonymous"`, because in `AUTH_MODE=apikey` the API only knows that a valid key was sent (`data/api/src/lib/auth.js`). The flow ran with the connection you, the author, chose in the flow.
- Step 2 (if shared): Marcus gets the same result, with no prompt. Every dispatch in the API log looks identical regardless of who asked.
- Step 4: **Observe and record.** Expected per the end-user credentials concept: the Test pane asks you to create or connect your own **HLE Outage API** connection before the tool runs, and that connection asks for the API key. Any other user would get the same prompt and would need the key.

### Root cause

No limits.md row applies; this is documented connector behavior, not a limit. A connection is "a stored authentication credential for a connector" (connection reference documentation). An agent flow uses the connections its author selected. A connector tool set to end-user credentials asks each user for their own connection. For an API key connector that means sharing the secret with every user, and for maker credentials it means no per-user identity reaches the API.

### Fix

- Keep the flow path (maker credentials) for API key APIs, and control who can chat with the agent instead. Do not give the API key to end users.
- If the API must know the user, change the API to OAuth (the mock API supports `AUTH_MODE=entra`, see `data/api/run-local.md` section 6), build the connector with OAuth 2.0 against Microsoft Entra ID, and use end-user credentials. Then `createdBy` carries the signed-in user principal name. Lab 6 shows the same idea for a declarative agent.
- Remove the direct connector tool you added in step 3 and turn the **HLE Get Outage Status** flow tool back on.

### Doc link

- https://learn.microsoft.com/en-us/power-apps/maker/data-platform/create-connection-reference (connections, sharing connections)
- https://learn.microsoft.com/en-us/microsoft-copilot-studio/flow-agent (agent flows; SNIP tier, check current wording)

---

## C-05-b: Agent flow 100-second response limit

**Caveat ID:** C-05-b

### Steps to reproduce

1. Confirm the API delay works through the tunnel (expect the call to take about 120 seconds and return the header `X-HLE-Delay-Applied-Ms: 120000`):

   ```powershell
   $h = @{ 'X-API-Key' = '<your API key>' }
   Invoke-WebRequest -Headers $h "https://<tunnel host>/api/outage-status?region=ON&delayMs=120000" | Select-Object StatusCode, Headers
   ```

2. In the Copilot Studio Test pane, run:

   ```text
   Run a delay test: check Ontario outages with delayMs 120000.
   ```

3. Watch the Test pane and the flow run history.

### Symptom you will see

**Observe and record.** Expected per CS-A02: the agent does not receive a flow response within 100 seconds, so the tool call fails and the agent reports an error or says it could not complete the request, while the flow run in Power Automate may still be running or finish later with a 200 from the API. Record the exact error text and the flow run duration.

### Root cause

CS-A02: an agent flow must return a response to the agent within 100 seconds. The API waits 120 seconds before answering, so **Respond to the agent** runs too late.

### Fix

Pick the fix that matches the cause:

1. **The API is slow (this case).** Remove `delayMs` or send `0`. In production, ask the API owner for a faster endpoint or a "request accepted" pattern.
2. **Long-running work that must continue.** Use the asynchronous response pattern (CS-A04; status UNVERIFIED, check Learn): the flow answers the agent quickly, keeps running, and the result is delivered later. A simple version you can build now: move **Respond to the agent** before the slow action, return `summary = "Outage status request accepted. Ask again in a few minutes."`, and let the flow continue. The user must ask again, because the agent is no longer waiting.
3. **The flow itself is slow (many actions, no slow API).** Turn on **express mode** for the flow (CS-A03, PREVIEW). Express mode needs the **When an agent calls a flow** trigger and does not allow delay or webhook actions. It does not make a 120-second API faster, so it does not fix this case; record that result if you try it.

After the fix, rerun step 2 with `delayMs 0` and confirm the agent answers.

### Doc link

- https://learn.microsoft.com/en-us/microsoft-copilot-studio/flow-agent (CS-A02)
- https://learn.microsoft.com/en-us/microsoft-copilot-studio/advanced-flow-create (CS-A02)
- https://learn.microsoft.com/en-us/microsoft-copilot-studio/flow-asynchronous-response (CS-A04)
- https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-flow-express-mode (CS-A03)

---

## C-05-c: Flows created outside a solution have no connection references

**Caveat ID:** C-05-c

### Steps to reproduce

1. In Power Automate (environment **HLE-Dev**), go to **My flows** (not **Solutions**) and create an instant cloud flow named `HLE Get Outage Status (outside solution)` with trigger **When an agent calls a flow**, one Text input `outageId`, the **HLE Outage API** action **Get current power outages and estimated restoration times**, and **Respond to the agent** with one Text output `summary` = `body('Get_current_power_outages_and_estimated_restoration_times')?['message']`. Save it.
2. Go to **Solutions** > **HLEHarbourlineOps** > **Add existing** > **Automation** > **Cloud flow** > **Outside Dataverse** (label may differ; check Learn) and add the flow.
3. Open the flow's details page inside the solution and look at the connections panel and the flow checker.
4. Optional (preview of Lab 11): export **HLEHarbourlineOps** as unmanaged and look at the solution contents for connection reference components.

### Symptom you will see

- The flow uses a **connection** for **HLE Outage API**, not a **connection reference**.
- The flow checker shows a warning to **Use connection references**, with an action **Remove connections so connection references can be added**.
- In an export, the flow has no connection reference to re-point, so after import into **HLE-Test** in Lab 11 it cannot be turned on until someone fixes its connections by hand.

### Root cause

No limits.md row applies; this is documented ALM behavior. "Flows created outside a solution use connections directly. Flows created in a solution use connection references." When a flow that is not in a solution is added to one, "it will continue to use connections initially." Canvas apps and flows added from outside solutions are not upgraded automatically.

### Fix

1. Preferred: delete `HLE Get Outage Status (outside solution)` and build flows inside **HLEHarbourlineOps** from the start, as in the README.
2. To repair an existing flow: open it inside the solution, select the flow checker action **Remove connections so connection references can be added**, then select or create the **HLE Outage API** connection reference in **HLEHarbourlineOps**.
3. Alternative: export the flow in an unmanaged solution and import it; the connections are replaced with connection references.
4. Lab 11 note: custom connectors must be imported in a separate solution, before the solution that holds their connection references and flows. Plan for that when you package **HLE Outage API**.

### Doc link

- https://learn.microsoft.com/en-us/power-apps/maker/data-platform/create-connection-reference

---

## C-05-d: Data policy (DLP) blocks the custom connector

**Caveat ID:** C-05-d

You need the Power Platform administrator role, or environment admin rights on **HLE-Dev**, to create an environment-level data policy. Data policies are the current name for DLP policies in the Power Platform admin center.

### Steps to reproduce

1. Open the Power Platform admin center (https://admin.powerplatform.microsoft.com) > **Security** > **Data and privacy** > **Data policies** (older builds: **Policies** > **Data policies**; label may differ; check Learn) > **New policy**.
2. Name: `HLE-Dev Lab 5 Block Outage API`.
3. On **Prebuilt connectors**, move **Microsoft Dataverse** to **Business**. (Dataverse cannot be blocked, but it can be classified.)
4. On **Custom connectors**, pick one variant:
   - **Variant 1 (Blocked):** set **HLE Outage API** to **Blocked**.
   - **Variant 2 (group conflict):** leave **HLE Outage API** in **Non-Business** (the default group for new policies) while Dataverse is in **Business**.
5. Scope: **Add multiple environments** > select **HLE-Dev** only. Create the policy.
6. Wait. Policy enforcement on existing flows works by polling and is not instantaneous. Check again after several minutes.
7. Open **HLE Dispatch Crew** and **HLE Get Outage Status** in Power Automate, then run the README Part D prompts in the Copilot Studio Test pane.

### Symptom you will see

- **Variant 1:** both flows are marked **Suspended** (they use a Blocked connector). Saving either flow shows a data policy error in the flow checker. The flow is saved but stays suspended.
- **Variant 2:** **HLE Dispatch Crew** is **Suspended**, because it combines a Business connector (Dataverse) with a Non-Business connector (HLE Outage API). **HLE Get Outage Status** keeps working, because it uses only one data group.
- In Copilot Studio: **Observe and record.** Expected: the agent cannot run a suspended flow, so the tool call fails and the agent reports it could not complete the request. Record the exact message.

### Root cause

No limits.md row applies; this is documented data policy behavior. "You can't share data among connectors that are located in different groups" and "you can block data flow to a specific service by marking that connector as Blocked." Flows that violate the latest policy are marked **Suspended** and do not run until the maker resolves the violation. Environment admins can classify custom connectors by name in environment-level policies.

### Fix

1. Edit `HLE-Dev Lab 5 Block Outage API` and move **HLE Outage API** to **Business** (same group as Dataverse). Or delete the policy.
2. Open each suspended flow and turn it on again (it does not always resume on its own).
3. Rerun the Part D prompts.
4. Production note: classify the custom connector deliberately. Tenant admins can also classify custom connectors by host URL pattern in tenant-level policies (for example, allow `https://*.harbourline.example/*` as Business and block everything else).

### Doc link

- https://learn.microsoft.com/en-us/power-platform/admin/dlp-connector-classification
- https://learn.microsoft.com/en-us/power-platform/admin/dlp-custom-connector-parity
- https://learn.microsoft.com/en-us/power-platform/admin/dlp-impact-policies-apps-flows
