import type { SheetData } from "write-excel-file/browser";
import { downloadCsv } from "../csv";
import type { ExportFormat } from "./columns";

type Grid = (string | number)[][];

const BOM = "﻿";

const csvText = (grid: Grid): string => {
  const cell = (value: string | number) => {
    const raw = String(value);
    return /[",\r\n]/.test(raw) ? `"${raw.replace(/"/g, '""')}"` : raw;
  };
  return BOM + grid.map((row) => row.map(cell).join(",")).join("\r\n");
};

/** Saves a template (header row bold in Excel) as .xlsx or .csv. */
export const downloadTemplate = async (grid: Grid, fileBase: string, format: Extract<ExportFormat, "xlsx" | "csv">): Promise<void> => {
  if (format === "csv") return downloadCsv(`${fileBase}.csv`, csvText(grid));
  const { default: writeXlsxFile } = await import("write-excel-file/browser");
  const [header, ...body] = grid;
  const data: SheetData = [header.map((value) => ({ value, fontWeight: "bold" as const })), ...body];
  await writeXlsxFile(data, { sheet: "Mau", stickyRowsCount: 1 }).toFile(`${fileBase}.xlsx`);
};
