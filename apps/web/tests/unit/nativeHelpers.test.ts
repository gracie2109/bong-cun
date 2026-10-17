import { describe, expect, it } from "vitest";
import { decideBackAction } from "@/features/native/helpers/backButton";
import { classifyLink } from "@/features/native/helpers/links";

describe("decideBackAction", () => {
  it("leaves the app from the home page or the first history entry", () => {
    expect(decideBackAction(5, "/")).toBe("exit");
    expect(decideBackAction(0, "/products")).toBe("exit");
    expect(decideBackAction(undefined, "/products")).toBe("exit");
  });

  it("goes back inside the app otherwise", () => {
    expect(decideBackAction(2, "/products/12")).toBe("back");
  });
});

describe("classifyLink", () => {
  const origin = "https://localhost";

  it("keeps in-app links, anchors and relative paths", () => {
    expect(classifyLink("/products", origin)).toBe("internal");
    expect(classifyLink("#main", origin)).toBe("internal");
    expect(classifyLink("https://localhost/cart", origin)).toBe("internal");
  });

  it("sends other sites and new-tab links to the browser", () => {
    expect(classifyLink("https://maps.google.com/?q=x", origin)).toBe("browser");
    expect(classifyLink("/privacy", origin, true)).toBe("browser");
  });

  it("hands phone, mail and chat links to the system", () => {
    expect(classifyLink("tel:0900000000", origin)).toBe("system");
    expect(classifyLink("mailto:a@b.vn", origin)).toBe("system");
    expect(classifyLink("zalo://chat", origin)).toBe("system");
  });
});
