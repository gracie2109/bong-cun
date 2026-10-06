// Orders (parent) and their lines. Replaces the Firestore pair order-services /
// order-services-service, where the parent held an `order_service[]` array of ids.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { listPetCombosByIds, type PetCombo } from "./petCombos";
import { listAllPetServices, type PetService } from "./petServices";
import { pageRange, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;
type OrderRow = Tables<"orders"> & { order_items: Tables<"order_items">[] };

export type OrderLineStatus = "PENDING" | "PROCESSING" | "CONFIRMED" | "CANCEL";

export type OrderLine = {
  /** Service id, or combo id when `type` is "combo". */
  id: string;
  name: string;
  price: number;
  /** Single-element array (the shape the detail screen reads). Minutes. */
  duration: number[];
  type: "combo" | "service";
  status: OrderLineStatus;
};

export type Order = {
  id: string;
  name: string;
  phoneNumber: string;
  petNum: number | null;
  /** When the customer wants to come (ISO), or null. */
  time: string | null;
  services: OrderLine[];
  status: OrderLineStatus;
  createdAt: string;
};

/** A line of an order, expanded to its current catalog entry. */
export type OrderDetailService = {
  id: string;
  name: string;
  /** "combo" for a combo; otherwise the service's own type ("all" / "by_weight"). */
  type: string | null;
  /** Combo price (null for a single service). */
  price: number | null;
  /** Single-service price (null for a combo). */
  generalPrice: number | null;
  /** Single-element array, minutes. */
  duration: number[];
  /** The services a combo is made of (empty for a single service). */
  serviceProfiles: PetService[];
};

export type OrderDetail = Omit<Order, "services"> & {
  /** Combos first, then single services (the order the old screen used). */
  services: OrderDetailService[];
};

const fromCombo = (combo: PetCombo): OrderDetailService => ({
  id: combo.id,
  name: combo.name,
  type: "combo",
  price: combo.price,
  generalPrice: null,
  duration: combo.duration,
  serviceProfiles: combo.serviceProfiles,
});

const fromService = (service: PetService): OrderDetailService => ({
  id: service.id,
  name: service.name,
  type: service.type,
  price: null,
  generalPrice: service.generalPrice,
  duration: service.duration,
  serviceProfiles: [],
});

export type CreateOrderInput = {
  name: string;
  phoneNumber: string;
  petNum?: number | string | null;
  time?: Date | string | null;
  services: {
    id: string;
    type: "combo" | "service";
    name: string;
    price: number | string;
    duration?: number[] | null;
  }[];
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

export const listOrders = async (
  client: Client,
  page: PageParams,
  filter: { phoneNumber?: string } = {}
): Promise<Page<Order>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("orders")
    .select(SELECT_WITH_ITEMS, { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);
  if (filter.phoneNumber) query = query.eq("phone_number", filter.phoneNumber);

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data as OrderRow[]).map(toOrder), total: count ?? 0 };
};

/** One order with each line expanded to its current catalog entry. */
export const getOrderDetail = async (client: Client, id: string): Promise<OrderDetail | null> => {
  const row = unwrap(
    await client.from("orders").select(SELECT_WITH_ITEMS).eq("id", id).maybeSingle()
  );
  if (!row) return null;

  const order = toOrder(row as OrderRow);
  const comboIds = order.services.filter((line) => line.type === "combo").map((line) => line.id);
  const serviceIds = new Set(
    order.services.filter((line) => line.type !== "combo").map((line) => line.id)
  );

  const [combos, allServices] = await Promise.all([
    listPetCombosByIds(client, comboIds),
    serviceIds.size > 0 ? listAllPetServices(client) : Promise.resolve([]),
  ]);

  const { services: _lines, ...rest } = order;
  return {
    ...rest,
    services: [
      ...combos.map(fromCombo),
      ...allServices.filter((service) => serviceIds.has(service.id)).map(fromService),
    ],
  };
};

/** Creates an order and its lines in one transaction; the caller becomes the owner. */
export const createOrder = async (client: Client, input: CreateOrderInput): Promise<string> =>
  unwrap(
    await client.rpc("create_order", {
      p: {
        name: input.name,
        phone_number: input.phoneNumber,
        pet_num: input.petNum ?? null,
        scheduled_at: input.time ? new Date(input.time).toISOString() : null,
        services: input.services.map((service) => ({
          id: service.id,
          type: service.type,
          name: service.name,
          price: service.price,
          duration_minutes: service.duration?.[0] ?? null,
        })),
      },
    })
  );

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
