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

/**
 * A person found while typing a phone number, email or name, with how many pets they have.
 * `customerId` is null for a web account that is not a customer yet; registering a pet for
 * them creates the customer record from `userId`.
 */
export type CustomerMatch = Omit<Customer, "id"> & {
  customerId: string | null;
  userId: string | null;
  petCount: number;
};

/** Stable list key: a match has a customer id, a web account id, or both. */
export const matchKey = (match: CustomerMatch): string => match.customerId ?? match.userId ?? match.phone;

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
    customerId: row.customer_id,
    userId: row.user_id,
    fullName: row.full_name,
    phone: row.phone,
    email: row.email,
    note: row.note,
    petCount: row.pet_count,
  }));
};
