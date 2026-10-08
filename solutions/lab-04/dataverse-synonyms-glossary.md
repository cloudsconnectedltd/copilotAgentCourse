# Lab 04 Dataverse knowledge: synonyms and glossary

Source of truth: [data/dataverse/schema.md](../../data/dataverse/schema.md) section 6. Copied here in the order you enter them. Glossary and synonym changes can take up to 15 minutes to apply (CS-K11).

## Column synonyms (enter in step 8)

| Table | Column | Synonyms |
|---|---|---|
| Work Order | Work Order Number | WO, WO number, job number (do NOT add "ticket number" yet: break-it C-04-d adds it) |
| Work Order | Assigned Crew | crew, team, gang |
| Work Order | Priority | urgency, severity |
| Work Order | Opened On | raised, created, logged |
| Work Order | Due Date | deadline, target date |
| Work Order | Estimated Cost | cost, budget, estimate |
| Asset | Asset Number | asset ID, equipment ID, tag |
| Asset | Condition Score | health score, condition, health index |
| Asset | Install Year | installed, in-service year, age (derived) |
| Asset | Site | station, substation, location |
| Crew | Crew Lead | foreman, supervisor, crew chief |
| Crew | Certifications | tickets, qualifications, training |

Note: schema.md lists "tickets" as a Certifications synonym as well. Leave it in; C-04-d shows why both uses of "ticket" collide with the Lab 7 ticket system.

## Glossary (enter in step 10, then note the time)

| Term | Definition |
|---|---|
| TX | Transformer. Asset IDs that start with TX are transformers. |
| WO | Work order, a row in the Work Order table. |
| SW | Switch. |
| BRK | Circuit breaker. |
| RCL | Recloser, an automatic breaker on a distribution line. |
| REG | Voltage regulator. |
| OH | Overhead (as in "OH line"). Only in an asset ID (for example SW-OH-30110) does OH mean the Ohio region. |
| ON, NY | Region codes in asset and crew IDs: Ontario, New York. |
| ROW | Right of way, the cleared corridor around a power line. |
| LOTO | Lockout/tagout, the isolation procedure required before work. |
| DGA | Dissolved gas analysis, an oil test that detects transformer faults. |
| Open work order | A work order with Status New, Scheduled, In Progress or On Hold. |
| Overdue | An open work order whose Due Date is before today. |
| Poor condition | An asset with Condition Score below 30. |
| Mutual assistance | A crew from one region working on another region's assets, usually after a storm. |
