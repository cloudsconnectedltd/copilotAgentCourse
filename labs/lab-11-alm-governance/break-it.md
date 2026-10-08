# Lab 11: Break it

Seven caveats. Each starts from the state at the end of the README steps: `HLEHarbourlineOps` version 1.0.1.0 deployed as managed to `HLE-Test` and `HLE-Prod`, HLE Field Ops Assistant published from `HLE-Prod` and approved.

Where a symptom is not described precisely on Learn, the section says "Observe and record" and gives what the docs lead you to expect. Two sources used here have no row in `reference/limits.md` yet; they are cited by full URL and were read from the MicrosoftDocs/power-platform repository on 2026-09-30.

Increase the solution version in `HLE-Dev` before each redeploy (1.0.2.0, 1.0.3.0 and so on). Both the pipeline and the fallback script skip or refuse a version that is not higher than the target's.

---

## C-11-a: Pipeline target is not a managed environment

**Caveat ID:** C-11-a

### Steps to reproduce

Do this only if you have spare capacity for one more sandbox. It does not touch `HLE-Test` or `HLE-Prod`.

1. In the Power Platform admin center create a sandbox `HLE-Test2` with Dataverse, and do **not** enable Managed Environments.
2. In `HLE-Dev` > `HLEHarbourlineOps` > **Pipelines**, edit `HLE Ops Pipeline` or create `HLE Ops Pipeline 2` with one stage targeting `HLE-Test2`.
3. Deploy to that stage.
4. As an admin, open the Power Platform admin center > **Deployment** and look at the targets list.

### Symptom you will see

Observe and record. Expected per the pipelines docs (ALM-01):

- Before October 2026 the deployment may simply succeed.
- From October 2026 the admin deployment page notifies admins that a pipeline deployed to a non-managed target and starts a 30-day countdown. Makers can keep deploying during the countdown and can acknowledge the one-time extension, but they cannot enable managed environments themselves. After the grace period (and one optional 30-day extension per environment) deployments to that target are blocked.

Write down which of these you saw and the date.

### Root cause

Pipelines require every target environment other than a developer environment to be a managed environment, and managed environments need premium licenses for the people who run assets there (ALM-01). The requirement always existed; from October 2026 it is enforced with a notification and then a block.

### Fix

- Enable Managed Environments on the target (select the environment > **Enable Managed Environments**), or
- turn on automatic enablement for each pipelines host under Power Platform admin center > **Deployment** > **Settings**, so targets become managed on their next deployment. Turning automatic conversion off does not remove the requirement.
- If licensing makes managed targets impossible, use the fallback path (README Part D2) and accept that you lose the pipeline's approval gate, backups and history.
- Delete `HLE-Test2` afterwards.

### Doc link

https://learn.microsoft.com/en-us/power-platform/alm/pipelines

---

## C-11-b: Hotfix edited in the managed target

**Caveat ID:** C-11-b

### Steps to reproduce

1. Open Copilot Studio in environment `HLE-Test`, open `HLE Field Ops Assistant`, and try to change its instructions: add the line `Always end with "Test build".` Save and publish if the UI lets you. If Copilot Studio blocks editing a managed agent, instead open https://make.powerapps.com > `HLE-Test` > **Solutions** > **Default Solution**, find the agent flow `HLE Get Outage Status`, and edit it (for example rename an action). Record which one was possible.
2. In `HLE-Dev`, make a different change to the same component (for example add `Mention the outage ID in every answer.` to the instructions), increase the version to 1.0.2.0, and deploy to Test with the pipeline or the fallback script.
3. Ask the agent in `HLE-Test`: `What is the status of outage OUT-2026-0412?`
4. In https://make.powerapps.com > `HLE-Test` > **Solutions** > `HLEHarbourlineOps`, select the component > **Advanced** > **See solution layers** (UI labels may differ).

### Symptom you will see

- The Dev change does not appear in Test. The answer still ends with "Test build" (or the flow still has your manual edit).
- The solution layers view shows an **Active** (unmanaged) layer above the `HLEHarbourlineOps` managed layer.

If Copilot Studio refused the edit in step 1, record that: it is the safer outcome, and the flow path shows the same layering.

### Root cause

You cannot edit components inside a managed solution. An edit in the target creates an unmanaged customization, which lives in the single unmanaged layer that sits above all managed layers, and for most components the top layer wins at runtime. Pipelines import as *Upgrade* without *Overwrite customizations*, so the new managed version is installed underneath your unmanaged edit and the edit keeps winning. The edit also creates a dependency that can block uninstalling the managed solution. (Solution concepts and layers; pipelines FAQ.)

