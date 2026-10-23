<template>
  <WidgetCard
    :title="$t('dashboard.top.title')"
    :icon="PackageSearch"
    :state="state"
    :to="{ name: 'reportsItems', query: { preset: 'thisMonth' } }"
    :link-label="$t('dashboard.sales.open')"
    :empty-text="$t('dashboard.top.empty')"
    @retry="refetch()"
  >
    <ol class="space-y-2">
      <li v-for="(row, index) in rows" :key="row.itemId" class="flex items-center gap-3 text-sm">
        <span class="w-5 text-right text-xs font-semibold text-muted-foreground">{{ index + 1 }}</span>
        <span class="min-w-0 flex-1 truncate font-medium">{{ row.name }}</span>
        <span class="text-xs text-muted-foreground">{{ $t("dashboard.top.qty", { n: row.qtySold }) }}</span>
        <span class="w-28 text-right font-semibold">{{ money(row.netRevenue) }}</span>
      </li>
    </ol>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { PackageSearch } from "lucide-vue-next";
import { money } from "@/features/admin/reports";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useTopProducts } from "./useTopProducts";

const { state, rows, refetch } = useTopProducts();
</script>
