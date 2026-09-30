'use strict';
// Local retrieval over the extracted Outage Response Procedure (OPS-PRO-001 Rev 7).
//
// A custom engine agent has no Copilot orchestrator and no SharePoint grounding (limits.md CE-01),
// so HLE Grid Advisor owns retrieval. This is deliberately simple: the procedure is split into
// sections on "## " headings and scored with BM25 over lower-cased word tokens. It is enough for one
// five-page procedure. For more documents, replace it with a vector index (for example Azure AI Search).

const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_SOURCE = path.join(__dirname, '..', 'data', 'outage-response-procedure.md');
const SOURCE_TITLE = 'Outage Response Procedure (OPS-PRO-001 Rev 7)';
const SOURCE_PATH = 'Harbourline-Operations/Procedures/Outage-Response-Procedure.docx';

const STOPWORDS = new Set(('a an and are as at be by can do does for from has have how i in is it its me my of on or our ' +
  'should so than that the their then there these this to was we what when where which who why will with within you your').split(' '));

// Small domain synonym list so that everyday wording reaches the procedure's terms.
const SYNONYMS = {
  etr: ['estimated', 'restoration'],
  severity: ['level'],
  level: ['severity'],
  notify: ['notification'],
  notified: ['notification'],
  tell: ['notification'],
  call: ['notification', 'contact'],
  order: ['priority', 'sequence'],
  first: ['priority', 'step'],
  who: ['role', 'responsibility'],
  hospital: ['critical', 'facility'],
  regulator: ['regulatory'],
  oeb: ['regulatory'],
  close: ['closed', 'closure'],
  lower: ['de', 'escalation'],
  downgrade: ['de', 'escalation'],
  revision: ['revision', 'change'],
};

function stem(word) {
  if (word.length > 5 && word.endsWith('ies')) return word.slice(0, -3) + 'y';
  if (word.length > 5 && word.endsWith('ing')) return word.slice(0, -3);
  if (word.length > 4 && word.endsWith('ed')) return word.slice(0, -2);
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) return word.slice(0, -1);
  return word;
}

function tokenize(text) {
  const words = String(text).toLowerCase().match(/[a-z0-9]+/g) || [];
  return words.filter((w) => !STOPWORDS.has(w)).map(stem);
}

function expandQuery(tokens) {
  const out = [...tokens];
  for (const t of tokens) for (const s of SYNONYMS[t] || []) out.push(stem(s));
  return out;
}

function parseSections(markdown) {
  const lines = markdown.split(/\r?\n/).filter((l) => !l.startsWith('<!--'));
  const sections = [];
  let current = { section: 'Document control', lines: [] };
  for (const line of lines) {
    if (line.startsWith('## ')) {
      if (current.lines.join('').trim()) sections.push(current);
      current = { section: line.slice(3).trim(), lines: [] };
    } else {
      current.lines.push(line);
    }
  }
  if (current.lines.join('').trim()) sections.push(current);
  return sections.map((s, i) => ({
    id: `P${i + 1}`,
    section: s.section,
    text: s.lines.join('\n').trim(),
    source: SOURCE_TITLE,
    sourcePath: SOURCE_PATH,
  }));
}

function createRetriever(options = {}) {
  const markdown = options.markdown ?? fs.readFileSync(options.sourcePath || DEFAULT_SOURCE, 'utf8');
  const chunks = parseSections(markdown);
  const docs = chunks.map((c) => tokenize(`${c.section} ${c.section} ${c.text}`));
  const avgLen = docs.reduce((s, d) => s + d.length, 0) / Math.max(docs.length, 1);
  const df = new Map();
  for (const d of docs) for (const t of new Set(d)) df.set(t, (df.get(t) || 0) + 1);
  const k1 = 1.2;
  const b = 0.75;

  function search(query, { top = 3, minScore = options.minScore ?? 2.5 } = {}) {
    const q = expandQuery(tokenize(query));
    const scored = chunks.map((chunk, i) => {
      const d = docs[i];
      const tf = new Map();
      for (const t of d) tf.set(t, (tf.get(t) || 0) + 1);
      let score = 0;
      for (const t of new Set(q)) {
        const f = tf.get(t);
        if (!f) continue;
        const idf = Math.log(1 + (chunks.length - df.get(t) + 0.5) / (df.get(t) + 0.5));
        score += idf * ((f * (k1 + 1)) / (f + k1 * (1 - b + (b * d.length) / avgLen)));
      }
      return { ...chunk, score: Math.round(score * 100) / 100 };
    });
    return scored.filter((c) => c.score >= minScore).sort((x, y) => y.score - x.score).slice(0, top);
  }

  return { search, chunks };
}

module.exports = { createRetriever, tokenize, parseSections, SOURCE_TITLE, SOURCE_PATH };
