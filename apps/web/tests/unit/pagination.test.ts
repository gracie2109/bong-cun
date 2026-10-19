import { describe, expect, it } from "vitest";
import { pageFromQuery, pageItems } from "../../src/utils/shop/pagination";

describe("pageItems", () => {
  it("lists every page when there are few", () => {
    expect(pageItems(2, 3)).toEqual([1, 2, 3]);
  });

  it("keeps the first, last and neighbours with gaps between", () => {
    expect(pageItems(5, 10)).toEqual([1, "gap", 4, 5, 6, "gap", 10]);
    expect(pageItems(1, 10)).toEqual([1, 2, "gap", 10]);
    expect(pageItems(10, 10)).toEqual([1, "gap", 9, 10]);
  });
});

describe("pageFromQuery", () => {
  it("reads a positive whole number, otherwise page 1", () => {
    expect(pageFromQuery("3")).toBe(3);
    expect(pageFromQuery(["2", "5"])).toBe(2);
    for (const bad of [undefined, "", "0", "-1", "1.5", "abc"]) expect(pageFromQuery(bad)).toBe(1);
  });
});
