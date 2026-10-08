'use strict';
// Reads settings from environment variables. Copy .env.sample to .env and edit it.
// The Agents SDK reads its own bot identity settings (clientId, clientSecret, tenantId) from the same
// environment; they are not handled here.

function loadConfig(env = process.env) {
  return {
    modelProvider: (env.MODEL_PROVIDER || 'mock').toLowerCase(),
    azureOpenAiEndpoint: env.AZURE_OPENAI_ENDPOINT || '',
    azureOpenAiDeployment: env.AZURE_OPENAI_DEPLOYMENT || '',
    azureOpenAiApiVersion: env.AZURE_OPENAI_API_VERSION || '',
    azureOpenAiKey: env.AZURE_OPENAI_API_KEY || '',
    modelTimeoutMs: Number(env.MODEL_TIMEOUT_MS || 30000),
    apiBaseUrl: env.HLE_API_BASE_URL || 'http://localhost:7071/api',
    apiKey: env.HLE_API_KEY || '',
    apiTimeoutMs: Number(env.HLE_API_TIMEOUT_MS || 10000),
    raiFilters: (env.RAI_FILTERS || 'on').toLowerCase(),
    retrievalMinScore: env.RETRIEVAL_MIN_SCORE ? Number(env.RETRIEVAL_MIN_SCORE) : undefined,
  };
}

module.exports = { loadConfig };
