import test from 'node:test';
import assert from 'node:assert/strict';
import { putTemporaryRecord, getTemporaryRecord, clearAccountTemporaryRecords } from '../src/lib/browser-storage.js';

test('temporary records require an account namespace and key', async () => {
  await assert.rejects(() => putTemporaryRecord({ accountId: '', namespace: 'draft', id: '1', value: {} }), /Thiếu phạm vi/);
  assert.equal(await getTemporaryRecord({ accountId: '', namespace: 'draft', id: '1' }), null);
  await clearAccountTemporaryRecords('');
});

test('oversized temporary payloads are rejected before opening IndexedDB', async () => {
  const huge = 'x'.repeat(600 * 1024);
  await assert.rejects(
    () => putTemporaryRecord({ accountId: 'user-1', namespace: 'draft', id: 'exam-1', value: huge }, null),
    /vượt quá giới hạn/,
  );
});
