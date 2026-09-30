# Lab 05 cleanup

## Remove now (only created for break-it)

| Item | Where | How |
|---|---|---|
| Flow `HLE Get Outage Status (outside solution)` (C-05-c) | Power Automate, HLE-Dev, **My flows** (and **HLEHarbourlineOps** if you added it) | Remove from the solution, then delete from **My flows**. |
| Data policy `HLE-Dev Lab 5 Block Outage API` (C-05-d) | Power Platform admin center > data policies | Delete. Then turn **HLE Get Outage Status** and **HLE Dispatch Crew** back on if they are still suspended. |
| Direct connector tool for **HLE Outage API** (C-05-a) | Copilot Studio, **HLE Field Ops Assistant** > **Tools** | Delete the tool. Make sure the **HLE Get Outage Status** flow tool is turned on. |
| Your personal **HLE Outage API** connection created from the end-user credentials prompt (C-05-a) | Power Automate > **Connections** | Delete it if it is not the connection used by the flows. |

## Keep (later labs depend on these)

| Item | Needed by |
|---|---|
| Custom connector **HLE Outage API** in **HLEHarbourlineOps** | Lab 10, Lab 11 |
| Agent flows **HLE Get Outage Status** and **HLE Dispatch Crew** and their connection references | Lab 10, Lab 11 |
| **HLE Field Ops Assistant** with both flow tools | Lab 10 (connected agent of **HLE Front Door**), Lab 11, Lab 12 |
| The **HLE Outage API** connection used by the flows | Lab 10, Lab 11 |
| Dev tunnel and API key | Labs 6, 8, 10 |

## End of course teardown

After Lab 12:

1. In **HLEHarbourlineOps**, remove and delete **HLE Dispatch Crew**, **HLE Get Outage Status**, the two connection references, and the **HLE Outage API** custom connector (flows first, then connection references, then the connector).
2. Delete the **HLE Outage API** connection in Power Automate > **Connections**.
3. Stop the API host and delete the dev tunnel: `devtunnel list`, then `devtunnel delete <tunnel id>`.
4. If you deployed the API to Azure: `./data/api/deploy-azure.ps1 -ResourceGroup rg-hle-course -Cleanup`.
5. Environment **HLE-Dev** and solution **HLEHarbourlineOps** are removed by the Lab 11 cleanup and `data/dataverse/import-dataverse.ps1 -Cleanup`. Do not delete them here.
