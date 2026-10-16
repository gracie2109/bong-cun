import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";
import { toOverview, toSeriesPoint } from "./parse";
import type { Bucket, ReportFilter, ReportOverview, SeriesPoint } from "./types";

type Client = SupabaseClient<Database>;

/** KPI figures, the mix and the comparison with the period before. */
export const getOverview = async (client: Client, filter: ReportFilter): Promise<ReportOverview> =>
  toOverview(
    unwrap(await client.rpc("report_overview", { p_branch: filter.branchId, p_from: filter.from, p_to: filter.to }))
  );

/** Revenue per day, week or month; every bucket of the range is present. */
export const getRevenueSeries = async (
  client: Client,
  filter: ReportFilter,
  bucket: Bucket
): Promise<SeriesPoint[]> =>
  unwrap(
    await client.rpc("report_revenue_series", {
      p_branch: filter.branchId,
      p_from: filter.from,
      p_to: filter.to,
      p_bucket: bucket,
    })
  ).map(toSeriesPoint);
