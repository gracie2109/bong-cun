import { text, type Cell } from "./cells";
import { downloadTemplate } from "./templateFile";

/** The rows of `source` that have errors, as a grid with an extra "Lỗi" column, to fix and import again. */
export const errorGrid = (source: readonly Cell[][], notes: Record<string, string[]>): string[][] => {
  const headerAt = source.findIndex((cells) => cells.some((cell) => text(cell) !== ""));
  if (headerAt < 0) return [];
  const header = [...source[headerAt].map(text), "Lỗi"];
  const rows = Object.entries(notes)
    .filter(([row]) => /^\d+$/.test(row) && source[Number(row) - 1])
    .sort(([a], [b]) => Number(a) - Number(b))
    .map(([row, list]) => [...source[Number(row) - 1].map(text), list.join("; ")]);
  return [header, ...rows];
};

export const downloadErrorFile = (source: readonly Cell[][], notes: Record<string, string[]>, fileBase: string): Promise<void> =>
  downloadTemplate(errorGrid(source, notes), fileBase, "xlsx");
