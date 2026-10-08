# Lab 06 solution files

Finished artifacts for [Lab 6](../../labs/lab-06-declarative-agents-toolkit/README.md). No built app package (`.zip`) is included: Agents Toolkit builds it at **Provision** from these sources and your environment values.

| Path | What it is | How to use it |
|---|---|---|
| `hle-outage-desk/` | Complete Microsoft 365 Agents Toolkit project for the declarative agent **HLE Outage Desk**: app manifest, declarative agent manifest v1.8, API plugin manifest v2.4, Adaptive Card, OpenAPI file, `m365agents.yml`, env samples, variants. | Open the folder in VS Code with Agents Toolkit, fill in `env/`, then **Provision**. See `hle-outage-desk/README.md`. |
| `hle-outage-desk/variants/README.md` | Entra ID OAuth variant (`OAuthPluginVault`) with app registration steps, bearer API key variant, Lab 7 connector capability snippet. | Only when a lab step points to it. |
| `break-it/declarativeAgent.v1.0-broken.json` | The HLE Outage Desk agent declared with schema v1.0 while still using `WebSearch.sites` and `CodeInterpreter`, which were added in v1.2 (break-it C-06-a). | Copy over `appPackage/declarativeAgent.json` (after backing it up) and run **Provision** or validation. |

For the broken OpenAPI exercise (C-06-b) use `data/api/openapi-broken.yaml` and its defect list `data/api/openapi-broken-NOTES.md`; it is not duplicated here.

## Cross-lab notes

- Lab 7 adds the `GraphConnectors` capability with `connection_id` `hleTickets` to `appPackage/declarativeAgent.json` (snippet in `variants/lab07-graphconnectors-capability.json`).
- Lab 8 reuses the dev tunnel and API; it does not change this project.
