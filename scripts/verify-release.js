const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const readJson = (file) => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const versions = new Map([
  ['root package', readJson('package.json').version],
  ['backend package', readJson('backend/package.json').version],
  ['frontend package', readJson('frontend/package.json').version],
]);
const pubspec = fs.readFileSync(path.join(root, 'pubspec.yaml'), 'utf8');
const dartVersion = pubspec.match(/^version:\s*(\S+)\s*$/m)?.[1];
if (!dartVersion) throw new Error('pubspec.yaml must declare a version.');
versions.set('Dart package', dartVersion);

const expected = process.argv[2]?.replace(/^v/, '') ?? [...versions.values()][0];
if (!/^\d+\.\d+\.\d+$/.test(expected)) {
  throw new Error(`Release version must use semantic versioning (received ${expected}).`);
}
for (const [name, version] of versions) {
  if (version !== expected) throw new Error(`${name} is ${version}; expected ${expected}.`);
}
const changelog = fs.readFileSync(path.join(root, 'CHANGELOG.md'), 'utf8');
if (!new RegExp(`^## ${expected.replace(/\./g, '\\.')}\\b`, 'm').test(changelog)) {
  throw new Error(`CHANGELOG.md has no ${expected} release section.`);
}
console.log(`Verified WealthMax release metadata for v${expected}.`);
