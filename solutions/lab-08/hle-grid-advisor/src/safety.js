'use strict';
// Responsible AI controls owned by HLE Grid Advisor.
//
// A custom engine agent brings its own model and orchestration (limits.md CE-01), so the filtering,
// citation and refusal behavior that Copilot applies to declarative agents is the builder's job here.
// These rules are intentionally small and readable for the lab. They are a first layer, not a complete
// safety system: in production also enable the content filters on your Azure OpenAI or Foundry
// deployment and review them with your responsible AI process.

const MAX_INPUT_CHARS = 1000;
// Canary string placed in the system prompt. If it ever appears in model output, the prompt leaked.
const CANARY = 'HLE-GRID-ADVISOR-CANARY-7Q2';

const NO_ANSWER = 'I could not find that in my sources (the Outage Response Procedure OPS-PRO-001 and the Harbourline outage API), so I will not guess. For other procedures, check the Procedures library or ask HLE Outage Desk.';

const REFUSALS = {
  too_long: `Please shorten your question to under ${MAX_INPUT_CHARS} characters.`,
  injection: 'I cannot change my instructions or reveal them. I can answer questions about Harbourline outages and the Outage Response Procedure.',
  unsafe_work: 'I cannot help with bypassing lockout, tagout, grounding or other safety controls. Follow SAF-MAN-002 Lockout and Tagout Safety Manual and contact your supervisor or the Distribution System Operator.',
  customer_pii: 'I do not provide customer personal or account details. Customer account questions go through the contact centre process, not HLE Grid Advisor.',
  out_of_scope: 'I only answer questions about Harbourline outages and the Outage Response Procedure. For HR, finance or policy questions, use HLE HR Assistant or HLE Policy Helper.',
};

const INJECTION_PATTERNS = [
  /\bignore\b.{0,40}\b(instructions|rules|prompt)\b/i,
  /\b(reveal|print|show|repeat|output)\b.{0,30}\b(system prompt|your (instructions|prompt|rules))\b/i,
  /\bsystem prompt\b/i,
  /\byou are now\b/i,
  /\b(developer|dan|jailbreak) mode\b/i,
  /\bpretend (you are|to be)\b/i,
];

const UNSAFE_WORK_PATTERNS = [
  /\b(bypass|defeat|skip|override|remove|cut|get around)\b.{0,40}\b(lockout|lock-out|tagout|loto|locks?|grounds?|grounding|interlocks?|permits?|test-before-touch)\b/i,
  /\bwork(ing)?\b.{0,20}\b(hot|live|energi[sz]ed)\b.{0,40}\bwithout\b/i,
];

const PII_TARGET = /\b(customer|customers|account holder|resident|jane okafor|okafor|tremblay|castellanos|albescu)\b/i;
const PII_FIELD = /\b(home address|address|phone|email|balance|account number|date of birth|medical)\b/i;
const HLE_ACCOUNT = /\bHLE-ACC-\d{6}\b/i;

const HR_FIN_SCOPE = /\b(annual leave|vacation|carry-over|carryover|payroll|salary|expense|benefits?|harassment|parental leave)\b/i;

function checkInput(text) {
  const q = String(text || '').trim();
  if (!q) return { allowed: false, category: 'out_of_scope', message: REFUSALS.out_of_scope };
  if (q.length > MAX_INPUT_CHARS) return { allowed: false, category: 'too_long', message: REFUSALS.too_long };
  if (INJECTION_PATTERNS.some((re) => re.test(q))) return { allowed: false, category: 'injection', message: REFUSALS.injection };
  if (UNSAFE_WORK_PATTERNS.some((re) => re.test(q))) return { allowed: false, category: 'unsafe_work', message: REFUSALS.unsafe_work };
  if (HLE_ACCOUNT.test(q) || (PII_TARGET.test(q) && PII_FIELD.test(q))) {
    return { allowed: false, category: 'customer_pii', message: REFUSALS.customer_pii };
  }
  if (HR_FIN_SCOPE.test(q)) return { allowed: false, category: 'out_of_scope', message: REFUSALS.out_of_scope };
  return { allowed: true, category: 'ok' };
}

function redact(text) {
  return String(text)
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[redacted email]')
    .replace(/\bHLE-ACC-\d{6}\b/gi, '[redacted account]')
    .replace(/(\+?1[\s.-]?)?\(?\b\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}\b/g, '[redacted phone]');
}

// Validates model output: canary leak, PII redaction, and citation enforcement.
// allowedIds: the citation markers that were actually given to the model this turn (P1..Pn, API).
function checkOutput(text, allowedIds) {
  const raw = String(text || '').trim();
  if (!raw) return { text: NO_ANSWER, cited: [], category: 'no_answer' };
  if (raw.includes(CANARY)) return { text: REFUSALS.injection, cited: [], category: 'injection' };
  if (raw.startsWith('NO_ANSWER')) return { text: NO_ANSWER, cited: [], category: 'no_answer' };

  const cited = [...new Set((raw.match(/\[(P\d+|API)\]/g) || []).map((m) => m.slice(1, -1)))];
  const valid = cited.filter((id) => allowedIds.includes(id));
  if (valid.length === 0) {
    // Ungrounded or cites sources it was never given: do not show it.
    return { text: NO_ANSWER, cited: [], category: 'no_answer' };
  }
  let clean = raw;
  for (const id of cited) if (!valid.includes(id)) clean = clean.split(`[${id}]`).join('');
  return { text: redact(clean), cited: valid, category: 'answer' };
}

module.exports = { checkInput, checkOutput, redact, CANARY, NO_ANSWER, REFUSALS, MAX_INPUT_CHARS };
