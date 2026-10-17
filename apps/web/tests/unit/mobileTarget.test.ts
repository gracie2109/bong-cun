import { describe, expect, it } from "vitest";
import {
  dropAdminRoutes,
  isAdminRoute,
  mobileNuxtConfig,
  resolveAppTarget,
} from "../../config/mobileTarget";

describe("resolveAppTarget", () => {
  it("defaults to web", () => {
    expect(resolveAppTarget(undefined)).toBe("web");
    expect(resolveAppTarget("")).toBe("web");
    expect(resolveAppTarget("mobile")).toBe("mobile");
  });
});

describe("admin routes", () => {
  it("recognises admin paths only", () => {
    expect(isAdminRoute("/admin")).toBe(true);
    expect(isAdminRoute("/admin/pos")).toBe(true);
    expect(isAdminRoute("/administrator")).toBe(false);
    expect(isAdminRoute("/account")).toBe(false);
  });

  it("removes them from the page list, children included", () => {
    const pages = [
      { path: "/" },
      { path: "/admin", children: [{ path: "/admin/pos" }] },
      { path: "/account", children: [{ path: "/admin/x" }, { path: "/account/orders" }] },
    ];
    dropAdminRoutes(pages);
    expect(pages.map((p) => p.path)).toEqual(["/", "/account"]);
    expect(pages[1]!.children).toEqual([{ path: "/account/orders" }]);
  });
});

describe("mobileNuxtConfig", () => {
  it("renders client-side and keeps the session in localStorage", () => {
    const config = mobileNuxtConfig();
    expect(config.ssr).toBe(false);
    expect(config.supabase.useSsrCookies).toBe(false);
  });
});
