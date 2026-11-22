import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');
const migrationsDir = fileURLToPath(new URL('../ops/staging-history/supabase/migrations/', import.meta.url));

test('Staging history adapter is scoped to the existing Staging project', () => {
  const manifest = JSON.parse(read('../ops/staging-history/staging-history-manifest.json'));
  assert.equal(manifest.project_ref, 'cppalwtdkditlhojpeyc');
  assert.equal(manifest.expected_ledger_rows, 38);
  assert.equal(manifest.applied_migrations.length, 38);
  assert.equal(manifest.target_migration, '20261119160000_education_course_categories.sql');
  assert.doesNotMatch(JSON.stringify(manifest), /hwqtsopvpucadgpkigqz/);
});

test('every already-applied Staging version has a fail-closed marker', () => {
  const manifest = JSON.parse(read('../ops/staging-history/staging-history-manifest.json'));
  const files = readdirSync(migrationsDir).filter((name) => name.endsWith('.sql')).sort();
  const expected = [...manifest.applied_migrations.map((row) => row.marker_file), manifest.target_migration].sort();
  assert.deepEqual(files, expected);
  for (const row of manifest.applied_migrations) {
    const marker = read('../ops/staging-history/supabase/migrations/' + row.marker_file);
    assert.match(marker, /STAGING HISTORY MARKER ONLY/);
    assert.match(marker, /raise exception/i);
    assert.ok(marker.includes(row.version));
    assert.ok(marker.includes(row.statement_md5));
  }
});

test('Staging adapter applies the same reviewed category migration as the canonical chain', () => {
  const adapterMigration = read('../ops/staging-history/supabase/migrations/20261119160000_education_course_categories.sql');
  const canonicalMigration = read('../supabase/migrations/20261119160000_education_course_categories.sql');
  assert.equal(adapterMigration, canonicalMigration);
});

test('Staging preflight covers every remote version and its SQL fingerprint', () => {
  const manifest = JSON.parse(read('../ops/staging-history/staging-history-manifest.json'));
  const preflight = read('../ops/staging-history/preflight.sql');
  for (const row of manifest.applied_migrations) {
    assert.ok(preflight.includes("('" + row.version + "','" + row.name + "','" + row.statement_md5 + "')"));
  }
  assert.match(preflight, /full outer join actual a using\(version\)/i);
  assert.match(preflight, /row_count_matches/i);
  assert.match(preflight, /archived_category_preservation_present/i);
  assert.match(preflight, /staging_signup_fallback_present/i);
});
