// Splits the Location Service snapshot (NDJSON) into its catalog line, locations and GHN mappings.
const CODE = /^vn_[0-9a-z]{20}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const LEVELS = new Set(["province", "district", "commune"]);
const STATUSES = new Set(["active", "retired"]);

const fail = (line, message) => {
  throw new Error(`snapshot line ${line}: ${message}`);
};

const checkLocation = (row, line) => {
  if (!CODE.test(row.code ?? "")) fail(line, `bad code ${JSON.stringify(row.code)}`);
  if (!LEVELS.has(row.level)) fail(line, `bad level ${JSON.stringify(row.level)}`);
  if (!STATUSES.has(row.status)) fail(line, `bad status ${JSON.stringify(row.status)}`);
  if (!DATE.test(row.effective_from ?? "")) fail(line, `bad effective_from ${JSON.stringify(row.effective_from)}`);
  if (typeof row.name !== "string" || typeof row.full_name !== "string" || !row.name || !row.full_name) fail(line, "missing name");
  if (typeof row.unit_type !== "string" || !row.unit_type) fail(line, "missing unit_type");
};

const checkProviderCode = (row, line) => {
  if (!CODE.test(row.code ?? "")) fail(line, `bad code ${JSON.stringify(row.code)}`);
  for (const key of ["provider", "provider_model", "provider_code", "provider_name"]) {
    if (typeof row[key] !== "string" || !row[key]) fail(line, `missing ${key}`);
  }
};

/** @returns {{ catalog: object|null, locations: object[], providerCodes: object[] }} */
export const parseNdjson = (text) => {
  const result = { catalog: null, locations: [], providerCodes: [] };
  text.split("\n").forEach((raw, index) => {
    const line = index + 1;
    if (raw.trim() === "") return;
    let row;
    try {
      row = JSON.parse(raw);
    } catch {
      fail(line, "not JSON");
    }
    if (row.type === "catalog") {
      if (result.catalog) fail(line, "second catalog line");
      if (!row.id || !DATE.test(row.effective_on ?? "")) fail(line, "catalog needs id and effective_on");
      result.catalog = row;
    } else if (row.type === "location") {
      checkLocation(row, line);
      result.locations.push(row);
    } else if (row.type === "provider_code") {
      checkProviderCode(row, line);
      result.providerCodes.push(row);
    }
    // succession lines are not cached
  });
  return result;
};
