// Pure grid arithmetic for dashboard layouts: no Vue, no DOM, no widget components.
import { GRID_COLS, type SavedItem } from "@bongcun/core/dashboard";
import type { WidgetSize, WidgetTypeMeta } from "../widgetTypes/types";

type Cell = Pick<SavedItem, "x" | "y" | "w" | "h">;

export const overlaps = (a: Cell, b: Cell): boolean =>
  a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;

/** Reading order: top to bottom, then left to right. This is also the order of the one-column view. */
export const stackOrder = <T extends Cell>(items: readonly T[]): T[] =>
  [...items].sort((a, b) => a.y - b.y || a.x - b.x);

const between = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

/** Keeps an item inside the grid and inside the limits of its widget type. */
export const clampItem = <T extends SavedItem>(item: T, limits: Pick<WidgetTypeMeta, "minSize" | "maxSize"> | null): T => {
  const w = between(item.w, limits?.minSize.w ?? 1, Math.min(limits?.maxSize.w ?? GRID_COLS, GRID_COLS));
  const h = between(item.h, limits?.minSize.h ?? 1, limits?.maxSize.h ?? 12);
  return { ...item, w, h, x: between(item.x, 0, GRID_COLS - w), y: Math.max(0, item.y) };
};

/**
 * Pulls every item up as far as it goes. Items keep their reading order and the earlier one wins
 * when two overlap, so the result never has overlaps or holes above an item.
 */
export const compactLayout = <T extends SavedItem>(items: readonly T[]): T[] => {
  const placed: T[] = [];
  for (const item of stackOrder(items)) {
    let y = 0;
    while (placed.some((other) => overlaps({ ...item, y }, other))) y += 1;
    placed.push({ ...item, y });
  }
  return placed;
};

/** The first free spot, scanning rows top to bottom, where a widget of this size fits. */
export const findFreeCell = (items: readonly Cell[], size: WidgetSize): { x: number; y: number } => {
  const w = Math.min(size.w, GRID_COLS);
  for (let y = 0; ; y += 1) {
    for (let x = 0; x + w <= GRID_COLS; x += 1) {
      if (!items.some((other) => overlaps({ x, y, w, h: size.h }, other))) return { x, y };
    }
  }
};

/** Adds an item in the first free spot; the caller gives it an id. */
export const placeNewItem = (items: readonly SavedItem[], item: Omit<SavedItem, "x" | "y">): SavedItem[] => [
  ...items,
  { ...item, ...findFreeCell(items, item) },
];

/** Lays items out in the given order, each in the first free spot (used after a reorder). */
export const reflow = (ordered: readonly SavedItem[]): SavedItem[] => {
  const placed: SavedItem[] = [];
  for (const item of ordered) placed.push({ ...item, ...findFreeCell(placed, item) });
  return placed;
};

/** Moves one item a step up or down in reading order (the menu action that needs no dragging). */
export const moveBy = (items: readonly SavedItem[], id: string, step: -1 | 1): SavedItem[] => {
  const order = stackOrder(items);
  const from = order.findIndex((item) => item.id === id);
  const to = from + step;
  if (from < 0 || to < 0 || to >= order.length) return [...items];
  [order[from], order[to]] = [order[to] as SavedItem, order[from] as SavedItem];
  return reflow(order);
};

/** Changes the size of one item within its limits, then closes any overlap it caused. */
export const resizeTo = (
  items: readonly SavedItem[],
  id: string,
  size: WidgetSize,
  limits: Pick<WidgetTypeMeta, "minSize" | "maxSize"> | null
): SavedItem[] =>
  compactLayout(items.map((item) => (item.id === id ? clampItem({ ...item, ...size }, limits) : item)));
