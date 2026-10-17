// In-patient care. Reads and writes go through RPCs (supabase/migrations/20261021080*.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  admittedSchema,
  dischargedSchema,
  givenDoseSchema,
  inpatientKennelsSchema,
  wardSchema,
} from "@bongcun/core/medical";
import type { AdmitInput, InpatientKennel, LogKind, OrderInput, Ward } from "@bongcun/core/medical";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { orderPayload } from "./inpatientOrders";
import { toInpatientKennel, toWard } from "./mappers";

type Client = SupabaseClient<Database>;

export const listInpatientKennels = async (client: Client, branchId: string): Promise<InpatientKennel[]> =>
  (parseRpc("inpatient_kennels", inpatientKennelsSchema, unwrap(await client.rpc("inpatient_kennels", { p_branch: branchId }))) ?? []).map(
    toInpatientKennel
  );

export const getInpatientWard = async (client: Client, branchId: string, date?: string): Promise<Ward> =>
  toWard(parseRpc("inpatient_ward", wardSchema, unwrap(await client.rpc("inpatient_ward", { p_branch: branchId, p_date: date }))));

export const admitInpatient = async (client: Client, visitId: string, input: AdmitInput): Promise<void> => {
  parseRpc(
    "admit_inpatient",
    admittedSchema,
    unwrap(
      await client.rpc("admit_inpatient", {
        p_visit: visitId,
        p: { kennel_id: input.kennelId, planned_out_at: input.plannedOutAt, note: input.note },
      })
    )
  );
};

export const saveInpatientOrder = async (client: Client, input: OrderInput): Promise<void> => {
  unwrap(await client.rpc("save_inpatient_order", { p: orderPayload(input) }));
};

/** Returns the warnings of the line the dose was added to (low_stock). */
export const giveInpatientDose = async (client: Client, id: string): Promise<string[]> =>
  parseRpc("give_inpatient_dose", givenDoseSchema, unwrap(await client.rpc("give_inpatient_dose", { p_dose: id }))).warnings ?? [];

export const skipInpatientDose = async (client: Client, id: string, reason: string): Promise<void> => {
  unwrap(await client.rpc("skip_inpatient_dose", { p_dose: id, p_reason: reason }));
};

export const addInpatientLog = async (client: Client, stayPetId: string, kind: LogKind, content: string): Promise<void> => {
  unwrap(await client.rpc("add_inpatient_log", { p_stay_pet: stayPetId, p: { kind, content } }));
};

export const dischargeInpatient = async (client: Client, stayId: string): Promise<void> => {
  parseRpc("discharge_inpatient", dischargedSchema, unwrap(await client.rpc("discharge_inpatient", { p_stay: stayId })));
};
