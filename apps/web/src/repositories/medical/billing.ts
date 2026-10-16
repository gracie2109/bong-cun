// Signed visits that can be paid in the POS (see 20261021050000_medical_billing.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { BillableVisit } from "@bongcun/core/medical";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

export const listBillableMedical = async (client: Client, branchId: string, customerId: string): Promise<BillableVisit[]> => {
  const rows = unwrap(await client.rpc("billable_medical_items", { p_branch: branchId, p_customer: customerId }));
  return (Array.isArray(rows) ? rows : []).map((raw) => {
    const row = asRecord(raw);
    const items: unknown[] = Array.isArray(row.items) ? row.items : [];
    return {
      visitId: str(row.visit_id),
      code: str(row.code),
      petName: str(row.pet_name),
      total: Number(row.total ?? 0),
      items: items.map((itemRaw) => {
        const item = asRecord(itemRaw);
        return {
          id: str(item.id),
          kind: item.kind === "product" ? "product" : "service",
          name: str(item.name),
          qty: Number(item.qty ?? 0),
          unitName: strOrNull(item.unit_name),
          unitPrice: Number(item.unit_price ?? 0),
          amount: Number(item.amount ?? 0),
        };
      }),
    };
  });
};
