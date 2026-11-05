<template>
  <div class="flex min-h-0 flex-1 flex-col gap-3">
    <div class="flex flex-wrap items-end gap-2">
      <label class="text-xs text-muted-foreground">
        {{ $t("attendance.timesheet.from") }}
        <Input v-model="from" type="date" class="mt-1 h-11 w-40" />
      </label>
      <label class="text-xs text-muted-foreground">
        {{ $t("attendance.timesheet.to") }}
        <Input v-model="to" type="date" class="mt-1 h-11 w-40" />
      </label>
      <Input v-model="search" class="h-11 w-full sm:ml-auto sm:w-64" :placeholder="$t('attendance.timesheet.search')" />
      <ExportMenu :exporter="exporter" compact />
    </div>
    <p v-if="!rangeOk" class="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
      {{ $t("attendance.timesheet.rangeInvalid", { days: MAX_RANGE_DAYS }) }}
    </p>
    <SummaryTable v-else :rows="rows" :loading="query.isPending.value" />
    <div v-if="pageCount > 1" class="flex justify-end">
      <TablePager v-model:page="page.pageIndex" :page-count="pageCount" :loading="query.isFetching.value" />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import TablePager from "@/components/common/TablePager.vue";
import { Input } from "@/components/ui/input";
import SummaryTable from "./SummaryTable.vue";
import { MAX_RANGE_DAYS } from "./timesheetRange";
import { useTimesheetExport } from "./useTimesheetExport";
import { useTimesheetSummary } from "./useTimesheetSummary";

const props = defineProps<{ branchId: string | undefined; branchName: string | undefined }>();

const { from, to, search, page, filter, rangeOk, query, rows, pageCount } = useTimesheetSummary(toRef(props, "branchId"));
const exporter = useTimesheetExport(filter, rangeOk, () => props.branchName);
</script>
