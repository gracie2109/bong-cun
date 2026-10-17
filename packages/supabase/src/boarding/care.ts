// Care log and extra charges of a stay that is in the hotel.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { CareLogInput } from "@bongcun/core/boarding";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export const addCareLog = async (client: Client, stayPetId: string, input: CareLogInput): Promise<void> => {
  unwrap(
    await client.rpc("add_care_log", {
      p_stay_pet: stayPetId,
      p: {
        kind: input.kind,
        meal_eaten: input.kind === "meal" ? input.mealEaten : null,
        content: input.content.trim(),
        visible_to_customer: input.visibleToCustomer,
      },
    })
  );
};

export const deleteCareLog = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("delete_care_log", { p_id: id }));
};

export const addBoardingExtra = async (client: Client, stayPetId: string, serviceId: string, qty: number): Promise<void> => {
  unwrap(await client.rpc("add_boarding_extra", { p_stay_pet: stayPetId, p_service: serviceId, p_qty: qty }));
};

export const removeBoardingExtra = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("remove_boarding_extra", { p_id: id }));
};
