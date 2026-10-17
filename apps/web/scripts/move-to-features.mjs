// Moves src/queries and src/composables files into src/features (step 7 of
// docs/ke-hoach-don-monorepo-con-lai.md) with `git mv`, and rewrites every import that points at
// them. Nothing else changes in the files. Without --apply it only prints what it would move.
// Usage: node scripts/move-to-features.mjs <prefix>... [--apply]   e.g. shop/ shared/
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const prefixes = args.filter((arg) => !arg.startsWith("--"));
if (!prefixes.length) throw new Error("give at least one destination prefix, e.g. shop/");

const root = resolve(".");
const src = join(root, "src");
const EXTENSIONS = ["", ".ts", ".vue", ".js"];

const owners = JSON.parse(execFileSync("node", ["scripts/feature-owners.mjs", "--json"], { encoding: "utf8", maxBuffer: 1 << 28 }));
const moves = new Map(); // absolute old path -> absolute new path
for (const row of owners) {
  if (!row.to.startsWith("features/") || !prefixes.some((prefix) => row.to.startsWith(`features/${prefix}`))) continue;
  moves.set(resolve(row.file), join(src, row.to, basename(row.file)));
}

const files = execFileSync("git", ["ls-files", "src", "tests"], { encoding: "utf8" })
  .split("\n")
  .filter((file) => /\.(ts|vue)$/.test(file))
  .map((file) => resolve(file));

const resolveSpecifier = (specifier, fromFile) => {
  const base = specifier.startsWith("@/") ? join(src, specifier.slice(2)) : specifier.startsWith(".") ? resolve(dirname(fromFile), specifier) : null;
  if (!base) return null;
  for (const extension of EXTENSIONS) if (existsSync(base + extension) && /\.\w+$/.test(base + extension) && !existsSync(base + extension + "/")) return base + extension;
  for (const extension of [".ts", ".vue"]) if (existsSync(join(base, `index${extension}`))) return join(base, `index${extension}`);
  return null;
};

const aliasOf = (target, keepIndexAsDirectory) => {
  let path = "@/" + relative(src, target).replaceAll("\\\\", "/");
  path = path.replace(/\.(ts|vue)$/, "");
  return keepIndexAsDirectory ? path.replace(/\/index$/, "") : path;
};

const SPECIFIER = /((?:from|import\(|mock\()\s*)"([^"]+)"/g;
let rewritten = 0;
const edits = [];
for (const file of files) {
  const text = readFileSync(file, "utf8");
  const movedFile = moves.has(file);
  const next = text.replace(SPECIFIER, (match, lead, specifier) => {
    const target = resolveSpecifier(specifier, file);
    if (!target) return match;
    const destination = moves.get(target);
    const relativeInMovedFile = movedFile && specifier.startsWith(".");
    if (!destination && !relativeInMovedFile) return match;
    const asDirectory = !/\.(ts|vue)$/.test(specifier) && /\/index\.(ts|vue)$/.test(target);
    const replacement = aliasOf(destination ?? target, asDirectory);
    if (replacement === specifier) return match;
    rewritten += 1;
    return `${lead}"${replacement}"`;
  });
  if (next !== text) edits.push([file, next]);
}

console.log(`${moves.size} files to move, ${rewritten} imports to rewrite in ${edits.length} files`);
for (const [from, to] of moves) console.log(`  ${relative(root, from)} -> ${relative(root, to)}`);
if (!apply) process.exit(0);

for (const [file, next] of edits) writeFileSync(file, next);
for (const [from, to] of moves) {
  execFileSync("mkdir", ["-p", dirname(to)]);
  execFileSync("git", ["mv", from, to]);
}
