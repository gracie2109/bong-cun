// In-patient care. Reads and writes go through RPCs (supabase/migrations/20261021080*.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { AdmitInput, InpatientKennel, LogKind, OrderInput, OrderKind, Ward, WardDose, WardOrder, WardRow } from "@bongcun/core/medical";
import { unwrap } from "@bongcun/supabase/shared";
import { orderPayload } from "./inpatientOrders";
import { asRecord, str, strOrNull } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

const listOf = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);
const KINDS: OrderKind[] = ["product", "service", "care"];

export const listInpatientKennels = async (client: Client, branchId: string): Promise<InpatientKennel[]> =>
  listOf(unwrap(await client.rpc("inpatient_kennels", { p_branch: branchId }))).map((raw) => {
    const row = asRecord(raw);
    return {
      id: str(row.id),
      code: str(row.code),
      typeName: str(row.type_name),
      purpose: row.purpose === "isolation" ? "isolation" : "medical",
      free: row.free === true,
    };
  });

const toOrder = (raw: unknown): WardOrder => {
  const row = asRecord(raw);
  return {
    id: str(row.id),
    kind: KINDS.find((kind) => kind === row.kind) ?? "care",
    productId: strOrNull(row.product_id),
    serviceId: strOrNull(row.service_id),
    name: str(row.name),
    dose: str(row.dose),
    qtyPerDose: Number(row.qty_per_dose ?? 1),
    times: listOf(row.times).map(str),
    startOn: str(row.start_on),
    endOn: str(row.end_on),
    note: str(row.note),
    edited: Number(row.edited ?? 0),
    missed: Number(row.missed ?? 0),
  };
};

const toDose = (raw: unknown): WardDose => {
  const row = asRecord(raw);
  return {
    id: str(row.id),
    orderId: str(row.order_id),
    dueAt: str(row.due_at),
    givenAt: strOrNull(row.given_at),
    givenByName: strOrNull(row.given_by_name),
    skippedReason: strOrNull(row.skipped_reason),
    qty: row.qty == null ? null : Number(row.qty),
  };
};

const toRow = (raw: unknown): WardRow => {
  const row = asRecord(raw);
  const vitals = row.last_vitals ? asRecord(row.last_vitals) : null;
  return {
    stayId: str(row.stay_id),
    stayCode: str(row.stay_code),
    stayPetId: str(row.stay_pet_id),
    visitId: str(row.visit_id),
    visitCode: str(row.visit_code),
    petId: str(row.pet_id),
    petName: str(row.pet_name),
    petPhotoUrl: strOrNull(row.pet_photo_url),
    customerName: str(row.customer_name),
    customerPhone: str(row.customer_phone),
    kennelCode: str(row.kennel_code),
    purpose: row.purpose === "isolation" ? "isolation" : "medical",
    since: str(row.since),
    plannedOutAt: str(row.planned_out_at),
    overdue: row.overdue === true,
    allergies: strOrNull(row.allergies),
    orders: listOf(row.orders).map(toOrder),
    doses: listOf(row.doses).map(toDose),
    lastVitals: vitals ? { content: str(vitals.content), loggedAt: str(vitals.logged_at) } : null,
  };
};

export const getInpatientWard = async (client: Client, branchId: string, date?: string): Promise<Ward> => {
  const data = asRecord(unwrap(await client.rpc("inpatient_ward", { p_branch: branchId, p_date: date })));
  return { date: str(data.date), rows: listOf(data.rows).map(toRow) };
};

export const admitInpatient = async (client: Client, visitId: string, input: AdmitInput): Promise<void> => {
  unwrap(
    await client.rpc("admit_inpatient", {
      p_visit: visitId,
      p: { kennel_id: input.kennelId, planned_out_at: input.plannedOutAt, note: input.note },
    })
  );
};

export const saveInpatientOrder = async (client: Client, input: OrderInput): Promise<void> => {
  unwrap(await client.rpc("save_inpatient_order", { p: orderPayload(input) }));
};

/** Returns the warnings of the line the dose was added to (low_stock). */
export const giveInpatientDose = async (client: Client, id: string): Promise<string[]> => {
  const data = asRecord(unwrap(await client.rpc("give_inpatient_dose", { p_dose: id })));
  return listOf(data.warnings).map(str);
};

export const skipInpatientDose = async (client: Client, id: string, reason: string): Promise<void> => {
  unwrap(await client.rpc("skip_inpatient_dose", { p_dose: id, p_reason: reason }));
};

export const addInpatientLog = async (client: Client, stayPetId: string, kind: LogKind, content: string): Promise<void> => {
  unwrap(await client.rpc("add_inpatient_log", { p_stay_pet: stayPetId, p: { kind, content } }));
};

export const dischargeInpatient = async (client: Client, stayId: string): Promise<void> => {
  unwrap(await client.rpc("discharge_inpatient", { p_stay: stayId }));
};
