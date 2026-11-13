import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const manifest = JSON.parse(
  readFileSync("supabase/migration-recovery-manifest.json", "utf8")
);
const migrationDir = "supabase/migrations";
const errors = [];
const expected = new Set();
const recovered = manifest.migrations ?? [];
const subsequent = manifest.subsequent_migrations ?? [];

if (recovered.length !== 17) {
  errors.push(`Expected 17 recovered Production migrations; found ${recovered.length}.`);
}

let previousVersion = "";
for (const migration of recovered) {
  const filename = `${migration.version}_${migration.name}.sql`;
  const filepath = join(migrationDir, filename);
  if (expected.has(filename)) {
    errors.push(`Duplicate migration manifest entry: ${filename}`);
  }
  expected.add(filename);

  if (previousVersion && migration.version <= previousVersion) {
    errors.push(`Recovered migration order is not strictly increasing at ${filename}.`);
  }
  previousVersion = migration.version;

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

  if (!migration.redacted) {
    // Keep the original leading newline (if present) when hashing the stored SQL body.
    const sqlBody = lines.slice(bodyStart).join("\n");
    const actual = createHash("md5").update(sqlBody, "utf8").digest("hex");
    if (actual !== migration.source_md5) {
      errors.push(`${filename}: SQL body checksum mismatch (expected ${migration.source_md5}, got ${actual}).`);
    }
  }
}

for (const migration of subsequent) {
  const filename = `${migration.version}_${migration.name}.sql`;
  const filepath = join(migrationDir, filename);
  if (expected.has(filename)) {
    errors.push(`Duplicate migration entry across manifest sections: ${filename}`);
  }
  expected.add(filename);

  if (migration.version <= previousVersion) {
    errors.push(`Subsequent migration ${filename} must sort after the recovered chain.`);
  }
  previousVersion = migration.version;

  if (!readFileExists(filepath)) {
    errors.push(`Missing subsequent migration: ${filepath}`);
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
    `Verified ${recovered.length} recovered Production migration fingerprints and ${subsequent.length} subsequent migration file(s).`
  );
}

function readFileExists(filepath) {
  try {
    readFileSync(filepath);
    return true;
  } catch {
    return false;
  }
}
