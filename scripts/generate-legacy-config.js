import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

const supabaseUrl = process.env.VITE_SUPABASE_URL || '';
const publishableKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY || '';

const outputPath = resolve('dist/legacy/supabase-config.js');
await mkdir(dirname(outputPath), { recursive: true });
const payload = JSON.stringify({ url: supabaseUrl, publishableKey });
await writeFile(outputPath, 'window.__SUPABASE_CONFIG__ = ' + payload + ';\n', 'utf8');

const manifestPath = resolve('dist/.vite/manifest.json');
const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
const legacyAnalyticsEntry = manifest['src/legacy-analytics.js']?.file;
if (!legacyAnalyticsEntry) {
  throw new Error('The legacy analytics bundle is missing from the Vite build manifest.');
}

const legacyHtmlPath = resolve('dist/legacy/index.html');
const legacyHtml = await readFile(legacyHtmlPath, 'utf8');
const analyticsScript = '<script type="module" src="/' + legacyAnalyticsEntry + '"></script>';
if (!legacyHtml.includes(legacyAnalyticsEntry)) {
  const updatedHtml = legacyHtml.replace('</body>', analyticsScript + '</body>');
  if (updatedHtml === legacyHtml) {
    throw new Error('Could not find the closing body tag in the legacy application HTML.');
  }
  await writeFile(legacyHtmlPath, updatedHtml, 'utf8');
}
