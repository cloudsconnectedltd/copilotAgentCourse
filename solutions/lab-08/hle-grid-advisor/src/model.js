'use strict';
// Model client. HLE Grid Advisor brings its own model (limits.md CE-01).
//
// MODEL_PROVIDER=azure-openai  Azure OpenAI deployment, or a Microsoft Foundry deployment of an Azure OpenAI
//                              model that exposes the same chat completions endpoint.
// MODEL_PROVIDER=mock          Offline, deterministic, extractive answers built from the retrieved context.
//                              Use it to run the lab before your Azure resources exist, and in tests.
//
// CHECK BEFORE YOU RUN: the REST path, the api-version value and the request body fields below follow the
// Azure OpenAI chat completions REST shape. API versions and accepted fields (for example max_tokens versus
// max_completion_tokens, or whether temperature is accepted) change by model and version. Confirm them for
// your deployment on Microsoft Learn ("Azure OpenAI REST API reference") before the lab.

function createModel(config, fetchImpl = globalThis.fetch) {
  if (config.modelProvider === 'mock') return { name: 'mock', complete: async (_messages, context) => mockComplete(context) };
  if (config.modelProvider !== 'azure-openai') throw new Error(`Unknown MODEL_PROVIDER "${config.modelProvider}". Use azure-openai or mock.`);
  for (const k of ['azureOpenAiEndpoint', 'azureOpenAiDeployment', 'azureOpenAiApiVersion', 'azureOpenAiKey']) {
    if (!config[k]) throw new Error(`Missing setting ${k}. See .env.sample.`);
  }

  async function complete(messages) {
    const endpoint = config.azureOpenAiEndpoint.replace(/\/+$/, '');
    const url = `${endpoint}/openai/deployments/${encodeURIComponent(config.azureOpenAiDeployment)}/chat/completions?api-version=${encodeURIComponent(config.azureOpenAiApiVersion)}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.modelTimeoutMs || 30000);
    try {
      const res = await fetchImpl(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'api-key': config.azureOpenAiKey },
        body: JSON.stringify({ messages }),
        signal: controller.signal,
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        // A content filter block on the deployment arrives as an error: treat it as a refusal, not a crash.
        const code = body && body.error && body.error.code;
        return { text: '', error: `Model call failed (${res.status}${code ? `, ${code}` : ''}).` };
      }
      const choice = body.choices && body.choices[0];
      if (choice && choice.finish_reason === 'content_filter') return { text: '', error: 'Blocked by the deployment content filter.' };
      return { text: (choice && choice.message && choice.message.content) || '' };
    } catch (err) {
      return { text: '', error: `Model call failed: ${err && err.message ? err.message : err}` };
    } finally {
      clearTimeout(timer);
    }
  }

  return { name: 'azure-openai', complete };
}

// Deterministic extractive answer: no generation, only quotes from the context with markers.
function mockComplete(context) {
  const lines = [];
  for (const r of context.api) {
    if (!r.ok) {
      lines.push(`The outage API returned ${r.status || 'no response'} (${r.body.errorCode || 'error'}): ${r.body.message || ''} [API]`);
      continue;
    }
    for (const o of r.body.results || []) {
      const etr = o.status === 'Restored' ? `restored ${o.restoredTime}` : o.estimatedRestorationTime ? `ETR ${o.estimatedRestorationTime}` : 'no ETR published';
      lines.push(`${o.outageId}: ${o.municipality}, ${o.regionName}. ${o.status}, ${o.customersAffected} customers, cause: ${o.cause}, ${etr}, crew ${o.assignedCrewId || 'none'}. [API]`);
    }
    if ((r.body.results || []).length === 0) lines.push(`${r.body.message || 'No matching outages.'} [API]`);
  }
  const top = context.chunks[0];
  if (top) {
    const excerpt = top.text.split(/\n/).filter(Boolean).slice(0, 4).join(' ');
    lines.push(`From section "${top.section}": ${excerpt} [${top.id}]`);
  }
  return { text: lines.length ? lines.join('\n') : 'NO_ANSWER' };
}

module.exports = { createModel, mockComplete };
