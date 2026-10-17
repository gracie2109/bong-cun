// apps/web imports the Capacitor plugins and apps/mobile lets `cap sync` wire them into Android,
// so both package.json files must list every @capacitor/* plugin web uses, with the same range.
import { readFileSync } from "node:fs";

const read = (path) => JSON.parse(readFileSync(new URL(path, import.meta.url), "utf8"));
const capacitorDeps = (pkg) =>
  Object.fromEntries(
    Object.entries({ ...pkg.dependencies, ...pkg.devDependencies }).filter(([name]) => name.startsWith("@capacitor/")),
  );

const web = capacitorDeps(read("../../web/package.json"));
const mobile = capacitorDeps(read("../package.json"));

const problems = Object.entries(web).flatMap(([name, range]) => {
  if (!mobile[name]) return [`${name} is used by apps/web but missing from apps/mobile`];
  return mobile[name] === range ? [] : [`${name}: apps/web has ${range}, apps/mobile has ${mobile[name]}`];
});

if (problems.length) {
  console.error(problems.join("\n"));
  process.exit(1);
}
console.log(`Capacitor plugin versions match (${Object.keys(web).length} shared).`);
