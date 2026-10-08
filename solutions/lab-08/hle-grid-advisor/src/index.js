'use strict';
// HLE Grid Advisor: Microsoft 365 Agents SDK host (JavaScript, CommonJS).
//
// CHECK THE CURRENT SDK API BEFORE YOU RUN. The package names and calls below were checked against the
// published npm packages @microsoft/agents-hosting and @microsoft/agents-hosting-express version 1.9.1
// (type definitions) on 2026-09-30. They were NOT found in the Microsoft Learn source available to the
// course authors, so treat them as UNVERIFIED against Learn. If your Agents Toolkit template generates a
// different entry point, keep the template's host code and call advisor.answer() from its message handler.

const { AgentApplication, MemoryStorage } = require('@microsoft/agents-hosting'); // CHECK: exports
const { startServer } = require('@microsoft/agents-hosting-express'); // CHECK: startServer(agent, options)
const { loadConfig } = require('./config');
const { createAdvisor } = require('./advisor');

const config = loadConfig();
const advisor = createAdvisor(config);

const WELCOME = 'Hi, I am HLE Grid Advisor. Ask me about a current outage (for example "What is the status of OUT-2026-0412?") ' +
  'or about the Outage Response Procedure (for example "Who must be notified at L3, and how fast?"). I cite my sources and I will say so when I do not know.';

// CHECK: AgentApplication options. storage keeps conversation state in memory (lost on restart).
const app = new AgentApplication({ storage: new MemoryStorage(), startTypingTimer: true });

// CHECK: onConversationUpdate event name and activity shape.
app.onConversationUpdate('membersAdded', async (context) => {
  for (const member of context.activity.membersAdded || []) {
    if (member.id !== context.activity.recipient.id) await context.sendActivity(WELCOME);
  }
});

// CHECK: onActivity('message', handler) route registration.
app.onActivity('message', async (context) => {
  const text = context.activity.text || '';
  const result = await advisor.answer(text);
  console.log(JSON.stringify({ at: new Date().toISOString(), category: result.category, cited: result.cited }));
  await context.sendActivity(result.text);
});

// SSO (Lab 8 Part C) is configured through Agents Toolkit, which adds the Entra app, the Azure Bot Service
// OAuth connection and the manifest settings. If you need the signed-in user's token in code, the SDK exposes
// app.authorization.getToken(context, '<handler id>') when AgentApplication is created with an
// `authorization` option. CHECK the current option shape on Learn before adding it.

// CHECK: startServer reads clientId, clientSecret and tenantId from the environment, listens on PORT or 3978,
// and serves POST /api/messages. With no clientId and NODE_ENV not "production", it accepts unauthenticated
// local traffic (Agents Playground). Never deploy that way.
startServer(app, {
  beforeListen: (server) => {
    server.get('/health', (_req, res) => res.json({ status: 'ok', agent: 'HLE Grid Advisor', model: config.modelProvider, raiFilters: config.raiFilters }));
  },
});
