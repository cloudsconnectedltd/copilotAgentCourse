# Lab 11: Cleanup

Lab 12 re-runs the evals of every lab, including the admin checks in this lab and the published HLE Field Ops Assistant. If you are going on to Lab 12, do **only** the "Remove now" table and come back to the rest after Lab 12.

## Remove now (break-it leftovers)

| What | Where | How |
|---|---|---|
| Sandbox `HLE-Test2` (C-11-a) and `HLE-Scratch` (C-11-c) | Power Platform admin center > **Manage** > **Environments** | Select the environment > **Delete**. |
| Pipeline stage or pipeline `HLE Ops Pipeline 2` (C-11-a) | Power Apps > `HLE-Dev` > Solutions > `HLEHarbourlineOps` > **Pipelines** | Delete the extra pipeline. Keep `HLE Ops Pipeline` until the end of Lab 12. |
| Active (unmanaged) layers in `HLE-Test` and `HLE-Prod` (C-11-b, C-11-e) | Power Apps > environment > Solutions > `HLEHarbourlineOps` > component > **See solution layers** | **Remove active customizations** on any component that shows an Active layer. |
| Agent `HLE Priya Scratch` (C-11-d) | Copilot Studio, the default environment | Delete the agent. |
| Environment routing rule (C-11-d), only if you created one | Power Platform admin center > **Manage** > **Tenant settings** > **Environment routing** | Delete the rule you created. Leave the setting as it was before the lab. Developer environments that routing created are deleted separately under **Environments**. |
| Rejected org catalog submission of `HLE Policy Helper` | Nothing to delete | A rejected submission stays as history. `HLE Policy Helper` itself is kept (Lab 12). |

## Remove after Lab 12

Do these in order.

| Order | What | Where | How |
|---|---|---|---|
| 1 | HLE Field Ops Assistant in the Agent Store | Microsoft 365 admin center > **Agents** > **All agents** > select the agent | **Remove** (or **Block** first if users still have it pinned). This removes the store listing, not the Copilot Studio agent. |
| 2 | User access scoping | Microsoft 365 admin center > **Agents** > **Settings** > **User access** | Set it back to what it was before the lab (the course setup uses All users or `<Prefix>-AllStaff`, see `PLAN.md` section 3). |
| 3 | Managed solution in `HLE-Prod` and `HLE-Test` | Power Apps > environment > **Solutions** > `HLEHarbourlineOps` > **Delete**, or `./solutions/lab-11/Invoke-HleSolutionDeployment.ps1 -TargetEnvironmentUrl <url> -Stage Prod -Cleanup` (then `-Stage Test`) | Deleting a managed solution removes its components **and the rows in its custom tables** (`hle_Asset`, `hle_Crew`, `hle_WorkOrder`). That is intended here. Do **not** use `import-dataverse.ps1 -Cleanup` in these environments. |
| 4 | Connections to `HLE Outage API` in `HLE-Test` and `HLE-Prod` | Power Apps > environment > **Connections** | Delete. |
| 5 | Environments `HLE-Test` and `HLE-Prod` | Power Platform admin center > **Environments** | Delete both, unless your organization keeps them for other courses. Deleting the environment also removes anything left from steps 3 and 4. |
| 6 | Pipeline `HLE Ops Pipeline` | Power Apps > `HLE-Dev` > Solutions > `HLEHarbourlineOps` > **Pipelines** | Delete. Pipeline run records in the platform host remain as history. |
| 7 | Local files | `./out/lab-11/` | Delete the exported zips, deployment settings files and audit CSV. The settings files contain connection IDs; do not leave them in a public repository. `Search-HleAgentAudit.ps1 -Cleanup` removes the CSV it wrote. |
| 8 | `pac` auth profiles `<Prefix>-Dev`, `<Prefix>-Test`, `<Prefix>-Prod` | Your machine | `pac auth delete --name HLE-Test` (and the others), or the deployment script's `-Cleanup` with `-RemoveAuthProfiles`. |

## Do NOT delete

| What | Why |
|---|---|
| `HLE-Dev` and the unmanaged `HLEHarbourlineOps` in it | It is the development source for Labs 4, 5, 9, 10 and 12. Removing the solution container would leave the components but lose your ALM setup; `import-dataverse.ps1 -Cleanup` would delete the tables and data used by Labs 4, 5, 9 and 10. |
| HLE Field Ops Assistant, `HLE Get Outage Status`, `HLE Dispatch Crew`, `HLE Outage API` in `HLE-Dev` | Labs 10 and 12. |
| Environment variable `hle_OutageApiBaseUrl` in `HLE-Dev` | Harmless in Dev; the custom connector may now depend on it. If you remove it, restore the connector host first. |
| `HLE Policy Helper` | Lab 12 re-runs Lab 2 evals against it. |
| Audit settings in Purview | Tenant-wide. Leave auditing on. |
