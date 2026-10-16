// Checked-out stays that can be paid in the POS (see 20261020040000_boarding_billing.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { BillableBoardingStay } from "@bongcun/core/boarding";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

export const listBillableBoarding = async (client: Client, branchId: string, customerId: string): Promise<BillableBoardingStay[]> => {
  const rows = unwrap(await client.rpc("billable_boarding_charges", { p_branch: branchId, p_customer: customerId }));
  return (Array.isArray(rows) ? rows : []).map((raw) => {
    const row = asRecord(raw);
    const charges: unknown[] = Array.isArray(row.charges) ? row.charges : [];
    return {
      stayId: str(row.stay_id),
      code: str(row.code),
      total: Number(row.total ?? 0),
      charges: charges.map((chargeRaw) => {
        const charge = asRecord(chargeRaw);
        return {
          id: str(charge.id),
          name: str(charge.name),
          petName: strOrNull(charge.pet_name),
          qty: Number(charge.qty ?? 0),
          unitPrice: Number(charge.unit_price ?? 0),
          amount: Number(charge.amount ?? 0),
        };
      }),
    };
  });
};