### Fix

1. In the solution layers view, select the Active layer and choose **Remove active customizations** (UI labels may differ). The managed 1.0.2.0 behavior returns.
2. Make every change in `HLE-Dev`, bump the version, and redeploy. Treat Test and Prod as read-only.
3. Governance: in managed targets, give makers the Basic User role only, not System Customizer, so they cannot edit there.

### Doc link

https://learn.microsoft.com/en-us/power-platform/alm/pipelines (see also https://learn.microsoft.com/en-us/power-platform/alm/solution-layers-alm, not yet in `reference/limits.md`)

---

## C-11-c: Unmanaged import into a downstream environment

**Caveat ID:** C-11-c

### Steps to reproduce

Use `HLE-Test2` from C-11-a if you still have it, or a new sandbox `HLE-Scratch`. Do not do this in `HLE-Test` or `HLE-Prod`.

1. Import the **unmanaged** zip that the fallback script exported (`HLEHarbourlineOps_1_0_1_0.zip`) into the scratch environment:

   ```powershell
   pac solution import --path ./out/lab-11/HLEHarbourlineOps_1_0_1_0.zip --environment https://<scratch>.crm.dynamics.com --settings-file ./out/lab-11/deployment-settings.Test.json
   ```

2. In the scratch environment, change the description of the `hle_WorkOrder` Priority column. Then import the same unmanaged zip again, this time with `--force-overwrite`.
3. Try to import the **managed** zip into the same scratch environment.
4. Delete the solution `HLEHarbourlineOps` in the scratch environment (**Solutions** > **...** > **Delete**). Open **Tables**.

### Symptom you will see

- Step 2: the second import with `--force-overwrite` silently replaces your description change. `pac` documents the switch as "Force an overwrite of unmanaged customizations".
- Step 3: observe and record. Expected: the managed import fails, because a solution with the same unique name already exists in the environment as unmanaged. Record the exact error text.
- Step 4: the solution is gone but the tables `hle_Asset`, `hle_Crew`, `hle_WorkOrder`, the flows, the connector and the agent are still there. Deleting an unmanaged solution removes only its container; the components remain in the default solution.

The same trap happens without `pac`: running `import-dataverse.ps1` against an empty target creates an unmanaged `HLEHarbourlineOps` there, and the later managed deployment collides with it. That is why the README loads data only after the managed import (Part A step 6, Part E step 22).

### Root cause

Unmanaged solutions are for development environments; everything downstream should receive managed solutions. All unmanaged solutions share one unmanaged layer, unmanaged imports overwrite what is there when asked to, and an unmanaged solution cannot be uninstalled as a unit. Pipelines refuse unmanaged deployments for this reason ("Can I deploy unmanaged solutions? No", pipelines FAQ).

### Fix

- Only deploy managed exports outside `HLE-Dev`. The fallback script imports the `_managed.zip` and never uses `--force-overwrite`.
- Keep the unmanaged zip for source control only.
- To recover a polluted environment, delete the components by hand (work orders first, then crews and assets, as `import-dataverse.ps1 -Cleanup` does), or reset the scratch environment. Then delete the scratch environment.

### Doc link

https://learn.microsoft.com/en-us/power-platform/alm/pipelines (see also https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm, not yet in `reference/limits.md`)

---

## C-11-d: Makers land in the default environment

**Caveat ID:** C-11-d

### Steps to reproduce

1. Sign in as Priya Nandakumar (hr) in a private window. If `<Prefix>-HR` is not allowed to author in Copilot Studio (ADM-08), sign in as a maker account in `<Prefix>-CourseMakers` instead.
2. Open https://copilotstudio.microsoft.com and create an agent named `HLE Priya Scratch` without touching the environment picker.
3. Look at the environment picker at the top right.
4. As the Power Platform admin, open https://admin.powerplatform.microsoft.com > **Manage** > **Tenant settings** and find **Environment routing**. Read the current state; do not turn it on unless your facilitator says so (see Fix).

### Symptom you will see

- The agent was created in the tenant's default environment (named "{Microsoft Entra tenant name} (default)" unless an admin renamed it; its **Type** is Default), not in a governed environment. All licensed users have the Environment Maker role in the default environment (ENV-01 source page), so this agent now sits next to everyone else's experiments.
- Environment routing is **Off** (the docs say it is off by default).

### Root cause

When environment routing is off, or no routing rule matches the maker, makers are routed to the default environment. Environment routing is a tenant-level, premium governance feature that sends new or existing makers to their own personal developer environment in Copilot Studio, Power Apps and Power Automate. Environments it creates are managed developer environments, and people who run apps and flows in a managed developer environment need a premium license (creating and previewing does not). No limits row covers this yet; the source is https://learn.microsoft.com/en-us/power-platform/admin/default-environment-routing (MicrosoftDocs/power-platform, read 2026-09-30).

Tenants that use Copilot Managed Runtime have routing for that product selected by default, but makers in Copilot Studio are still not routed unless an admin turns routing on for Copilot Studio (same source, "Environment routing for Copilot Managed Runtime").

### Fix

- Power Platform admin center > **Manage** > **Tenant settings** > **Environment routing** (setting name as shown in the docs on 2026-09-30; **check Learn** for the current label). Select the portals (Copilot Studio at minimum), create a rule for a security group (for example `<Prefix>-CourseMakers`) or **Everyone**, pick an environment group, save. Rules are evaluated in order; the first match wins; no match means the default environment.
- The same switch in PowerShell (from the same page, Microsoft.PowerApps.Administration.PowerShell): `$s = Get-TenantSettings; $s.powerPlatform.governance.enableDefaultEnvironmentRouting = $true; Set-TenantSettings -RequestBody $s`.
- In a shared course tenant, do not turn routing on for Everyone: it creates a developer environment for every maker and counts against their limit of 3 developer environments (ENV-03). Discuss it, or scope it to one test group.
- Delete `HLE Priya Scratch` from the default environment.

### Doc link

https://learn.microsoft.com/en-us/power-platform/admin/environments-overview (environment types, ENV-01) and https://learn.microsoft.com/en-us/power-platform/admin/default-environment-routing (routing, not yet in `reference/limits.md`)

---

## C-11-e: Published agent waits for admin approval

**Caveat ID:** C-11-e

### Steps to reproduce

1. In Copilot Studio (`HLE-Prod`), add a sentence to the HLE Field Ops Assistant instructions, for example `Give estimated restoration times in Eastern Time.`, and publish. (Unmanaged edit in a managed target: do this, observe, then remove it as in C-11-b. Or make the change in Dev and redeploy 1.0.3.0 first.)
2. Do not approve anything yet. As Marcus Delaney, ask: `What is the status of outage OUT-2026-0419?`
3. As the learner, submit `HLE Policy Helper` to the org catalog (README step 32) and, without approving it, sign in as Priya and search the Agent Store under **Built by your org**.
4. As AI Administrator, open **Agents** > **All agents** > **Requests**. Optionally run `./solutions/lab-11/Get-HleAgentInventory.ps1 -PendingOnly`.

### Symptom you will see

- Step 2: Marcus gets the previous behavior. An update to an already published agent shows in the admin center as **Pending update**, and the previous version stays available to users until an admin selects **Update in store**. (Expected answer data either way: OUT-2026-0419, Syracuse NY, 1,087 customers, underground cable fault, Crew Assigned CREW-NY-02 Megan Iverson, ETR 2026-09-30 12:00.)
- Step 3: `HLE Policy Helper` is not in **Built by your org**. The submit dialog says **Waiting for approval**. People it was *shared* with in Lab 2 can still use it, because the shared version and the Agent Store version are separate entries.
- Step 4: both requests appear with states such as **Pending review** and **Pending update**. The Graph call returns them with `requestStatus` `pending` and `requestType` `publish` or `update`.

### Root cause

Publishing an agent to the organization (Copilot Studio "available to everyone in the org", or Agent Builder **Submit to your org catalog**) creates a request that an admin must approve in the Microsoft 365 admin center before users see it (ADM-04, AB-10). An agent can have only one active pending submission; a resubmission replaces it. Sharing is a separate path that only an owner controls (AB-10), and the tenant's **Sharing** setting applies only to Agent Builder agents (ADM-03). The admin page paths are SRC-STALE (ADM-04); the Graph API is PREVIEW (ADM-05).

### Fix

