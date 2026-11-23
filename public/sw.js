const CACHE_NAME = 'lit-public-assets-v2';
const MAX_CACHED_ASSETS = 80;
const MAX_ASSET_BYTES = 512 * 1024;
const MAX_CACHE_BYTES = 8 * 1024 * 1024;
const ALLOWED_PREFIXES = ['/assets/', '/brand/'];
const ALLOWED_CONTENT_TYPES = [
  'application/javascript',
  'text/javascript',
  'text/css',
  'font/',
  'image/svg+xml',
];

function cacheableSize(response) {
  const contentType = (response.headers.get('content-type') || '').toLowerCase();
  const rawLength = response.headers.get('content-length');
  if (!ALLOWED_CONTENT_TYPES.some((type) => contentType.startsWith(type))) return 0;
  if (!rawLength || !/^\d+$/.test(rawLength)) return 0;
  const size = Number(rawLength);
  return Number.isSafeInteger(size) && size > 0 && size <= MAX_ASSET_BYTES ? size : 0;
}

async function trimCache(cache, incomingBytes) {
  let keys = await cache.keys();
  let sizes = await Promise.all(keys.map(async (request) => {
    const response = await cache.match(request);
    const rawLength = response?.headers.get('content-length');
    return rawLength && /^\d+$/.test(rawLength) ? Number(rawLength) : 0;
  }));
  let totalBytes = sizes.reduce((total, size) => total + size, 0);

  while (keys.length && (keys.length >= MAX_CACHED_ASSETS || totalBytes + incomingBytes > MAX_CACHE_BYTES)) {
    await cache.delete(keys[0]);
    totalBytes -= sizes[0];
    keys = keys.slice(1);
    sizes = sizes.slice(1);
  }
}

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter((name) => name.startsWith('lit-public-assets-') && name !== CACHE_NAME).map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('authorization') || request.headers.has('range')) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (!ALLOWED_PREFIXES.some((prefix) => url.pathname.startsWith(prefix))) return;
  if (url.pathname.includes('/..') || url.searchParams.has('token') || url.searchParams.has('code')) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) return cached;
    const response = await fetch(request);
    const size = response.ok && response.type === 'basic' && !response.headers.has('set-cookie')
      && !/\bno-store\b/i.test(response.headers.get('cache-control') || '')
      ? cacheableSize(response)
      : 0;
    if (size) {
      await trimCache(cache, size);
      await cache.put(request, response.clone());
    }
    return response;
  })());
});
