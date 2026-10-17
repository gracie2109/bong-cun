import { describe, expect, it } from "vitest";
import { APP_TABS, tabForRoute } from "@/features/native/helpers/tabs";

describe("tabForRoute", () => {
  it("maps the five main areas and their sub-pages", () => {
    expect(tabForRoute("home")).toBe("home");
    expect(tabForRoute("product-detail")).toBe("products");
    expect(tabForRoute("spa-book")).toBe("spa");
    expect(tabForRoute("checkout")).toBe("cart");
    expect(tabForRoute("account-orders")).toBe("account");
    expect(tabForRoute("order-detail")).toBe("account");
    expect(tabForRoute("login")).toBe("account");
  });

  it("selects nothing on other pages", () => {
    expect(tabForRoute("contact")).toBeNull();
    expect(tabForRoute(undefined)).toBeNull();
  });

  it("has one tab per id, in order", () => {
    expect(APP_TABS.map((t) => t.id)).toEqual(["home", "products", "spa", "cart", "account"]);
  });
});
