// Reading single cells of an imported sheet (Excel or CSV). Pure TS.

export type Cell = string | number | boolean | Date | null | undefined;

export const text = (value: Cell): string => {
  if (value === null || value === undefined) return "";
  if (value instanceof Date) return isoDay(value);
  return String(value).trim();
};

export const isBlankRow = (cells: readonly Cell[]): boolean => cells.every((cell) => text(cell) === "");

const pad = (value: number): string => String(value).padStart(2, "0");

// Excel hands back date cells as UTC midnight.
const isoDay = (date: Date): string => `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;

/** Reads a number typed with a dot or a comma; "1.000" is not guessed, use plain digits. */
export const toNumber = (value: Cell): number | null | "invalid" => {
  if (typeof value === "number") return value;
  const raw = text(value);
  if (raw === "") return null;
  const parsed = Number(raw.replace(/\s/g, "").replace(",", "."));
  return Number.isFinite(parsed) ? parsed : "invalid";
};

const YES = ["có", "co", "yes", "y", "1", "true", "x"];
const NO = ["không", "khong", "no", "n", "0", "false"];

/** "Có"/"Không" (also yes/no, 1/0, true/false); empty gives the default. */
export const toFlag = (value: Cell, fallback: boolean): boolean | "invalid" => {
  if (typeof value === "boolean") return value;
  const raw = text(value).toLowerCase();
  if (raw === "") return fallback;
  if (YES.includes(raw)) return true;
  if (NO.includes(raw)) return false;
  return "invalid";
};

/** A day as yyyy-mm-dd from an Excel date cell, "dd/mm/yyyy" or "yyyy-mm-dd"; empty gives null. */
export const toDate = (value: Cell): string | null | "invalid" => {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? "invalid" : isoDay(value);
  const raw = text(value);
  if (raw === "") return null;
  const iso = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(raw);
  const vn = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(raw);
  const [year, month, day] = iso ? [iso[1], iso[2], iso[3]] : vn ? [vn[3], vn[2], vn[1]] : [];
  if (!year) return "invalid";
  const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
  const real = date.getUTCFullYear() === Number(year) && date.getUTCMonth() === Number(month) - 1 && date.getUTCDate() === Number(day);
  return real ? `${year}-${pad(Number(month))}-${pad(Number(day))}` : "invalid";
};

/** Header text compared loosely: no accents, no case, single spaces. */
export const normalizeHeader = (value: Cell): string =>
  text(value)
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/gi, "d")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
