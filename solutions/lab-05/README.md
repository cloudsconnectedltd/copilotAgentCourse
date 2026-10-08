# Lab 05 solution files

Finished artifacts for [Lab 5](../../labs/lab-05-studio-actions-flows/README.md). No exported solution zip is provided: flows and connectors are environment-specific, so you build them from these source files and then export **HLEHarbourlineOps** yourself (Lab 11).

| File | What it is | How to use it |
|---|---|---|
| `hle-outage-api.swagger.json` | OpenAPI 2.0 (Swagger) conversion of `data/api/openapi-apikey.yaml`, limited to `getOutageStatus` and `dispatchCrew`, with the `X-API-Key` header scheme. | Power Automate > **Solutions** > **HLEHarbourlineOps** > **New** > **Automation** > **Custom connector** > **Import an OpenAPI file**. Name it `HLE Outage API`. Replace `REPLACE_WITH_API_HOST` with your tunnel host (or set **Host** on the **General** tab). |
| `flow-hle-get-outage-status.md` | Full definition of agent flow **HLE Get Outage Status**: trigger inputs, action settings, output expressions, expected results, and the respond-early variant for C-05-b. | Build the flow in the designer inside **HLEHarbourlineOps**. |
| `flow-hle-dispatch-crew.md` | Full definition of agent flow **HLE Dispatch Crew** (Dataverse **List rows** plus the custom connector). | Same as above. |
| `agent-instructions-addendum.txt` | Text to append to the Lab 4 instructions of **HLE Field Ops Assistant**. | Copilot Studio > agent > **Overview** > **Instructions**. Append, do not replace. |

## Exporting after you build

1. Power Automate or Power Apps > **Solutions** > **HLEHarbourlineOps** > **Export solution**.
2. Custom connectors must be imported in a separate solution, before the solution that contains their connection references and flows (connection reference known issue on Learn). Lab 11 covers the split.
3. Do not commit exported zips or `local.settings.json` with a real API key.

## Why a Swagger 2.0 file

The course API ships OpenAPI 3.0.3 files for Microsoft 365 Copilot (Lab 6). Power Platform custom connector import has historically required OpenAPI 2.0; this could not be verified on Learn during course build (UNVERIFIED), so this conversion is provided. Operation IDs, parameters, responses and the security scheme match `openapi-apikey.yaml`. `x-nullable` replaces OpenAPI 3 `nullable`, and `delayMs` is marked `x-ms-visibility: advanced` so it is hidden by default in the flow designer.
