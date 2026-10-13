// Spa appointments: bookings with one ticket per pet and service, each with a staff member and
// a table. Reads and writes go through RPCs (supabase/migrations/20261013030000_spa_appointments.sql),
// which check the "schedule" permission at the branch, the opening hours and double booking.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap, type Page } from "./shared";

type Client = SupabaseClient<Database>;

export type AppointmentStatus = "booked" | "checked_in" | "in_progress" | "done" | "paid" | "cancelled" | "no_show";
export type TicketStatus = "waiting" | "in_progress" | "done" | "cancelled";

export const APPOINTMENT_STATUSES: readonly AppointmentStatus[] = [
  "booked",
  "checked_in",
  "in_progress",
  "done",
  "paid",
  "cancelled",
  "no_show",
];

/** The tickets of a booked appointment can still be changed; nothing else can. */
export const isEditable = (status: AppointmentStatus): boolean => status === "booked";

/** Minutes between the start times offered when booking; the database requires the same step. */
export const SLOT_MINUTES = 15;

// Hints the RPCs attach to a refusal (see save_appointment).
export const SPA_ERROR_HINTS = [
  "slot_staff",
  "slot_resource",
  "closed",
  "outside_hours",
  "bad_time",
  "in_past",
  "not_editable",
  "no_customer",
  "no_pet",
  "bad_hours",
] as const;
export type SpaErrorHint = (typeof SPA_ERROR_HINTS)[number];

export const spaErrorHint = (error: unknown): SpaErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return SPA_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** The service an error is about (the ticket that clashed), when the database names one. */
export const spaErrorDetail = (error: unknown): string => (error as { details?: string } | null)?.details ?? "";

const str = (value: unknown): string => (typeof value === "string" ? value : "");
const strOrNull = (value: unknown): string | null => (typeof value === "string" ? value : null);
const numOrNull = (value: unknown): number | null => (value === null || value === undefined ? null : Number(value));

// ------------------------------------------------------------- spa tables
export type SpaResource = { id: string; branchId: string; name: string; isActive: boolean; sortOrder: number };

const toSpaResource = (row: Tables<"spa_resources">): SpaResource => ({
  id: row.id,
  branchId: row.branch_id,
  name: row.name,
  isActive: row.is_active,
  sortOrder: row.sort_order,
});

export const listSpaResources = async (client: Client, branchId: string): Promise<SpaResource[]> =>
  unwrap(
    await client
      .from("spa_resources")
      .select("*")
      .eq("branch_id", branchId)
      .order("sort_order")
      .order("name")
  ).map(toSpaResource);

export type SpaResourceInput = { branchId: string; name: string; isActive?: boolean; sortOrder?: number };

export const saveSpaResource = async (client: Client, input: SpaResourceInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("save_spa_resource", {
      p: {
        branch_id: input.branchId,
        name: input.name,
        is_active: input.isActive ?? null,
        sort_order: input.sortOrder ?? null,
      },
      p_id: id,
    })
  );

// ---------------------------------------------------------------- hours
export type DayHours = { weekday: number; openTime: string; closeTime: string; isClosed: boolean };

/** Monday = 1 ... Sunday = 7, as the database stores it. */
export const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7] as const;

export const getWeekHours = async (client: Client, branchId: string): Promise<DayHours[]> => {
  const rows = unwrap(await client.rpc("spa_week_hours", { p_branch: branchId })) as Record<string, unknown>[] | null;
  return (rows ?? []).map((row) => ({
    weekday: Number(row.weekday),
    openTime: str(row.open_time),
    closeTime: str(row.close_time),
    isClosed: row.is_closed === true,
  }));
};

export const saveWeekHours = async (client: Client, branchId: string, hours: DayHours[]): Promise<void> => {
  unwrap(
    await client.rpc("save_branch_hours", {
      p_branch: branchId,
      p: hours.map((day) => ({
        weekday: day.weekday,
        open_time: day.openTime,
        close_time: day.closeTime,
        is_closed: day.isClosed,
      })),
    })
  );
};

