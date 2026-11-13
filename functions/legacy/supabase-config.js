export async function onRequestGet({ env }) {
  const url = env.VITE_SUPABASE_URL || env.SUPABASE_URL || '';
  const publishableKey =
    env.VITE_SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_PUBLISHABLE_KEY || '';

  if (!url || !publishableKey) {
    return new Response('Supabase Preview configuration is missing.', {
      status: 503,
      headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
    });
  }

  const payload = JSON.stringify({ url, publishableKey });
  return new Response(`window.__SUPABASE_CONFIG__ = ${payload};`, {
    headers: {
      'Content-Type': 'application/javascript; charset=utf-8',
      'Cache-Control': 'no-store, max-age=0',
      'X-Content-Type-Options': 'nosniff',
    },
  });
}
