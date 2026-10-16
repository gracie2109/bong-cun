// Spa tables, opening hours and which staff do services (branch settings).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";
import { str } from "./parse";

type Client = SupabaseClient<Database>;

// ------------------------------------------------------------- spa tables
export type SpaResource = { id: string; branchId: string; name: string; isActive: boolean; sortOrder: number };

const toSpaResource = (row: Tables<"spa_resources">): SpaResource => ({
  id: row.id,
  branchId: row.branch_id,
  name: row.name,
  isActive: row.is_active,
  sortOrder: row.sort_order,
});

export const listSpaResources = async (client: Client, branchId: string): Promise<SpaResource[]> =>
  unwrap(
    await client
      .from("spa_resources")
      .select("*")
      .eq("branch_id", branchId)
      .order("sort_order")
      .order("name")
  ).map(toSpaResource);

export type SpaResourceInput = { branchId: string; name: string; isActive?: boolean; sortOrder?: number };

export const saveSpaResource = async (client: Client, input: SpaResourceInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("save_spa_resource", {
      p: {
        branch_id: input.branchId,
        name: input.name,
        is_active: input.isActive ?? null,
        sort_order: input.sortOrder ?? null,
      },
      p_id: id,
    })
  );

// ---------------------------------------------------------------- hours
export type DayHours = { weekday: number; openTime: string; closeTime: string; isClosed: boolean };

/** Monday = 1 ... Sunday = 7, as the database stores it. */
export const WEEKDAYS = [1, 2, 3, 4, 5, 6, 7] as const;

export const getWeekHours = async (client: Client, branchId: string): Promise<DayHours[]> => {
  const rows = unwrap(await client.rpc("spa_week_hours", { p_branch: branchId })) as Record<string, unknown>[] | null;
  return (rows ?? []).map((row) => ({
    weekday: Number(row.weekday),
    openTime: str(row.open_time),
    closeTime: str(row.close_time),
    isClosed: row.is_closed === true,
  }));
};

export const saveWeekHours = async (client: Client, branchId: string, hours: DayHours[]): Promise<void> => {
  unwrap(
    await client.rpc("save_branch_hours", {
      p_branch: branchId,
      p: hours.map((day) => ({
        weekday: day.weekday,
        open_time: day.openTime,
        close_time: day.closeTime,
        is_closed: day.isClosed,
      })),
    })
  );
};

// ---------------------------------------------------------------- staff
export type BranchStaff = { userId: string; name: string; role: string; doesServices: boolean };

export const listBranchStaff = async (client: Client, branchId: string): Promise<BranchStaff[]> =>
  unwrap(await client.rpc("list_branch_staff", { p_branch: branchId })).map((row) => ({
    userId: row.user_id,
    name: row.name,
    role: row.role,
    doesServices: row.does_services,
  }));

export const setStaffDoesServices = async (
  client: Client,
  args: { userId: string; branchId: string; value: boolean }
): Promise<void> => {
  unwrap(
    await client.rpc("set_staff_does_services", {
      p_user: args.userId,
      p_branch: args.branchId,
      p_value: args.value,
    })
  );
};

