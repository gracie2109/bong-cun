<template>
  <router-link
    v-if="visible"
    :to="{ name: 'reportsOverview', query: { preset: 'today' } }"
    class="block rounded-xl border bg-white p-4 transition-colors hover:border-primary hover:bg-primary/5"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <h3 class="flex items-center gap-2 text-sm font-semibold">
        <ChartColumn class="size-4 text-primary" />
        {{ $t("reports.today.title") }}
        <span v-if="branch" class="text-xs font-normal text-muted-foreground">{{ branch.code }} · {{ branch.name }}</span>
      </h3>
      <span class="text-xs text-primary">{{ $t("reports.today.open") }}</span>
    </div>
    <div v-if="data" class="mt-3 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <div>
        <p class="text-xs text-muted-foreground">{{ $t("reports.kpi.netRevenue") }}</p>
        <p class="text-xl font-bold">{{ money(data.netRevenue) }}</p>
      </div>
      <div>
        <p class="text-xs text-muted-foreground">{{ $t("reports.kpi.invoiceCount") }}</p>
        <p class="text-xl font-bold">{{ data.invoiceCount }}</p>
      </div>
      <div>
        <p class="text-xs text-muted-foreground">{{ $t("reports.segment.shop") }}</p>
        <p class="text-xl font-bold">{{ money(data.segments.shop - data.refunds) }}</p>
      </div>
      <div>
        <p class="text-xs text-muted-foreground">{{ $t("reports.segment.spa") }}</p>
        <p class="text-xl font-bold">{{ money(data.segments.spa) }}</p>
      </div>
    </div>
    <p v-else class="mt-3 text-sm text-muted-foreground">{{ $t("reports.loading") }}</p>
  </router-link>
</template>

<script lang="ts" setup>
import { ChartColumn } from "lucide-vue-next";
import { money } from "../reports/shared/format";
import { useTodaySales } from "./useTodaySales";

const { branch, visible, data } = useTodaySales();
</script>
