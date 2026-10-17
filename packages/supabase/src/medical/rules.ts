// Medical rules of a branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { MedicalRules } from "@bongcun/core/medical";
import { medicalRulesRowSchema } from "@bongcun/core/medical";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toMedicalRules } from "./mappers";

type Client = SupabaseClient<Database>;

export const getMedicalRules = async (client: Client, branchId: string): Promise<MedicalRules> => {
  const raw = unwrap(await client.rpc("medical_settings_get", { p_branch: branchId }));
  return toMedicalRules(parseRpc("medical_settings_get", medicalRulesRowSchema, raw));
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
