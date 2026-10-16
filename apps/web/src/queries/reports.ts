import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import {
  getOverview,
  getRevenueSeries,
  listAdjustments,
  listReportBranchIds,
  listShiftRecon,
  listStaffRevenue,
  listTopItems,
  type AdjustmentFilter,
  type Bucket,
  type ReportFilter,
  type ShiftReconFilter,
  type StaffFilter,
  type TopItemFilter,
} from "@/repositories/reports";
import { toPage, type PageParams } from "@/repositories/shared";
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

export const useTopItems = (page: MaybeRef<PageParams>, filter: MaybeRef<TopItemFilter | null>) =>
  useQuery({
    queryKey: computed(() => reportKeys.items(toPage(unref(page)), unref(filter) as TopItemFilter)),
    queryFn: () => listTopItems(supabaseClient(), toPage(unref(page)), unref(filter) as TopItemFilter),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useStaffRevenue = (page: MaybeRef<PageParams>, filter: MaybeRef<StaffFilter | null>) =>
  useQuery({
    queryKey: computed(() => reportKeys.staff(toPage(unref(page)), unref(filter) as StaffFilter)),
    queryFn: () => listStaffRevenue(supabaseClient(), toPage(unref(page)), unref(filter) as StaffFilter),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useAdjustments = (page: MaybeRef<PageParams>, filter: MaybeRef<AdjustmentFilter | null>) =>
  useQuery({
    queryKey: computed(() => reportKeys.adjustments(toPage(unref(page)), unref(filter) as AdjustmentFilter)),
    queryFn: () => listAdjustments(supabaseClient(), toPage(unref(page)), unref(filter) as AdjustmentFilter),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });

export const useShiftRecon = (page: MaybeRef<PageParams>, filter: MaybeRef<ShiftReconFilter | null>) =>
  useQuery({
    queryKey: computed(() => reportKeys.shifts(toPage(unref(page)), unref(filter) as ShiftReconFilter)),
    queryFn: () => listShiftRecon(supabaseClient(), toPage(unref(page)), unref(filter) as ShiftReconFilter),
    enabled: computed(() => !!unref(filter)),
    placeholderData: keepPreviousData,
  });