- Admin: **Agents** > **All agents** > **Requests** > select the agent > **Publish to store** (new) or **Update in store** (update), scope to `<Prefix>-AllStaff`, or **Reject submission** with a comment.
- Makers: tell users the Store version changes only after approval; test with sharing while the request is pending.
- Operations: add the pending-request query (`requestStatus eq 'pending'`) to a daily admin check so agents do not wait unseen.

### Doc link

https://learn.microsoft.com/en-us/microsoft-365/admin/manage/manage-copilot-agents-integrated-apps (ADM-04), https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/agent-builder-share-manage-agents (AB-10), https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-registry (ADM-05)

---

## C-11-f: Environment-specific values travel with the solution

**Caveat ID:** C-11-f

### Steps to reproduce

1. In `HLE-Dev`, open the environment variable `hle_OutageApiBaseUrl` and add the current value back into the solution (**Add existing** > **Environment variable value**, or re-enter the value while the solution is open; UI labels may differ). Set it to your dev tunnel URL.
2. Bump to 1.0.4.0. With the fallback script, delete the `hle_OutageApiBaseUrl` entry from `deployment-settings.Test.json`; with the pipeline, accept the prefilled value on the deployment screen.
3. Deploy to `HLE-Test`. Stop your dev tunnel (`Ctrl+C` in the `devtunnel host` window).
4. In `HLE-Test`, ask HLE Field Ops Assistant: `What is the status of outage OUT-2026-0427?`
5. Separately, remove the `ConnectionId` value for the `HLE Outage API` connection reference from the settings file and deploy again (1.0.5.0) with the fallback script.

### Symptom you will see

- Step 2 (pipeline): the deployment screen shows the value prefilled with a label saying it came from the solution.
- Step 4: the flow fails or times out because Test is calling your developer's tunnel. The agent says it cannot get the outage status. (Expected data when it works: OUT-2026-0427, Toledo OH, 12,480 customers, substation transformer failure at Maumee Bay substation, ETR 2026-10-01 18:00, crew CREW-OH-01 Dale Rutherford.)
- Step 5: observe and record. Expected: the import either asks for the connection or completes with the flow turned off and a connection reference without a connection. The pipelines FAQ states that a connection reference without a value in the solution or target cannot be updated during a pipeline deployment.

### Root cause

An environment variable has a default value (part of the definition) and a current value (a separate record). A current value included in the solution is exported as its own file inside the zip and is used in the next environment even if a default exists. Connection references carry only the connector; the connection must exist in each target and be supplied at import (deployment settings file, or the pipeline's connection step). Pipelines deploy connections, connection references and environment variables as configuration, but only the values you give them.

### Fix

- Keep the current value out of the solution (**Current value** > **...** > **Remove from this solution**), as in README step 10.
- Generate the settings file with `pac solution create-settings`, keep one file per stage (`deployment-settings.Test.json`, `deployment-settings.Prod.json`), store them in source control without secrets, and fill connection IDs per environment.
- Treat empty values as a failed build: the fallback script refuses to import while any value is empty.
- Restart your tunnel and redeploy 1.0.6.0 with correct values.

### Doc link

https://learn.microsoft.com/en-us/power-platform/alm/pipelines

---

## C-11-g: Personas cannot reach an agent in the developer environment

**Caveat ID:** C-11-g

### Steps to reproduce

1. In Copilot Studio switch to `HLE-Dev`, open `HLE Field Ops Assistant`, and try to share it with `<Prefix>-Ops-Ontario`, or open https://admin.powerplatform.microsoft.com > `HLE-Dev` > **Settings** > **Users + permissions** > **Security roles**/**Access** and try to assign the group.
2. Try to publish the Dev copy to Teams and ask Marcus Delaney to use it.

### Symptom you will see

- The security group option is not available for a developer environment, or the assignment fails.
- Observe and record what Marcus sees when he opens the Dev copy (for example an access error, or the agent never appears for him).

### Root cause

Developer environments are owner-only and cannot be assigned security groups (ENV-02). Anything that must be used by other people, including testers, belongs in a sandbox or production environment. Lab 3 met the same wall and used a temporary sandbox; this lab turns that into a standing environment strategy (ENV-01).

### Fix

Test with personas in `HLE-Test` (sandbox, `<Prefix>-CourseMakers`) and release to users from `HLE-Prod` (`<Prefix>-AllStaff`). Keep `HLE-Dev` for the maker only. If you need another developer environment, remember the limit of 3 per user and the 30-day inactivity disable (ENV-03).

### Doc link

https://learn.microsoft.com/en-us/power-platform/admin/environments-overview
