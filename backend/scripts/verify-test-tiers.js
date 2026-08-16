const fs = require('node:fs');
const path = require('node:path');
const tiers = require('../test-tiers.json');

const root = path.resolve(__dirname, '..');
const discovered = fs.readdirSync(path.join(root, 'tests'))
  .filter((name) => name.endsWith('.test.ts'))
  .map((name) => `tests/${name}`)
  .sort();
const assigned = Object.values(tiers).flat().sort();
const duplicates = assigned.filter((file, index) => assigned.indexOf(file) !== index);
const missing = discovered.filter((file) => !assigned.includes(file));
const stale = assigned.filter((file) => !discovered.includes(file));

if (duplicates.length || missing.length || stale.length) {
  if (duplicates.length) console.error(`Tests assigned more than once: ${[...new Set(duplicates)].join(', ')}`);
  if (missing.length) console.error(`Tests missing a tier: ${missing.join(', ')}`);
  if (stale.length) console.error(`Tier entries without a test file: ${stale.join(', ')}`);
  process.exit(1);
}

console.log(`Verified ${discovered.length} backend test files across ${Object.keys(tiers).length} tiers.`);
