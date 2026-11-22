import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildEducationCoursePayload, splitRecordIdentity } from './educationPayload.js';

test('new education records omit the empty UUID id from insert payloads', () => {
  const result = splitRecordIdentity({
    id: '',
    education_level_id: 'level-uuid',
    subject_id: 'subject-uuid',
    display_name: 'Giải tích 1',
  });

  assert.equal(result.id, '');
  assert.deepEqual(result.values, {
    education_level_id: 'level-uuid',
    subject_id: 'subject-uuid',
    display_name: 'Giải tích 1',
  });
  assert.equal(Object.hasOwn(result.values, 'id'), false);
});

test('existing education records keep their UUID for update targeting but omit it from update payloads', () => {
  const result = splitRecordIdentity({
    id: 'offering-uuid',
    education_level_id: 'level-uuid',
    subject_id: 'subject-uuid',
  });

  assert.equal(result.id, 'offering-uuid');
  assert.deepEqual(result.values, {
    education_level_id: 'level-uuid',
    subject_id: 'subject-uuid',
  });
  assert.equal(Object.hasOwn(result.values, 'id'), false);
});

test('University course create payload includes the selected category and normalized local code', () => {
  assert.deepEqual(buildEducationCoursePayload({
    category_id: 'category-1',
    local_code: ' MATH101 ',
    display_name: 'Giải tích 1',
    display_order: '2',
    is_active: true,
  }, 'university-level', true), {
    category_id: 'category-1',
    local_code: 'MATH101',
    display_name: 'Giải tích 1',
    display_order: 2,
    is_active: true,
    education_level_id: 'university-level',
  });
});

test('THPT course create payload always keeps category_id null', () => {
  assert.deepEqual(buildEducationCoursePayload({
    category_id: 'stale-category',
    local_code: ' THPT-MATH ',
    display_name: 'Toán',
    display_order: '0',
    is_active: true,
  }, 'thpt-level', false), {
    category_id: null,
    local_code: 'THPT-MATH',
    display_name: 'Toán',
    display_order: 0,
    is_active: true,
    education_level_id: 'thpt-level',
  });
});

test('editing a course reassigns its category without putting the course UUID in the payload', () => {
  const { id, values } = splitRecordIdentity({
    id: 'course-1',
    category_id: 'new-category',
    local_code: 'CS101',
    display_name: 'Cơ sở dữ liệu',
    display_order: 3,
    is_active: true,
  });
  const payload = buildEducationCoursePayload(values, 'university-level', true);

  assert.equal(id, 'course-1');
  assert.equal(payload.category_id, 'new-category');
  assert.equal(Object.hasOwn(payload, 'id'), false);
});

test('all education create and update flows strip form identity before writing', () => {
  const page = readFileSync(new URL('../pages/AdminEducationPage.jsx', import.meta.url), 'utf8');
  assert.match(page, /splitRecordIdentity\(categoryForm\)/);
  assert.match(page, /splitRecordIdentity\(courseForm\)/);
  assert.doesNotMatch(page, /\.insert\(\{\s*\.\.\.(?:categoryForm|courseForm)/);
});


test('exam editor offers searchable level and category course pickers', () => {
  const editor = readFileSync(new URL('../../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(editor, /f-education-search/);
  assert.match(editor, /f-education-level/);
  assert.match(editor, /f-education-category/);
  assert.match(editor, /education_course_categories/);
  assert.doesNotMatch(editor, /knowledge_category|education_nodes/);
  assert.match(editor, /data-search=/);
});


test('student course browsing uses editable categories and direct course links', () => {
  const browse = readFileSync(new URL('../pages/EducationBrowsePages.jsx', import.meta.url), 'utf8');
  assert.match(browse, /education_course_categories/);
  assert.match(browse, /EducationCategoryPage/);
  assert.doesNotMatch(browse, /knowledge_category|education_nodes/);
});
