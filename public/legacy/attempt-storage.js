(function (root) {
  'use strict';

  const DB_NAME = 'lit-attempt-storage';
  const DB_VERSION = 1;
  const STORE_NAME = 'attempts';
  const LEGACY_INDEX = 'tsa-active-attempt-index';
  const LEGACY_PREFIXES = ['tsa-active-attempt-', 'tsa-attempt-'];
  let dbPromise = null;
  let activeAccountId = null;
  let memory = new Map();
  let writeQueue = Promise.resolve();
  let mode = 'indexeddb';

  function emitError(error, operation) {
    try {
      root.dispatchEvent(new CustomEvent('lit-attempt-storage-error', {
        detail: { message: error?.message || String(error), operation }
      }));
    } catch (_) {}
  }

  function openDatabase() {
    if (!root.indexedDB) return Promise.reject(new Error('Trình duyệt không hỗ trợ IndexedDB.'));
    if (dbPromise) return dbPromise;
    dbPromise = new Promise((resolve, reject) => {
      const request = root.indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          const store = db.createObjectStore(STORE_NAME, { keyPath: 'id' });
          store.createIndex('accountId', 'accountId', { unique: false });
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error || new Error('Không mở được IndexedDB.'));
      request.onblocked = () => reject(new Error('IndexedDB đang bị chặn bởi một tab khác.'));
    });
    dbPromise.catch(() => { dbPromise = null; });
    return dbPromise;
  }

  function transactionDone(transaction) {
    return new Promise((resolve, reject) => {
      transaction.oncomplete = () => resolve();
      transaction.onerror = () => reject(transaction.error || new Error('Giao dịch IndexedDB thất bại.'));
      transaction.onabort = () => reject(transaction.error || new Error('Giao dịch IndexedDB bị hủy.'));
    });
  }

  function requestValue(request) {
    return new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error || new Error('Không đọc được dữ liệu IndexedDB.'));
    });
  }

  function recordId(accountId, logicalKey) {
    return accountId + '::' + logicalKey;
  }

  function readLegacy(key) {
    try {
      const raw = root.localStorage.getItem(key);
      return raw == null ? null : JSON.parse(raw);
    } catch (_) {
      return null;
    }
  }

  function removeLegacy(key) {
    try { root.localStorage.removeItem(key); } catch (_) {}
  }

  function queueWrite(operation, label) {
    writeQueue = writeQueue.catch(() => {}).then(operation).catch(error => {
      emitError(error, label);
      throw error;
    });
    writeQueue.catch(() => {});
    return writeQueue;
  }

  async function getAllForAccount(db, accountId) {
    const tx = db.transaction(STORE_NAME, 'readonly');
    const request = tx.objectStore(STORE_NAME).index('accountId').getAll(accountId);
    const records = await requestValue(request);
    await transactionDone(tx);
    return records || [];
  }

  async function setAccount(accountId) {
    await flush();
    activeAccountId = accountId ? String(accountId) : null;
    memory = new Map();
    mode = 'indexeddb';
    if (!activeAccountId) return;

    try {
      const db = await openDatabase();
      const oldIds = readLegacy(LEGACY_INDEX);
      const ids = Array.isArray(oldIds) ? oldIds : [];
      const recordsToMigrate = [];
      const migratedIds = [];

      for (const attemptId of ids) {
        const pointerKey = 'tsa-active-attempt-' + attemptId;
        const cacheKey = 'tsa-attempt-' + attemptId;
        const pointer = readLegacy(pointerKey);
        if (!pointer || pointer.userId !== activeAccountId) continue;
        const cache = readLegacy(cacheKey);
        recordsToMigrate.push(
          { id: recordId(activeAccountId, pointerKey), accountId: activeAccountId, logicalKey: pointerKey, value: pointer, updatedAt: Date.now() },
          { id: recordId(activeAccountId, cacheKey), accountId: activeAccountId, logicalKey: cacheKey, value: cache, updatedAt: Date.now() }
        );
        migratedIds.push(String(attemptId));
      }

      if (recordsToMigrate.length) {
        const tx = db.transaction(STORE_NAME, 'readwrite');
        const store = tx.objectStore(STORE_NAME);
        recordsToMigrate.forEach(record => store.put(record));
        await transactionDone(tx);

        const verified = await getAllForAccount(db, activeAccountId);
        const verifiedById = new Map(verified.map(record => [record.id, record]));
        const allVerified = recordsToMigrate.every(expected => {
          const actual = verifiedById.get(expected.id);
          return actual && JSON.stringify(actual.value) === JSON.stringify(expected.value);
        });
        if (!allVerified) throw new Error('Legacy migration verified failed; legacy records were retained.');

        migratedIds.forEach(attemptId => {
          removeLegacy('tsa-active-attempt-' + attemptId);
          removeLegacy('tsa-attempt-' + attemptId);
        });
        const remaining = ids.filter(attemptId => !migratedIds.includes(String(attemptId)));
        try { root.localStorage.setItem(LEGACY_INDEX, JSON.stringify(remaining)); } catch (_) {}
      }

      const records = await getAllForAccount(db, activeAccountId);
      records.forEach(record => memory.set(record.logicalKey, record.value));
      const activeIds = records.filter(record => record.logicalKey.startsWith('tsa-active-attempt-') && record.logicalKey !== LEGACY_INDEX)
        .map(record => record.logicalKey.slice('tsa-active-attempt-'.length));
      memory.set(LEGACY_INDEX, activeIds);
    } catch (error) {
      mode = 'legacy-fallback';
      emitError(error, 'initialize');
      const ids = readLegacy(LEGACY_INDEX);
      (Array.isArray(ids) ? ids : []).forEach(attemptId => {
        const pointerKey = 'tsa-active-attempt-' + attemptId;
        const pointer = readLegacy(pointerKey);
        if (!pointer || pointer.userId !== activeAccountId) return;
        memory.set(pointerKey, pointer);
        memory.set('tsa-attempt-' + attemptId, readLegacy('tsa-attempt-' + attemptId));
      });
    }
  }

  function get(key) {
    return memory.has(key) ? memory.get(key) : null;
  }

  function set(key, value) {
    if (!activeAccountId) {
      emitError(new Error('Chưa thiết lập namespace tài khoản cho bản nháp.'), 'write');
      return Promise.resolve(false);
    }
    memory.set(key, value);
    if (mode === 'legacy-fallback') {
      try {
        root.localStorage.setItem(key, JSON.stringify(value));
        return Promise.resolve(true);
      } catch (error) {
        emitError(error, 'fallback-write');
        return Promise.resolve(false);
      }
    }
    return queueWrite(async () => {
      const db = await openDatabase();
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put({
        id: recordId(activeAccountId, key),
        accountId: activeAccountId,
        logicalKey: key,
        value,
        updatedAt: Date.now()
      });
      await transactionDone(tx);
      return true;
    }, 'write').catch(error => {
      try {
        root.localStorage.setItem(key, JSON.stringify(value));
        mode = 'legacy-fallback';
        return true;
      } catch (fallbackError) {
        emitError(fallbackError, 'fallback-write');
        throw error;
      }
    });
  }

  function del(key) {
    memory.delete(key);
    if (!activeAccountId) return Promise.resolve(false);
    if (mode === 'legacy-fallback') {
      removeLegacy(key);
      return Promise.resolve(true);
    }
    return queueWrite(async () => {
      const db = await openDatabase();
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).delete(recordId(activeAccountId, key));
      await transactionDone(tx);
      return true;
    }, 'delete');
  }

  async function flush() {
    try { await writeQueue; } catch (_) {}
  }

  root.LITAttemptStorage = { setAccount, get, set, del, flush };
})(window);
