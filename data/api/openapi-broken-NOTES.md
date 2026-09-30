# openapi-broken.yaml: defect list

`openapi-broken.yaml` is a deliberately non-compliant description of the Harbourline mock API, used in the Lab 6 break-it exercises. It is valid OpenAPI 3.0.3 (a generic validator accepts it), but it breaks the Microsoft 365 Copilot API plugin guidance. Each defect is marked with a `DEFECT n` comment in the file.

The fixed version of every defect is in `openapi.yaml`.

## How to use it

1. Run the API locally with `AUTH_MODE=none` (see `run-local.md`).
2. In Visual Studio Code, use Microsoft 365 Agents Toolkit: **Create a New Agent/App** > **Declarative Agent** > **Add an Action** > **Start with an OpenAPI Description Document**, and browse to `openapi-broken.yaml`.
3. Record what the operation picker, the generated project and the Copilot debug output show for each defect below.
4. Repeat with `openapi.yaml` and compare.

The "Expected symptom" column describes what the documentation predicts. Exact messages depend on the Agents Toolkit version, so learners record what they actually see. Tooling behavior that the docs do not describe is marked "observe".

## Defects

| # | Defect | Where in the file | Expected symptom | limits.md |
|---|---|---|---|---|
| 1 | Missing `operationId` | `paths./outage-status.get` | Agents Toolkit requires an `operationId` for each operation it turns into a function. Expect the operation to be missing from, or flagged in, the operation picker (observe which). If it is not offered, the agent cannot answer outage questions and falls back to general knowledge or says it cannot help. Copilot's debug output names functions by `operationId`, so there is nothing to trace. | DA-13, DA-15 |
| 2 | `oneOf` in the POST request body | `components.schemas.DispatchRequest.properties.assignment` | Polymorphic references (`oneOf`, `allOf`, `anyOf`) are not supported for API plugins. Expect `dispatchCrew` to be rejected or flagged when the plugin is generated (observe), or, if it is generated, Copilot cannot build a valid `assignment` value. | DA-12 |
| 3 | Nested object in the POST request body | `components.schemas.DispatchRequest.properties.siteContact` (and `siteContact.location`) | Nested objects in request bodies or parameters are not supported for API plugins. Expect the same generation-time flag as defect 2 (observe). At runtime, any object value that reaches the API is rejected: the mock API returns `400` with `errorCode: NESTED_VALUE_NOT_SUPPORTED`. Note: the Teams API-based message extension docs say nested request objects are supported there; that statement does not apply to Copilot API plugins. | DA-12 |
| 4 | Unbounded array response, no paging | `paths./customers.get` (`listAllCustomers`) | The operation has no `pageSize`, the response is a bare array with no `maxItems`, and the `/api/customers` route returns every account (300 with no filter). A plugin response is limited to 25 items and the agent to 4,096 tokens (DA-07), so expect the answer to cover only part of the data, to be truncated, or to fail. A response size limit in KB or MB is not documented (DA-16, UNVERIFIED): observe and record, do not state a number. | DA-07, DA-16 |

## Side effects to point out

- Defects 2 and 3 also change the request contract: the broken spec describes `assignment` and `siteContact` fields that the API does not accept. If Copilot does send them, the API answers `400 NESTED_VALUE_NOT_SUPPORTED` (for an object value) or `400 MISSING_FIELD` for `crewId`. This is a good prompt for the "read the error body" troubleshooting step in Lab 12.
- The descriptions in the broken file are short and generic on purpose (for example "Sends a crew to an outage."). Compare routing quality against the LLM-oriented descriptions in `openapi.yaml`: this is guidance quality, not a hard limit (DA-14 notes quality may drop as the number of functions grows).

## Fix checklist (answer)

1. Add `operationId: getOutageStatus` to `GET /outage-status`.
2. Replace `assignment` (oneOf) with a flat `crewId` string.
3. Remove `siteContact`, or flatten it into top-level strings (the compliant API uses a single `notes` string).
4. Stop using `/customers`. Use `GET /customer-lookup` with `pageSize` (default 5) and `page`, returning an envelope with `totalMatches` and `results`.
