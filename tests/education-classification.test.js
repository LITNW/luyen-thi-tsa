import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('admin education workflow manages direct courses and editable course groups', () => {
  const admin = read('../src/pages/AdminEducationPage.jsx');
  assert.match(admin, /education_subject_groups/);
  assert.match(admin, /group_id/);
  assert.doesNotMatch(admin, /knowledge_group|SUBJECT CATALOGUE|MAJORS/);
});

test('student browse uses university groups while preserving direct course links', () => {
  const browse = read('../src/pages/EducationBrowsePages.jsx');
  assert.match(browse, /education_subject_groups/);
  assert.match(browse, /group_id/);
  assert.doesNotMatch(browse, /knowledge_group|education_nodes/);
});

test('exam placement picker groups university courses and skips groups for THPT', () => {
  const admin = read('../src/pages/AdminPages.jsx');
  const editor = read('../public/legacy/index.html');
  assert.match(admin, /education_subject_groups/);
  assert.match(editor, /education_subject_groups/);
  assert.match(editor, /group_id/);
  assert.match(editor, /f-education-group/);
  assert.match(editor, /p_education_subject_id/);
  assert.match(editor, /educationSubjectId=educationSelect\?\.value\|\|view\.education_subject_id\|\|''/);
  assert.match(admin, /groupId: '', courseId: ''/);
  assert.match(admin, /groupId: event\.target\.value, courseId: ''/);
  assert.match(editor, /view\.education_group_id='';view\.education_subject_id=null/);
  assert.match(editor, /selectedCourse\.education_level_id!==selectedLevelId/);
});

test('old context browse URLs redirect to the current level route', () => {
  const browse = read('../src/pages/EducationBrowsePages.jsx');
  assert.match(browse, /export function EducationNodePage\(\).*Navigate to=\{`\/education\/\$\{levelCode\}`\} replace/s);
});

test('ordered migration enforces same-level group membership and preserves course and exam IDs', () => {
  const migration = read('../supabase/migrations/20261119160000_education_subject_groups.sql');
  assert.match(migration, /education_subject_groups/);
  assert.match(migration, /group_id/);
  assert.match(migration, /foreign key\s*\(education_level_id,group_id\)/i);
  assert.match(migration, /unclassified/i);
  assert.match(migration, /education_subject_id/);
  assert.doesNotMatch(migration, /delete from public\.education_subjects/i);
});
