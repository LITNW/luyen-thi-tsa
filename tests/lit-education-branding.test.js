import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('education and admin education layouts use the LIT horizontal wordmark', () => {
  for (const path of ['../src/pages/AdminEducationPage.jsx', '../src/pages/EducationBrowsePages.jsx']) {
    const source = readFileSync(new URL(path, import.meta.url), 'utf8');
    assert.match(source, /\/brand\/lit-horizontal\.svg/);
    assert.doesNotMatch(source, /TSA Practice/);
  }
});
