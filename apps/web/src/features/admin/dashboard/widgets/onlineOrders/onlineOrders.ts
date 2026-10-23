import type { ShopOrderStatus } from "@bongcun/core/shop";

/** The statuses worth a glance on the dashboard, in the order an order moves through them. */
export const ONLINE_ORDER_STATUSES: readonly ShopOrderStatus[] = ["pending", "confirmed", "packed", "shipping"];

export type OrderCounts = Partial<Record<ShopOrderStatus, number>>;

export const countOf = (counts: OrderCounts | undefined, status: ShopOrderStatus): number => counts?.[status] ?? 0;

/** True when no order waits for a step. */
export const noOpenOrders = (counts: OrderCounts | undefined): boolean =>
  ONLINE_ORDER_STATUSES.every((status) => countOf(counts, status) === 0);
