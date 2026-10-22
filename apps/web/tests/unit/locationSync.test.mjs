import { mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { runChecks } from "../../scripts/location-sync/checks.mjs";
import { diffState } from "../../scripts/location-sync/diffState.mjs";
import { migrationFileName, nextMigrationVersion } from "../../scripts/location-sync/migrationName.mjs";
import { parseNdjson } from "../../scripts/location-sync/parseNdjson.mjs";
import { selectGhn, selectUnits } from "../../scripts/location-sync/selectRows.mjs";
import { emptyState } from "../../scripts/location-sync/state.mjs";
import { writeMigration } from "../../scripts/location-sync/writeMigration.mjs";

const fixturePath = fileURLToPath(new URL("../fixtures/location-snapshot.ndjson", import.meta.url));
const runScript = fileURLToPath(new URL("../../scripts/location-sync/run.mjs", import.meta.url));
const fixture = readFileSync(fixturePath, "utf8");
const P1 = "vn_aaaaaaaaaaaaaaaaaaaa";
const C1 = "vn_cccccccccccccccccccc";
const OLD_COMMUNE = "vn_gggggggggggggggggggg";

const firstSync = () => {
  const parsed = parseNdjson(fixture);
  const previous = emptyState();
  const units = selectUnits(parsed.locations, previous.units);
  const ghn = selectGhn(parsed.providerCodes);
  return { parsed, previous, units, ghn, diff: diffState(previous, units, ghn, "2026-11-01") };
};

describe("parseNdjson", () => {
  it("reads the catalog, locations and GHN codes, and ignores successions", () => {
    const { catalog, locations, providerCodes } = parseNdjson(fixture);
    expect(catalog.id).toBe("fixture-2025-07-01");
    expect(locations).toHaveLength(7);
    expect(providerCodes).toHaveLength(2);
  });

  it("names the line of a bad row", () => {
    expect(() => parseNdjson('{"type":"location","code":"nope"}\n')).toThrow(/line 1: bad code/);
    expect(() => parseNdjson("not json\n")).toThrow(/line 1: not JSON/);
  });
});

describe("selectUnits", () => {
  it("keeps active provinces and communes only, and no district or never-cached retired unit", () => {
    const { units } = firstSync();
    expect(Object.keys(units)).toHaveLength(5);
    expect(units[OLD_COMMUNE]).toBeUndefined();
  });

  it("keeps updating a unit it already holds when that unit retires", () => {
    const { parsed, diff } = firstSync();
    const retired = parsed.locations.map((row) => (row.code === C1 ? { ...row, status: "retired", effective_to: "2026-12-31" } : row));
    const next = selectUnits(retired, diff.nextUnits);
    expect(next[C1].status).toBe("retired");
  });
});

describe("diffState", () => {
  it("writes everything the first time and nothing the second time", () => {
    const first = firstSync();
    expect(first.diff.changedUnits).toHaveLength(5);
    expect(first.diff.changedUnits.slice(0, 2).every((code) => first.diff.nextUnits[code].level === "province")).toBe(true);
    const state = { catalog: null, units: first.diff.nextUnits, ghn: first.diff.nextGhn };
    const again = diffState(state, first.units, first.ghn, "2026-11-02");
    expect(again.changedUnits).toEqual([]);
    expect(again.changedGhn).toEqual([]);
  });

  it("retires a unit the snapshot no longer lists, and deactivates a GHN code that disappeared", () => {
    const first = firstSync();
    const state = { catalog: null, units: first.diff.nextUnits, ghn: first.diff.nextGhn };
    const { [C1]: _gone, ...rest } = first.units;
    const { [C1]: _goneGhn, ...restGhn } = first.ghn;
    const next = diffState(state, rest, restGhn, "2026-11-02");
    expect(next.nextUnits[C1]).toMatchObject({ status: "retired", effective_to: "2026-11-02" });
    expect(next.nextGhn[C1].active).toBe(false);
    expect(next.retired).toBe(1);
  });
});

describe("runChecks", () => {
  const input = () => {
    const { parsed, previous, units, ghn, diff } = firstSync();
    return { catalog: parsed.catalog, previous, units, ghn, nextUnits: diff.nextUnits, retired: diff.retired, allowCountChange: true };
  };

  it("passes the fixture when counts may change", () => {
    expect(runChecks(input())).toEqual([]);
  });

  it("stops when the province count is not 34", () => {
    expect(runChecks({ ...input(), allowCountChange: false }).join()).toMatch(/2 active provinces, expected 34/);
  });

  it("stops on an older catalog", () => {
    const previous = { ...emptyState(), catalog: { effective_on: "2026-01-01" } };
    expect(runChecks({ ...input(), previous }).join()).toMatch(/older than/);
  });

  it("stops on a commune whose province is not active", () => {
    const base = input();
    const units = { ...base.units };
    delete units[P1];
    expect(runChecks({ ...base, units }).join()).toMatch(/has no active province/);
  });

  it("stops on a GHN mapping to a unit that is not cached", () => {
    const base = input();
    const ghn = { ...base.ghn, vn_zzzzzzzzzzzzzzzzzzzz: base.ghn[P1] };
    expect(runChecks({ ...base, ghn }).join()).toMatch(/not cached/);
  });

  it("stops when too many units retire at once", () => {
    expect(runChecks({ ...input(), allowCountChange: false, retired: 51 }).join()).toMatch(/51 units would retire/);
  });
});

describe("migrationName", () => {
  it("uses the clock when it is later than every migration", () => {
    expect(nextMigrationVersion(["20261001000000_a.sql"], new Date("2026-11-05T01:02:03Z"))).toBe("20261105010203");
  });

  it("goes one minute past the newest migration when the clock is behind", () => {
    expect(nextMigrationVersion(["20261101010000_location_cache.sql"], new Date("2026-10-22T09:00:00Z"))).toBe("20261101010100");
  });

  it("names the file after the catalog", () => {
    expect(migrationFileName("20261101010100", "Fixture-2025-07-01")).toBe("20261101010100_location_sync_fixture_2025_07_01.sql");
  });
});

describe("writeMigration", () => {
  it("is the same SQL for the same input, ends with a count check and escapes quotes", () => {
    const { parsed, diff } = firstSync();
    const catalog = { id: parsed.catalog.id, source: "o'brien", source_ref: null, effective_on: "2025-07-01", extracted_at: null, checksum: null };
    const one = writeMigration({ catalog, nextUnits: diff.nextUnits, nextGhn: diff.nextGhn, diff });
    const two = writeMigration({ catalog, nextUnits: diff.nextUnits, nextGhn: diff.nextGhn, diff });
    expect(one.sql).toBe(two.sql);
    expect(one.sql).toContain("'o''brien'");
    expect(one.sql).toContain("on conflict (code) do update");
    expect(one.sql).toMatch(/raise exception 'location sync: expected/);
    expect(one.counts).toEqual({ provinces: 2, communes: 3, retired: 0, ghn: 2 });
  });
});

describe("run.mjs", () => {
  it("writes a migration and state, and a second run finds nothing to do", () => {
    const dir = mkdtempSync(join(tmpdir(), "location-sync-"));
    const migrations = join(dir, "migrations");
    execFileSync("mkdir", [migrations]);
    writeFileSync(join(migrations, "20261101010000_location_cache.sql"), "-- stub\n");
    const args = ["--from-file", fixturePath, "--state", join(dir, "state.json"), "--migrations-dir", migrations, "--report", join(dir, "report.md"), "--allow-count-change", "--today", "2026-11-01"];
    execFileSync("node", [runScript, ...args], { encoding: "utf8" });
    const written = readdirSync(migrations).filter((name) => name.includes("location_sync"));
    expect(written).toHaveLength(1);
    expect(readFileSync(join(migrations, written[0]), "utf8")).toContain("insert into public.location_units");
    expect(readFileSync(join(dir, "report.md"), "utf8")).toContain("Active communes | 3");

    const second = execFileSync("node", [runScript, ...args], { encoding: "utf8" });
    expect(second).toContain("Nothing changed");
    expect(readdirSync(migrations).filter((name) => name.includes("location_sync"))).toHaveLength(1);
  });
});
