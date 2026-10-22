// supabase/data/locations/state.json: what the location migrations have written so far.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { sortedObject } from "./diffState.mjs";

export const emptyState = () => ({ catalog: null, units: {}, ghn: {} });

export const readState = (path) => (existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : emptyState());

export const writeState = (path, state) => {
  const ordered = { catalog: state.catalog, units: sortedObject(state.units), ghn: sortedObject(state.ghn) };
  writeFileSync(path, JSON.stringify(ordered, null, 1) + "\n");
};

export const catalogForState = (catalog) => ({
  id: catalog.id,
  source: catalog.source,
  source_ref: catalog.source_ref ?? null,
  effective_on: catalog.effective_on,
  extracted_at: catalog.extracted_at ?? null,
  checksum: catalog.file_sha256 ?? null,
});
