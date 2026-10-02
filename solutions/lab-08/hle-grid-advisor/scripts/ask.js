'use strict';
// Command-line test of the engine without the Agents SDK or a channel:
//   npm run ask -- "What is the status of OUT-2026-0412?"
const { loadConfig } = require('../src/config');
const { createAdvisor } = require('../src/advisor');

const question = process.argv.slice(2).join(' ');
if (!question) {
  console.error('Usage: npm run ask -- "<question>"');
  process.exit(1);
}
createAdvisor(loadConfig()).answer(question).then((r) => {
  console.log(`[${r.category}]`);
  console.log(r.text);
});
