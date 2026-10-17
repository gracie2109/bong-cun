// `get_appointment` / `list_appointments` rows -> domain types. Pure: no client, no Vue.
import type { AppointmentRow } from "@bongcun/core/spa";
import type { Appointment, AppointmentTicket } from "../types";

type TicketRow = NonNullable<AppointmentRow["items"]>[number];

export const toTicket = (row: TicketRow): AppointmentTicket => ({
  id: row.id,
  name: row.name,
  type: row.item_type,
  itemId: (row.item_type === "combo" ? row.combo_id : row.service_id) ?? "",
  status: row.status,
  petId: row.pet_id ?? null,
  petName: row.pet_name ?? null,
  petPhotoUrl: row.pet_photo_url ?? null,
  staffId: row.staff_id ?? null,
  staffName: row.staff_name ?? null,
  resourceId: row.resource_id ?? null,
  resourceName: row.resource_name ?? null,
  startAt: row.start_at,
  endAt: row.end_at,
  estPrice: row.est_price ?? null,
  weightKg: row.weight_kg ?? null,
  unitPrice: row.unit_price ?? null,
  billed: row.billed === true,
});

export const toAppointment = (row: AppointmentRow): Appointment => ({
  id: row.id,
  code: row.code,
  source: row.source,
  status: row.status,
  startAt: row.start_at,
  endAt: row.end_at,
  customerId: row.customer_id,
  customerName: row.customer_name ?? "",
  customerPhone: row.customer_phone ?? "",
  note: row.note ?? null,
  checkedInAt: row.checked_in_at ?? null,
  tickets: (row.items ?? []).map(toTicket),
});
