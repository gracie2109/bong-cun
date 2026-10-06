<template>
  <div class="grid grid-cols-2 xl:grid-cols-4 gap-4">
    <div
      v-for="card in cards"
      :key="card.key"
      class="rounded-xl border bg-white p-4 flex items-center justify-between gap-3"
    >
      <div class="min-w-0">
        <p class="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
          {{ card.label }}
        </p>
        <p class="mt-1 flex items-baseline gap-2">
          <span class="text-2xl font-bold">{{ card.value }}</span>
          <span v-if="card.hint" class="text-xs text-muted-foreground truncate">
            {{ card.hint }}
          </span>
        </p>
      </div>
      <span class="grid place-items-center size-10 shrink-0 rounded-lg bg-primary/10 text-primary">
        <component :is="card.icon" class="size-5" />
      </span>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { Award, PawPrint, Repeat2, Users } from "lucide-vue-next";
import { NEW_CUSTOMER_DAYS } from "../customer-stats";

const props = defineProps<{
  total?: number;
  newCount?: number;
}>();

const { t, n } = useI18n();
const NO_VALUE = "—";

// Pets, VIP tiers and return rate have no data source yet; they show a dash.
const cards = computed(() => [
  {
    key: "total",
    label: t("pageFields.customers.kpi.total"),
    value: props.total === undefined ? NO_VALUE : n(props.total),
    hint:
      props.newCount === undefined
        ? ""
        : t("pageFields.customers.kpi.newThisPeriod", {
            n: props.newCount,
            days: NEW_CUSTOMER_DAYS,
          }),
    icon: Users,
  },
  {
    key: "pets",
    label: t("pageFields.customers.kpi.activePets"),
    value: NO_VALUE,
    hint: t("pageFields.customers.kpi.noData"),
    icon: PawPrint,
  },
  {
    key: "vip",
    label: t("pageFields.customers.kpi.vip"),
    value: NO_VALUE,
    hint: t("pageFields.customers.kpi.noData"),
    icon: Award,
  },
  {
    key: "return",
    label: t("pageFields.customers.kpi.returnRate"),
    value: NO_VALUE,
    hint: t("pageFields.customers.kpi.noData"),
    icon: Repeat2,
  },
]);
</script>
