# Challenge 01: Procurement Desk

| | |
|---|---|
| Format | Objectives only. No steps, no hints. |
| Time box | 1 working day (about 6 hours) |
| Prerequisites | Setup scripts 01 to 03 have run. Labs 1 to 5 completed or equivalent experience. |
| Build path | Your decision |

This challenge works like a real engagement: you get a request from the business, the access you would normally have, and a deadline. Choosing the build path, finding the data, discovering the limits and proving the result are all part of the work.

Do not open `solutions/challenge-01/` or `evals/challenge-01-questions.csv` until you have submitted. They hold the acceptance tests and the marking guide.

---

## The request

> **From:** Ingrid Solberg, Director, Procurement
> **To:** Microsoft 365 team
> **Subject:** Procurement Desk agent
>
> My team answers the same questions all day: who has to approve a purchase, whether we can use a given vendor, what the card rules are. People also send purchase requests by email with half the information missing, and we spend days chasing them.
>
> I want an assistant that staff across Ontario, New York and Ohio can use from Teams and Copilot. It has to give the right answer, not a plausible one. Finance has been burned before by people quoting an out-of-date approval limit, and an auditor will look at this.
>
> Some of our buyers, Tom Whitfield for example, don't have Copilot licenses. They need it as much as anyone.
>
> Sofia Brennan in Finance will be my main tester. Please have something we can try by end of day, and tell me honestly what it can't do.

## Objectives

1. Staff can ask who must approve a purchase of a given category, amount and region, and get the current answer with the source shown.
2. Staff can ask about any vendor in the vendor register (contact, status, contract value, renewal date, risk) and get a correct answer for every vendor in it.
3. The agent warns before encouraging the use of a vendor that is suspended, expired or high risk.
4. Staff can ask about expense, travel and corporate card rules and get answers grounded in Finance policy.
5. Staff can submit a purchase request through the agent. The request is complete (the agent collects whatever Procurement needs to act on it), the requester is told who must approve it, and Procurement receives it without anyone re-typing it.
6. Staff without a Microsoft 365 Copilot license can use the agent.
7. The agent stays within its remit. It does not answer HR or compensation questions, and it never reveals content the person asking could not open themselves.
8. Procurement can maintain the agent without you: they can see who uses it, and changes to Finance documents flow through without a rebuild.

## What you have

- The Harbourline tenant created by the setup scripts, with the Hub and Operations sites and everything in them.
- The persona accounts: Sofia Brennan (Finance), Tom Whitfield (no Copilot license), Priya Nandakumar (HR) and Marcus Delaney (field technician).
- Your own admin account and whatever Microsoft 365 and Power Platform tools your licenses allow.

Nobody will tell you where the data lives or which documents are authoritative. Find out.

## Deliverables

Put these in a folder of your own (for example `my-work/challenge-01/`, which you create).

1. **The working agent**, available to Sofia and Tom in Teams.
2. **A design note** of no more than two pages:
   - the build path you chose and why, including what you ruled out
   - each knowledge source and tool, and why you trust it
   - authentication, and what each persona can and cannot see
   - licensing and cost for unlicensed users
   - known limitations, in plain language Ingrid would understand
3. **Your own test plan and results**: the questions you asked, as which persona, the expected answer and source, and pass or fail.

## How it will be assessed

After you submit, run the acceptance tests in `evals/challenge-01-questions.csv` against your agent as the personas listed, then compare your design note with `solutions/challenge-01/marking-guide.md`.

| Area | Weight |
|---|---|
| Acceptance tests passed | 40% |
| Design note: correct reasoning about build path, limits, licensing and security | 30% |
| Your own test plan: did you find the problems before the acceptance tests did? | 20% |
| Honesty about limitations | 10% |
