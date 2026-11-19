import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
const legacyClassification = () => {
  const context = {};
  runInNewContext(read('../public/legacy/education-classification.js'), context);
  return context.LITEducationClassification;
};

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
  assert.match(editor, /LITEducationClassification\.resetForLevelChange/);
  assert.match(editor, /LITEducationClassification\.resetForGroupChange/);
  assert.match(editor, /LITEducationClassification\.isValidCourseSelection/);
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
  assert.match(migration, /p\.status='active'/);
  assert.match(migration, /or \(select public\.is_admin\(\)\)/);
});

test('legacy exam selector filters active University courses by the selected group', () => {
  const { filterCourses } = legacyClassification();
  const courses = [
    { id: 'uni-in-group', education_level_id: 'uni', group_id: 'g1', is_active: true },
    { id: 'uni-other-group', education_level_id: 'uni', group_id: 'g2', is_active: true },
    { id: 'uni-inactive', education_level_id: 'uni', group_id: 'g1', is_active: false },
    { id: 'thpt', education_level_id: 'thpt', group_id: null, is_active: true },
  ];

  assert.deepEqual(filterCourses(courses, 'uni', 'university', 'g1').map((course) => course.id), ['uni-in-group']);
});

test('legacy exam selector keeps THPT direct and excludes grouped or inactive courses', () => {
  const { filterCourses } = legacyClassification();
  const courses = [
    { id: 'thpt-direct', education_level_id: 'thpt', group_id: null, is_active: true },
    { id: 'thpt-grouped', education_level_id: 'thpt', group_id: 'g1', is_active: true },
    { id: 'thpt-inactive', education_level_id: 'thpt', group_id: null, is_active: false },
  ];

  assert.deepEqual(filterCourses(courses, 'thpt', 'thpt', '').map((course) => course.id), ['thpt-direct']);
});

test('level and group changes clear downstream exam selector values', () => {
  const { resetForLevelChange, resetForGroupChange } = legacyClassification();
  const current = { education_level_id: 'uni', education_group_id: 'g1', education_subject_id: 'course-1', title: 'draft' };

  const afterLevelChange = resetForLevelChange(current, 'thpt');
  assert.equal(afterLevelChange.education_level_id, 'thpt');
  assert.equal(afterLevelChange.education_group_id, '');
  assert.equal(afterLevelChange.education_subject_id, null);
  assert.equal(afterLevelChange.title, 'draft');

  const afterGroupChange = resetForGroupChange(current, 'g2');
  assert.equal(afterGroupChange.education_level_id, 'uni');
  assert.equal(afterGroupChange.education_group_id, 'g2');
  assert.equal(afterGroupChange.education_subject_id, null);
  assert.equal(afterGroupChange.title, 'draft');
});

test('exam create and edit accept only courses matching level and group', () => {
  const { isValidCourseSelection } = legacyClassification();
  const university = { id: 'course-1', education_level_id: 'uni', group_id: 'g1', is_active: true };
  const thpt = { id: 'course-2', education_level_id: 'thpt', group_id: null, is_active: true };
  const archived = { id: 'course-archived', education_level_id: 'uni', group_id: 'g1', is_active: false };

  assert.equal(isValidCourseSelection(university, 'uni', 'university', 'g1', null), true);
  assert.equal(isValidCourseSelection(university, 'uni', 'university', 'g2', null), false);
  assert.equal(isValidCourseSelection(thpt, 'thpt', 'thpt', '', null), true);
  assert.equal(isValidCourseSelection({ ...thpt, group_id: 'g1' }, 'thpt', 'thpt', '', null), false);
  assert.equal(isValidCourseSelection(archived, 'uni', 'university', 'g1', null), false);
  assert.equal(isValidCourseSelection(archived, 'uni', 'university', 'g1', archived.id), true);
});

test('legacy exam editor applies the tested selector model before both create and edit saves', () => {
  const editor = read('../public/legacy/index.html');
  assert.match(editor, /<script src="\/legacy\/education-classification\.js"><\/script>/);
  assert.match(editor, /window\.LITEducationClassification\.filterCourses/);
  assert.match(editor, /window\.LITEducationClassification\.isValidCourseSelection/);
  assert.match(editor, /window\.LITEducationClassification\.resetForLevelChange/);
  assert.match(editor, /window\.LITEducationClassification\.resetForGroupChange/);
  assert.match(editor, /admin_save_exam_content_with_education/);
  assert.match(editor, /p_education_subject_id:educationSubjectId\|\|null/);
});

test('Staging cutover runbook has backup, freeze, exact dry-run, deploy, and recovery gates', () => {
  const runbook = read('../docs/education-course-classification-staging-cutover.md');
  assert.match(runbook, /cppalwtdkditlhojpeyc/);
  assert.match(runbook, /restore.*separate disposable Supabase project/i);
  assert.match(runbook, /staging_pause_university_course_insert/);
  assert.match(runbook, /staging_pause_university_course_update/);
  assert.match(runbook, /supabase db push --remote=cppalwtdkditlhojpeyc --dry-run/);
  assert.ok(runbook.includes('It must contain **only** `20261119160000_education_subject_groups.sql`'));
  assert.match(runbook, /deploy the approved PR #41 frontend artifact to the Staging frontend/i);
  assert.match(runbook, /keep the University write freeze active/i);
  assert.match(runbook, /separate explicit approval/i);
});
