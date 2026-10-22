// Keeps what Pawtiny caches: provinces and communes in force, plus any unit it already holds.
// Districts and the old catalog's units never enter, because old addresses use GHN codes, not state codes.
const LEVELS = new Set(["province", "commune"]);

const UNIT_KEYS = ["level", "unit_type", "official_code", "name", "full_name", "parent_code", "status", "effective_from", "effective_to"];

export const toUnit = (row) => Object.fromEntries(UNIT_KEYS.map((key) => [key, row[key] ?? null]));

/** Units to cache, by code. A unit already in `previousUnits` is kept up to date even when it retires. */
export const selectUnits = (locations, previousUnits) => {
  const units = {};
  for (const row of locations) {
    if (!LEVELS.has(row.level)) continue;
    if (row.status !== "active" && !(row.code in previousUnits)) continue;
    units[row.code] = toUnit(row);
  }
  return units;
};

const GHN_KEYS = ["provider_model", "provider_environment", "provider_code", "provider_parent_code", "provider_name", "match_method", "verified_at"];

/** GHN mappings, by unit code. A snapshot from before the environment column existed came from the test gateway. */
export const selectGhn = (providerCodes) => {
  const ghn = {};
  for (const row of providerCodes) {
    if (row.provider !== "ghn" || row.provider_model !== "ghn_v2") continue;
    const entry = Object.fromEntries(GHN_KEYS.map((key) => [key, row[key] ?? null]));
    entry.provider_environment = row.provider_environment ?? "test";
    entry.active = true;
    ghn[row.code] = entry;
  }
  return ghn;
};
