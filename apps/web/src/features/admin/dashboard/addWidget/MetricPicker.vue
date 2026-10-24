<template>
  <div class="space-y-3">
    <input
      v-model="query"
      type="search"
      :placeholder="$t('dashboard.add.search')"
      class="h-9 w-full rounded-md border bg-white px-3 text-sm"
    />
    <div v-if="missingFixed.length && !query" class="space-y-1">
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{{ $t("dashboard.add.fixed") }}</p>
      <button
        v-for="type in missingFixed"
        :key="type"
        type="button"
        class="block w-full rounded-lg border px-3 py-2 text-left text-sm hover:border-primary hover:bg-primary/5"
        @click="emit('pickFixed', type)"
      >
        {{ $t(`dashboard.add.fixedTypes.${type}`) }}
      </button>
    </div>
    <div v-for="entry in groups" :key="entry.group" class="space-y-1">
      <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{{ $t(`dashboard.metricGroup.${entry.group}`) }}</p>
      <button
        v-for="def in entry.metrics"
        :key="def.key"
        type="button"
        class="block w-full rounded-lg border px-3 py-2 text-left text-sm hover:border-primary hover:bg-primary/5"
        @click="emit('pickMetric', def)"
      >
        {{ $t(def.labelKey) }}
        <span v-if="!offered(def)" class="ml-1 text-xs text-muted-foreground">({{ $t("dashboard.add.otherBranch") }})</span>
      </button>
    </div>
    <p v-if="!groups.length && !missingFixed.length" class="py-6 text-center text-sm text-muted-foreground">{{ $t("dashboard.add.none") }}</p>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useAuthStore } from "@/stores";
import { METRIC_LIST } from "../metrics/catalogue";
import { metricAccess, metricOfferedAt } from "../metrics/metricAccess";
import type { DashboardScope } from "../kit/types";
import type { MetricDef } from "../metrics/types";
import { groupMetrics } from "./metricSearch";

const props = defineProps<{ scope: DashboardScope; missingFixed: string[] }>();
const emit = defineEmits<{ pickMetric: [def: MetricDef]; pickFixed: [type: string] }>();
const { t } = useI18n();
const auth = useAuthStore();
const query = ref("");

// Only metrics the account may read at one of its branches are offered at all.
const available = computed(() => METRIC_LIST.filter((def) => metricOfferedAt(def, props.scope.branchIds, auth.canAt)));
const groups = computed(() => groupMetrics(available.value, query.value, (def) => t(def.labelKey)));
// A metric the account holds elsewhere is offered, with a note, when it is hidden at the branch in view.
const offered = (def: MetricDef) => metricAccess(def, props.scope, auth.canAt) !== "hidden";
</script>
