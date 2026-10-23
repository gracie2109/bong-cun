import { describe, expect, it, vi } from "vitest";

// The reports barrel pulls in the data layer; only its pure number formats are needed here.
vi.mock("@/features/admin/pos/format", () => ({ money: (value: number) => String(value) }));
vi.mock("@/features/admin/reports", () => import("@/features/admin/reports/shared/format"));

import { changeOf, changeTone, formatFigure } from "@/features/admin/dashboard/widgets/metric/kpiFormat";
import { resolveMetricConfig } from "@/features/admin/dashboard/widgets/metric/metricConfig";
import { paramText } from "@/features/admin/dashboard/widgets/metric/paramText";

describe("kpiFormat", () => {
  it("formats money through the given formatter and counts with separators", () => {
    expect(formatFigure(1500, "money", (v) => `${v}đ`)).toBe("1500đ");
    expect(formatFigure(1234567, "count", () => "")).toBe((1234567).toLocaleString("vi-VN"));
  });
  it("has no change without a previous figure or against zero", () => {
    expect(changeOf(5, undefined)).toBeNull();
    expect(changeOf(5, 0)).toBeNull();
    expect(changeOf(150, 100)).toEqual({ percent: 50, direction: "up" });
  });
  it("tones a rise as good, except where rising is bad", () => {
    expect(changeTone("up", false)).toBe("good");
    expect(changeTone("up", true)).toBe("bad");
    expect(changeTone("down", true)).toBe("good");
    expect(changeTone("flat", true)).toBe("flat");
  });
});

describe("resolveMetricConfig", () => {
  it("accepts a catalogue metric and fills in default parameters", () => {
    const resolved = resolveMetricConfig({ metric: "revenue.net" });
    expect(resolved?.def.key).toBe("revenue.net");
    expect(resolved?.params).toEqual({ segment: "all" });
    expect(resolved?.compare).toBe(false);
  });
  it("refuses an unknown metric, a bad parameter and a malformed config", () => {
    expect(resolveMetricConfig({ metric: "drop.table" })).toBeNull();
    expect(resolveMetricConfig({ metric: "revenue.net", params: { segment: "x" } })).toBeNull();
    expect(resolveMetricConfig(undefined)).toBeNull();
    expect(resolveMetricConfig({ metric: 5 })).toBeNull();
    expect(resolveMetricConfig({ metric: "revenue.net", title: "x".repeat(61) })).toBeNull();
  });
});

describe("paramText", () => {
  const t = (key: string, named?: Record<string, unknown>) => (named ? `${key}:${named.n}` : key);
  const te = (key: string) => !key.endsWith(".unknown");
  it("joins the labels it knows", () => {
    expect(paramText({ segment: "spa", days: 30 }, t, te)).toBe("dashboard.param.segment.spa · dashboard.param.days:30");
  });
  it("skips parameters without a label", () => {
    expect(paramText({ segment: "unknown" }, t, te)).toBe("");
  });
});
