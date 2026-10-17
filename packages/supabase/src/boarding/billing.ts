// Checked-out stays that can be paid in the POS (see 20261020040000_boarding_billing.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { billableStaysSchema } from "@bongcun/core/boarding";
import type { BillableBoardingStay } from "@bongcun/core/boarding";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toBillableStay } from "./mappers";

type Client = SupabaseClient<Database>;

export const listBillableBoarding = async (client: Client, branchId: string, customerId: string): Promise<BillableBoardingStay[]> => {
  const raw = unwrap(await client.rpc("billable_boarding_charges", { p_branch: branchId, p_customer: customerId }));
  return (parseRpc("billable_boarding_charges", billableStaysSchema, raw) ?? []).map(toBillableStay);
};
