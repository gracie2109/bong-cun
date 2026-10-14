import type { CellKind, CellValue } from "./columns";

export type CellTarget = "csv" | "print";

const pad = (value: number): string => String(value).padStart(2, "0");

const toDate = (value: CellValue): Date | null => {
  if (value === null || value === undefined || value === "") return null;
  const date = value instanceof Date ? value : new Date(value as string | number);
  return Number.isNaN(date.getTime()) ? null : date;
};

// A date-only string ("2026-10-14") is shown as written, so the time zone cannot move the day.
const DATE_ONLY = /^(\d{4})-(\d{2})-(\d{2})$/;

export const formatDate = (value: CellValue): string => {
  if (typeof value === "string") {
    const match = DATE_ONLY.exec(value);
    if (match) return `${match[3]}/${match[2]}/${match[1]}`;
  }
  const date = toDate(value);
  return date ? `${pad(date.getDate())}/${pad(date.getMonth() + 1)}/${date.getFullYear()}` : "";
};

export const formatDateTime = (value: CellValue): string => {
  const date = toDate(value);
  return date ? `${formatDate(date)} ${pad(date.getHours())}:${pad(date.getMinutes())}` : "";
};

export const formatFlag = (value: CellValue): string => (value ? "Có" : "Không");

/**
 * The text of one cell. CSV keeps numbers raw so Excel reads them as numbers; the printed table
 * groups thousands the Vietnamese way.
 */
export const formatCell = (value: CellValue, kind: CellKind = "text", target: CellTarget = "csv"): string => {
  if (value === null || value === undefined) return "";
  switch (kind) {
    case "number":
    case "money": {
      const amount = Number(value);
      if (value === "" || Number.isNaN(amount)) return String(value);
      return target === "print" ? amount.toLocaleString("vi-VN") : String(amount);
    }
    case "date":
      return formatDate(value);
    case "datetime":
      return formatDateTime(value);
    case "flag":
      return formatFlag(value);
    default:
      return String(value);
  }
};
