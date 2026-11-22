import test from 'node:test';
import assert from 'node:assert/strict';
import { createAiHandler } from '../api/ai/respond.js';

function makeResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: '',
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; },
    end(value = '') { this.body = value; },
    json() { return this.body ? JSON.parse(this.body) : null; },
  };
}

function makeRequest({ method = 'POST', body = { input: 'Giải thích định luật Newton.' }, authorization = 'Bearer user-token' } = {}) {
  return { method, body, headers: { authorization, 'content-type': 'application/json' } };
}

function jsonResponse(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

function enabledEnv(overrides = {}) {
  return {
    AI_GATEWAY_ENABLED: 'true',
    OPENAI_API_KEY: 'test-secret',
    VITE_SUPABASE_URL: 'https://lit-test.supabase.co',
    VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_test',
    OPENAI_MODEL: 'gpt-6.2-astra',
    ...overrides,
  };
}

test('gateway is disabled unless explicitly enabled', async () => {
  let calls = 0;
  const handler = createAiHandler({ env: enabledEnv({ AI_GATEWAY_ENABLED: 'false' }), fetchImpl: async () => { calls += 1; } });
  const response = makeResponse();

  await handler(makeRequest(), response);

  assert.equal(response.statusCode, 503);
  assert.equal(response.json().error.code, 'ai_gateway_disabled');
  assert.equal(calls, 0);
});

test('rejects non-POST requests', async () => {
  const handler = createAiHandler({ env: enabledEnv(), fetchImpl: async () => { throw new Error('must not call network'); } });
  const response = makeResponse();

  await handler(makeRequest({ method: 'GET' }), response);

  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.allow, 'POST');
});

test('requires a Supabase bearer token before contacting upstream services', async () => {
  let calls = 0;
  const handler = createAiHandler({ env: enabledEnv(), fetchImpl: async () => { calls += 1; } });
  const response = makeResponse();

  await handler(makeRequest({ authorization: '' }), response);

  assert.equal(response.statusCode, 401);
  assert.equal(response.json().error.code, 'unauthorized');
  assert.equal(calls, 0);
});

test('rejects empty and oversized prompts', async () => {
  const handler = createAiHandler({ env: enabledEnv(), fetchImpl: async () => { throw new Error('must not call network'); } });
  const emptyResponse = makeResponse();
  await handler(makeRequest({ body: { input: '   ' } }), emptyResponse);
  assert.equal(emptyResponse.statusCode, 400);

  const largeResponse = makeResponse();
  await handler(makeRequest({ body: { input: 'x'.repeat(8001) } }), largeResponse);
  assert.equal(largeResponse.statusCode, 413);
});

test('only active administrators can use the shared AI gateway', async () => {
  const fetchImpl = async (url) => {
    if (String(url).endsWith('/auth/v1/user')) return jsonResponse({ id: 'user-1' });
    return jsonResponse([{ id: 'user-1', role: 'student', status: 'active' }]);
  };
  const handler = createAiHandler({ env: enabledEnv(), fetchImpl });
  const response = makeResponse();

  await handler(makeRequest(), response);

  assert.equal(response.statusCode, 403);
  assert.equal(response.json().error.code, 'admin_required');
});

test('sends a bounded, non-stored Responses API request for an active administrator', async () => {
  const requests = [];
  const fetchImpl = async (url, options = {}) => {
    requests.push({ url: String(url), options });
    if (String(url).endsWith('/auth/v1/user')) return jsonResponse({ id: 'admin-1' });
    if (String(url).includes('/rest/v1/profiles?')) {
      return jsonResponse([{ id: 'admin-1', role: 'admin', status: 'active' }]);
    }
    return jsonResponse({
      id: 'resp_test',
      model: 'gpt-6.2-astra',
      output: [{ type: 'message', content: [{ type: 'output_text', text: 'Định luật Newton mô tả...' }] }],
      usage: { input_tokens: 12, output_tokens: 8 },
    });
  };
  const handler = createAiHandler({ env: enabledEnv(), fetchImpl });
  const response = makeResponse();

  await handler(makeRequest(), response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.json().output_text, 'Định luật Newton mô tả...');
  assert.equal(requests.length, 3);
  const openAiRequest = requests[2];
  assert.equal(openAiRequest.url, 'https://api.openai.com/v1/responses');
  assert.equal(openAiRequest.options.headers.Authorization, 'Bearer test-secret');
  const payload = JSON.parse(openAiRequest.options.body);
  assert.equal(payload.model, 'gpt-6.2-astra');
  assert.equal(payload.store, false);
  assert.equal(payload.max_output_tokens, 1200);
  assert.equal(payload.input, 'Giải thích định luật Newton.');
});

test('does not expose upstream error details to the client', async () => {
  const fetchImpl = async (url) => {
    if (String(url).endsWith('/auth/v1/user')) return jsonResponse({ id: 'admin-1' });
    if (String(url).includes('/rest/v1/profiles?')) return jsonResponse([{ id: 'admin-1', role: 'admin', status: 'active' }]);
    return jsonResponse({ error: { message: 'sensitive upstream diagnostic' } }, 429);
  };
  const handler = createAiHandler({ env: enabledEnv(), fetchImpl });
  const response = makeResponse();

  await handler(makeRequest(), response);

  assert.equal(response.statusCode, 429);
  assert.equal(response.json().error.code, 'openai_rate_limited');
  assert.equal(JSON.stringify(response.json()).includes('sensitive upstream diagnostic'), false);
});
