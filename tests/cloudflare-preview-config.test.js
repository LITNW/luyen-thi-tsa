import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('Cloudflare Worker preview config matches the existing static-assets Worker and enables previews', () => {
  const config = JSON.parse(readFileSync(new URL('../wrangler.json', import.meta.url), 'utf8'));
  assert.equal(config.name, 'luyen-thi-tsa');
  assert.equal(config.compatibility_date, '2026-11-13');
  assert.deepEqual(config.assets, {
    directory: './dist',
    not_found_handling: 'single-page-application',
  });
  assert.deepEqual(config.previews, {});
});
