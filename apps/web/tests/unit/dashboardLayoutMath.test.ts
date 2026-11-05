import { describe, expect, it } from "vitest";
import type { SavedItem } from "@bongcun/core/dashboard";
import { clampItem, compactLayout, findFreeCell, moveBy, overlaps, placeNewItem, resizeTo, stackOrder } from "@/features/admin/dashboard/layout/layoutMath";
import { areaPath, lineDots, linePath } from "@/features/admin/reports/shared/chartScale";
import { metricOf } from "@/features/admin/dashboard/metrics/catalogue";
import { defaultItemsFor, roleDefaultKey } from "@/features/admin/dashboard/layout/roleDefaults";
import { parseMetricConfig } from "@bongcun/core/dashboard";
import { defaultItemId, defaultLayout, resolveLayout, toDisplayItems } from "@/features/admin/dashboard/layout/layoutCodec";
import { DASHBOARDS } from "@/features/admin/dashboard/dashboards";
import { WIDGET_META, metaOf } from "@/features/admin/dashboard/widgetTypes/meta";

const it_ = (id: string, x: number, y: number, w: number, h: number): SavedItem => ({ id: id.padEnd(8, "0"), type: "kpi", x, y, w, h });
const noOverlap = (items: SavedItem[]) => items.every((a, i) => items.every((b, j) => i === j || !overlaps(a, b)));

describe("compactLayout", () => {
  it("pulls items up and leaves no holes", () => {
    const out = compactLayout([it_("a", 0, 5, 2, 2), it_("b", 2, 9, 2, 2)]);
    expect(out.map((i) => i.y)).toEqual([0, 0]);
  });

  it("separates overlapping items, the earlier one stays", () => {
    const out = compactLayout([it_("a", 0, 0, 2, 2), it_("b", 1, 0, 2, 2)]);
    expect(noOverlap(out)).toBe(true);
    expect(out.find((i) => i.id.startsWith("a"))?.y).toBe(0);
    expect(out.find((i) => i.id.startsWith("b"))?.y).toBe(2);
  });
});

describe("placing", () => {
  it("finds the first free cell, scanning left to right then down", () => {
    const items = [it_("a", 0, 0, 2, 2)];
    expect(findFreeCell(items, { w: 2, h: 2 })).toEqual({ x: 2, y: 0 });
    expect(findFreeCell(items, { w: 3, h: 1 })).toEqual({ x: 0, y: 2 });
  });

  it("places a new item without overlap", () => {
    const out = placeNewItem([it_("a", 0, 0, 4, 2)], { id: "bbbbbbbb", type: "kpi", w: 1, h: 2 });
    expect(out).toHaveLength(2);
    expect(out[1]).toMatchObject({ x: 0, y: 2 });
  });
});

describe("moveBy", () => {
  it("swaps reading order and re-flows", () => {
    const out = moveBy([it_("a", 0, 0, 2, 2), it_("b", 2, 0, 2, 2), it_("c", 0, 2, 4, 1)], "a0000000", 1);
    expect(stackOrder(out).map((i) => i.id[0])).toEqual(["b", "a", "c"]);
    expect(noOverlap(out)).toBe(true);
  });

  it("does nothing at the ends or for an unknown id", () => {
    const items = [it_("a", 0, 0, 2, 2), it_("b", 2, 0, 2, 2)];
    expect(moveBy(items, "a0000000", -1)).toEqual(items);
    expect(moveBy(items, "zz", 1)).toEqual(items);
  });
});

describe("clamp and resize", () => {
  const limits = { minSize: { w: 2, h: 3 }, maxSize: { w: 3, h: 5 } };

  it("keeps size within limits and the item inside the grid", () => {
    expect(clampItem(it_("a", 3, 0, 4, 9), limits)).toMatchObject({ w: 3, h: 5, x: 1 });
    expect(clampItem(it_("a", 0, 0, 1, 1), limits)).toMatchObject({ w: 2, h: 3 });
  });

  it("closes the overlap a bigger item causes", () => {
    const out = resizeTo([it_("a", 0, 0, 2, 3), it_("b", 2, 0, 2, 3)], "a0000000", { w: 3, h: 3 }, limits);
    expect(noOverlap(out)).toBe(true);
  });
});

