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

test('legacy Admin editor loads education placement and optional categories before atomic save', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(html, /list_active_exam_categories/);
  assert.match(html, /id="f-category"/);
  assert.match(html, /loadEditorEducationSubjects/);
  assert.match(html, /id="f-education-subject"/);
  assert.match(html, /admin_save_exam_content_with_education/);
  assert.match(html, /p_education_subject_id:educationSubjectId/);
  assert.match(html, /p_category_id:categoryId/);
  assert.match(html, /category_id:currentCategory\?\.category_id\|\|null/);
  assert.match(html, /category_id:categoryId/);
  assert.match(html, /education_subject_id:educationSubjectId/);
  assert.match(html, /const categoryId=selectedCategory\|\|null/);
});

test('legacy editor preserves uncategorized and archived category assignments until explicitly changed', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(html, /category_id:currentCategory\?\.category_id\|\|null/);
  assert.match(html, /Không phân loại/);
  assert.match(html, /Danh mục đã ẩn/);
  assert.match(html, /giữ nguyên/);
});

test('legacy editor uses build-generated environment config, never a production hardcode or Pages Function route', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
  const generator = readFileSync(new URL('../scripts/generate-legacy-config.js', import.meta.url), 'utf8');
  assert.match(html, /src="\/legacy\/supabase-config\.js"/);
  assert.match(html, /window\.__SUPABASE_CONFIG__/);
  assert.doesNotMatch(html, /hwqtsopvpucadgpkigqz\.supabase\.co/);
  assert.doesNotMatch(html, /sb_publishable_[A-Za-z0-9_-]{20,}/);
  assert.match(packageJson.scripts.build, /generate-legacy-config\.js/);
  assert.match(generator, /VITE_SUPABASE_URL/);
  assert.match(generator, /VITE_SUPABASE_PUBLISHABLE_KEY/);
  assert.match(generator, /dist\/legacy\/supabase-config\.js/);
});

test('legacy Admin editor synchronizes the education offering selection before save', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(html, /t\.id==='f-education-subject'[\s\S]*?view\.education_subject_id=t\.value/);
  assert.match(html, /educationSubjectId=educationSelect\?\.value\|\|view\.education_subject_id\|\|''/);
});

test('legacy exam editor supports question-local images and shared stimulus media', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(html, /id="f-media-files"/);
  assert.match(html, /id="f-stimulus-files"/);
  assert.match(html, /uploadQuestionMedia/);
  assert.match(html, /uploadStimulusMedia/);
  assert.match(html, /admin_save_stimulus_version/);
  assert.match(html, /stimulus_version_id:stimulusVersionId/);
  assert.match(html, /examStimulusHtml\(q\.stimulus\)/);
  assert.match(html, /examMediaHtml\(q\.media\)/);
});

test('student media URLs are signed and question media metadata stays in public content only', () => {
  const html = readFileSync(new URL('../public/legacy/index.html', import.meta.url), 'utf8');
  const migration = readFileSync(new URL('../supabase/migrations/20261115100000_question_media_stimulus_groups.sql', import.meta.url), 'utf8');
  assert.match(html, /createSignedUrl\(item\.path,86400\)/);
  assert.match(html, /storage\.from\('lit-question-media'\)\.upload/);
  assert.match(migration, /lit_question_media_read_published/);
  assert.match(migration, /lit_can_read_question_media/);
  assert.match(migration, /stimulus_version_id uuid null/);
  assert.match(migration, /question_versions_attach_stimulus_snapshot/);
});
