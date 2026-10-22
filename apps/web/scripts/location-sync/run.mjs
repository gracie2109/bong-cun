// Downloads the Location Service snapshot and writes the migration that brings the cache up to date.
// Usage: node apps/web/scripts/location-sync/run.mjs [--dry-run] [--allow-count-change] [--from-file snapshot.ndjson]
//   [--state path] [--migrations-dir path] [--report path] [--today YYYY-MM-DD]
// Env: LOCATION_SERVICE_URL, LOCATION_SERVICE_KEY (not needed with --from-file).
import { appendFileSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { runChecks } from "./checks.mjs";
import { diffState } from "./diffState.mjs";
import { fetchSnapshot } from "./fetchSnapshot.mjs";
import { migrationFileName, nextMigrationVersion } from "./migrationName.mjs";
import { parseNdjson } from "./parseNdjson.mjs";
import { selectGhn, selectUnits } from "./selectRows.mjs";
import { catalogForState, readState, writeState } from "./state.mjs";
import { writeMigration } from "./writeMigration.mjs";
import { writeReport } from "./writeReport.mjs";

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name, fallback) => (args.includes(name) ? args[args.indexOf(name) + 1] : fallback);

const statePath = option("--state", "supabase/data/locations/state.json");
const migrationsDir = option("--migrations-dir", "supabase/migrations");
const reportPath = option("--report", "location-sync-report.md");
const now = new Date();
const today = option("--today", now.toISOString().slice(0, 10));

const setOutput = (name, value) => {
  if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${value}\n`);
};

const main = async () => {
  const text = option("--from-file") ? readFileSync(option("--from-file"), "utf8") : await fetchSnapshot(process.env);
  const { catalog, locations, providerCodes } = parseNdjson(text);
  const previous = readState(statePath);

  const units = selectUnits(locations, previous.units);
  const ghn = selectGhn(providerCodes);
  const diff = diffState(previous, units, ghn, today);

  const errors = runChecks({ catalog, previous, units, ghn, nextUnits: diff.nextUnits, retired: diff.retired, allowCountChange: flag("--allow-count-change") });
  if (errors.length) {
    console.error(`Location sync stopped:\n${errors.map((e) => `- ${e}`).join("\n")}`);
    process.exit(1);
  }
  if (diff.changedUnits.length === 0 && diff.changedGhn.length === 0) {
    console.log("Nothing changed since the last sync.");
    setOutput("changed", "false");
    return;
  }

  const { sql, counts } = writeMigration({ catalog: catalogForState(catalog), nextUnits: diff.nextUnits, nextGhn: diff.nextGhn, diff });
  const fileName = migrationFileName(nextMigrationVersion(readdirSync(migrationsDir), now), catalog.id);
  const report = writeReport({ catalog, counts, diff, previous, fileName });
  console.log(report);
  setOutput("changed", "true");
  setOutput("catalog_id", catalog.id);
  if (flag("--dry-run")) return;

  writeFileSync(join(migrationsDir, fileName), sql);
  writeState(statePath, { catalog: catalogForState(catalog), units: diff.nextUnits, ghn: diff.nextGhn });
  writeFileSync(reportPath, report);
  setOutput("migration", fileName);
};

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
