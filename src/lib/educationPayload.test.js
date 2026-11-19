import test from 'node:test';
import assert from 'node:assert/strict';
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
