import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

test('legacy exam application inline JavaScript remains syntactically valid', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
    .filter((match) => !/\btype\s*=\s*["']application\/json["']/i.test(match[1]))
    .map((match) => match[2].trim())
    .filter(Boolean);
  assert.ok(scripts.length > 0, 'expected at least one inline JavaScript script');
  for (const [index, source] of scripts.entries()) {
    assert.doesNotThrow(() => new vm.Script(source), 'inline script ' + (index + 1) + ' must parse');
  }
});

test('legacy HTML document has one closing tag and no leaked source after it', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  const closingTags = [...html.matchAll(/<\\/html\\s*>/gi)];
  assert.equal(closingTags.length, 1, 'legacy document must close exactly once');
  const closingTag = closingTags[0];
  const documentEnd = closingTag.index + closingTag[0].length;
  assert.equal(html.slice(documentEnd).trim(), '', 'no source or markup may appear after </html>');
  const scriptOpenCount = [...html.matchAll(/<script\\b/gi)].length;
  const scriptCloseCount = [...html.matchAll(/<\\/script\\s*>/gi)].length;
  assert.equal(scriptCloseCount, scriptOpenCount, 'script elements must be balanced');
});
