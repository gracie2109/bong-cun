<template>
  <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
    <KpiCard
      :label="$t('reports.kpi.netRevenue')"
      :value="money(data.netRevenue)"
      :compare="{ current: data.netRevenue, previous: data.previous.netRevenue }"
    />
    <KpiCard
      :label="$t('reports.kpi.invoiceCount')"
      :value="String(data.invoiceCount)"
      :compare="{ current: data.invoiceCount, previous: data.previous.invoiceCount }"
      :hint="data.cancelledCount ? $t('reports.kpi.cancelled', { n: data.cancelledCount }) : undefined"
    />
    <KpiCard
      :label="$t('reports.kpi.avgTicket')"
      :value="money(data.avgTicket)"
      :compare="{ current: data.avgTicket, previous: data.previous.avgTicket }"
    />
    <KpiCard
      :label="$t('reports.kpi.refunds')"
      :value="money(data.refunds)"
      :compare="{ current: data.refunds, previous: data.previous.refunds }"
      rise-is-bad
      :hint="$t('reports.kpi.returnCount', { n: data.returnCount })"
    />
    <KpiCard
      :label="$t('reports.kpi.grossProfit')"
      :value="money(data.grossProfit)"
      :hint="data.missingCostLines ? $t('reports.kpi.missingCost', { n: data.missingCostLines }) : $t('reports.kpi.estimated')"
      :hint-warn="data.missingCostLines > 0"
    />
  </div>
</template>

<script lang="ts" setup>
import type { ReportOverview } from "@/repositories/reports";
import { money } from "../shared/format";
import KpiCard from "../shared/KpiCard.vue";

defineProps<{ data: ReportOverview }>();
</script>
