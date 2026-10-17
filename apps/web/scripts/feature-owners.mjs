// Prints which feature modules use each file of src/queries and src/composables, and where the file
// should live once it moves into src/features (docs/ke-hoach-don-monorepo-con-lai.md, step 7).
// Usage: node scripts/feature-owners.mjs [--json]
import { execFileSync } from "node:child_process";
import { basename } from "node:path";
import { STAY, decisions } from "./featureDecisions.mjs";

// Stay in src/queries or src/composables: infrastructure and helpers with no business owner.
const INFRA = new Set(["keys", "invalidate", "notify"]);

const raw = execFileSync("npx", ["depcruise", "src", "--config", ".dependency-cruiser.cjs", "--output-type", "json"], {
  encoding: "utf8",
  maxBuffer: 1 << 28,
});
const modules = JSON.parse(raw).modules;
const dependents = new Map(modules.map((m) => [m.source, m.dependents]));

// features/<area>/<module>/... -> "area/module"; features/<area>/... -> "area"
const featureOf = (source) => {
  const match = source.match(/^src\/features\/(admin|shop|shared|auth|home)\/?([^/]*)/);
  if (!match) return null;
  const [, area, rest] = match;
  return area === "admin" || area === "shop" || area === "shared" ? `${area}/${rest.includes(".") ? "" : rest}`.replace(/\/$/, "") : area;
};

// Feature modules that reach a file through plain imports, stopping at the first feature on each path.
const featuresReaching = (start) => {
  const found = new Map();
  const seen = new Set([start]);
  const queue = [start];
  while (queue.length) {
    const current = queue.pop();
    for (const source of dependents.get(current) ?? []) {
      if (seen.has(source)) continue;
      seen.add(source);
      const feature = featureOf(source);
      if (feature) found.set(feature, (found.get(feature) ?? 0) + 1);
      else queue.push(source);
    }
  }
  return found;
};

const areaOf = (feature) => feature.split("/")[0];

const destination = (file, users) => {
  const key = file.replace(/^src\//, "").replace(/\.(ts|vue)$/, "");
  const kind = file.includes("/queries/") ? "queries" : "composables";
  const decided = decisions[key];
  if (decided === STAY) return { to: `src/${kind} (stays)`, note: "generic or unused" };
  if (decided) return { to: `features/${decided}/${kind}`, note: "decided in featureDecisions.mjs" };
  const name = basename(file).replace(/\.(ts|vue)$/, "");
  if (users.size === 0) return { to: "UNUSED", note: "no feature imports it" };
  const areas = new Set([...users.keys()].map(areaOf));
  if (areas.has("admin") && areas.has("shop")) return { to: `features/shared/<module>/${kind}`, note: "admin and shop" };
  const modules = [...users.keys()];
  if (modules.length === 1) return { to: `features/${modules[0]}/${kind}`, note: "one module" };
  const named = modules.find((module) => name.toLowerCase().startsWith(module.split("/").pop() ?? "?"));
  if (named) return { to: `features/${named}/${kind}`, note: `owner by name, also used by ${modules.length - 1} more` };
  const top = [...users.entries()].sort((a, b) => b[1] - a[1])[0][0];
  return { to: `features/${top}/${kind}`, note: `DECIDE: ${modules.length} modules, most importers in ${top}` };
};

const rows = modules
  .map((m) => m.source)
  .filter((source) => /^src\/(queries|composables)\//.test(source))
  .filter((source) => !INFRA.has(basename(source).replace(/\.ts$/, "")))
  .sort()
  .map((file) => {
    const users = featuresReaching(file);
    return { file, users: Object.fromEntries(users), ...destination(file, users) };
  });

if (process.argv.includes("--json")) console.log(JSON.stringify(rows, null, 2));
else {
  console.log("| File | Used by | Destination | Note |\n| --- | --- | --- | --- |");
  for (const row of rows) console.log(`| \`${row.file}\` | ${Object.keys(row.users).join(", ") || "-"} | \`${row.to}\` | ${row.note} |`);
}
