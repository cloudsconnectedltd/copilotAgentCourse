# Lab 11: ALM and governance

| | |
|---|---|
| Build path | Power Platform solutions, pipelines and the Power Platform CLI (`pac`); Power Platform admin center; Microsoft 365 admin center; Microsoft Purview audit |
| Estimated time | 3.5 hours (add 30 minutes if you take the fallback path in Part D) |
| Prerequisites | [Lab 4](../lab-04-studio-dataverse-topics/README.md) (HLE Field Ops Assistant and the Dataverse tables in `HLE-Dev`, loaded by [`data/dataverse/import-dataverse.ps1`](../../data/dataverse/import-dataverse.ps1), which also creates the unmanaged solution `HLEHarbourlineOps`). [Lab 5](../lab-05-studio-actions-flows/README.md) (custom connector `HLE Outage API`, agent flows `HLE Get Outage Status` and `HLE Dispatch Crew`). [Lab 10](../lab-10-multi-agent/README.md) completed (its agents stay in `HLE-Dev`; they are not moved in this lab). [Lab 2](../lab-02-agent-builder-deep-dive/README.md) agent `HLE Policy Helper` for the org catalog step. Mock API reachable in the cloud ([`data/api/run-local.md`](../../data/api/run-local.md) dev tunnel, or [`data/api/deploy-azure.ps1`](../../data/api/deploy-azure.ps1)). Tools: PowerShell 7, `pac` CLI, ExchangeOnlineManagement, Microsoft.Graph. Roles: Power Platform Administrator, AI Administrator, and an audit search role in Purview. |
| Personas used | Learner (maker and admin), Marcus Delaney (tech, uses the published agent so audit records exist), Priya Nandakumar (hr, checks the org catalog) |
| Status | GA, except: PREVIEW: Agent Registry / package management Graph APIs (ADM-05). Contains SNIP rows: AUD-01, ADM-08. SRC-STALE rows: ADM-01, ADM-02, ADM-04, ADM-06. |
| Limits referenced | [ENV-01, ENV-02, ENV-03, ALM-01, ADM-01, ADM-02, ADM-03, ADM-04, ADM-05, ADM-06, ADM-07, ADM-08, AB-10, AUD-01](../../reference/limits.md) |

