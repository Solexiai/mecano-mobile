'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const { validateWebEnvironment } = require('../../scripts/validate_web_environment.cjs');
const valid = 'AIza' + 'FakeNotARealKey_'.repeat(3);

test('optional absent key preserves fail-closed build configuration', () => {
  assert.deepEqual(validateWebEnvironment({}), { mapsConfigured: false });
  assert.deepEqual(validateWebEnvironment({ GOOGLE_MAPS_API_KEY: '' }), { mapsConfigured: false });
});
test('existing restricted key shape is accepted without mutation', () => {
  const config = Object.freeze({ GOOGLE_MAPS_API_KEY: valid });
  assert.equal(validateWebEnvironment(config).mapsConfigured, true);
  assert.equal(config.GOOGLE_MAPS_API_KEY, valid);
});
test('redacted exports and malformed values fail without disclosing the value', () => {
  for (const value of ['[REDACTED]', '********', valid + '\n', ' ' + valid, 'AIza!', 123]) {
    assert.throws(() => validateWebEnvironment({ GOOGLE_MAPS_API_KEY: value }),
      error => error.message.includes('malformed or redacted') && !error.message.includes(String(value)));
  }
});
test('CLI refuses a placeholder and logs no credential', () => {
  const value = '[masked-local-export]';
  const result = cp.spawnSync(process.execPath, ['scripts/validate_web_environment.cjs'], {
    cwd: path.resolve(__dirname, '../..'), encoding: 'utf8',
    env: { ...process.env, GOOGLE_MAPS_API_KEY: value },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /malformed or redacted/);
  assert.ok(!(result.stdout + result.stderr).includes(value));
});
test('Vercel validates configuration before SDK setup or Flutter compilation', () => {
  const script = fs.readFileSync(path.resolve(__dirname, '../../scripts/vercel_build.sh'), 'utf8');
  const guard = script.indexOf('validate_web_environment.cjs');
  assert.ok(guard > script.indexOf('set -euo pipefail'));
  assert.ok(guard < script.indexOf('git clone'));
  assert.ok(guard < script.lastIndexOf('build web --release'));
});
