import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const supabaseUrl = process.env.VITE_SUPABASE_URL || '';
const publishableKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY || '';

const outputPath = resolve('dist/legacy/supabase-config.js');
await mkdir(dirname(outputPath), { recursive: true });
const payload = JSON.stringify({ url: supabaseUrl, publishableKey });
await writeFile(outputPath, 'window.__SUPABASE_CONFIG__ = ' + payload + ';\n', 'utf8');
