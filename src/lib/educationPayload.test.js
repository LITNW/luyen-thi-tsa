import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { splitRecordIdentity } from './educationPayload.js';

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

test('all education create and update flows strip form identity before writing', () => {
  const page = readFileSync(new URL('../pages/AdminEducationPage.jsx', import.meta.url), 'utf8');
  assert.match(page, /splitRecordIdentity\(levelForm\)/);
  assert.match(page, /splitRecordIdentity\(nodeForm\)/);
  assert.match(page, /splitRecordIdentity\(offeringForm\)/);
  assert.doesNotMatch(page, /\.insert\(\{\s*\.\.\.(?:levelForm|nodeForm|offeringForm)/);
});


test('exam editor offers a searchable course picker with knowledge-group context', () => {
  const editor = readFileSync(new URL('../../public/legacy/index.html', import.meta.url), 'utf8');
  assert.match(editor, /f-education-search/);
  assert.match(editor, /knowledge_group/);
  assert.match(editor, /data-search=/);
});
