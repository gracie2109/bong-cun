// Check-in / check-out rules of a branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { BoardingRules } from "@bongcun/core/boarding";
import { boardingRulesRowSchema } from "@bongcun/core/boarding";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toBoardingRules } from "./mappers";

type Client = SupabaseClient<Database>;

export const getBoardingRules = async (client: Client, branchId: string): Promise<BoardingRules> => {
  const raw = unwrap(await client.rpc("boarding_settings_get", { p_branch: branchId }));
  return toBoardingRules(parseRpc("boarding_settings_get", boardingRulesRowSchema, raw));
};

export const saveBoardingRules = async (client: Client, branchId: string, rules: BoardingRules): Promise<void> => {
  unwrap(
    await client.rpc("save_boarding_settings", {
      p_branch: branchId,
      p: {
        check_in_from: rules.checkInFrom,
        check_out_by: rules.checkOutBy,
        late_half_until: rules.lateHalfUntil,
        max_nights: rules.maxNights,
        day_stay_nights: rules.dayStayNights,
      },
    })
  );
};
