import { describe, expect, it } from "vitest";
import {
  closeShiftInput, paymentMethod, saleInput, saleResult, salesReturnInput, salesReturnResult, shiftSummaryResult,
} from "@bongcun/core/pos";
import { payPickupInput, placeOrderInput, placedOrderResult } from "@bongcun/core/shop";

const id = "7b0c6a52-0a6e-4f6c-9d5f-0d3f0a1b2c3d";

describe("pos contracts", () => {
  const sale = {
    branchId: id,
    customer: null,
    lines: [{ type: "product", id, qty: 1 }],
    discountAmount: 0,
    payments: [{ method: "cash", amount: 50000 }],
  };

  it("accepts a plain counter sale", () => {
    expect(saleInput.safeParse(sale).success).toBe(true);
  });

  it("rejects an empty cart, an unknown payment method and a negative discount", () => {
    expect(saleInput.safeParse({ ...sale, lines: [] }).success).toBe(false);
    expect(paymentMethod.safeParse("bitcoin").success).toBe(false);
    expect(saleInput.safeParse({ ...sale, discountAmount: -1 }).success).toBe(false);
  });

  it("checks the refund and the counted cash", () => {
    expect(salesReturnInput.safeParse({ invoiceId: id, reason: "", refundMethod: "cash", lines: [] }).success).toBe(false);
    expect(closeShiftInput.safeParse({ shiftId: id, countedCash: -5 }).success).toBe(false);
  });

  it("reads the answers the database gives", () => {
    expect(saleResult.parse({ id, code: "HD1", total: 5, change_amount: 0 }).replayed).toBeUndefined();
    expect(salesReturnResult.safeParse({ id, code: "TH1" }).success).toBe(false);
    expect(shiftSummaryResult.safeParse({ opening_cash: 1 }).success).toBe(false);
  });
});

describe("shop contracts", () => {
  const order = {
    clientRef: id,
    deliveryMethod: "delivery",
    addressId: id,
    receiver: null,
    lines: [{ productId: id, unitId: null, qty: 2 }],
    shippingFeeQuote: 30000,
    note: "",
  };

  it("needs an address to deliver and a receiver to pick up", () => {
    expect(placeOrderInput.safeParse(order).success).toBe(true);
    expect(placeOrderInput.safeParse({ ...order, addressId: null }).success).toBe(false);
    expect(placeOrderInput.safeParse({ ...order, deliveryMethod: "pickup", addressId: null }).success).toBe(false);
    expect(
      placeOrderInput.safeParse({ ...order, deliveryMethod: "pickup", addressId: null, receiver: { name: "An", phone: "0900" } }).success
    ).toBe(true);
  });

  it("limits a cart to 30 lines", () => {
    const lines = Array.from({ length: 31 }, () => order.lines[0]);
    expect(placeOrderInput.safeParse({ ...order, lines }).success).toBe(false);
  });

  it("takes a numeric string total from the database", () => {
    expect(placedOrderResult.parse({ id, code: "DH1", total: "150000", replayed: false }).total).toBe(150000);
  });

  it("wants at least one payment to collect a pickup order", () => {
    expect(payPickupInput.safeParse({ orderId: id, payments: [] }).success).toBe(false);
  });
});
