// Finished spa tickets that can be paid in the POS (see 20261013050000_spa_billing.sql).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { billableTicketsSchema } from "@bongcun/core/spa";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toBillableTickets } from "./mappers";
import type { BillableTicket } from "./types";

type Client = SupabaseClient<Database>;

export const listBillableTickets = async (client: Client, branchId: string, customerId: string): Promise<BillableTicket[]> => {
  const raw = unwrap(await client.rpc("billable_appointment_items", { p_branch: branchId, p_customer: customerId }));
  return toBillableTickets(parseRpc("billable_appointment_items", billableTicketsSchema, raw ?? []));
};
