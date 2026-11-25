import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('education and admin education pages rely on the shared LIT shell wordmark', () => {
  const shell = readFileSync(new URL('../src/components/AppShell.jsx', import.meta.url), 'utf8');
  assert.match(shell, /\/brand\/lit-horizontal\.svg/);
  for (const path of ['../src/pages/AdminEducationPage.jsx', '../src/pages/EducationBrowsePages.jsx']) {
    const source = readFileSync(new URL(path, import.meta.url), 'utf8');
    assert.doesNotMatch(source, /TSA Practice/);
    assert.doesNotMatch(source, /topbar|top-links/);
  }
});
