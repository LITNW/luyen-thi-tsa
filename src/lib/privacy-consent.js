export const CONSENT_VERSION = '2026-11-16.1';
export const PRIVACY_STORAGE_KEY = 'lit.privacy.preferences';

export const DEFAULT_PRIVACY_PREFERENCES = Object.freeze({
  categories: Object.freeze({
    essential: true,
    security: true,
    preferences: false,
    pageState: false,
    analytics: false,
  }),
});

const normalizeCategories = (input = {}) => ({
  essential: true,
  security: true,
  preferences: input.preferences === true,
  pageState: input.pageState === true,
  // LIT has no enabled analytics/performance measurement provider at this release.
  analytics: false,
});

export function readPrivacyPreferences(storage = globalThis.localStorage) {
  try {
    const raw = storage?.getItem(PRIVACY_STORAGE_KEY);
    if (!raw) return { version: CONSENT_VERSION, updatedAt: null, categories: normalizeCategories() };
    const parsed = JSON.parse(raw);
    if (parsed?.version !== CONSENT_VERSION || !parsed?.categories || typeof parsed.categories !== 'object') {
      return { version: CONSENT_VERSION, updatedAt: null, categories: normalizeCategories() };
    }
    return {
      version: CONSENT_VERSION,
      updatedAt: typeof parsed.updatedAt === 'string' ? parsed.updatedAt : null,
      categories: normalizeCategories(parsed.categories),
    };
  } catch {
    return { version: CONSENT_VERSION, updatedAt: null, categories: normalizeCategories() };
  }
}

export function savePrivacyPreferences(storage = globalThis.localStorage, choices = {}) {
  const payload = {
    version: CONSENT_VERSION,
    updatedAt: new Date().toISOString(),
    categories: normalizeCategories(choices),
  };
  try {
    storage?.setItem(PRIVACY_STORAGE_KEY, JSON.stringify(payload));
    return { ...payload, persisted: true };
  } catch {
    return { ...payload, persisted: false };
  }
}
