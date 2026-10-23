import { describe, expect, it } from "vitest";
import { branchesWithAnyRole, branchesWithPermission, canUseAt, type BranchGrants } from "@bongcun/core/auth";

const byBranch: BranchGrants = {
  a: { medical: ["VIEW"], reports: ["ALL"] },
  b: { pos: ["VIEW", "CREATE"] },
  c: {},
};
const merged = { medical: ["VIEW"], reports: ["ALL"], pos: ["VIEW", "CREATE"] };

describe("canUseAt", () => {
  it("answers per branch, not for any branch", () => {
    expect(canUseAt(merged, byBranch, "medical", "a")).toBe(true);
    expect(canUseAt(merged, byBranch, "medical", "b")).toBe(false);
    expect(canUseAt(merged, byBranch, "pos", "b", "CREATE")).toBe(true);
    expect(canUseAt(merged, byBranch, "pos", "b", "DELETE")).toBe(false);
  });

  it("treats ALL as every method and refuses a missing branch", () => {
    expect(canUseAt(merged, byBranch, "reports", "a", "EXPORT")).toBe(true);
    expect(canUseAt(merged, byBranch, "medical", null)).toBe(false);
    expect(canUseAt(merged, byBranch, "medical", "zzz")).toBe(false);
  });

  it("lets admin accounts without branch roles through everywhere", () => {
    expect(canUseAt("all", {}, "medical", "b")).toBe(true);
  });
});

describe("branch lists", () => {
  it("keeps the branches where a permission is held", () => {
    expect(branchesWithPermission(merged, byBranch, ["a", "b", "c"], "pos")).toEqual(["b"]);
    expect(branchesWithPermission("all", {}, ["a", "b"], "pos")).toEqual(["a", "b"]);
  });

  it("offers only branches with a role", () => {
    expect(branchesWithAnyRole(merged, byBranch, ["a", "b", "c"])).toEqual(["a", "b"]);
    expect(branchesWithAnyRole("all", {}, ["a", "c"])).toEqual(["a", "c"]);
  });
});
