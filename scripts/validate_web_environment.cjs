'use strict';
const fs = require('node:fs');

function validateWebEnvironment(values) {
  const key = values.GOOGLE_MAPS_API_KEY ?? '';
  // Preserve optional fail-closed mode; reject redacted or malformed exports.
  if (key !== '' && (typeof key !== 'string' || !/^AIza[A-Za-z0-9_-]{30,}$/.test(key))) {
    throw new Error('GOOGLE_MAPS_API_KEY is malformed or redacted. Supply the existing restricted browser key; its value must not be logged.');
  }
  return { mapsConfigured: key !== '' };
}

if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    let values = process.env;
    if (args.length) {
      if (args.length !== 2 || args[0] !== '--dart-defines') {
        throw new Error('Usage: node scripts/validate_web_environment.cjs [--dart-defines <local JSON file>]');
      }
      values = JSON.parse(fs.readFileSync(args[1], 'utf8'));
    }
    const result = validateWebEnvironment(values);
    console.log('Web environment validated. Places key configured: ' + result.mapsConfigured + ' (value hidden).');
  } catch (error) {
    console.error(error instanceof SyntaxError ? 'Invalid local build configuration JSON.' : error.message);
    process.exitCode = 1;
  }
}
module.exports = { validateWebEnvironment };
