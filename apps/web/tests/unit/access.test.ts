import { describe, expect, it } from "vitest";
import { canAccess, canOpenAdminRoute, canUse, isAdminRole, isStaffRole } from "@bongcun/core/auth";

describe("roles", () => {
  it("tells staff from customers", () => {
    expect(isStaffRole("cashier")).toBe(true);
    expect(isStaffRole("customer")).toBe(false);
    expect(isStaffRole(null)).toBe(false);
    expect(isAdminRole("superAdmin")).toBe(true);
    expect(isAdminRole("cashier")).toBe(false);
  });
});

describe("canAccess", () => {
  const guest = { isAuthenticated: false, role: null };
  const staff = { isAuthenticated: true, role: "cashier" };

  it("keeps guests out of pages that need a login", () => {
    expect(canAccess({ requiresAuth: true }, guest)).toBe(false);
    expect(canAccess({ requiresAuth: true }, staff)).toBe(true);
  });

  it("keeps signed-in users away from guest-only pages", () => {
    expect(canAccess({ guestOnly: true }, staff)).toBe(false);
    expect(canAccess({ guestOnly: true }, guest)).toBe(true);
  });

  it("checks roles and staff-only pages", () => {
    expect(canAccess({ roles: ["admin"] }, staff)).toBe(false);
    expect(canAccess({ staffOnly: true }, { isAuthenticated: true, role: "customer" })).toBe(false);
    expect(canAccess({ staffOnly: true }, staff)).toBe(true);
  });
});

describe("grants", () => {
  it("honours ALL and the all-access marker", () => {
    expect(canUse("all", "pos", "DELETE")).toBe(true);
    expect(canUse({ pos: ["VIEW"] }, "pos")).toBe(true);
    expect(canUse({ pos: ["VIEW"] }, "pos", "UPDATE")).toBe(false);
    expect(canUse({ pos: ["ALL"] }, "pos", "UPDATE")).toBe(true);
    expect(canUse({}, "pos")).toBe(false);
  });

  it("opens routes the grants allow", () => {
    expect(canOpenAdminRoute("all", "anything")).toBe(true);
  });
});
