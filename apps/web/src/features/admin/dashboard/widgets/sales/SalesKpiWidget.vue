<template>
  <WidgetCard
    :title="$t(selectable ? 'dashboard.sales.title' : 'dashboard.sales.today')"
    :icon="ChartColumn"
    :state="state"
    :to="{ name: 'reportsOverview', query: { preset: period } }"
    :link-label="$t('dashboard.sales.open')"
    @retry="refetch()"
  >
    <div v-if="selectable" class="mb-3 flex gap-1 rounded-lg border p-0.5 w-fit">
      <button
        v-for="item in SALES_PERIODS"
        :key="item"
        type="button"
        class="rounded-md px-2 py-0.5 text-xs font-semibold transition-colors"
        :class="period === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
        @click="period = item"
      >
        {{ $t(`dashboard.sales.periods.${item}`) }}
      </button>
    </div>
    <template v-if="data">
      <div class="grid gap-3 sm:grid-cols-3">
        <KpiCard
          :label="$t('reports.kpi.netRevenue')"
          :value="money(data.netRevenue)"
          :compare="selectable ? { current: data.netRevenue, previous: data.previous.netRevenue } : undefined"
        />
        <KpiCard :label="$t('reports.kpi.invoiceCount')" :value="String(data.invoiceCount)" />
        <KpiCard :label="$t('reports.kpi.avgTicket')" :value="money(data.avgTicket)" />
      </div>
      <p v-if="data.invoiceCount === 0" class="mt-2 text-xs text-muted-foreground">{{ $t("dashboard.sales.noInvoices") }}</p>
      <dl class="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div v-for="row in segments" :key="row.key">
          <dt class="text-xs text-muted-foreground">{{ $t(`reports.segment.${row.key}`) }}</dt>
          <dd class="text-lg font-bold">{{ money(row.value) }}</dd>
        </div>
      </dl>
    </template>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { ChartColumn } from "lucide-vue-next";
import { KpiCard, money } from "@/features/admin/reports";
import WidgetCard from "../../kit/WidgetCard.vue";
import { SALES_PERIODS, segmentRows, type SalesPeriod } from "./salesKpi";
import { useSalesKpi } from "./useSalesKpi";

const props = withDefaults(defineProps<{ selectable?: boolean; initial?: SalesPeriod }>(), {
  selectable: false,
  initial: "today",
});
const { state, period, data, refetch } = useSalesKpi(props.initial);
const segments = computed(() => (data.value ? segmentRows(data.value) : []));
</script>
