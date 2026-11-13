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


test('legacy Admin editor loads categories and saves through the category-aware RPC', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(html, /list_active_exam_categories/);
  assert.match(html, /id="f-category"/);
  assert.match(html, /admin_save_exam_content_with_category/);
  assert.match(html, /p_category_id:categoryId/);
  assert.match(html, /category_id:currentCategory\?\.category_id\|\|null/);
  assert.match(html, /category_id:categoryId/);
  assert.match(html, /const categoryId=selectedCategory\|\|null/);
});

test('legacy editor preserves uncategorized and archived category assignments until explicitly changed', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(html, /category_id:currentCategory\?\.category_id\|\|null/);
  assert.match(html, /Không phân loại/);
  assert.match(html, /Danh mục đã ẩn/);
  assert.match(html, /giữ nguyên/);
});
