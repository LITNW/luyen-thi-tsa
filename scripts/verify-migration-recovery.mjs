import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const manifest = JSON.parse(
  readFileSync("supabase/migration-recovery-manifest.json", "utf8")
);
const migrationDir = "supabase/migrations";
const errors = [];
const expected = new Set();

if (manifest.migrations.length !== 17) {
  errors.push(`Expected 17 recovered Production migrations; found ${manifest.migrations.length}.`);
}

for (const migration of manifest.migrations) {
  const filename = `${migration.version}_${migration.name}.sql`;
  const filepath = join(migrationDir, filename);
  expected.add(filename);

  let content;
  try {
    content = readFileSync(filepath, "utf8").replace(/\r\n/g, "\n");
  } catch {
    errors.push(`Missing recovered migration: ${filepath}`);
    continue;
  }

  const lines = content.split("\n");
  if (lines[0] !== "-- Recovered from Supabase Production migration ledger.") {
    errors.push(`${filename}: recovery header missing.`);
    continue;
  }

  const hashMatch = lines[1]?.match(/^-- Original statement MD5: ([a-f0-9]{32})$/);
  if (!hashMatch || hashMatch[1] !== migration.source_md5) {
    errors.push(`${filename}: source MD5 header does not match manifest.`);
    continue;
  }

  let bodyStart = 2;
  if (migration.redacted) {
    if (!lines[bodyStart]?.startsWith("-- Recovery redaction:")) {
      errors.push(`${filename}: expected redaction notice is missing.`);
      continue;
    }
    bodyStart += 1;
    if (!content.includes("SET_ADMIN_EMAIL_BEFORE_APPLY")) {
      errors.push(`${filename}: bootstrap placeholder is missing.`);
    }
    const emailPattern = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;
    if (emailPattern.test(content)) {
      errors.push(`${filename}: an email address must not be committed in the recovery copy.`);
    }
  }

  if (lines[bodyStart] !== "") {
    errors.push(`${filename}: expected blank line before recovered SQL body.`);
    continue;
  }
  bodyStart += 1;

  if (!migration.redacted) {
    const sqlBody = "\n" + lines.slice(bodyStart).join("\n");
    const actual = createHash("md5").update(sqlBody, "utf8").digest("hex");
    if (actual !== migration.source_md5) {
      errors.push(`${filename}: SQL body checksum mismatch (expected ${migration.source_md5}, got ${actual}).`);
    }
  }
}

for (const pending of manifest.pending ?? []) {
  const filename = `${pending.version}_${pending.name}.sql`;
  expected.add(filename);
  if (!readdirSync(migrationDir).includes(filename)) {
    errors.push(`Missing pending migration: ${join(migrationDir, filename)}`);
  }
}

const activeSqlFiles = readdirSync(migrationDir).filter((name) => name.endsWith(".sql"));
for (const filename of activeSqlFiles) {
  if (!expected.has(filename)) {
    errors.push(`Unexpected SQL file in active migration directory: ${filename}`);
  }
}

if (errors.length) {
  for (const error of errors) console.error(`ERROR: ${error}`);
  process.exitCode = 1;
} else {
  console.log(
    `Verified ${manifest.migrations.length} recovered Production migrations and ${(manifest.pending ?? []).length} pending migration(s).`
  );
}
