// "My appointments": the customer's spa visits, listed and cancelled through RPCs (docs 3.6).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { AppointmentScope, MyAppointment } from "@bongcun/core/account";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

type AppointmentJson = {
  id: string;
  code: string;
  status: string;
  start_at: string;
  end_at: string;
  note: string | null;
  branch_name: string;
  branch_phone: string | null;
  can_cancel: boolean;
  est_total: number;
  has_unpriced: boolean;
  items: { name: string; pet_name: string | null; pet_photo_url: string | null; start_at: string; status: string; est_price: number | null }[];
};

const toAppointment = (row: AppointmentJson): MyAppointment => ({
  id: row.id,
  code: row.code,
  status: row.status,
  startAt: row.start_at,
  endAt: row.end_at,
  note: row.note ?? "",
  branchName: row.branch_name,
  branchPhone: row.branch_phone ?? "",
  canCancel: row.can_cancel,
  estTotal: Number(row.est_total),
  hasUnpriced: row.has_unpriced,
  items: row.items.map((item) => ({
    name: item.name,
    petName: item.pet_name ?? "",
    petPhotoUrl: item.pet_photo_url,
    startAt: item.start_at,
    status: item.status,
    estPrice: item.est_price === null ? null : Number(item.est_price),
  })),
});

export type MyAppointmentPage = { total: number; rows: MyAppointment[] };

export const listMyAppointments = async (
  client: Client,
  scope: AppointmentScope,
  page: number,
  pageSize: number
): Promise<MyAppointmentPage> => {
  const json = unwrap(await client.rpc("my_appointments", { p_scope: scope, p_page: page, p_page_size: pageSize })) as {
    total: number;
    rows: AppointmentJson[];
  };
  return { total: Number(json.total), rows: json.rows.map(toAppointment) };
};

export const cancelMyAppointment = async (client: Client, id: string, reason?: string): Promise<void> => {
  unwrap(await client.rpc("cancel_my_appointment", { p_id: id, p_reason: reason ?? null }));
};

/** Error hints raised by cancel_my_appointment, for readable messages. */
export const CANCEL_ERROR_HINTS = ["no_customer", "not_found", "not_cancellable", "too_late"] as const;
export type CancelErrorHint = (typeof CANCEL_ERROR_HINTS)[number];

export const cancelErrorHint = (error: unknown): CancelErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return CANCEL_ERROR_HINTS.find((item) => item === hint) ?? null;
};
