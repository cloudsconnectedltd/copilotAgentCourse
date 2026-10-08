# Lab 06 cleanup

## Remove now (break-it only)

| Item | Where | How |
|---|---|---|
| Throwaway project `hle-outage-desk-broken` (C-06-b) | Your working folder, Teams Developer Portal, Microsoft 365 Copilot | Teams Developer Portal (https://dev.teams.microsoft.com/apps) > find the app > **Delete**. In Teams, **Apps** > **Manage your apps**, remove it. Delete the local folder. |
| Setup policy `HLE Lab 6 No Upload` (C-06-d) | Teams admin center > **Teams apps** > **Setup policies** | Remove the assignment from the learner, then delete the policy. |
| Extra API key registration created in C-06-f | Teams Developer Portal > **Tools** > **API key registration** | Delete the registration that is not referenced by `APIKEYAUTH_REGISTRATION_ID` in `env/.env.dev`. |
| Entra OAuth variant (Part G), if you did it and are not keeping it | Entra admin center; Teams Developer Portal > **Tools** > **OAuth client registration** | Delete app registrations `HLE Outage API (course)` and `HLE Outage Desk plugin client (course)`, delete the OAuth client registration (the Teams Developer Portal is the only place it can be deleted), set `AUTH_MODE` back to `apikey`. |

Restore the working project files (declarative agent manifest, OpenAPI file, instructions) and provision once more.

## Keep (later labs depend on these)

| Item | Needed by |
|---|---|
| Project folder `hle-outage-desk` with its `env/.env.dev` (TEAMS_APP_ID, APIKEYAUTH_REGISTRATION_ID) | Lab 7 adds the `hleTickets` connector capability and provisions again |
| The provisioned agent **HLE Outage Desk dev** and its API key registration | Lab 7, Lab 12 |
| Dev tunnel and API | Labs 7 (testing), 8, 10 |

## End of course teardown

1. Teams Developer Portal > **Apps** > **HLE Outage Desk dev** > **Delete**. In Teams, **Apps** > **Manage your apps** > remove it.
2. Teams Developer Portal > **Tools** > **API key registration**: delete the HLE registration. Do the same under **OAuth client registration** if you created one.
3. Delete any Entra app registrations you created for the OAuth variant.
4. Stop the API and delete the dev tunnel (`devtunnel delete <tunnel id>`). If you deployed to Azure: `./data/api/deploy-azure.ps1 -ResourceGroup rg-hle-course -Cleanup`.
5. Delete `env/.env.dev.user` (it contains the API key).
