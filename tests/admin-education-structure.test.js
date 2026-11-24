import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { isValidEducationCategoryCode } from '../src/lib/educationCategoryCode.js';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('category code accepts the documented lowercase ASCII format', () => {
  for (const code of ['unclassified', 'classified', 'math_advanced', 'group01', 'toan_cao_cap', 'a1', 'a'.repeat(64)]) {
    assert.equal(isValidEducationCategoryCode(code), true, `${code} should be valid`);
  }
});

test('category code rejects values outside the database constraint', () => {
  for (const code of ['Aclassified', '1group', 'a', 'math-advanced', 'toán_cao_cap', 'math advanced', 'a'.repeat(65), 'classified\n', '']) {
    assert.equal(isValidEducationCategoryCode(code), false, `${code} should be invalid`);
  }
});

test('category code pattern stays aligned with the database check', () => {
  const migration = read('../supabase/migrations/20261119160000_education_course_categories.sql');
  assert.match(migration, /code text not null check \(code ~ '\^\[a-z\]\[a-z0-9_\]\{1,63\}\$'\)/);
});

test('Admin category form explains the code rule and provides accessible selection states', () => {
  const admin = read('../src/pages/AdminEducationPage.jsx');
  const styles = read('../src/styles.css');
  const codeRules = read('../src/lib/educationCategoryCode.js');
  assert.match(codeRules, /2–64 ký tự; bắt đầu bằng a–z/);
  assert.match(admin, /EDUCATION_CATEGORY_CODE_HELP/);
  assert.match(admin, /aria-pressed=\{selectedLevel === item\.id\}/);
  assert.match(admin, /aria-pressed=\{selectedCategory === category\.id\}/);
  assert.match(admin, /toggle\('education_course_categories', category/);
  assert.match(admin, /toggle\('education_subjects', course/);
  assert.match(styles, /education-admin-level-select\.selected/);
  assert.match(styles, /education-admin-level-select:hover/);
  assert.match(styles, /education-admin-level-select:focus-visible/);
  assert.match(styles, /education-admin-level-select:disabled/);
});

test('Admin exposes guarded category and course deletion actions', () => {
  const admin = read('../src/pages/AdminEducationPage.jsx');
  assert.match(admin, /deleteCategory/);
  assert.match(admin, /deleteCourse/);
  assert.match(admin, /Không thể xóa danh mục mặc định/);
  assert.match(admin, /education_subject_id/);
  assert.match(admin, /exams/);
});

test('database deletion guards retain admin authorization and restrictive dependencies', () => {
  const migration = read('../supabase/migrations/20261124100000_education_structure_delete_guards.sql');
  assert.match(migration, /public\.is_admin\(\)/);
  assert.match(migration, /unclassified/i);
  assert.match(migration, /education_subjects/);
  assert.match(migration, /exams/);
  assert.match(migration, /before delete/i);
  assert.match(migration, /on delete restrict/i);
  assert.doesNotMatch(migration, /on delete cascade/i);
});
