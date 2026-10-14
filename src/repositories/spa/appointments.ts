// Appointments: booking, listing, check-in and ticket progress.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap, type Page } from "../shared";
import { asRecord, numOrNull, str, strOrNull } from "./parse";
import type { AppointmentStatus, TicketStatus } from "./rules";

type Client = SupabaseClient<Database>;

// --------------------------------------------------------- appointments
export type AppointmentTicket = {
  id: string;
  name: string;
  type: "service" | "combo";
  /** The service or combo booked. */
  itemId: string;
  status: TicketStatus;
  petId: string | null;
  petName: string | null;
  staffId: string | null;
  staffName: string | null;
  resourceId: string | null;
  resourceName: string | null;
  startAt: string;
  endAt: string;
  estPrice: number | null;
  /** Weight taken at check-in (or the one the price was estimated from). */
  weightKg: number | null;
  /** The price fixed at check-in. */
  unitPrice: number | null;
  /** Already on an invoice. */
  billed: boolean;
};

/** Where an appointment came from; 'web' = booked by the customer on the website. */
export type AppointmentSource = "counter" | "phone" | "legacy" | "web";

export type Appointment = {
  id: string;
  code: string;
  source: AppointmentSource;
  status: AppointmentStatus;
  startAt: string;
  endAt: string;
  customerId: string;
  customerName: string;
  customerPhone: string;
  note: string | null;
  checkedInAt: string | null;
  tickets: AppointmentTicket[];
};


const toTicket = (raw: unknown): AppointmentTicket => {
  const row = asRecord(raw);
  return {
    id: str(row.id),
    name: str(row.name),
    type: row.item_type === "combo" ? "combo" : "service",
    itemId: str(row.item_type === "combo" ? row.combo_id : row.service_id),
    status: str(row.status) as TicketStatus,
    petId: strOrNull(row.pet_id),
    petName: strOrNull(row.pet_name),
    staffId: strOrNull(row.staff_id),
    staffName: strOrNull(row.staff_name),
    resourceId: strOrNull(row.resource_id),
    resourceName: strOrNull(row.resource_name),
    startAt: str(row.start_at),
    endAt: str(row.end_at),
    estPrice: numOrNull(row.est_price),
    weightKg: numOrNull(row.weight_kg),
    unitPrice: numOrNull(row.unit_price),
    billed: row.billed === true,
  };
};

const toAppointment = (raw: unknown): Appointment => {
  const row = asRecord(raw);
  return {
    id: str(row.id),
    code: str(row.code),
    source: str(row.source) as AppointmentSource,
    status: str(row.status) as AppointmentStatus,
    startAt: str(row.start_at),
    endAt: str(row.end_at),
    customerId: str(row.customer_id),
    customerName: str(row.customer_name),
    customerPhone: str(row.customer_phone),
    note: strOrNull(row.note),
    checkedInAt: strOrNull(row.checked_in_at),
    tickets: Array.isArray(row.items) ? row.items.map(toTicket) : [],
  };
};

export type AppointmentFilter = {
  /** Business dates (yyyy-MM-dd), inclusive. */
  from?: string;
  to?: string;
  status?: AppointmentStatus | "";
  search?: string;
};

export const listAppointments = async (
  client: Client,
  branchId: string,
  page: { pageIndex: number; pageSize: number },
  filter: AppointmentFilter = {}
): Promise<Page<Appointment>> => {
  const result = asRecord(
    unwrap(
      await client.rpc("list_appointments", {
        p_branch: branchId,
        p_from: filter.from || undefined,
        p_to: filter.to || undefined,
        p_status: filter.status || undefined,
        p_search: filter.search?.trim() || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
      })
    )
  );
  const rows = Array.isArray(result.rows) ? result.rows : [];
  return { rows: rows.map(toAppointment), total: Number(result.total ?? 0) };
};

export type TicketInput = {
  petId: string;
  type: "service" | "combo";
  /** Service or combo id. */
  id: string;
  /** ISO timestamp, on a quarter hour. */
  startAt: string;
  staffId?: string | null;
  resourceId?: string | null;
  /** Only to estimate a by-weight price; the real weight is taken at check-in. */
  weightKg?: number | null;
};

export type AppointmentInput = {
  branchId: string;
  customerId: string;
  note?: string;
  source?: "counter" | "phone";
  tickets: TicketInput[];
};

/** Books (no id) or replaces a booked appointment. Names, durations and prices come from the catalog. */
export const saveAppointment = async (
  client: Client,
  input: AppointmentInput,
  id?: string
): Promise<{ id: string; code: string }> => {
  const result = asRecord(
    unwrap(
      await client.rpc("save_appointment", {
        p: {
          branch_id: input.branchId,
          customer_id: input.customerId,
          note: input.note ?? null,
          source: input.source ?? "counter",
          items: input.tickets.map((ticket) => ({
            pet_id: ticket.petId,
            type: ticket.type,
            id: ticket.id,
            start_at: ticket.startAt,
            staff_id: ticket.staffId ?? null,
            resource_id: ticket.resourceId ?? null,
            weight_kg: ticket.weightKg ?? null,
          })),
        },
        p_id: id,
      })
    )
  );
  return { id: str(result.id), code: str(result.code) };
};

export const cancelAppointment = async (client: Client, id: string, reason?: string): Promise<void> => {
  unwrap(await client.rpc("cancel_appointment", { p_id: id, p_reason: reason }));
};

/** One appointment by id, in the same shape as the list; null when it does not exist. */
export const getAppointment = async (client: Client, id: string): Promise<Appointment | null> => {
  const row = unwrap(await client.rpc("get_appointment", { p_id: id }));
  return row ? toAppointment(row) : null;
};

export type PetWeight = { petId: string; weightKg: number };

/** The pet has arrived: records the weights, fixes the price of every ticket and marks the appointment checked in. */
export const checkInAppointment = async (client: Client, id: string, weights: PetWeight[]): Promise<void> => {
  unwrap(
    await client.rpc("check_in_appointment", {
      p_id: id,
      p_weights: weights.map((item) => ({ pet_id: item.petId, weight_kg: item.weightKg })),
    })
  );
};

/** waiting -> in_progress -> done, plus one step back. */
export const setTicketStatus = async (client: Client, ticketId: string, status: TicketStatus): Promise<void> => {
  unwrap(await client.rpc("set_appointment_item_status", { p_item: ticketId, p_status: status }));
};

export const markNoShow = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("mark_no_show", { p_id: id }));
};

