// Appointments: booking, listing, check-in and ticket progress.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { appointmentPageSchema, appointmentRowSchema, savedAppointmentSchema } from "@bongcun/core/spa";
import type { AppointmentStatus, TicketStatus } from "@bongcun/core/spa";
import { parseRpc, unwrap, type Page } from "@bongcun/supabase/shared";
import { toAppointment } from "./mappers";
import type { Appointment, AppointmentFilter, AppointmentInput, PetWeight } from "./types";

type Client = SupabaseClient<Database>;

export const listAppointments = async (
  client: Client,
  branchId: string,
  page: { pageIndex: number; pageSize: number },
  filter: AppointmentFilter = {}
): Promise<Page<Appointment>> => {
  const raw = unwrap(
    await client.rpc("list_appointments", {
      p_branch: branchId,
      p_from: filter.from || undefined,
      p_to: filter.to || undefined,
      p_status: filter.status || undefined,
      p_search: filter.search?.trim() || undefined,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
    })
  );
  const result = parseRpc("list_appointments", appointmentPageSchema, raw);
  return { rows: (result.rows ?? []).map(toAppointment), total: result.total };
};

/** Books (no id) or replaces a booked appointment. Names, durations and prices come from the catalog. */
export const saveAppointment = async (
  client: Client,
  input: AppointmentInput,
  id?: string
): Promise<{ id: string; code: string }> => {
  const raw = unwrap(
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
  );
  return parseRpc("save_appointment", savedAppointmentSchema, raw);
};

export const cancelAppointment = async (client: Client, id: string, reason?: string): Promise<void> => {
  unwrap(await client.rpc("cancel_appointment", { p_id: id, p_reason: reason }));
};

/** One appointment by id, in the same shape as the list; null when it does not exist. */
export const getAppointment = async (client: Client, id: string): Promise<Appointment | null> => {
  const row = unwrap(await client.rpc("get_appointment", { p_id: id }));
  return row ? toAppointment(parseRpc("get_appointment", appointmentRowSchema, row)) : null;
};

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

