import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CONSENT_VERSION,
  DEFAULT_PRIVACY_PREFERENCES,
  readPrivacyPreferences,
  savePrivacyPreferences,
} from '../src/lib/privacy-consent.js';

function createStorage(initial = {}) {
  const values = new Map(Object.entries(initial));
  return {
    getItem(key) { return values.has(key) ? values.get(key) : null; },
    setItem(key, value) { values.set(key, String(value)); },
    removeItem(key) { values.delete(key); },
  };
}

test('new visitors receive only essential and security storage by default', () => {
  const preferences = readPrivacyPreferences(createStorage());
  assert.deepEqual(preferences.categories, DEFAULT_PRIVACY_PREFERENCES.categories);
  assert.equal(preferences.categories.essential, true);
  assert.equal(preferences.categories.security, true);
  assert.equal(preferences.categories.preferences, false);
  assert.equal(preferences.categories.pageState, false);
  assert.equal(preferences.categories.analytics, false);
});

test('saving preferences cannot disable essential security or enable unavailable analytics', () => {
  const storage = createStorage();
  const saved = savePrivacyPreferences(storage, {
    essential: false,
    security: false,
    preferences: true,
    pageState: true,
    analytics: true,
  });
  assert.equal(saved.categories.essential, true);
  assert.equal(saved.categories.security, true);
  assert.equal(saved.categories.preferences, true);
  assert.equal(saved.categories.pageState, true);
  assert.equal(saved.categories.analytics, false);
});

test('stored choices are versioned and malformed or outdated data falls back to safe defaults', () => {
  const storage = createStorage();
  const saved = savePrivacyPreferences(storage, { preferences: true });
  assert.equal(saved.version, CONSENT_VERSION);
  assert.ok(saved.updatedAt);
  assert.deepEqual(readPrivacyPreferences(storage), saved);

  storage.setItem('lit.privacy.preferences', '{invalid');
  assert.deepEqual(readPrivacyPreferences(storage).categories, DEFAULT_PRIVACY_PREFERENCES.categories);

  storage.setItem('lit.privacy.preferences', JSON.stringify({ version: 'old', categories: { analytics: true } }));
  assert.deepEqual(readPrivacyPreferences(storage).categories, DEFAULT_PRIVACY_PREFERENCES.categories);
});

test('storage failure is handled without breaking application startup', () => {
  const unavailableStorage = {
    getItem() { throw new Error('blocked'); },
    setItem() { throw new Error('quota'); },
  };
  assert.deepEqual(readPrivacyPreferences(unavailableStorage).categories, DEFAULT_PRIVACY_PREFERENCES.categories);
  assert.equal(savePrivacyPreferences(unavailableStorage, { preferences: true }).persisted, false);
});
