const MAX_INPUT_CHARS = 8_000;
const MAX_OUTPUT_TOKENS = 1_200;
const OPENAI_RESPONSES_URL = 'https://api.openai.com/v1/responses';
const DEFAULT_MODEL = 'gpt-6.2-astra';

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.end(JSON.stringify(payload));
}

function parseRequestBody(body) {
  if (body && typeof body === 'object' && !Buffer.isBuffer(body)) return body;
  if (typeof body === 'string') {
    try {
      return JSON.parse(body);
    } catch {
      return null;
    }
  }
  return null;
}

function extractOutputText(response) {
  if (typeof response?.output_text === 'string') return response.output_text.trim();
  const chunks = [];
  for (const item of response?.output ?? []) {
    if (item?.type !== 'message' || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (content?.type === 'output_text' && typeof content.text === 'string') {
        chunks.push(content.text);
      }
    }
  }
  return chunks.join('\n').trim();
}

function bearerToken(req) {
  const value = req.headers?.authorization ?? req.headers?.Authorization ?? '';
  if (typeof value !== 'string') return '';
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? '';
}

export function createAiHandler({ env = process.env, fetchImpl = fetch } = {}) {
  return async function aiHandler(req, res) {
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST');
      return sendJson(res, 405, { error: { code: 'method_not_allowed' } });
    }

    if (env.AI_GATEWAY_ENABLED !== 'true') {
      return sendJson(res, 503, { error: { code: 'ai_gateway_disabled' } });
    }

    const openAiKey = env.OPENAI_API_KEY;
    const supabaseUrl = (env.VITE_SUPABASE_URL || env.SUPABASE_URL || '').replace(/\/+$/, '');
    const publishableKey = env.VITE_SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_PUBLISHABLE_KEY;
    if (!openAiKey || !supabaseUrl || !publishableKey) {
      return sendJson(res, 503, { error: { code: 'ai_gateway_configuration_missing' } });
    }

    const contentLength = Number(req.headers?.['content-length'] ?? 0);
    if (Number.isFinite(contentLength) && contentLength > 16_384) {
      return sendJson(res, 413, { error: { code: 'request_too_large' } });
    }

    const token = bearerToken(req);
    if (!token) {
      return sendJson(res, 401, { error: { code: 'unauthorized' } });
    }

    const body = parseRequestBody(req.body);
    const input = typeof body?.input === 'string' ? body.input.trim() : '';
    if (!input) {
      return sendJson(res, 400, { error: { code: 'input_required' } });
    }
    if (input.length > MAX_INPUT_CHARS) {
      return sendJson(res, 413, { error: { code: 'input_too_large', max_chars: MAX_INPUT_CHARS } });
    }

    let user;
    let profiles;
    try {
      const authResponse = await fetchImpl(`${supabaseUrl}/auth/v1/user`, {
        method: 'GET',
        headers: {
          apikey: publishableKey,
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
        },
      });
      if (!authResponse.ok) {
        return sendJson(res, 401, { error: { code: 'invalid_session' } });
      }
      user = await authResponse.json();
      if (!user?.id) return sendJson(res, 401, { error: { code: 'invalid_session' } });

      const profileUrl = new URL('/rest/v1/profiles', supabaseUrl);
      profileUrl.searchParams.set('id', `eq.${user.id}`);
      profileUrl.searchParams.set('select', 'id,role,status');
      profileUrl.searchParams.set('limit', '1');
      const profileResponse = await fetchImpl(profileUrl, {
        method: 'GET',
        headers: {
          apikey: publishableKey,
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
        },
      });
      if (!profileResponse.ok) {
        return sendJson(res, 503, { error: { code: 'profile_verification_unavailable' } });
      }
      profiles = await profileResponse.json();
    } catch {
      return sendJson(res, 503, { error: { code: 'authentication_service_unavailable' } });
    }

    const profile = Array.isArray(profiles) ? profiles[0] : null;
    if (profile?.id !== user.id || profile.role !== 'admin' || profile.status !== 'active') {
      return sendJson(res, 403, { error: { code: 'admin_required' } });
    }

    const model = env.OPENAI_MODEL || DEFAULT_MODEL;
    let openAiResponse;
    try {
      openAiResponse = await fetchImpl(OPENAI_RESPONSES_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${openAiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          input,
          max_output_tokens: MAX_OUTPUT_TOKENS,
          store: false,
        }),
        signal: AbortSignal.timeout(25_000),
      });
    } catch (error) {
      const timedOut = error?.name === 'TimeoutError' || error?.name === 'AbortError';
      return sendJson(res, timedOut ? 504 : 502, {
        error: { code: timedOut ? 'openai_timeout' : 'openai_unavailable' },
      });
    }

    if (!openAiResponse.ok) {
      return sendJson(res, openAiResponse.status === 429 ? 429 : 502, {
        error: {
          code: openAiResponse.status === 429 ? 'openai_rate_limited' : 'openai_upstream_error',
          request_id: openAiResponse.headers?.get?.('x-request-id') || undefined,
        },
      });
    }

    let result;
    try {
      result = await openAiResponse.json();
    } catch {
      return sendJson(res, 502, { error: { code: 'openai_invalid_response' } });
    }

    const outputText = extractOutputText(result);
    if (!outputText) {
      return sendJson(res, 502, {
        error: {
          code: 'openai_empty_response',
          request_id: openAiResponse.headers?.get?.('x-request-id') || undefined,
        },
      });
    }

    return sendJson(res, 200, {
      id: result.id,
      model: result.model || model,
      output_text: outputText,
      usage: result.usage ? {
        input_tokens: result.usage.input_tokens,
        output_tokens: result.usage.output_tokens,
      } : null,
      request_id: openAiResponse.headers?.get?.('x-request-id') || undefined,
    });
  };
}

export default function handler(req, res) {
  return createAiHandler()(req, res);
}
