# TSA Practice

A TSA exam practice platform. The current migration is moving the existing single-page application to React + Vite + React Router while preserving Supabase Auth, PostgreSQL, RLS, RPC-based workflows, and the Vercel deployment.

## Development

Requirements: Node.js 20.19+.

```bash
npm install
npm run dev
```

Set the following environment variables for local development:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Use only the Supabase publishable/anon key in the browser. Never use `service_role`, Supabase secret keys, JWT secrets, or database passwords in frontend code.

## Build

```bash
npm run build
npm run preview
```

## Migration status

The current React client contains the authentication screens, account view, and published-exam dashboard. The previous complete application is retained at `/legacy/index.html` for the exam room, results, history, authoring, imports, and administration while those modules are migrated and tested.

See [the baseline audit](docs/react-migration-audit.md) before changing Supabase schema or migration history.
