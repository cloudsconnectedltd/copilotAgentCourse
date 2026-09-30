# Lab 08: Cleanup

## Keep if you continue the course

| Keep | Why |
|---|---|
| The mock API (local or the Function App from `data/api/deploy-azure.ps1`) | Labs 5, 6 and 10 use it. |
| `solutions/lab-08/hle-grid-advisor` source | Lab 12 re-runs `evals/lab-08-questions.csv`. Keep the Azure deployment only if you want to run the capstone in Teams; otherwise the capstone can use the local run. |
| Lab 6 project and HLE Outage Desk | Used in C-08-a and later labs. |

Nothing in Labs 9 to 11 depends on HLE Grid Advisor.

## Reset break-it changes now

1. `RAI_FILTERS=on` in your local `.env` and in the App Service settings.
2. `HLE_API_BASE_URL` set back to the public API URL in the App Service settings (C-08-e).
3. SSO values restored, or re-run Agents Toolkit **Provision** (C-08-d).

## Full removal

1. **Teams app.** Teams > Apps > Manage your apps > HLE Grid Advisor > Remove, for the learner and for Tom Whitfield. If an admin published it for the organization, remove it in Teams admin center > Manage apps (or Microsoft 365 admin center > Integrated apps).
2. **Azure resources created in Part B.** In `rg-hle-course`, delete the App Service `hle-grid-advisor-<unique>`, its App Service plan (if nothing else uses it), and the Azure Bot `hle-grid-advisor-bot`. If Agents Toolkit provisioned them, delete the resource group the toolkit created (named in `env/.env.dev`), after checking it holds nothing else.
3. **Model deployment.** Delete the chat model deployment you created in Part A, and the Azure OpenAI resource or Foundry project if you created it only for this lab. Deleted Azure OpenAI and Foundry resources can be held in a soft-deleted state; purge them if your policy requires it.
4. **Entra app registrations.** Delete `HLE-Grid-Advisor-Bot` and any SSO app registration Agents Toolkit created (check App registrations for names containing your project name).
5. **Mock API in Azure.** Only at the end of the course: `./data/api/deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral -Cleanup`. This deletes the resource group only if it carries the tag `createdBy=hle-course`; delete Lab 8 resources first if they are in the same group and you want to keep the API.
6. **Dev tunnel.** If you used one, stop `devtunnel host` and run `devtunnel delete <tunnel id>`.
7. **Part D (optional).** In Copilot Studio (HLE-Dev), delete the agent `HLE Grid Advisor (Studio)` and its prompt tool `Classify outage severity`. Do not delete the Lab 5 agent flow **HLE Get Outage Status** or the **HLE Outage API** connector: Labs 5 and 10 own them.
8. **Local files.** Delete `.env` (it holds keys) and `node_modules` in `solutions/lab-08/hle-grid-advisor`, and any `hle-grid-advisor.zip` you created.
