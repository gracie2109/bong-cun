// Check-in, extend and check-out of a stay.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { CheckInPetInput, CheckoutPreview } from "@bongcun/core/boarding";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str } from "../spa/parse";
import { toCharge } from "./care";

type Client = SupabaseClient<Database>;

export const checkInBoarding = async (
  client: Client,
  id: string,
  pets: CheckInPetInput[],
  emergencyPhone: string
): Promise<void> => {
  unwrap(
    await client.rpc("check_in_boarding", {
      p_id: id,
      p_pets: pets.map((pet) => ({
        stay_pet_id: pet.stayPetId,
        weight_kg: pet.weightKg,
        vaccine_checked: pet.vaccineChecked,
        vaccine_note: pet.vaccineNote.trim(),
        belongings: pet.belongings.trim(),
        feeding: pet.feeding.trim(),
        medication: pet.medication.trim(),
      })),
      p_emergency_phone: emergencyPhone.trim() || undefined,
    })
  );
};

/** `plannedOutAt` is an ISO instant. */
export const extendBoardingStay = async (client: Client, id: string, plannedOutAt: string): Promise<void> => {
  unwrap(await client.rpc("extend_boarding_stay", { p_id: id, p_planned_out_at: plannedOutAt }));
};

export const getCheckoutPreview = async (client: Client, id: string): Promise<CheckoutPreview> => {
  const row = asRecord(unwrap(await client.rpc("boarding_checkout_preview", { p_id: id })));
  const items = Array.isArray(row.items) ? row.items.map(toCharge) : [];
  return {
    at: str(row.at),
    items: items.map(({ stayPetId, petName, kind, name, qty, unitPrice, amount }) => ({
      stayPetId,
      petName,
      kind,
      name,
      qty,
      unitPrice,
      amount,
    })),
    total: Number(row.total ?? 0),
    belongings: (Array.isArray(row.belongings) ? row.belongings : []).map((value) => {
      const item = asRecord(value);
      return {
        stayPetId: str(item.stay_pet_id),
        petName: str(item.pet_name),
        belongings: str(item.belongings),
        returned: item.returned === true,
      };
    }),
  };
};

/** `returnedPetIds`: stay pet ids whose belongings were handed back. Returns what is owed. */
export const checkOutBoarding = async (client: Client, id: string, returnedPetIds: string[]): Promise<number> => {
  const result = asRecord(unwrap(await client.rpc("check_out_boarding", { p_id: id, p_returned: returnedPetIds })));
  return Number(result.total ?? 0);
};
