// The shape of a saved dashboard layout: where each widget sits, how big it is and its settings.
// supabase/migrations/20261103010000_dashboard_layouts.sql checks the same limits on the server.
import { z } from "zod";

export const GRID_COLS = 4;
export const MAX_ITEMS = 24;
export const MAX_ROWS = 200;
export const MAX_ITEM_HEIGHT = 12;
export const LAYOUT_VERSION = 1;

export const savedItemSchema = z.object({
  id: z.string().regex(/^[a-z0-9]{8,24}$/),
  type: z.string().regex(/^[a-zA-Z][a-zA-Z0-9]{0,31}$/),
  x: z.number().int().min(0).max(GRID_COLS - 1),
  y: z.number().int().min(0).max(MAX_ROWS - 1),
  w: z.number().int().min(1).max(GRID_COLS),
  h: z.number().int().min(1).max(MAX_ITEM_HEIGHT),
  // Checked again by the widget type that owns it; here only "an object".
  config: z.record(z.unknown()).optional(),
});
export type SavedItem = z.infer<typeof savedItemSchema>;

export type SavedLayout = { v: typeof LAYOUT_VERSION; items: SavedItem[] };

/** A stored layout split into the items that are well formed and the ones that are not. */
export type ParsedLayout = { items: SavedItem[]; broken: number };

/**
 * Reads a stored layout without ever throwing. Returns null when the whole value is unusable
 * (the caller then shows the default layout); otherwise the valid items and how many were dropped.
 */
export const parseLayout = (json: unknown): ParsedLayout | null => {
  if (typeof json !== "object" || json === null) return null;
  const { v, items } = json as { v?: unknown; items?: unknown };
  if (v !== LAYOUT_VERSION || !Array.isArray(items)) return null;
  const seen = new Set<string>();
  const valid: SavedItem[] = [];
  for (const raw of items.slice(0, MAX_ITEMS)) {
    const parsed = savedItemSchema.safeParse(raw);
    if (!parsed.success || parsed.data.x + parsed.data.w > GRID_COLS || seen.has(parsed.data.id)) continue;
    seen.add(parsed.data.id);
    valid.push(parsed.data);
  }
  return { items: valid, broken: items.length - valid.length };
};

export const serializeLayout = (items: readonly SavedItem[]): SavedLayout => ({ v: LAYOUT_VERSION, items: [...items] });
