# Lab 8 solutions

| Path | What it is | How to use it |
|---|---|---|
| `hle-grid-advisor/` | Main path. Microsoft 365 Agents SDK (JavaScript) custom engine agent **HLE Grid Advisor**: local retrieval over the Outage Response Procedure, mock API tool, Azure OpenAI or Foundry model through environment variables, and its own responsible AI controls. | See `hle-grid-advisor/README.md`. Run locally with `npm install`, `npm test`, `npm start`, `npm run playground`; deploy per Lab 8 Part B. |
| `hle-grid-advisor/appPackage/manifest.json` | Sample app manifest (1.21) declaring the bot as a custom engine agent. | Compare with your Agents Toolkit template; add icons; zip `manifest.json`, `color.png`, `outline.png` for upload. |
| `studio-extension-instructions.txt` | Instructions text for the optional Copilot Studio extension (Lab 8 Part D) that uses a Foundry model. | Paste into the agent's Instructions field in Copilot Studio. |

No exported Copilot Studio solution zip is provided. If you build the Part D agent, export it from Copilot Studio (Solutions > your solution > Export) if you want to keep it; Lab 11 covers solution export.

## Checked and unchecked items

| Item | Status |
|---|---|
| npm package names `@microsoft/agents-hosting`, `@microsoft/agents-hosting-express` 1.9.1; `AgentApplication`, `MemoryStorage`, `onActivity`, `onConversationUpdate`, `startServer(agent, { beforeListen })`, env settings `clientId`, `clientSecret`, `tenantId` | Checked against the npm package type definitions on 2026-09-30. Not found in the Learn source available to the authors: UNVERIFIED against Learn. |
| Local run: `POST /api/messages` with no bot identity answered a message end to end (SDK 1.9.1, Node 22, mock model, mock API) | Tested by the course authors on 2026-09-30. |
| `@microsoft/m365agentsplayground` CLI options `-e` and `-c` | Checked with `agentsplayground --help` (0.2.28). |
| Azure OpenAI REST path, `api-version`, request body fields | CHECK on Learn for your deployment. |
| App manifest `copilotAgents.customEngineAgents` shape | Minimum manifest version 1.21 is stated on the Learn custom engine agent overview. Property shape: compare with your Agents Toolkit template. |
