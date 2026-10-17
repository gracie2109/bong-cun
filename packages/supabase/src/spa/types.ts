// Domain types of the spa admin module; the repositories and their mappers share them.
import type { AppointmentStatus, TicketStatus } from "@bongcun/core/spa";

export type { AppointmentInput, DayHours, PetWeight, TicketInput } from "@bongcun/core/spa";

export type AppointmentTicket = {
  id: string;
  name: string;
  type: "service" | "combo";
  /** The service or combo booked. */
  itemId: string;
  status: TicketStatus;
  petId: string | null;
  petName: string | null;
  petPhotoUrl: string | null;
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

export type AppointmentFilter = {
  /** Business dates (yyyy-MM-dd), inclusive. */
  from?: string;
  to?: string;
  status?: AppointmentStatus | "";
  search?: string;
};

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
  petPhotoUrl: string | null;
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

export type BillableTicket = {
  id: string;
  /** Code of the appointment it belongs to. */
  code: string;
  name: string;
  type: "service" | "combo";
  petId: string | null;
  petName: string | null;
  petPhotoUrl: string | null;
  /** The price fixed at check-in. */
  unitPrice: number;
};
