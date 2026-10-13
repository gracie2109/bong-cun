import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "../shared";

type Client = SupabaseClient<Database>;

const VIEW_METHODS = ["VIEW", "ALL"];

/** Ids of the branches where the caller holds "reports: VIEW". */
export const listReportBranchIds = async (client: Client): Promise<string[]> => {
  const rows = unwrap(await client.rpc("my_permissions"));
  return [
    ...new Set(
      rows
        .filter((row) => row.permission === "reports" && row.methods.some((method) => VIEW_METHODS.includes(method)))
        .map((row) => row.branch_id)
    ),
  ];
};
