// Medical rules of a branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { MedicalRules } from "@bongcun/core/medical";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

export const getMedicalRules = async (client: Client, branchId: string): Promise<MedicalRules> => {
  const row = asRecord(unwrap(await client.rpc("medical_settings_get", { p_branch: branchId })));
  return {
    examServiceId: strOrNull(row.exam_service_id),
    examServiceName: strOrNull(row.exam_service_name),
    remindAheadDays: Number(row.remind_ahead_days ?? 7),
    contagiousDays: Number(row.contagious_days ?? 30),
    requireVaccineForBoarding: row.require_vaccine_for_boarding === true,
  };
};

export const saveMedicalRules = async (client: Client, branchId: string, rules: MedicalRules): Promise<void> => {
  unwrap(
    await client.rpc("save_medical_settings", {
      p_branch: branchId,
      p: {
        exam_service_id: rules.examServiceId,
        remind_ahead_days: rules.remindAheadDays,
        contagious_days: rules.contagiousDays,
        require_vaccine_for_boarding: rules.requireVaccineForBoarding,
      },
    })
  );
};
