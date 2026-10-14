/** What an import function says about one file row. `row` is the line number in the sheet. */
export type ImportRowResult = { row: string; action: "create" | "update" | "skip"; errors: string[] };

/** The answer of an import function for one batch (or, merged, for the whole file). */
export type ImportReport = {
  ok: boolean;
  created: number;
  updated: number;
  rows: ImportRowResult[];
  /** Counts and notes only some screens have (new categories, created customers...). */
  extra?: Record<string, unknown>;
};

export const emptyReport = (): ImportReport => ({ ok: true, created: 0, updated: 0, rows: [] });

const mergeExtra = (a: ImportReport["extra"], b: ImportReport["extra"]): ImportReport["extra"] => {
  if (!a && !b) return undefined;
  const merged: Record<string, unknown> = { ...a };
  for (const [key, value] of Object.entries(b ?? {})) {
    const old = merged[key];
    if (typeof old === "number" && typeof value === "number") merged[key] = old + value;
    else if (Array.isArray(old) && Array.isArray(value)) merged[key] = [...new Set([...old, ...value])];
    else merged[key] = value;
  }
  return merged;
};

/** Adds the answer for one batch to the running total. */
export const mergeReports = (total: ImportReport, part: ImportReport): ImportReport => ({
  ok: total.ok && part.ok,
  created: total.created + part.created,
  updated: total.updated + part.updated,
  rows: [...total.rows, ...part.rows],
  extra: mergeExtra(total.extra, part.extra),
});

/** The rows read from a file, with the problems found before anything is sent. */
export type ParsedImport<R> = {
  rows: R[];
  /** Row number -> notes; "file" holds notes about the whole file. */
  problems: Record<string, string[]>;
  /** The sheet the rows came from, for the "download the rows with errors" file. */
  source?: (string | number | boolean | Date | null | undefined)[][];
};

export const addProblem = (problems: Record<string, string[]>, row: string, note: string): void => {
  (problems[row] ??= []).push(note);
};

export const MAX_IMPORT_ROWS = 2000;
/** Rows sent to the database in one call. */
export const IMPORT_BATCH_SIZE = 200;
/** The most rows an import function accepts per call. */
export const IMPORT_CALL_LIMIT = 500;
