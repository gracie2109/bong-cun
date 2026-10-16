// Finished spa tickets that can be paid in the POS (see 20261013050000_spa_billing.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, numOrNull, str, strOrNull } from "./parse";

type Client = SupabaseClient<Database>;

export type BillableTicket = {
  id: string;
  /** Code of the appointment it belongs to. */
  code: string;
  name: string;
  type: "service" | "combo";
  petId: string | null;
  petName: string | null;
  /** The price fixed at check-in. */
  unitPrice: number;
};

export const listBillableTickets = async (client: Client, branchId: string, customerId: string): Promise<BillableTicket[]> => {
  const rows = unwrap(await client.rpc("billable_appointment_items", { p_branch: branchId, p_customer: customerId }));
  return (Array.isArray(rows) ? rows : []).map((raw) => {
    const row = asRecord(raw);
    return {
      id: str(row.id),
      code: str(row.code),
      name: str(row.name),
      type: row.item_type === "combo" ? "combo" : "service",
      petId: strOrNull(row.pet_id),
      petName: strOrNull(row.pet_name),
      unitPrice: numOrNull(row.unit_price) ?? 0,
    };
  });
};
