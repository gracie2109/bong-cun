// Public booking requests ("Đặt lịch"), submitted from the home page by visitors
// who may not be signed in.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";

type Client = SupabaseClient<Database>;

export type BookingInput = {
  name: string;
  email: string;
  phone_number: string;
  /** When the visitor wants to come. A Date or an ISO string. */
  time: Date | string;
  content?: string | null;
};

/**
 * Anonymous visitors have no read access to the table, so the id is generated
 * here instead of being read back from the insert. `user_id` is not sent: the
 * database fills it from the caller's JWT (NULL when signed out).
 */
export const createBooking = async (client: Client, input: BookingInput): Promise<string> => {
  const id = globalThis.crypto.randomUUID();
  const { error } = await client.from("bookings").insert({
    id,
    name: input.name,
    email: input.email,
    phone_number: input.phone_number,
    scheduled_at: new Date(input.time).toISOString(),
    content: input.content || null,
  });
  if (error) throw error;
  return id;
};
