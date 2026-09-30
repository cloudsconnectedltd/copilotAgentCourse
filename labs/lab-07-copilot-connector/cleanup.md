# Lab 07: Cleanup

## Do not delete yet if you continue the course

| Keep | Why |
|---|---|
| Connection `hleTickets` and its 5,000 items | Lab 12 (capstone) re-runs `evals/lab-07-questions.csv`. Lab 10 connects HLE HR Assistant, which now uses the connector, to HLE Front Door. |
| The `GraphConnectors` capability in HLE Outage Desk, and the connector knowledge in HLE Policy Helper and HLE HR Assistant | Same reason. The agents themselves belong to Labs 2, 3 and 6 and are removed by those labs' cleanup. |
| App registration `HLE-Tickets-Connector` and its certificate | Needed to re-ingest or to run `-Cleanup` later. |
| Persona group memberships | Everything in the course depends on them. |

## Undo break-it changes now

1. Restore the semantic labels if you removed them in C-07-d:

   ```powershell
   cd solutions/lab-07
   ./Set-TicketLabels.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint> -Cleanup
   ```

2. If you removed the learner from `<Prefix>-Ops-Ontario` while testing C-07-b, add the learner back (or re-run `setup/01-provision-users.ps1`, which is idempotent).
3. If you assigned Search Administrator or AI Administrator to a persona for C-07-f, remove that role assignment.

## Full removal (end of course)

Run these in order.

1. **Detach the connector from the agents** (skip any agent you already deleted):
   - HLE Outage Desk: remove the `GraphConnectors` object from `appPackage/declarativeAgent.json`, remove the ticket paragraph from the instructions, and Provision again.
   - HLE Policy Helper: Edit > Configure > Knowledge, remove Harbourline Tickets (HLE), Update.
   - HLE HR Assistant: Knowledge, remove the Copilot connector source, Publish.
2. **Delete the connection.** This removes the schema and all items; deletion completes in the background.

   ```powershell
   cd data/connector
   ./ingest-tickets.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint> -Prefix HLE -Cleanup
   ```

   Confirm in the admin center (Copilot > Connectors) that Harbourline Tickets (HLE) is gone.
3. **Delete the app registration.** Microsoft Entra admin center > App registrations > `HLE-Tickets-Connector` > Delete. Then check **Deleted applications** and delete permanently if your policy requires it.
4. **Remove the certificate** from the machine that ran the script (`Cert:\CurrentUser\My`, subject `CN=HLE-Tickets-Connector`) and delete any `conn.key`, `conn.pfx` or `.cer` files you created.
5. **Optional SQL database.** If you loaded `tickets-seed.sql` into SQL Server or Azure SQL, drop the database `HarbourlineTickets` (or delete the Azure SQL database and, if you created it for this lab only, its server and resource group).
6. **Graph Explorer consent.** If personas consented to Graph Explorer permissions for the Search API checks, an admin can remove those grants in Entra ID > Enterprise applications > Graph Explorer > Permissions.

Groups and personas are removed by `setup/99-teardown.ps1`, not here.
