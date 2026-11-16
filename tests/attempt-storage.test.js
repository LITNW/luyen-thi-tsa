import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../public/legacy/attempt-storage.js', import.meta.url), 'utf8');

class FakeRequest {}
class FakeObjectStore {
  constructor(database, transaction) { this.database = database; this.transaction = transaction; }
  createIndex() { return {}; }
  put(record) {
    if (this.database.failWrites) throw new Error('QuotaExceededError');
    this.database.records.set(record.id, structuredClone(record));
    queueMicrotask(() => this.transaction.oncomplete?.());
    return new FakeRequest();
  }
  delete(id) {
    this.database.records.delete(id);
    queueMicrotask(() => this.transaction.oncomplete?.());
    return new FakeRequest();
  }
  getAll() {
    const request = new FakeRequest();
    request.result = [...this.database.records.values()];
    queueMicrotask(() => { request.onsuccess?.(); queueMicrotask(() => this.transaction.oncomplete?.()); });
    return request;
  }
  index() {
    return { getAll: accountId => {
      const request = new FakeRequest();
      request.result = [...this.database.records.values()].filter(record => record.accountId === accountId);
      queueMicrotask(() => { request.onsuccess?.(); queueMicrotask(() => this.transaction.oncomplete?.()); });
      return request;
    }};
  }
}
class FakeTransaction {
  constructor(database) { this.database = database; }
  objectStore() { return new FakeObjectStore(this.database, this); }
}
class FakeDatabase {
  constructor() {
    this.records = new Map();
    this.failWrites = false;
    this.objectStoreNames = { contains: () => true };
  }
  createObjectStore() { return new FakeObjectStore(this, null); }
  transaction() { return new FakeTransaction(this); }
}
function makeEnvironment(database = new FakeDatabase(), legacy = new Map()) {
  const localStorage = {
    getItem: key => legacy.has(key) ? legacy.get(key) : null,
    setItem: (key, value) => legacy.set(key, String(value)),
    removeItem: key => legacy.delete(key)
  };
  const listeners = [];
  const window = {
    localStorage,
    indexedDB: { open: () => {
      const request = new FakeRequest();
      request.result = database;
      queueMicrotask(() => request.onsuccess?.());
      return request;
    }},
    dispatchEvent: event => { listeners.push(event); return true; }
  };
  class CustomEvent { constructor(type, init) { this.type = type; this.detail = init?.detail; } }
  vm.runInNewContext(source, { window, CustomEvent, Map, Promise, Date, JSON, String, Array, Error });
  return { storage: window.LITAttemptStorage, database, legacy, listeners };
}

test('migrates only the signed-in user legacy records and removes them only after IndexedDB read-back verification', async () => {
  const legacy = new Map([
    ['tsa-active-attempt-index', JSON.stringify(['attempt-a', 'attempt-b'])],
    ['tsa-active-attempt-attempt-a', JSON.stringify({ attemptId: 'attempt-a', userId: 'user-a', examSnapshot: { questions: [] } })],
    ['tsa-attempt-attempt-a', JSON.stringify({ ans: [1], dirtyAnswers: { 0: 1 } })],
    ['tsa-active-attempt-attempt-b', JSON.stringify({ attemptId: 'attempt-b', userId: 'user-b', examSnapshot: { questions: [] } })],
    ['tsa-attempt-attempt-b', JSON.stringify({ ans: [2] })]
  ]);
  const env = makeEnvironment(undefined, legacy);
  await env.storage.setAccount('user-a');
  assert.equal(env.storage.get('tsa-attempt-attempt-a').ans[0], 1);
  assert.equal(legacy.has('tsa-active-attempt-attempt-a'), false);
  assert.equal(legacy.has('tsa-attempt-attempt-a'), false);
  assert.equal(legacy.has('tsa-active-attempt-attempt-b'), true);
  assert.deepEqual(env.storage.get('tsa-active-attempt-index'), ['attempt-a']);
});

test('keeps attempt records isolated when switching accounts and restores them after reload', async () => {
  const db = new FakeDatabase();
  const first = makeEnvironment(db);
  await first.storage.setAccount('user-a');
  await first.storage.set('tsa-attempt-a1', { ans: ['A'], timeQueue: [{ seconds: 8 }] });
  await first.storage.flush();
  await first.storage.setAccount('user-b');
  assert.equal(first.storage.get('tsa-attempt-a1'), null);
  await first.storage.set('tsa-attempt-b1', { ans: ['B'] });
  await first.storage.flush();

  const reloaded = makeEnvironment(db);
  await reloaded.storage.setAccount('user-a');
  assert.deepEqual(reloaded.storage.get('tsa-attempt-a1'), { ans: ['A'], timeQueue: [{ seconds: 8 }] });
  assert.equal(reloaded.storage.get('tsa-attempt-b1'), null);
  await reloaded.storage.setAccount('user-b');
  assert.deepEqual(reloaded.storage.get('tsa-attempt-b1'), { ans: ['B'] });
});

test('reports quota failures and does not silently discard the in-memory draft', async () => {
  const env = makeEnvironment();
  await env.storage.setAccount('user-a');
  env.database.failWrites = true;
  await assert.rejects(env.storage.set('tsa-attempt-a1', { ans: ['unsynced'] }), /QuotaExceededError/);
  assert.deepEqual(env.storage.get('tsa-attempt-a1'), { ans: ['unsynced'] });
  assert.ok(env.listeners.some(event => event.type === 'lit-attempt-storage-error'));
});

test('a new page context can restore a draft after an offline reload without relying on localStorage', async () => {
  const db = new FakeDatabase();
  const first = makeEnvironment(db);
  await first.storage.setAccount('user-a');
  await first.storage.set('tsa-active-attempt-offline', {
    attemptId: 'offline', userId: 'user-a', examSnapshot: { questions: [{ id: 'q1' }] }
  });
  await first.storage.set('tsa-attempt-offline', {
    ans: ['saved-answer'], dirtyAnswers: { 0: 1 }, timeQueue: [{ seconds: 12 }]
  });
  await first.storage.set('tsa-active-attempt-index', ['offline']);
  await first.storage.flush();

  const reloaded = makeEnvironment(db);
  await reloaded.storage.setAccount('user-a');
  assert.equal(reloaded.storage.get('tsa-active-attempt-offline').examSnapshot.questions.length, 1);
  assert.equal(reloaded.storage.get('tsa-attempt-offline').ans[0], 'saved-answer');
  assert.equal(reloaded.storage.get('tsa-attempt-offline').timeQueue[0].seconds, 12);
});
