// Legacy orders (read-only). Booking now lives in appointments (see repositories/spa);
// only the per-customer history/stats on the customers screen still reads this table.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;
type OrderRow = Tables<"orders"> & { order_items: Tables<"order_items">[] };

export type OrderLineStatus = "PENDING" | "PROCESSING" | "CONFIRMED" | "CANCEL";

export type OrderLine = {
  /** Service id, or combo id when `type` is "combo". */
  id: string;
  name: string;
  price: number;
  /** Single-element array. Minutes. */
  duration: number[];
  type: "combo" | "service";
  status: OrderLineStatus;
};

export type Order = {
  id: string;
  name: string;
  phoneNumber: string;
  petNum: number | null;
  /** When the customer wanted to come (ISO), or null. */
  time: string | null;
  services: OrderLine[];
  status: OrderLineStatus;
  createdAt: string;
};

const SELECT_WITH_ITEMS = "*, order_items(*)";

/** An order's status is derived from its lines: the least-finished line wins. */
export const deriveOrderStatus = (lines: { status: OrderLineStatus }[]): OrderLineStatus => {
  if (lines.some((line) => line.status === "PENDING")) return "PENDING";
  if (lines.some((line) => line.status === "PROCESSING")) return "PROCESSING";
  if (lines.length > 0 && lines.every((line) => line.status === "CANCEL")) return "CANCEL";
  return lines.length > 0 ? "CONFIRMED" : "PENDING";
};

const toOrder = (row: OrderRow): Order => {
  const services = row.order_items.map<OrderLine>((item) => ({
    id: (item.combo_id ?? item.service_id) as string,
    name: item.name,
    price: item.price,
    duration: [item.duration_minutes ?? 0],
    type: item.combo_id ? "combo" : "service",
    status: item.status as OrderLineStatus,
  }));
  return {
    id: row.id,
    name: row.name,
    phoneNumber: row.phone_number,
    petNum: row.pet_num,
    time: row.scheduled_at,
    services,
    status: deriveOrderStatus(services),
    createdAt: row.created_at,
  };
};

export type CustomerOrder = Order & { userId: string };

/** Every order placed by the given accounts, newest first (for per-customer stats and history). */
export const listOrdersByUserIds = async (
  client: Client,
  userIds: string[]
): Promise<CustomerOrder[]> => {
  if (userIds.length === 0) return [];
  const rows = unwrap(
    await client
      .from("orders")
      .select(SELECT_WITH_ITEMS)
      .in("user_id", userIds)
      .order("created_at", { ascending: false })
  ) as OrderRow[];
  return rows.map((row) => ({ ...toOrder(row), userId: row.user_id as string }));
};
