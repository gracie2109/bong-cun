import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getOverview, getRevenueSeries, listReportBranchIds, type Bucket, type ReportFilter } from "@/repositories/reports";
import { reportKeys } from "./keys";

/** The filter is null until a branch and a valid range are known, which keeps the query off. */
type MaybeFilter = MaybeRef<ReportFilter | null>;

export const useReportBranchIds = () =>
  useQuery({ queryKey: reportKeys.branches(), queryFn: () => listReportBranchIds(supabaseClient()) });

export const useReportOverview = (filter: MaybeFilter) =>
  useQuery({
    queryKey: computed(() => reportKeys.overview(unref(filter) as ReportFilter)),
    queryFn: () => getOverview(supabaseClient(), unref(filter) as ReportFilter),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useRevenueSeries = (filter: MaybeFilter, bucket: MaybeRef<Bucket>) =>
  useQuery({
    queryKey: computed(() => reportKeys.series(unref(filter) as ReportFilter, unref(bucket))),
    queryFn: () => getRevenueSeries(supabaseClient(), unref(filter) as ReportFilter, unref(bucket)),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });
