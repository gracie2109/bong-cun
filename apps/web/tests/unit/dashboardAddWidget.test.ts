import { describe, expect, it, vi } from "vitest";

// The reports barrel pulls in the data layer; the range check only needs its date maths.
vi.mock("@/features/admin/reports", () => import("@/features/admin/reports/shared/dateRange"));

import { parseLayout, type SavedItem } from "@bongcun/core/dashboard";
import { addFixedItem, addMetricItem, applySettings, configFromForm, defaultForm, newItemId } from "@/features/admin/dashboard/addWidget/addWidgetItem";
import { fold, groupMetrics } from "@/features/admin/dashboard/addWidget/metricSearch";
import { METRIC_LIST, metricOf } from "@/features/admin/dashboard/metrics/catalogue";
import { resolveMetricConfig } from "@/features/admin/dashboard/widgets/metric/metricConfig";

const net = metricOf("revenue.net")!;
const existing = (id: string, over: Partial<SavedItem> = {}): SavedItem => ({ id, type: "trend", x: 0, y: 0, w: 4, h: 4, ...over });

describe("addMetricItem", () => {
  it("places a valid widget in the first free spot", () => {
    const form = { ...defaultForm(net), params: { segment: "spa" } };
    const out = addMetricItem([existing("aaaaaaaa")], net, form, "bbbbbbbb");
    expect(out).toHaveLength(2);
    expect(out[1]).toMatchObject({ id: "bbbbbbbb", type: "kpi", x: 0, y: 4, w: 1, h: 2 });
    expect(parseLayout({ v: 1, items: out })?.broken).toBe(0);
    expect(resolveMetricConfig(out[1]?.config)?.params).toEqual({ segment: "spa" });
  });

  it("allows two widgets of one metric with different settings", () => {
    const first = addMetricItem([], net, { ...defaultForm(net), params: { segment: "spa" } }, "aaaaaaaa");
    const second = addMetricItem(first, net, { ...defaultForm(net), params: { segment: "shop" } }, "bbbbbbbb");
    expect(second.map((item) => item.id)).toEqual(["aaaaaaaa", "bbbbbbbb"]);
    expect(new Set(second.map((item) => `${item.x},${item.y}`)).size).toBe(2);
  });

  it("refuses a 25th widget", () => {
    const full = Array.from({ length: 24 }, (_, i) => existing(`id${String(i).padStart(6, "0")}`, { x: 0, y: i * 4 > 199 ? 199 : i * 4 }));
    expect(addMetricItem(full, net, defaultForm(net))).toHaveLength(24);
    expect(addFixedItem(full, "actions")).toHaveLength(24);
  });
});

describe("configFromForm", () => {
  it("keeps compare only where the metric can compare", () => {
    expect(configFromForm(net, { ...defaultForm(net), compare: true }).compare).toBe(true);
    expect(configFromForm(net, { ...defaultForm(net), params: { segment: "spa" }, compare: true }).compare).toBeUndefined();
    expect(configFromForm(metricOf("stock.low")!, { ...defaultForm(metricOf("stock.low")!), compare: true }).compare).toBeUndefined();
  });
  it("trims the title and drops an empty one", () => {
    expect(configFromForm(net, { ...defaultForm(net), title: "  Spa thang  " }).title).toBe("Spa thang");
    expect(configFromForm(net, { ...defaultForm(net), title: "   " }).title).toBeUndefined();
  });
});

describe("settings and ids", () => {
  it("applies new settings but keeps place and size", () => {
    const [added] = addMetricItem([], net, defaultForm(net), "aaaaaaaa");
    const out = applySettings([added!], "aaaaaaaa", net, { ...defaultForm(net), view: "kpi", params: { segment: "shop" }, title: "Shop" });
    expect(out[0]).toMatchObject({ x: 0, y: 0, w: 1, h: 2 });
    expect(resolveMetricConfig(out[0]?.config)).toMatchObject({ params: { segment: "shop" }, title: "Shop" });
  });
  it("makes ids the layout accepts", () => {
    for (let i = 0; i < 50; i += 1) expect(newItemId()).toMatch(/^[a-z0-9]{8,24}$/);
  });
  it("adds a removed fixed widget back with its default size", () => {
    expect(addFixedItem([], "actions", "aaaaaaaa")[0]).toMatchObject({ type: "actions", w: 2, h: 4 });
    expect(addFixedItem([], "nope")).toEqual([]);
  });
});

describe("metric search", () => {
  const label = (def: { key: string }) => ({ "revenue.net": "Doanh thu", "stock.low": "Hàng sắp hết" })[def.key] ?? def.key;
  it("folds accents and the letter đ", () => {
    expect(fold("Đơn hàng Sắp Hết")).toBe("don hang sap het");
  });
  it("finds metrics without typing accents, grouped in a fixed order", () => {
    const groups = groupMetrics(METRIC_LIST, "hang sap", label);
    expect(groups.map((g) => g.group)).toEqual(["stock"]);
    expect(groups[0]?.metrics.map((m) => m.key)).toEqual(["stock.low"]);
  });
  it("lists everything for an empty query, revenue first", () => {
    const groups = groupMetrics(METRIC_LIST, "", label);
    expect(groups[0]?.group).toBe("revenue");
    expect(groups.reduce((sum, g) => sum + g.metrics.length, 0)).toBe(METRIC_LIST.length);
  });
});

describe("range in the form", () => {
  it("is saved only for metrics that use a range, and only when usable", () => {
    const preset = { kind: "preset", preset: "last30" } as const;
    expect(configFromForm(net, { ...defaultForm(net), range: preset }).range).toEqual(preset);
    expect(configFromForm(net, { ...defaultForm(net), range: { kind: "fixed", from: "2026-10-05", to: "2026-10-01" } }).range).toBeUndefined();
    const stock = metricOf("stock.low")!;
    expect(configFromForm(stock, { ...defaultForm(stock), range: preset }).range).toBeUndefined();
  });
  it("reads a saved range back into the form", () => {
    const form = defaultForm(net, { metric: "revenue.net", range: { kind: "preset", preset: "lastMonth" } });
    expect(form.range).toEqual({ kind: "preset", preset: "lastMonth" });
  });
});
