import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import type { ReportFilter } from "@bongcun/supabase/reports";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import {
  DEFAULT_PRESET,
  isIsoDate,
  isPreset,
  presetRange,
  previousRange,
  rangeProblem,
  todayInVietnam,
  type DateRange,
  type Preset,
} from "./dateRange";
import { useReportBranches } from "./useReportBranches";

/** Value of the "every branch" option in the branch picker. */
export const ALL_BRANCHES = "all";

const FILTER_KEYS = ["branch", "preset", "from", "to"] as const;

const queryText = (value: unknown): string | undefined => (typeof value === "string" ? value : undefined);

/**
 * Branch and date range shared by every report tab. The state lives in the URL query, so
 * switching tab keeps it, F5 does not lose it and a link can be sent.
 */
export const useReportFilters = () => {
  const route = useRoute();
  const router = useRouter();
  const { branches, ready, canPickAll } = useReportBranches();
  const { branchId: currentBranchId } = useCurrentBranch();

  const preset = computed<Preset>(() => {
    const value = route.query.preset;
    return isPreset(value) ? value : DEFAULT_PRESET;
  });

  const range = computed<DateRange>(() => {
    const from = queryText(route.query.from);
    const to = queryText(route.query.to);
    if (preset.value === "custom" && isIsoDate(from) && isIsoDate(to)) return { from, to };
    return presetRange(preset.value === "custom" ? DEFAULT_PRESET : preset.value, todayInVietnam());
  });

  /** The chosen branch id or ALL_BRANCHES; falls back to the branch the staff member works at. */
  const branchValue = computed<string | undefined>(() => {
    const wanted = queryText(route.query.branch);
    if (wanted === ALL_BRANCHES && canPickAll.value) return ALL_BRANCHES;
    if (wanted && branches.value.some((branch) => branch.id === wanted)) return wanted;
    const current = branches.value.find((branch) => branch.id === currentBranchId.value);
    return (current ?? branches.value[0])?.id;
  });

  const problem = computed(() => rangeProblem(range.value));
  const previous = computed(() => previousRange(range.value));

  /** Null until a branch is known and the range is valid, which keeps the report queries off. */
  const filter = computed<ReportFilter | null>(() => {
    if (!branchValue.value || problem.value) return null;
    return {
      branchId: branchValue.value === ALL_BRANCHES ? null : branchValue.value,
      from: range.value.from,
      to: range.value.to,
    };
  });

  const patch = (changes: Record<string, string | undefined>) =>
    router.replace({ query: { ...route.query, ...changes } });

  const selectBranch = (value: string) => patch({ branch: value });
  const selectPreset = (value: Preset) =>
    value === "custom"
      ? patch({ preset: value, from: range.value.from, to: range.value.to })
      : patch({ preset: value, from: undefined, to: undefined });
  const selectRange = (value: DateRange) => patch({ preset: "custom", from: value.from, to: value.to });

  return {
    branches,
    ready,
    canPickAll,
    branchValue,
    preset,
    range,
    previous,
    problem,
    filter,
    selectBranch,
    selectPreset,
    selectRange,
  };
};

/** The filter keys of a query, to carry between tabs. */
export const filterQuery = (query: Record<string, unknown>): Record<string, string> => {
  const kept: Record<string, string> = {};
  for (const key of FILTER_KEYS) {
    const value = queryText(query[key]);
    if (value) kept[key] = value;
  }
  return kept;
};
