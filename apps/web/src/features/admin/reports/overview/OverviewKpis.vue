<template>
  <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
    <KpiCard
      :label="$t('reports.kpi.netRevenue')"
      :value="money(data.netRevenue)"
      :compare="{ current: data.netRevenue, previous: data.previous.netRevenue }"
      :hint="pendingCodHint"
    />
    <KpiCard
      :label="$t('reports.kpi.invoiceCount')"
      :value="String(data.invoiceCount)"
      :compare="{ current: data.invoiceCount, previous: data.previous.invoiceCount }"
      :hint="invoiceHint"
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
import type { ReportOverview } from "@bongcun/supabase/reports";
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { money } from "../shared/format";
import KpiCard from "../shared/KpiCard.vue";

const props = defineProps<{ data: ReportOverview }>();
const { t } = useI18n();

const invoiceHint = computed(() => {
  const parts: string[] = [];
  if (props.data.cancelledCount) parts.push(t("reports.kpi.cancelled", { n: props.data.cancelledCount }));
  if (props.data.returnedOnlineCount) parts.push(t("reports.kpi.returnedOnline", { n: props.data.returnedOnlineCount }));
  return parts.length ? parts.join(" · ") : undefined;
});

const pendingCodHint = computed(() =>
  props.data.pendingCod.count
    ? t("reports.kpi.pendingCod", { amount: money(props.data.pendingCod.amount), n: props.data.pendingCod.count })
    : undefined,
);
</script>