> **Check before you run.** Confirm these rows on Microsoft Learn before class. If Learn now says something different, follow Learn and tell your facilitator.
>
> | Row | Tag | What to confirm | Page |
> |---|---|---|---|
> | AUD-01 | SNIP | Record type name `CopilotInteraction` and the `AppIdentity` / `AgentId` fields in the audit record | https://learn.microsoft.com/en-us/purview/audit-copilot |
> | ADM-08 | SNIP | "Copilot Studio authors" tenant setting takes a security group | https://learn.microsoft.com/en-us/troubleshoot/power-platform/copilot-studio/licensing/authors-access |
> | ADM-01, ADM-02, ADM-04, ADM-06 | SRC-STALE | Menu paths in the Microsoft 365 admin center (**Agents > Settings**, **Agents > All agents**, the older **Settings > Integrated apps** path) and the roles that can act on agents | https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-settings and https://learn.microsoft.com/en-us/microsoft-365/admin/manage/manage-copilot-agents-integrated-apps |
> | ADM-05 | SRC, PREVIEW | Whether the package management Graph API is still preview, and which version (`beta` or `v1.0`) to call | https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-registry |
> | ALM-01 | SRC | The October 2026 enforcement dates for pipelines that deploy to non-managed targets | https://learn.microsoft.com/en-us/power-platform/alm/pipelines |
>
> Two facts in this lab come from Learn pages that have no row in `reference/limits.md` yet. Both were read from the MicrosoftDocs/power-platform source on 2026-09-30: environment routing (https://learn.microsoft.com/en-us/power-platform/admin/default-environment-routing) and solution layering (https://learn.microsoft.com/en-us/power-platform/alm/solution-layers-alm). Setting names for environment routing are given as the docs showed them on that date; **check Learn** for the current label.
>
> Copilot Studio documentation could not be read from source for this course. Where a step says "UI labels may differ", look for the concept, not the exact words.

> **Additional learners:** the setup scripts listed in Prerequisites are run once by the setup owner. If you are not the setup owner, skip them; the setup owner gives you access with `05-add-learner.ps1` (see [Two or more learners](../../setup/README.md#two-or-more-learners)).

## Objective

Move **HLE Field Ops Assistant** and everything it depends on from your developer environment to test and production the way a regulated utility would: as a managed solution, through a pipeline, with environment-specific settings, an approval gate before users see it, and an audit trail of who used it.

By the end you will have:

| Artifact | Where |
|---|---|
| Solution `HLEHarbourlineOps` (unmanaged) holding the three `hle_` tables, HLE Field Ops Assistant, the two agent flows, the custom connector, connection references and the environment variable `hle_OutageApiBaseUrl` | `HLE-Dev` |
| Managed `HLEHarbourlineOps` | `HLE-Test` (sandbox, managed environment) and `HLE-Prod` (production, managed environment) |
| A pipeline `HLE Ops Pipeline` with stages Test and Prod, or the documented `pac` fallback | Power Apps > Solutions > Pipelines |
| HLE Field Ops Assistant published to Teams and Microsoft 365 Copilot from `HLE-Prod`, approved in the Microsoft 365 admin center | Microsoft 365 admin center > Agents |
| An audit search showing Marcus Delaney's interactions with the agent | Microsoft Purview |

## Concepts

- **Environment strategy.** Power Platform has Default, Production, Sandbox, Trial, Developer and Dataverse for Teams environments, each with zero or one Dataverse database (ENV-01). A developer environment is owner-only and cannot be assigned security groups (ENV-02), which is why personas cannot test in `HLE-Dev`. The free Developer Plan gives up to 3 developer environments per user, and they are disabled after 30 days of inactivity (ENV-03).
- **Unmanaged vs managed solutions.** You build in an unmanaged solution in development and deploy a managed export everywhere else. You cannot edit components directly inside a managed solution; an edit made in a target environment lands in the unmanaged layer, which sits on top of every managed layer and wins at runtime. Deleting an unmanaged solution removes only the container; its components stay behind. Deleting a managed solution removes its components and the data in its custom tables. (Solution concepts and layers pages, SRC, see the callout above.)
- **Pipelines.** In-product deployments from a development environment through stages. Target environments other than developer environments must be managed environments. From October 2026 admins are notified when a pipeline deploys to a non-managed target and get 30 days (plus one 30-day extension per environment) before those deployments are blocked (ALM-01). Pipelines import as *Upgrade* without *Overwrite customizations*, and they never deploy unmanaged solutions.
- **Connection references and environment variables.** A connection reference lets a flow or agent point at "a connection to HLE Outage API" instead of a specific person's connection. An environment variable holds a value that changes per environment, here the API base URL. A *deployment settings file* supplies both values at import time so nobody types them by hand.
- **Microsoft 365 governance.** Agent settings (who can use and share agents) are under **Agents > Settings** (ADM-01, ADM-02, ADM-03). The inventory where admins publish, deploy, block and remove agents is under **Agents > All agents** (older docs: **Settings > Integrated apps**) (ADM-04). The same inventory is exposed through preview Graph APIs (ADM-05). AI Administrator manages agents; Global Reader can only view (ADM-06).
- **Audit.** Every Copilot interaction, including with an agent, is written to the unified audit log as a `CopilotInteraction` record carrying `AppIdentity` and `AgentId` (AUD-01, SNIP).

## Steps

### Part A: Environment strategy (30 min)

1. Go to https://admin.powerplatform.microsoft.com > **Manage** > **Environments**. Confirm `HLE-Dev` exists, type **Developer**, with Dataverse. It was created before Lab 4 (see `PLAN.md` section 3).
2. Create `HLE-Test`: **New** > Name `HLE-Test`, Type **Sandbox**, Region the same as `HLE-Dev`, **Add a Dataverse data store** = Yes, Security group `<Prefix>-CourseMakers`. Save and wait until the state is **Ready**.
3. Create `HLE-Prod`: **New** > Name `HLE-Prod`, Type **Production**, same region, Dataverse = Yes, Security group `<Prefix>-AllStaff`. Save.
   - Why the region matters: a pipeline host and all its environments must be in the same geography unless cross-geo deployment is enabled on the host (pipelines FAQ).
4. Turn `HLE-Test` and `HLE-Prod` into managed environments: select each environment > **Enable Managed Environments** (the command may sit under the **...** menu; UI labels may differ). Accept the defaults. Managed environments need premium licensing for the people who *run* apps and flows there (`PLAN.md` section 3).
   - If your tenant has no premium licensing, stop here, do **not** enable managed environments, and take the **fallback path** in Part D. You still complete Parts B, C, E, F and G.
5. Record what you built in the table below. You will need both environment URLs (select the environment > **Environment URL**, for example `https://hle-test-xxxx.crm.dynamics.com`).

   | Environment | Type (ENV-01) | Managed | Security group | Who can test here |
   |---|---|---|---|---|
   | `HLE-Dev` | Developer | No (not required, ALM-01) | none possible (ENV-02) | Learner only |
   | `HLE-Test` | Sandbox | Yes | `<Prefix>-CourseMakers` | Makers and the learner |
   | `HLE-Prod` | Production | Yes | `<Prefix>-AllStaff` | All personas with licenses |

6. Load Harbourline data into `HLE-Test` and `HLE-Prod` **after** Part D, not now. Solutions carry table definitions but never table rows (pipelines FAQ), and running the import script against an empty target now would create an *unmanaged* `HLEHarbourlineOps` there (see break-it C-11-c).

### Part B: Assemble the solution in HLE-Dev (45 min)

7. Go to https://make.powerapps.com, pick environment `HLE-Dev`, open **Solutions**. Open `HLEHarbourlineOps` (publisher `hleharbourline`, prefix `hle`, version 1.0.0.0). It already holds `hle_Asset`, `hle_Crew`, `hle_WorkOrder` and their two relationships, created by `import-dataverse.ps1`. If it is missing, run:

   ```powershell
   ./data/dataverse/import-dataverse.ps1 -EnvironmentUrl https://<your-hle-dev>.crm.dynamics.com -Prefix HLE -SkipData
   ```

8. Set it as the preferred solution so new components land in it: **Solutions** > **...** > **Set preferred solution** > `HLEHarbourlineOps` (UI labels may differ). Lab 4 step 4 recommended this already, and Lab 5 created the custom connector and both agent flows inside this solution, so several components below may already be listed. Add only what is missing.
9. Add the existing components: **Add existing** and choose, one type at a time:

   | Add existing > | Select | Notes |
   |---|---|---|
   | Agent (may be listed as Chatbot or Copilot) | `HLE Field Ops Assistant` | Adding the agent may offer to add its topics, knowledge and tools as required components. Accept. |
   | Automation > Cloud flow (agent flows may be listed here or under Agent flows) | `HLE Get Outage Status`, `HLE Dispatch Crew` | Include required objects when prompted. |
   | Automation > Custom connector | `HLE Outage API` | |
   | More > Connection reference | Every connection reference the flows and agent use. Lab 5 created two: **HLE Outage API** and **Microsoft Dataverse** (used by `HLE Dispatch Crew`) | A flow created outside a solution uses a direct connection instead of a reference (Lab 5 break-it C-05-c). Do not add the Lab 5 copy `HLE Get Outage Status (outside solution)`. |

   Do not add `HLE Front Door`, `HLE HR Assistant` or other Lab 10 agents. They stay in `HLE-Dev`; moving a multi-agent set across environments is out of scope for this lab.

10. Create the environment variable: **New** > **More** > **Environment variable**.

    | Field | Value |
    |---|---|
    | Display name | `HLE Outage API Base URL` |
    | Name | `hle_OutageApiBaseUrl` |
    | Data type | Text |
    | Default value | leave empty |
    | Current value | your development API base URL, for example `https://<tunnel-id>-7071.<region>.devtunnels.ms/api` or `https://hle-outage-api-<suffix>.azurewebsites.net/api` |

    Then remove the current value from the solution so it does not travel: on the variable, **Current value** > **...** > **Remove from this solution**. The value stays in `HLE-Dev`; the next environment gets its own value from the deployment settings file (break-it C-11-f shows what happens if you skip this).

11. Point the custom connector at the variable. Open `HLE Outage API` > **Edit** > **General**. Custom connectors in solutions can read environment variables in their connection settings; the Learn page "Environment variable support in custom connectors" (https://learn.microsoft.com/en-us/connectors/custom-connectors/environment-variables) gives the exact syntax, for example `@environmentVariables("hle_OutageApiBaseUrl")`. Confirm the syntax on that page before you type it; this course could not read it from source. If your connector cannot use the variable for its host, keep the host as is and note that the `HLE-Test` and `HLE-Prod` connectors must be edited after import (which creates an unmanaged layer, see C-11-b).
12. Publish all customizations (**Publish all customizations** on the solution command bar). In Copilot Studio, publish HLE Field Ops Assistant once in `HLE-Dev` and run one test: `What is the status of outage OUT-2026-0412?` Expected: Crew On Site, 3,214 customers, Kingston, ETR 2026-09-30 14:30 EDT, crew CREW-ON-03 (Devon Achebe) (`data/answer-keys/api.md`).
13. Increase the version to `1.0.1.0`: open the solution > **...** > **Settings** or **Edit** > Version (UI labels may differ), or run `pac solution online-version --solution-name HLEHarbourlineOps --solution-version 1.0.1.0 --environment <HLE-Dev URL>`.

### Part C: Deployment settings (15 min)

14. Open [`solutions/lab-11/deployment-settings.sample.json`](../../solutions/lab-11/deployment-settings.sample.json). It has the shape that `pac solution create-settings` produces: an `EnvironmentVariables` array (`SchemaName`, `Value`) and a `ConnectionReferences` array (`LogicalName`, `ConnectionId`, `ConnectorId`).
15. You will generate the real file from your own export in Part D (the logical names of connection references include a random suffix, so do not copy them from the sample). For each target you need:
    - `HLE-Test` and `HLE-Prod` each need their own connections, created by the learner after the first import makes the custom connector exist there (the pipeline's deployment screen can also create them): https://make.powerapps.com > environment > **Connections** > **New connection**.
      - `HLE Outage API`: Lab 5 runs the API with `AUTH_MODE=apikey`, so the connection asks for the API key. Use the key of the API instance that stage calls (`data/api/run-local.md`, `data/api/deploy-azure.ps1`).
      - `Microsoft Dataverse`: sign in as the learner.
      - The connection ID is the last segment of the connection's URL. On the fallback path the custom connector does not exist in the target before the first import, so you cannot create its connection yet; README Part D2 step 19 handles this with `-AllowIncompleteSettings`.
    - The API base URL for that stage. For a course tenant it is fine to use the same Azure Function App for Test and Prod; in a real deployment they would differ.

### Part D: Deploy with a pipeline, or with the fallback (60 min)

Choose **D1** if `HLE-Test` and `HLE-Prod` are managed environments. Choose **D2** if they are not (premium licensing missing), or if your organization forbids the platform host.

#### D1: Pipelines (hands-on)

16. In https://make.powerapps.com > `HLE-Dev` > **Solutions** > `HLEHarbourlineOps` > **Pipelines** (left pane of the solution). Select **Create pipeline** (this uses the tenant's platform host; a custom host set up by an admin also works).

    | Field | Value |
    |---|---|
    | Name | `HLE Ops Pipeline` |
    | Stage 1 | Name `Test`, target `HLE-Test` |
    | Stage 2 | Name `Prod`, target `HLE-Prod`, previous stage `Test` |

    The target picker lists only environments you can import into. You cannot choose a target that is already linked to the host as a development environment (pipelines setup FAQ).
17. Select **Deploy here** on the Test stage. The pipeline validates the solution against the target and then asks for connections and environment variable values: select the `HLE Outage API` connection you made in step 15 and enter the Test API base URL for `hle_OutageApiBaseUrl`.
18. Wait for **Deployment succeeded**. Open **Run history** and note the version (1.0.1.0) and the deployed artifact. Pipelines keep both a managed and an unmanaged backup of every deployed version in the host.
19. Repeat **Deploy here** on the Prod stage. The same artifact that passed Test is deployed; a stage cannot be skipped.
20. As an admin, open https://admin.powerplatform.microsoft.com > **Deployment** (or **Deployments**; UI labels may differ). Confirm both targets show as managed and no "unmanaged target" warning is shown. Under **Deployment > Settings** you can turn on automatic managed-environment enablement for pipeline targets (ALM-01).
21. Optional (pro developer): list and run the same pipeline from the CLI:

    ```powershell
    pac pipeline list --environment <HLE-Dev URL>
    pac pipeline deploy --solutionName HLEHarbourlineOps --stageId <stage id from the list> --currentVersion 1.0.1.0 --newVersion 1.0.2.0 --wait
    ```

    Confirm the parameter names with `pac pipeline deploy --help`; they are taken from the `pac pipeline` reference page on 2026-09-30.

#### D2: Fallback, manual export and import of the managed solution with pac

Use [`solutions/lab-11/Invoke-HleSolutionDeployment.ps1`](../../solutions/lab-11/Invoke-HleSolutionDeployment.ps1). It is idempotent (it skips the import when the target already has the same or a higher version, using `--skip-lower-version`) and has `-Cleanup`.

16. Sign in once per environment. The script creates `pac` auth profiles named `<Prefix>-Dev`, `<Prefix>-Test`, `<Prefix>-Prod` if they do not exist (interactive sign-in).
17. Export both flavours and generate the settings file:

    ```powershell
    ./solutions/lab-11/Invoke-HleSolutionDeployment.ps1 -Prefix HLE `
        -SourceEnvironmentUrl https://<hle-dev>.crm.dynamics.com `
        -TargetEnvironmentUrl https://<hle-test>.crm.dynamics.com -Stage Test `
        -OutputFolder ./out/lab-11
    ```

    On the first run the script exports `HLEHarbourlineOps_1_0_1_0.zip` (unmanaged, for source control) and `HLEHarbourlineOps_1_0_1_0_managed.zip`, runs `pac solution create-settings`, writes `./out/lab-11/deployment-settings.Test.json`, and stops because the values are empty.
18. Fill in `deployment-settings.Test.json`: the `hle_OutageApiBaseUrl` value and the `ConnectionId` of each connection reference (step 15). Compare with the sample file.
19. Run the same command again. The script now imports the managed zip into `HLE-Test` with `pac solution import --settings-file ... --skip-lower-version`, then lists the solutions in the target. It never passes `--force-overwrite` (see C-11-c).
    - First import into a target only: the `HLE Outage API` connection cannot exist yet, so its `ConnectionId` is empty and the script refuses. Add `-AllowIncompleteSettings` (environment variable values must still be filled). After the import, create the `HLE Outage API` connection in the target, open **Solutions** > `HLEHarbourlineOps` > **Connection references** > the HLE Outage API reference, select the new connection, save, and turn both flows on. Put the connection ID into the settings file so later deployments are complete.
20. Repeat steps 17 to 19 with `-TargetEnvironmentUrl https://<hle-prod>.crm.dynamics.com -Stage Prod`.
21. Record in your notes that this path has no approval gate, no automatic backup in a pipelines host and no deployment history in the admin center. That is the governance cost of the fallback.

### Part E: Data and a working agent in HLE-Prod (20 min)

22. Load the rows into both targets now that the managed tables exist (the script sees the tables and the existing solution and only upserts rows):

    ```powershell
    ./data/dataverse/import-dataverse.ps1 -EnvironmentUrl https://<hle-test>.crm.dynamics.com -Prefix HLE
    ./data/dataverse/import-dataverse.ps1 -EnvironmentUrl https://<hle-prod>.crm.dynamics.com -Prefix HLE
    ```

    Never run this script with `-Cleanup` against `HLE-Test` or `HLE-Prod`. Its cleanup deletes tables and the `HLEHarbourlineOps` solution, which in a target is the managed deployment.
23. Open Copilot Studio (https://copilotstudio.microsoft.com), switch environment to `HLE-Prod`, open `HLE Field Ops Assistant`. Check that the agent flows are **On** and that their connection references show your `HLE-Prod` connection. Turn on any flow that is off (flows imported with unresolved connections can arrive off; observe and record).
24. Publish the agent in `HLE-Prod` and test: `What is the status of outage OUT-2026-0412?` and `Is work order WO-2026-01076 an Ohio problem?` Expected for the second: No. The asset RCL-ON-13307 is in Ontario (Barrie Depot); OH in the title means overhead (`data/answer-keys/dataverse-connector.md`, P-DV-08).

### Part F: Publish to Teams and Microsoft 365 Copilot with admin approval (40 min)

25. Check the tenant prerequisites for Copilot Studio agents in Microsoft 365: generative AI features on in the Power Platform admin center, and the Copilot Studio app deployed in the Microsoft 365 admin center (ADM-07). `setup/00-prereqs-check.ps1` lists these as manual checks.
26. Review the Microsoft 365 agent settings: https://admin.microsoft.com > **Agents** > **Settings** (ADM-01).
    - **User access**: All users (default), No users, or specific users and groups (ADM-02). Set it to specific groups: `<Prefix>-AllStaff`.
    - **Sharing**: this setting applies only to agents built in Agent Builder (ADM-03). Leave it as it is.
    - Note the **Allowed agent types** and **Agent templates** sections. Do not change them.
27. In Copilot Studio (`HLE-Prod`) > `HLE Field Ops Assistant` > **Channels** > **Teams and Microsoft 365 Copilot**. Turn on the channel, select **Availability options**, choose to make it available to everyone in the organization (UI labels may differ), and submit it for admin approval. Keep the page open: the status should now say it is waiting for admin approval.
28. As AI Administrator (ADM-06), open https://admin.microsoft.com > **Agents** > **All agents** > **Requests** (older docs: **Settings > Integrated apps**; ADM-04). The agent appears with state **Pending review**. Open it and read the capabilities, data sources and actions shown.
29. Optional, preview API (ADM-05): list the same queue with Microsoft Graph:

    ```powershell
    ./solutions/lab-11/Get-HleAgentInventory.ps1 -Prefix HLE -PendingOnly
    ```

    The script calls `GET /beta/copilot/admin/catalog/packages?$filter=requestStatus eq 'pending'` with the `CopilotPackages.Read.All` permission and prints display name, platform, request type and status.
30. Select **Publish to store**. In the wizard: users who can install = `<Prefix>-AllStaff`; preinstalled for = none; policy template = default; review permissions; **Publish**.
31. Sign in as Priya Nandakumar (hr) in a private window, open https://microsoft365.com/chat > **Agents** (Agent Store) > **Built by your org**. `HLE Field Ops Assistant` should be listed. Sign in as Marcus Delaney (tech), add the agent, and ask in Teams or Copilot: `What is the status of outage OUT-2026-0412?` and `Who leads crew CREW-OH-07?` (Tessa Whitaker, Toledo Storm Response Crew A, the only crew certified Live-Line Barehand 69 kV; P-DV-11).
32. Agent Builder path (AB-10): open `HLE Policy Helper` from Lab 2 as the learner > **...** > **Submit to your org catalog**. Fill the dialog (display name, short description, developer name, creator website, privacy statement and terms of use URLs, for example `https://harbourline.example/privacy`). Select **Continue**. The dialog shows **Submitted for admin approval**; the status is **Waiting for approval**. It appears in the same **Requests** list. Reject it with a comment (for example "Course demo: resubmit after Lab 12"), then reopen the dialog and read the rejection banner. Break-it C-11-e explains why the shared version keeps working for the people it was shared with.

### Part G: Audit agent interactions in Purview (30 min)

33. Confirm auditing is on. In Exchange Online PowerShell: `Get-AdminAuditLogConfig | Format-List UnifiedAuditLogIngestionEnabled` should return `True`. If it is `False`, turn on auditing in the Purview portal and wait before searching (the delay is not stated in `reference/limits.md`; check Learn).
34. Portal search: https://purview.microsoft.com > **Audit** > **Search**. Date range: today. Record types: `CopilotInteraction` (AUD-01). Users: `hle-tech@<domain>`. Run the search and open one record. Find `AppIdentity` and `AgentId` in the details and write down the agent's value. (UI labels may differ; the record type name is SNIP and must be confirmed.)
35. Scripted search: run [`solutions/lab-11/Search-HleAgentAudit.ps1`](../../solutions/lab-11/Search-HleAgentAudit.ps1):

    ```powershell
    ./solutions/lab-11/Search-HleAgentAudit.ps1 -Prefix HLE -AdminUpn admin@<domain> `
        -UserIds hle-tech@<domain> -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date) `
        -OutputCsv ./out/lab-11/copilot-interactions.csv
    ```

    It calls `Search-UnifiedAuditLog -RecordType CopilotInteraction` in pages, parses `AuditData`, and writes one row per record with user, time, `AppIdentity`, `AgentId` and agent name if present. The script header lists the parameters and field names you must confirm on Learn.
36. Compare the two results. They should show the same interactions for Marcus. If the scripted search returns nothing but the portal does, the record type name or field names differ from what the script assumes: fix the parameter and tell your facilitator.

Now run [`validate.md`](validate.md), then [`break-it.md`](break-it.md), then [`cleanup.md`](cleanup.md).

## Caveats this lab triggers

| Caveat ID | Name | Where in break-it.md |
|---|---|---|
| C-11-a | Pipeline target is not a managed environment | [C-11-a](break-it.md#c-11-a-pipeline-target-is-not-a-managed-environment) |
| C-11-b | Hotfix edited in the managed target | [C-11-b](break-it.md#c-11-b-hotfix-edited-in-the-managed-target) |
| C-11-c | Unmanaged import into a downstream environment | [C-11-c](break-it.md#c-11-c-unmanaged-import-into-a-downstream-environment) |
| C-11-d | Makers land in the default environment | [C-11-d](break-it.md#c-11-d-makers-land-in-the-default-environment) |
| C-11-e | Published agent waits for admin approval | [C-11-e](break-it.md#c-11-e-published-agent-waits-for-admin-approval) |
| C-11-f | Environment-specific values travel with the solution | [C-11-f](break-it.md#c-11-f-environment-specific-values-travel-with-the-solution) |
| C-11-g | Personas cannot reach an agent in the developer environment | [C-11-g](break-it.md#c-11-g-personas-cannot-reach-an-agent-in-the-developer-environment) |

## Files

| File | Purpose |
|---|---|
| [`validate.md`](validate.md) | Run `evals/lab-11-questions.csv` (admin checks) |
| [`break-it.md`](break-it.md) | Reproduce the seven caveats |
| [`cleanup.md`](cleanup.md) | Remove what this lab created, and what to keep for Lab 12 |
| [`caveats.csv`](caveats.csv) | Caveat register rows for this lab |
| [`../../solutions/lab-11/`](../../solutions/lab-11/README.md) | pac deployment script, deployment settings sample, audit search script, agent inventory script |
