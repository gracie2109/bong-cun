// The day view and the lookup behind a click on one of its tickets.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "../shared";
import { type Appointment, listAppointments } from "./appointments";
import { asRecord, str, strOrNull } from "./parse";
import type { AppointmentStatus, TicketStatus } from "./rules";

type Client = SupabaseClient<Database>;

// ----------------------------------------------------------------- day board
export type BoardTicket = {
  id: string;
  appointmentId: string;
  code: string;
  /** 'web' for a booking made by the customer online. */
  source: string;
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
      source: str(item.source),
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

