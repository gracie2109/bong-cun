// Translates between saved items and the shape the grid library wants.
import type { SavedItem } from "@bongcun/core/dashboard";
import { metaOf } from "../widgetTypes/meta";

export type GridEntry = {
  i: string;
  x: number;
  y: number;
  w: number;
  h: number;
  minW: number;
  minH: number;
  maxW: number;
  maxH: number;
};

export const toGridEntries = (items: readonly SavedItem[]): GridEntry[] =>
  items.map((item) => {
    const meta = metaOf(item.type);
    return {
      i: item.id, x: item.x, y: item.y, w: item.w, h: item.h,
      minW: meta?.minSize.w ?? 1, minH: meta?.minSize.h ?? 1, maxW: meta?.maxSize.w ?? 4, maxH: meta?.maxSize.h ?? 12,
    };
  });

/** Applies the positions the grid reports to the saved items, keeping type and config. */
export const fromGridEntries = (items: readonly SavedItem[], entries: readonly Pick<GridEntry, "i" | "x" | "y" | "w" | "h">[]): SavedItem[] =>
  items.map((item) => {
    const entry = entries.find((candidate) => candidate.i === item.id);
    return entry ? { ...item, x: entry.x, y: entry.y, w: entry.w, h: entry.h } : item;
  });
