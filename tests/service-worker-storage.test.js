import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../public/sw.js', import.meta.url), 'utf8');

class FakeResponse {
  constructor(size, contentType = 'application/javascript', extraHeaders = {}) {
    this.ok = true;
    this.type = 'basic';
    this.headers = new Map([
      ['content-length', String(size)],
      ['content-type', contentType],
      ...Object.entries(extraHeaders),
    ]);
  }

  clone() { return this; }
}

function makeRuntime(initial = []) {
  const listeners = new Map();
  const entries = new Map(initial.map(([url, size]) => [url, new FakeResponse(size)]));
  const cache = {
    async match(request) { return entries.get(typeof request === 'string' ? request : request.url) || null; },
    async put(request, response) { entries.set(typeof request === 'string' ? request : request.url, response); },
    async keys() { return [...entries.keys()].map((url) => ({ url })); },
    async delete(request) { return entries.delete(typeof request === 'string' ? request : request.url); },
  };
  const requestHeaders = (values = {}) => ({ has: (name) => Object.hasOwn(values, name) });
  const context = {
    URL,
    Promise,
    Number,
    self: {
      location: { origin: 'https://lit.example' },
      addEventListener: (name, listener) => listeners.set(name, listener),
    },
    caches: {
      async open() { return cache; },
      async keys() { return ['lit-public-assets-v2']; },
      async delete() { return true; },
    },
    fetch: async () => new FakeResponse(128),
  };
  vm.runInNewContext(source, context);
  return {
    entries,
    requestHeaders,
    async fetch(url, { response, headers = {}, method = 'GET', ...requestOptions } = {}) {
      let responsePromise;
      listeners.get('fetch')({
        request: { url: `https://lit.example${url}`, method, headers: requestHeaders(headers), ...requestOptions },
        respondWith(promise) { responsePromise = promise; },
      });
      context.fetch = async () => response || new FakeResponse(128);
      if (!responsePromise) return null;
      return responsePromise;
    },
  };
}

test('caches only bounded static assets and never media, unknown-size, or no-store responses', async () => {
  const runtime = makeRuntime();
  await runtime.fetch('/assets/app.js', { response: new FakeResponse(1024) });
  await runtime.fetch('/assets/large.js', { response: new FakeResponse(512 * 1024 + 1) });
  await runtime.fetch('/assets/photo.jpg', { response: new FakeResponse(1024, 'image/jpeg') });
  await runtime.fetch('/assets/unknown.css', { response: new FakeResponse(null, 'text/css') });
  await runtime.fetch('/assets/private.css', { response: new FakeResponse(1024, 'text/css', { 'cache-control': 'private, no-store' }) });

  assert.deepEqual([...runtime.entries.keys()], ['https://lit.example/assets/app.js']);
});

test('evicts oldest cached files to stay within the 8 MiB and 80 asset limits', async () => {
  const byteLimit = Array.from({ length: 16 }, (_, index) => [`https://lit.example/assets/old-${index}.js`, 512 * 1024]);
  const byBytes = makeRuntime(byteLimit);
  await byBytes.fetch('/assets/new.js', { response: new FakeResponse(512 * 1024) });
  assert.equal(byBytes.entries.size, 16);
  assert.equal(byBytes.entries.has('https://lit.example/assets/old-0.js'), false);
  assert.equal(byBytes.entries.has('https://lit.example/assets/new.js'), true);

  const byCount = makeRuntime(Array.from({ length: 80 }, (_, index) => [`https://lit.example/assets/file-${index}.js`, 64]));
  await byCount.fetch('/assets/latest.js', { response: new FakeResponse(64) });
  assert.equal(byCount.entries.size, 80);
  assert.equal(byCount.entries.has('https://lit.example/assets/file-0.js'), false);
  assert.equal(byCount.entries.has('https://lit.example/assets/latest.js'), true);
});

test('does not intercept authenticated or partial-content requests', async () => {
  const runtime = makeRuntime();
  const authResult = await runtime.fetch('/assets/app.js', {
    headers: { authorization: true }, response: new FakeResponse(64),
  });
  const rangeResult = await runtime.fetch('/assets/app.js', {
    headers: { range: true }, response: new FakeResponse(64),
  });
  assert.equal(authResult, null);
  assert.equal(rangeResult, null);
  assert.equal(runtime.entries.size, 0);
});
