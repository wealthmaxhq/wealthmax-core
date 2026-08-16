const { spawnSync } = require('node:child_process');
const path = require('node:path');
const tiers = require('../test-tiers.json');

const tier = process.argv[2];
if (!Object.hasOwn(tiers, tier)) {
  console.error(`Unknown backend test tier: ${tier || '(missing)'}`);
  process.exit(1);
}

const verification = spawnSync(process.execPath, [path.join(__dirname, 'verify-test-tiers.js')], {
  stdio: 'inherit',
});
if (verification.status !== 0) process.exit(verification.status ?? 1);

const jest = require.resolve('jest/bin/jest');
const result = spawnSync(process.execPath, [jest, '--runInBand', '--runTestsByPath', ...tiers[tier]], {
  cwd: path.resolve(__dirname, '..'),
  stdio: 'inherit',
});
process.exit(result.status ?? 1);
