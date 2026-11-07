// Weekly availability: a person's own pattern, and what a manager sees or edits for staff.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { availabilityListSchema } from "@bongcun/core/attendance";
import type { AvailabilityItem } from "@bongcun/core/attendance";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toAvailabilityItem, toAvailabilityPayload } from "./availabilityMappers";

type Client = SupabaseClient<Database>;

export const getMyAvailability = async (client: Client): Promise<AvailabilityItem[]> =>
  parseRpc("my_availability", availabilityListSchema, unwrap(await client.rpc("my_availability"))).map(toAvailabilityItem);

export const saveMyAvailability = async (client: Client, items: AvailabilityItem[]): Promise<AvailabilityItem[]> =>
  parseRpc(
    "save_my_availability",
    availabilityListSchema,
    unwrap(await client.rpc("save_my_availability", { p_items: toAvailabilityPayload(items) }))
  ).map(toAvailabilityItem);

export const getStaffAvailability = async (client: Client, userId: string): Promise<AvailabilityItem[]> =>
  parseRpc(
    "staff_availability_of",
    availabilityListSchema,
    unwrap(await client.rpc("staff_availability_of", { p_user: userId }))
  ).map(toAvailabilityItem);

export const saveStaffAvailability = async (client: Client, userId: string, items: AvailabilityItem[]): Promise<AvailabilityItem[]> =>
  parseRpc(
    "save_staff_availability",
    availabilityListSchema,
    unwrap(await client.rpc("save_staff_availability", { p_user: userId, p_items: toAvailabilityPayload(items) }))
  ).map(toAvailabilityItem);
