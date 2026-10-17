// Day board, week hours and billable ticket answers -> domain types. Pure: no client, no Vue.
import type { z } from "zod";
import type { billableTicketsSchema, dayBoardSchema, DayHours, weekHoursSchema } from "@bongcun/core/spa";
import type { BillableTicket, DayBoard } from "../types";

export const toDayBoard = (row: z.infer<typeof dayBoardSchema>): DayBoard => ({
  date: row.date,
  isClosed: row.is_closed,
  openTime: row.open_time,
  closeTime: row.close_time,
  staff: row.staff,
  resources: row.resources,
  tickets: row.items.map((item) => ({
    id: item.id,
    appointmentId: item.appointment_id,
    code: item.code,
    source: item.source,
    appointmentStatus: item.appointment_status,
    status: item.status,
    name: item.name,
    startAt: item.start_at,
    endAt: item.end_at,
    staffId: item.staff_id ?? null,
    resourceId: item.resource_id ?? null,
    petName: item.pet_name ?? null,
    petPhotoUrl: item.pet_photo_url ?? null,
    customerName: item.customer_name ?? "",
  })),
});

export const toWeekHours = (rows: z.infer<typeof weekHoursSchema>): DayHours[] =>
  rows.map((row) => ({ weekday: row.weekday, openTime: row.open_time, closeTime: row.close_time, isClosed: row.is_closed }));

export const toBillableTickets = (rows: z.infer<typeof billableTicketsSchema>): BillableTicket[] =>
  rows.map((row) => ({
    id: row.id,
    code: row.code,
    name: row.name,
    type: row.item_type,
    petId: row.pet_id ?? null,
    petName: row.pet_name ?? null,
    petPhotoUrl: row.pet_photo_url ?? null,
    unitPrice: row.unit_price ?? 0,
  }));
