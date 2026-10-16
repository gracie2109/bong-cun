// Care log and extra charges of a stay that is in the hotel.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { CareKind, CareLog, CareLogInput, ChargeKind, MealEaten, StayCharge } from "@bongcun/core/boarding";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

export const toCareLog = (value: unknown): CareLog => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    stayPetId: str(row.stay_pet_id),
    petName: str(row.pet_name),
    kind: str(row.kind) as CareKind,
    mealEaten: (strOrNull(row.meal_eaten) as MealEaten | null) ?? null,
    content: strOrNull(row.content),
    visibleToCustomer: row.visible_to_customer === true,
    loggedAt: str(row.logged_at),
    createdByName: strOrNull(row.created_by_name),
    canDelete: row.can_delete === true,
  };
};

export const toCharge = (value: unknown): StayCharge => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    stayPetId: strOrNull(row.stay_pet_id),
    petName: strOrNull(row.pet_name),
    kind: str(row.kind) as ChargeKind,
    name: str(row.name),
    qty: Number(row.qty ?? 0),
    unitPrice: Number(row.unit_price ?? 0),
    amount: Number(row.amount ?? 0),
    invoiceLineId: strOrNull(row.invoice_line_id),
  };
};

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
