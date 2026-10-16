<template>
  <div class="flex flex-wrap items-center justify-between gap-3">
    <div class="flex flex-wrap items-center gap-3">
      <ReportBranchPicker :model-value="branchValue" :options="branches" :can-pick-all="canPickAll" @update:model-value="selectBranch" />
      <DatePresetChips :preset="preset" :range="range" @select="selectPreset" @update:range="selectRange" />
    </div>
    <div class="flex flex-wrap items-center gap-3">
      <slot name="actions" />
    </div>
  </div>
  <p v-if="problem" class="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600">
    {{ $t(`reports.problems.${problem}`, { max: MAX_REPORT_DAYS }) }}
  </p>
</template>

<script lang="ts" setup>
import { MAX_REPORT_DAYS } from "@/repositories/reports";
import DatePresetChips from "./DatePresetChips.vue";
import ReportBranchPicker from "./ReportBranchPicker.vue";
import { useReportFilters } from "./useReportFilters";

// The state is in the URL, so this bar and the page that shows the report read the same filter.
const { branches, canPickAll, branchValue, preset, range, problem, selectBranch, selectPreset, selectRange } =
  useReportFilters();
</script>
