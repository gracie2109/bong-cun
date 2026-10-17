// Signed visits that can be paid in the POS (see 20261021050000_medical_billing.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { billableVisitsSchema } from "@bongcun/core/medical";
import type { BillableVisit } from "@bongcun/core/medical";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toBillableVisit } from "./mappers";

type Client = SupabaseClient<Database>;

export const listBillableMedical = async (client: Client, branchId: string, customerId: string): Promise<BillableVisit[]> => {
  const raw = unwrap(await client.rpc("billable_medical_items", { p_branch: branchId, p_customer: customerId }));
  return (parseRpc("billable_medical_items", billableVisitsSchema, raw) ?? []).map(toBillableVisit);
};
