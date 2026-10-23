// Personal dashboard layouts: read from the table (RLS: own rows only), written through the RPCs.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@bongcun/supabase/db";
import { parseLayout, serializeLayout, type ParsedLayout, type SavedItem } from "@bongcun/core/dashboard";
import { unwrap } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export type StoredLayout = {
  /** null when the stored value is unusable: show the default layout instead. */
  layout: ParsedLayout | null;
  version: number;
  updatedAt: string;
};

/** The caller's saved layout, or null when they never saved one (the default layout applies). */
export const fetchLayout = async (client: Client, dashboardKey: string): Promise<StoredLayout | null> => {
  const { data: row, error } = await client
    .from("dashboard_layouts")
    .select("layout,version,updated_at")
    .eq("dashboard_key", dashboardKey)
    .maybeSingle();
  if (error) throw error;
  if (!row) return null;
  const layout = parseLayout(row.layout);
  if (!layout) console.warn(`dashboard layout "${dashboardKey}" is unreadable, using the default`);
  return { layout, version: row.version, updatedAt: row.updated_at };
};

/** Saves the layout; `expectedVersion` is 0 when nothing was saved yet. Returns the new version. */
export const saveLayout = async (
  client: Client,
  dashboardKey: string,
  items: readonly SavedItem[],
  expectedVersion: number
): Promise<number> =>
  unwrap(
    await client.rpc("save_dashboard_layout", {
      p_dashboard: dashboardKey,
      p_layout: serializeLayout(items) as unknown as Json,
      p_expected_version: expectedVersion,
    })
  );

export const resetLayout = async (client: Client, dashboardKey: string): Promise<void> => {
  unwrap(await client.rpc("reset_dashboard_layout", { p_dashboard: dashboardKey }));
};
