import { describe, expect, it } from "vitest";
import { isForbiddenError, resolveWidgetState } from "@/features/admin/dashboard/kit/widgetState";

const ok = { isPending: false, isError: false };

describe("resolveWidgetState", () => {
  it("hides, then asks for a branch, before looking at the query", () => {
    expect(resolveWidgetState({ allowed: false, query: ok, isEmpty: false })).toBe("hidden");
    expect(resolveWidgetState({ allowed: true, needsBranch: true, query: { ...ok, isError: true }, isEmpty: false })).toBe("needsBranch");
  });

  it("separates a refusal from other errors, and never falls back to stale data on error", () => {
    expect(resolveWidgetState({ allowed: true, query: { ...ok, isError: true, error: { code: "42501" } }, isEmpty: false })).toBe("forbidden");
    expect(resolveWidgetState({ allowed: true, query: { ...ok, isError: true, error: { code: "forbidden" } }, isEmpty: false })).toBe("forbidden");
    expect(resolveWidgetState({ allowed: true, query: { ...ok, isError: true, error: new Error("x") }, isEmpty: false })).toBe("error");
  });

  it("shows a skeleton while loading or while the data belongs to another branch", () => {
    expect(resolveWidgetState({ allowed: true, query: { ...ok, isPending: true }, isEmpty: false })).toBe("loading");
    expect(resolveWidgetState({ allowed: true, query: { ...ok, isPlaceholderData: true }, isEmpty: false })).toBe("loading");
  });

  it("tells empty from ready", () => {
    expect(resolveWidgetState({ allowed: true, query: ok, isEmpty: true })).toBe("empty");
    expect(resolveWidgetState({ allowed: true, query: ok, isEmpty: false })).toBe("ready");
  });
});

describe("isForbiddenError", () => {
  it("reads the code of an error", () => {
    expect(isForbiddenError({ code: "42501" })).toBe(true);
    expect(isForbiddenError(null)).toBe(false);
    expect(isForbiddenError("42501")).toBe(false);
  });
});
