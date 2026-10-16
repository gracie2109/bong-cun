import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

export type Branch = {
  id: string;
  code: string;
  name: string;
  address: string | null;
  phone: string | null;
  isActive: boolean;
};

export const listBranches = async (client: Client): Promise<Branch[]> =>
  unwrap(await client.from("branches").select("*").eq("is_active", true).order("code")).map(
    (row) => ({
      id: row.id,
      code: row.code,
      name: row.name,
      address: row.address,
      phone: row.phone,
      isActive: row.is_active,
    })
  );
