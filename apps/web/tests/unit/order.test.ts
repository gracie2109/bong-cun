import { describe, expect, it } from "vitest";
import { canCancelOrder, checkoutErrors, isOpenOrder, isValidPhone, orderShippingFee, toCartInput } from "@bongcun/core/shop";

describe("order status rules", () => {
  it("lets a shopper cancel only before shipping starts", () => {
    expect(canCancelOrder("pending")).toBe(true);
    expect(canCancelOrder("confirmed")).toBe(true);
    expect(canCancelOrder("completed")).toBe(false);
  });

  it("treats completed, cancelled and returned orders as closed", () => {
    expect(isOpenOrder("pending")).toBe(true);
    expect(isOpenOrder("completed")).toBe(false);
    expect(isOpenOrder("cancelled")).toBe(false);
    expect(isOpenOrder("returned")).toBe(false);
  });

  it("uses the confirmed shipping fee over the estimate", () => {
    expect(orderShippingFee({ shippingFee: 25_000, shippingFeeQuote: 20_000 })).toBe(25_000);
    expect(orderShippingFee({ shippingFee: null, shippingFeeQuote: 20_000 })).toBe(20_000);
  });
});

describe("checkout", () => {
  it("accepts 8 to 15 digit phone numbers", () => {
    expect(isValidPhone("0901 234 567")).toBe(true);
    expect(isValidPhone("1234567")).toBe(false);
    expect(isValidPhone("1234567890123456")).toBe(false);
  });

  it("asks for what the delivery method needs", () => {
    expect(checkoutErrors({ method: "delivery", address: null, receiverName: "", receiverPhone: "" })).toEqual({ address: true });
    expect(checkoutErrors({ method: "pickup", address: null, receiverName: " ", receiverPhone: "12" })).toEqual({
      receiverName: true,
      receiverPhone: true,
    });
  });

  it("keeps only product, unit and quantity when sending the cart", () => {
    const lines = [{ productId: "p", unitId: null, qty: 2, extra: "x" }] as never;
    expect(toCartInput(lines)).toEqual([{ productId: "p", unitId: null, qty: 2 }]);
  });
});
