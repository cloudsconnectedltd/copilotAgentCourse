# Routing descriptions for HLE Front Door

The parent chooses a specialist from its name and description (C-10-a). Section 1 is the working set. Section 2 is the deliberately vague set for the break-it exercise.

Where to put them:

| Agent | Kind | Where the description lives |
|---|---|---|
| HLE HR Assistant | Connected | The agent's own description (Overview or Settings), then publish. The parent shows it on its Agents page; edit it there too if your UI allows. |
| HLE Field Ops Assistant | Connected | Same as above |
| HLE Policy Router | Child | The child agent's "when to use" description inside HLE Front Door |

## 1. Precise descriptions (use these)

### HLE HR Assistant

```text
Answers Harbourline Energy Co. HR policy questions from the HR-Policies library: annual leave and carry-over, bereavement, parental leave, FMLA (US), overtime, on-call and storm call-out pay, remote work, code of conduct, harassment prevention, performance reviews, accommodation, grievances and safety incident reporting. Does not answer expense limits, per diems, hotel caps or approval authority (use HLE Policy Router), or assets, work orders, crews and outages (use HLE Field Ops Assistant).
```

### HLE Policy Router

```text
Answers Harbourline Energy Co. finance and spending policy questions: expense claims, per diems and meal limits, receipts, hotel caps, mileage rates, corporate cards, submission deadlines, approval authority and the approval matrix, and capital project approval. Owns hotel caps and mileage even though the Travel Policy also lists them, because the Expense Policy HLE-FIN-101 governs money. Does not answer HR pay rules such as on-call stipends or overtime rates (use HLE HR Assistant), or field operations (use HLE Field Ops Assistant).
```

### HLE Field Ops Assistant

```text
Answers Harbourline Energy Co. field operations questions from Dataverse and the outage system: assets (poles, transformers, switches, breakers, reclosers, regulators) by asset ID such as TX-ON-10423, condition scores and install years; work orders by number such as WO-2026-01043, priority, status and due dates; crews by code such as CREW-ON-03, their leads, depots and certifications; and live outage status by outage ID such as OUT-2026-0412. Does not answer HR or finance policy questions.
```

Descriptions stay well under the 1,000-character description limits documented for Agent Builder (AB-02) and declarative agents (DA-03). A description limit for Copilot Studio agents was not found; check Learn if you write longer ones.

## 2. Vague descriptions (break-it only, C-10-a)

| Agent | Vague description |
|---|---|
| HLE HR Assistant | `Helps employees with questions.` |
| HLE Policy Router | `Answers questions about company policies and money.` |
| HLE Field Ops Assistant | `Operations assistant.` |

Why each is bad:

- "Helps employees with questions" matches everything, so it competes with every other specialist.
- "policies and money" pulls in the on-call stipend (an HR pay rule) and claims all "policies", including HR policies.
- "Operations assistant" gives no entities (asset, work order, crew, outage) and no ID patterns, so "Which crews are based at Kingston Service Centre?" has nothing to match.

## 3. Overlaps to resolve explicitly

| Topic | Appears in | Governing source | Route to |
|---|---|---|---|
| Hotel caps (Toronto CAD 275, other Ontario CAD 200, New York City USD 350, other US USD 225) | Expense-Policy.docx 4 and Travel-Policy.docx 4.3 | Expense Policy HLE-FIN-101 | HLE Policy Router |
| Mileage (Ontario CAD 0.72/km, NY and OH USD 0.70/mile) | Expense-Policy.docx 5.2 and Travel-Policy.docx 4.4 | Expense Policy HLE-FIN-101 | HLE Policy Router |
| On-call stipend (CAD 300 / USD 250 per week) | Overtime-and-On-Call.docx 4.2 | Overtime policy HR-POL-038 | HLE HR Assistant |
| Storm Level 3 effects on leave | Leave policy 5.1, Overtime policy 4.3 | HR policies | HLE HR Assistant |
| "Ticket" (work order number synonym in Lab 4 vs Lab 7 ticket system) | Dataverse synonyms, HLE Tickets connector | Depends on the ID format | HLE Field Ops Assistant for WO- numbers |
