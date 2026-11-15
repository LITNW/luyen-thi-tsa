import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('legacy visible brand labels use LIT while TSA exam references remain contextual', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(html, /LIT · PHÒNG THI/);
  assert.match(html, /LIT PRACTICE PLATFORM|LIT · LEARN · PRACTICE · GROW/);
  assert.match(html, /<div class="hero-core">LIT<\/div>/);
  assert.doesNotMatch(html, /TSA PRACTICE · PHÒNG THI/);
  assert.doesNotMatch(html, /<b>TSA Practice<\/b>/);
  assert.doesNotMatch(html, /TSA PRACTICE PLATFORM/);
});
