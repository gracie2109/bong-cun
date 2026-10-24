// Builds the saved items for the "Add widget" and "Settings" dialogs. Pure, so it can be tested.
import { MAX_ITEMS, parseMetricConfig, type MetricConfig, type RangeConfig, type SavedItem } from "@bongcun/core/dashboard";
import { metaOf } from "../widgetTypes/meta";
import { placeNewItem } from "../layout/layoutMath";
import { isUsableRange } from "../range/widgetRange";
import { resolveParams, supportsCompare } from "../metrics/params";
import type { MetricDef, MetricParams, MetricView } from "../metrics/types";

export type MetricForm = {
  view: MetricView;
  params: MetricParams;
  title: string;
  compare: boolean;
  /** Undefined = the metric's own default range. */
  range?: RangeConfig;
};

export const defaultForm = (def: MetricDef, saved?: MetricConfig | null): MetricForm => ({
  view: saved?.view && def.views.includes(saved.view) ? saved.view : (def.views[0] as MetricView),
  params: resolveParams(def, saved?.params) ?? (resolveParams(def, undefined) as MetricParams),
  title: saved?.title ?? "",
  compare: saved?.compare === true,
  range: def.usesRange ? saved?.range : undefined,
});

/** The widget `config` for a form; only values the catalogue allows reach it. */
export const configFromForm = (def: MetricDef, form: MetricForm): MetricConfig => {
  const config: MetricConfig = { metric: def.key, view: form.view };
  if (Object.keys(form.params).length) config.params = { ...form.params };
  if (form.title.trim()) config.title = form.title.trim().slice(0, 60);
  if (def.usesRange && form.range && (form.range.kind === "preset" || isUsableRange(form.range))) config.range = form.range;
  if (form.compare && supportsCompare(def, form.params)) config.compare = true;
  return config;
};

/** A short random id that matches the layout rule ([a-z0-9], 8 to 24 characters). */
export const newItemId = (random: () => number = Math.random): string =>
  Array.from({ length: 10 }, () => "abcdefghijklmnopqrstuvwxyz0123456789"[Math.floor(random() * 36)]).join("");

export const canAddMore = (items: readonly SavedItem[]): boolean => items.length < MAX_ITEMS;

/** Adds a metric widget in the first free spot, sized by its view. Returns the list unchanged when full. */
export const addMetricItem = (items: readonly SavedItem[], def: MetricDef, form: MetricForm, id = newItemId()): SavedItem[] => {
  if (!canAddMore(items)) return [...items];
  const meta = metaOf(form.view);
  const size = meta?.defaultSize ?? { w: 1, h: 2 };
  return placeNewItem(items, { id, type: form.view, w: size.w, h: size.h, config: configFromForm(def, form) });
};

/** Adds a fixed widget back (one that was removed from the dashboard). */
export const addFixedItem = (items: readonly SavedItem[], type: string, id = newItemId()): SavedItem[] => {
  const meta = metaOf(type);
  if (!meta || !canAddMore(items)) return [...items];
  return placeNewItem(items, { id, type, w: meta.defaultSize.w, h: meta.defaultSize.h });
};

/** Replaces the settings of one item, keeping its place and size. The type follows the chosen view. */
export const applySettings = (items: readonly SavedItem[], id: string, def: MetricDef, form: MetricForm): SavedItem[] =>
  items.map((item) => (item.id === id ? { ...item, type: form.view, config: configFromForm(def, form) } : item));

export const savedConfigOf = (item: SavedItem): MetricConfig | null => parseMetricConfig(item.config);
