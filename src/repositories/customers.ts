// Walk-in and registered customers. A customer owns pets (pet_owners) and pays the invoices.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { filterSafe, unwrap } from "./shared";

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

type CustomerWithPets = Tables<"customers"> & { pet_owners: { count: number }[] };

export const toCustomer = (row: Tables<"customers">): Customer => ({
  id: row.id,
  fullName: row.full_name,
  phone: row.phone,
  email: row.email,
  note: row.note,
});

export const digitsOf = (phone: string): string => phone.replace(/\D/g, "");

/** Customers whose phone starts with the typed digits or whose name contains the text. */
export const searchCustomers = async (
  client: Client,
  text: string,
  limit = 5
): Promise<CustomerMatch[]> => {
  const term = filterSafe(text);
  if (term.length < 2) return [];
  const digits = digitsOf(term);
  const conditions = [`full_name.ilike.%${term}%`];
  if (digits.length >= 3) conditions.push(`phone_digits.like.${digits}%`);

  const rows = unwrap(
    await client
      .from("customers")
      .select("*, pet_owners(count)")
      .eq("is_active", true)
      .or(conditions.join(","))
      .order("full_name")
      .limit(limit)
  ) as CustomerWithPets[];
  return rows.map((row) => ({ ...toCustomer(row), petCount: row.pet_owners[0]?.count ?? 0 }));
};
