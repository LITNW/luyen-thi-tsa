const DB_NAME = 'lit-browser-cache';
const DB_VERSION = 1;
const STORE_NAME = 'temporary';
const MAX_ENTRY_BYTES = 512 * 1024;

function openDatabase(indexedDBImpl = globalThis.indexedDB) {
  if (!indexedDBImpl) return Promise.reject(new Error('IndexedDB không khả dụng.'));
  return new Promise((resolve, reject) => {
    const request = indexedDBImpl.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: 'key' });
        store.createIndex('expiresAt', 'expiresAt', { unique: false });
        store.createIndex('accountId', 'accountId', { unique: false });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('Không thể mở IndexedDB.'));
  });
}

function requestResult(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('IndexedDB request thất bại.'));
  });
}

export async function putTemporaryRecord({ accountId, namespace, id, value, ttlMs = 24 * 60 * 60 * 1000 }, indexedDBImpl) {
  if (!accountId || !namespace || !id) throw new Error('Thiếu phạm vi tài khoản hoặc khóa bản ghi.');
  const serialized = JSON.stringify(value);
  if (new TextEncoder().encode(serialized).byteLength > MAX_ENTRY_BYTES) throw new Error('Bản ghi tạm vượt quá giới hạn 512 KiB.');
  const db = await openDatabase(indexedDBImpl);
  try {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    tx.objectStore(STORE_NAME).put({
      key: [accountId, namespace, id].join(':'),
      accountId,
      namespace,
      value,
      updatedAt: Date.now(),
      expiresAt: Date.now() + Math.max(1000, ttlMs),
    });
    await new Promise((resolve, reject) => {
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error || new Error('Không thể lưu bản ghi tạm.'));
      tx.onabort = () => reject(tx.error || new Error('Giao dịch IndexedDB bị hủy.'));
    });
  } finally { db.close(); }
}

export async function getTemporaryRecord({ accountId, namespace, id }, indexedDBImpl) {
  if (!accountId || !namespace || !id) return null;
  const db = await openDatabase(indexedDBImpl);
  try {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const record = await requestResult(store.get([accountId, namespace, id].join(':')));
    if (!record) return null;
    if (record.expiresAt <= Date.now()) {
      store.delete(record.key);
      return null;
    }
    return record.value;
  } finally { db.close(); }
}

export async function clearAccountTemporaryRecords(accountId, indexedDBImpl) {
  if (!accountId) return;
  const db = await openDatabase(indexedDBImpl);
  try {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const index = tx.objectStore(STORE_NAME).index('accountId');
    const keys = await requestResult(index.getAllKeys(IDBKeyRange.only(accountId)));
    keys.forEach((key) => tx.objectStore(STORE_NAME).delete(key));
    await new Promise((resolve, reject) => {
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error || new Error('Không thể xóa dữ liệu tạm.'));
      tx.onabort = () => reject(tx.error || new Error('Giao dịch xóa bị hủy.'));
    });
  } finally { db.close(); }
}

export async function purgeExpiredTemporaryRecords(indexedDBImpl) {
  const db = await openDatabase(indexedDBImpl);
  try {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const range = IDBKeyRange.upperBound(Date.now());
    const keys = await requestResult(store.index('expiresAt').getAllKeys(range));
    keys.forEach((key) => store.delete(key));
    await new Promise((resolve, reject) => {
      tx.oncomplete = resolve;
      tx.onerror = () => reject(tx.error || new Error('Không thể dọn dữ liệu hết hạn.'));
      tx.onabort = () => reject(tx.error || new Error('Giao dịch dọn dữ liệu bị hủy.'));
    });
    return keys.length;
  } finally { db.close(); }
}
