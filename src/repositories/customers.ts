// Walk-in and registered customers. A customer owns pets (pet_owners) and pays the invoices.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

export type Customer = {
  id: string;
  fullName: string;
  phone: string;
  email: string | null;
  note: string | null;
};

/** A customer found while typing a phone number or name, with how many pets they have. */
export type CustomerMatch = Customer & { petCount: number };

export const toCustomer = (row: Tables<"customers">): Customer => ({
  id: row.id,
  fullName: row.full_name,
  phone: row.phone,
  email: row.email,
  note: row.note,
});

export const digitsOf = (phone: string): string => phone.replace(/\D/g, "");

/**
 * Basic customer search shared by every screen that picks a customer: one text box matches
 * name, email and phone, ignoring case and accents. Runs in the database (`search_customers`),
 * so a richer search can extend that function later without changing callers.
 */
export const searchCustomers = async (
  client: Client,
  text: string,
  limit = 5
): Promise<CustomerMatch[]> => {
  if (text.trim().length < 2) return [];
  const rows = unwrap(await client.rpc("search_customers", { p_text: text, p_limit: limit }));
  return rows.map((row) => ({
    id: row.id,
    fullName: row.full_name,
    phone: row.phone,
    email: row.email,
    note: row.note,
    petCount: row.pet_count,
  }));
};
