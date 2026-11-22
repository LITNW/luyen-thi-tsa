# LIT OpenAI AI Gateway

## Purpose

This is the shared, server-side OpenAI entry point for future LIT AI features. It deliberately does not add a student-facing AI chat or connect any existing exam workflow yet.

## Architecture

- React code calls `requestAiResponse(input)` from `src/lib/ai.js`.
- The helper obtains the current Supabase Auth access token and calls `POST /api/ai/respond`.
- The Vercel Node Function validates the token with Supabase Auth, then reads the caller's own `profiles` row using the caller's JWT and the public publishable key.
- Version 1 permits only profiles with `role = admin` and `status = active`.
- Only the Vercel function reads `OPENAI_API_KEY`. The key is never included in frontend bundles or responses.

## Runtime configuration

Required Vercel environment variables:

- `OPENAI_API_KEY` — sensitive secret; already configured for the Vercel Production, Preview, and Development targets.
- `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` — public Supabase connection settings already used by the client.

Optional:

- `OPENAI_MODEL` — model ID override. Defaults to `gpt-6.2-astra`.
- `AI_GATEWAY_ENABLED` — must equal `true` to permit requests. If unset or any other value, the endpoint returns `503 ai_gateway_disabled`.

Keep `AI_GATEWAY_ENABLED` disabled in Production until the Preview workflow has been reviewed and explicitly approved. Enable it only for the dedicated Preview branch while testing.

## Request contract

```js
import { requestAiResponse } from './lib/ai.js';

const result = await requestAiResponse('Explain Newton\'s second law.');
console.log(result.output_text);
```

The endpoint accepts only a JSON `input` string. It enforces an 8,000-character input limit and a fixed 1,200-token output ceiling. The model is selected by server configuration, never by the browser.

OpenAI is called through the Responses API with `store: false`. Prompt content, API credentials, and raw upstream error bodies are not logged or returned to the client. Responses include a request ID where OpenAI provides one.

## Security and rollout constraints

- POST only; requires a valid Supabase bearer token.
- Active Admin profile required in v1.
- Supabase profile verification uses the caller's JWT; no service-role key is used.
- No database migration and no Supabase Production changes are required.
- No frontend feature or exam workflow is changed.
- Vercel Function is configured with a 45-second maximum duration.
- The initial gateway has bounded prompts/output but does not yet implement a durable per-user quota or database-backed rate limiter. Do not enable it for student-wide access until those controls, usage accounting, privacy rules, and budget alerts are in place.
- This route is hosted by Vercel. Cloudflare static/preview deployments do not receive this Vercel Function; a separate Cloudflare Worker adapter and secret would be required before using the gateway there.

## Verification

Run:

```sh
npm test
npm run build
```

Then verify the dedicated Vercel Preview deployment with an active Admin account. Keep Production disabled until Preview checks pass and the rollout is approved.
