// The signed-in customer's profile: account name, phone and birth date, kept on the customer record.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { MyProfile, ProfileInput } from "@/types/account";
import { unwrap } from "../shared";

type Client = SupabaseClient<Database>;

type ProfileJson = {
  email: string | null;
  full_name: string | null;
  phone: string | null;
  birth_date: string | null;
  customer_id: string | null;
};

const toProfile = (row: ProfileJson): MyProfile => ({
  email: row.email,
  fullName: row.full_name ?? "",
  phone: row.phone ?? "",
  birthDate: row.birth_date ?? "",
  customerId: row.customer_id,
});

export const getMyProfile = async (client: Client): Promise<MyProfile> =>
  toProfile(unwrap(await client.rpc("my_profile")) as ProfileJson);

export const saveMyProfile = async (client: Client, input: ProfileInput): Promise<MyProfile> =>
  toProfile(
    unwrap(
      await client.rpc("save_my_profile", {
        p: { full_name: input.fullName.trim(), phone: input.phone.trim(), birth_date: input.birthDate || null },
      })
    ) as ProfileJson
  );

/** Error hints raised by save_my_profile, for readable messages. */
export const PROFILE_ERROR_HINTS = ["invalid_name", "invalid_phone", "invalid_birth_date", "phone_in_use"] as const;
export type ProfileErrorHint = (typeof PROFILE_ERROR_HINTS)[number];

export const profileErrorHint = (error: unknown): ProfileErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return PROFILE_ERROR_HINTS.find((item) => item === hint) ?? null;
};
