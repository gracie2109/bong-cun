// Check-in / check-out rules of a branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { BoardingRules } from "@/types/boarding";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str } from "../spa/parse";

type Client = SupabaseClient<Database>;

export const getBoardingRules = async (client: Client, branchId: string): Promise<BoardingRules> => {
  const row = asRecord(unwrap(await client.rpc("boarding_settings_get", { p_branch: branchId })));
  return {
    checkInFrom: str(row.check_in_from),
    checkOutBy: str(row.check_out_by),
    lateHalfUntil: str(row.late_half_until),
    maxNights: Number(row.max_nights ?? 30),
    dayStayNights: Number(row.day_stay_nights ?? 1),
  };
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
