const CACHE_NAME = 'lit-public-assets-v1';
const MAX_CACHED_ASSETS = 80;
const ALLOWED_PREFIXES = ['/assets/', '/brand/'];

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
  if (request.method !== 'GET' || request.headers.has('authorization')) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (!ALLOWED_PREFIXES.some((prefix) => url.pathname.startsWith(prefix))) return;
  if (url.pathname.includes('/..') || url.searchParams.has('token') || url.searchParams.has('code')) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok && response.type === 'basic' && !response.headers.has('set-cookie')) {
      await cache.put(request, response.clone());
      const keys = await cache.keys();
      if (keys.length > MAX_CACHED_ASSETS) {
        await cache.delete(keys[0]);
      }
    }
    return response;
  })());
});
