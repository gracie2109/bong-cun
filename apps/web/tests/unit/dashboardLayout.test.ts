import { describe, expect, it } from "vitest";
import { parseLayout, serializeLayout } from "@bongcun/core/dashboard";

const item = (over: Record<string, unknown> = {}) => ({ id: "aaaaaaaa", type: "kpi", x: 0, y: 0, w: 2, h: 2, ...over });

describe("parseLayout", () => {
  it("keeps valid items and counts the dropped ones", () => {
    const parsed = parseLayout({
      v: 1,
      items: [item(), item({ id: "bbbbbbbb", x: 3, w: 2 }), item({ id: "cccccccc", w: 0 }), item({ id: "dddddddd", x: 2 })],
    });
    expect(parsed?.items.map((i) => i.id)).toEqual(["aaaaaaaa", "dddddddd"]);
    expect(parsed?.broken).toBe(2);
  });

  it("drops a repeated id", () => {
    expect(parseLayout({ v: 1, items: [item(), item({ x: 2 })] })?.items).toHaveLength(1);
  });

  it("returns null for an unusable value instead of throwing", () => {
    expect(parseLayout(null)).toBeNull();
    expect(parseLayout("x")).toBeNull();
    expect(parseLayout({ v: 2, items: [] })).toBeNull();
    expect(parseLayout({ v: 1, items: "no" })).toBeNull();
  });

  it("round trips through serializeLayout", () => {
    const items = [item({ config: { metric: "revenue.net" } })];
    expect(parseLayout(serializeLayout(items))?.items).toEqual(items);
  });
});
