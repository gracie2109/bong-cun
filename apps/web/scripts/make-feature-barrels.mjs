// Step 7e of docs/ke-hoach-don-monorepo-con-lai.md. Finds every import that crosses from one
// feature module to another, writes the index.ts of the target with exactly the names that are
// used, and points the importers at that index. A feature's root format.ts holds pure helpers
// (dates, money, tones) and stays directly importable, so tests and other features do not load its screens. Without --apply it only prints the plan.
// Usage: node scripts/make-feature-barrels.mjs [--apply]
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";

const apply = process.argv.includes("--apply");
const src = resolve("src");

const featureOf = (file) => {
  const match = relative(src, file).replaceAll("\\", "/").match(/^features\/(admin|shop|shared)\/([^/]+)\//) ?? relative(src, file).replaceAll("\\", "/").match(/^features\/(auth|home)\//);
  return match ? (match[2] ? `${match[1]}/${match[2]}` : match[1]) : null;
};
const featureDir = (feature) => join(src, "features", ...feature.split("/"));

const resolveSpecifier = (specifier, fromFile) => {
  const base = specifier.startsWith("@/") ? join(src, specifier.slice(2)) : specifier.startsWith(".") ? resolve(dirname(fromFile), specifier) : null;
  if (!base) return null;
  for (const extension of ["", ".ts", ".vue"]) if (existsSync(base + extension) && /\.\w+$/.test(base + extension)) return base + extension;
  for (const extension of [".ts", ".vue"]) if (existsSync(join(base, `index${extension}`))) return join(base, `index${extension}`);
  return null;
};

const files = execFileSync("git", ["ls-files", "src/features"], { encoding: "utf8" })
  .split("\n")
  .filter((file) => /\.(ts|vue)$/.test(file))
  .map((file) => resolve(file));

// import [type] [Default][, { a, type b as c }] from "x"   (also `export { ... } from`)
const STATEMENT = /^(import|export)\s+(type\s+)?([\s\S]*?)\s+from\s+"([^"]+)";?[ \t]*$/gm;

const parseClause = (clause) => {
  const names = [];
  let rest = clause.trim();
  const braces = rest.match(/\{([\s\S]*)\}/);
  if (braces) {
    for (const part of braces[1].split(",").map((item) => item.trim()).filter(Boolean)) {
      const type = part.startsWith("type ");
      const [imported, local = imported] = part.replace(/^type\s+/, "").split(/\s+as\s+/).map((item) => item.trim());
      names.push({ imported, local, type });
    }
    rest = rest.replace(braces[0], "").replace(/,\s*$/, "").trim();
  }
  if (rest && !rest.startsWith("*")) names.push({ imported: "default", local: rest.replace(/,$/, "").trim(), type: false });
  return names;
};

// target feature -> target file -> exported names used by other features
const plan = new Map();
const edits = [];
for (const file of files) {
  const text = readFileSync(file, "utf8");
  const own = featureOf(file);
  let result = text;
  for (const match of text.matchAll(STATEMENT)) {
    const [statement, keyword, typeOnly, clause, specifier] = match;
    const target = resolveSpecifier(specifier, file);
    const feature = target && featureOf(target);
    if (!feature || feature === own || target === join(featureDir(feature), "index.ts") || target === join(featureDir(feature), "format.ts")) continue;
    if (clause.trim().startsWith("*")) throw new Error(`cannot handle ${statement} in ${file}`);
    const names = parseClause(clause).map((name) => ({ ...name, type: name.type || Boolean(typeOnly) }));
    const files = plan.get(feature) ?? new Map();
    plan.set(feature, files);
    const used = files.get(target) ?? new Map();
    files.set(target, used);
    const rewritten = names.map((name) => {
      const exported = name.imported === "default" ? basename(target).replace(/\.(ts|vue)$/, "") : name.imported;
      used.set(exported, { from: name.imported, type: name.type });
      return { ...name, exported };
    });
    const parts = rewritten.map((name) => `${name.type && !typeOnly ? "type " : ""}${name.exported === name.local ? name.exported : `${name.exported} as ${name.local}`}`);
    const line = `${keyword}${typeOnly ? " type" : ""} { ${parts.join(", ")} } from "@/features/${feature}";`;
    result = result.replace(statement, line);
  }
  if (result !== text) edits.push([file, result]);
}

const barrels = [];
for (const [feature, targets] of plan) {
  const lines = [`// Public surface of ${feature}: what other features may import. Everything else stays private.`];
  const owner = new Map();
  for (const [target, used] of [...targets].sort()) {
    const path = "./" + relative(featureDir(feature), target).replaceAll("\\", "/").replace(/\.ts$/, "").replace(/\/index$/, "");
    const named = [...used].sort().map(([exported, info]) => ({ exported, ...info }));
    for (const item of named) {
      if (owner.has(item.exported)) throw new Error(`${feature} exports ${item.exported} twice (${owner.get(item.exported)} and ${path})`);
      owner.set(item.exported, path);
    }
    const values = named.filter((item) => !item.type).map((item) => (item.from === "default" ? `default as ${item.exported}` : item.exported));
    const types = named.filter((item) => item.type).map((item) => item.exported);
    if (values.length) lines.push(`export { ${values.join(", ")} } from "${path}";`);
    if (types.length) lines.push(`export type { ${types.join(", ")} } from "${path}";`);
  }
  barrels.push([join(featureDir(feature), "index.ts"), lines.join("\n") + "\n"]);
}

console.log(`${barrels.length} barrels, ${edits.length} importing files`);
for (const [file] of barrels) console.log(`  ${relative(src, file)}${existsSync(file) ? " (exists!)" : ""}`);
if (apply) {
  for (const [file, text] of barrels) {
    if (existsSync(file)) throw new Error(`${file} already exists`);
    writeFileSync(file, text);
  }
  for (const [file, text] of edits) writeFileSync(file, text);
}