describe("default layouts", () => {
  it("only use known types, inside their limits, without overlap", () => {
    for (const dashboard of DASHBOARDS) {
      const items = defaultLayout(dashboard);
      expect(noOverlap(items)).toBe(true);
      for (const item of items) {
        const meta = metaOf(item.type);
        expect(meta, item.type).not.toBeNull();
        expect(clampItem(item, meta)).toEqual(item);
        expect(item.x + item.w).toBeLessThanOrEqual(4);
      }
    }
  });

  it("have a meta for every type key", () => {
    for (const [key, meta] of Object.entries(WIDGET_META)) expect(meta.key).toBe(key);
  });

  it("use ids a saved layout accepts", () => {
    for (const dashboard of DASHBOARDS) for (const item of defaultLayout(dashboard)) expect(item.id).toMatch(/^[a-z0-9]{8,24}$/);
  });
});

describe("resolveLayout", () => {
  const dashboard = DASHBOARDS[0]!;
  it("shows the default when nothing usable is stored", () => {
    expect(resolveLayout(null, dashboard).isDefault).toBe(true);
  });
  it("uses the stored items and reports broken ones", () => {
    const out = resolveLayout({ items: [it_("a", 0, 0, 1, 1)], broken: 2 }, dashboard);
    expect(out).toMatchObject({ isDefault: false, broken: 2 });
  });
  it("display items are clamped and compacted", () => {
    const out = toDisplayItems([{ ...it_("a", 0, 7, 9, 1), type: "trend" }]);
    expect(out[0]).toMatchObject({ y: 0, w: 4, h: 3 });
  });
});

describe("role defaults", () => {
  const today = DASHBOARDS.find((dashboard) => dashboard.key === "today") as (typeof DASHBOARDS)[number];
  const holdsOnly = (...held: string[]) => (permission: string) => held.includes(permission);

  it("picks the layout of the work a person does, and the base one for managers or no match", () => {
    expect(roleDefaultKey(today, holdsOnly("medical", "boarding"))).toBe("clinic");
    expect(roleDefaultKey(today, holdsOnly("schedule", "boarding"))).toBe("spa");
    expect(roleDefaultKey(today, holdsOnly("shop_orders"))).toBe("front");
    expect(roleDefaultKey(today, holdsOnly("medical", "schedule", "reports"))).toBeNull();
    expect(roleDefaultKey(today, holdsOnly())).toBeNull();
    expect(defaultItemsFor(today, holdsOnly("reports"))).toBe(today.defaultItems);
  });

  it("only uses widget types of the base layout, no overlap, sizes inside limits, unique types", () => {
    const base = new Set(today.defaultItems.map((item) => item.type));
    for (const role of today.roleDefaults ?? []) {
      const items = role.items.map((item) => ({ ...item, id: defaultItemId(item.type) }));
      expect(new Set(items.map((item) => item.type)).size, role.key).toBe(items.length);
      expect(noOverlap(items), role.key).toBe(true);
      for (const item of items) {
        expect(base.has(item.type), `${role.key}/${item.type}`).toBe(true);
        expect(clampItem(item, metaOf(item.type)), `${role.key}/${item.type}`).toEqual(item);
      }
    }
  });
});

describe("line chart view", () => {
  it("is a known widget type and an offered view of the revenue series", () => {
    expect(metaOf("lineChart")).not.toBeNull();
    expect(metricOf("revenue.series")?.views).toContain("lineChart");
    expect(parseMetricConfig({ metric: "revenue.series", view: "lineChart" })?.view).toBe("lineChart");
  });
});

describe("line geometry", () => {
  it("puts the highest value on top, centred in its slot", () => {
    const dots = lineDots({ values: [0, 50, 100], max: 100, plotHeight: 200, slot: 20 });
    expect(dots).toEqual([{ x: 10, y: 200 }, { x: 30, y: 100 }, { x: 50, y: 0 }]);
    expect(linePath(dots)).toBe("M10 200 L30 100 L50 0");
    expect(areaPath(dots, 200)).toBe("M10 200 L30 100 L50 0 L50 200 L10 200 Z");
  });

  it("draws a single dot and ignores negatives", () => {
    expect(linePath([{ x: 5, y: 7 }])).toBe("M5 7 h0");
    expect(areaPath([{ x: 5, y: 7 }], 100)).toBe("");
    expect(lineDots({ values: [-5], max: 10, plotHeight: 100, slot: 10 })[0]?.y).toBe(100);
  });
});