// ---------------------------------------------------------------- staff
export type BranchStaff = { userId: string; name: string; role: string; doesServices: boolean };

export const listBranchStaff = async (client: Client, branchId: string): Promise<BranchStaff[]> =>
  unwrap(await client.rpc("list_branch_staff", { p_branch: branchId })).map((row) => ({
    userId: row.user_id,
    name: row.name,
    role: row.role,
    doesServices: row.does_services,
  }));

export const setStaffDoesServices = async (
  client: Client,
  args: { userId: string; branchId: string; value: boolean }
): Promise<void> => {
  unwrap(
    await client.rpc("set_staff_does_services", {
      p_user: args.userId,
      p_branch: args.branchId,
      p_value: args.value,
    })
  );
};

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
  unitPrice: number | null;
};

export type Appointment = {
  id: string;
  code: string;
  status: AppointmentStatus;
  startAt: string;
  endAt: string;
  customerId: string;
  customerName: string;
  customerPhone: string;
  note: string | null;
  tickets: AppointmentTicket[];
};

const asRecord = (value: unknown): Record<string, unknown> => (value ?? {}) as Record<string, unknown>;

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
    unitPrice: numOrNull(row.unit_price),
  };
};

const toAppointment = (raw: unknown): Appointment => {
  const row = asRecord(raw);
  return {
    id: str(row.id),
    code: str(row.code),
    status: str(row.status) as AppointmentStatus,
    startAt: str(row.start_at),
    endAt: str(row.end_at),
    customerId: str(row.customer_id),
    customerName: str(row.customer_name),
    customerPhone: str(row.customer_phone),
    note: strOrNull(row.note),
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

// ----------------------------------------------------------------- day board
export type BoardTicket = {
  id: string;
  appointmentId: string;
  code: string;
  appointmentStatus: AppointmentStatus;
  status: TicketStatus;
  name: string;
  startAt: string;
  endAt: string;
  staffId: string | null;
  resourceId: string | null;
  petName: string | null;
  customerName: string;
};

export type DayBoard = {
  date: string;
  isClosed: boolean;
  /** HH:MM */
  openTime: string;
  closeTime: string;
  staff: { id: string; name: string }[];
  resources: { id: string; name: string }[];
  tickets: BoardTicket[];
};

export const getDayBoard = async (client: Client, branchId: string, date: string): Promise<DayBoard> => {
  const row = asRecord(unwrap(await client.rpc("spa_day_board", { p_branch: branchId, p_date: date })));
  const list = (value: unknown): Record<string, unknown>[] => (Array.isArray(value) ? value : []);
  return {
    date: str(row.date),
    isClosed: row.is_closed === true,
    openTime: str(row.open_time),
    closeTime: str(row.close_time),
    staff: list(row.staff).map((item) => ({ id: str(item.id), name: str(item.name) })),
    resources: list(row.resources).map((item) => ({ id: str(item.id), name: str(item.name) })),
    tickets: list(row.items).map((item) => ({
      id: str(item.id),
      appointmentId: str(item.appointment_id),
      code: str(item.code),
      appointmentStatus: str(item.appointment_status) as AppointmentStatus,
      status: str(item.status) as TicketStatus,
      name: str(item.name),
      startAt: str(item.start_at),
      endAt: str(item.end_at),
      staffId: strOrNull(item.staff_id),
      resourceId: strOrNull(item.resource_id),
      petName: strOrNull(item.pet_name),
      customerName: str(item.customer_name),
    })),
  };
};

/** One appointment by its code (the day board only knows the code of a ticket's appointment). */
export const findAppointment = async (client: Client, branchId: string, code: string): Promise<Appointment | null> => {
  const { rows } = await listAppointments(client, branchId, { pageIndex: 1, pageSize: 5 }, { search: code });
  return rows.find((row) => row.code === code) ?? null;
};
