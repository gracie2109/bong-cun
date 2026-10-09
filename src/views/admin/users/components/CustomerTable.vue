<template>
  <div class="rounded-xl border bg-white overflow-hidden">
    <div class="flex items-center justify-between gap-3 px-4 py-3 bg-muted/40 border-b">
      <div class="flex items-center gap-2 min-w-0">
        <h2 class="text-xs font-semibold uppercase tracking-wide">
          {{ $t("pageFields.customers.listTitle") }}
        </h2>
        <span class="rounded-full bg-primary/10 text-primary px-2 py-0.5 text-[11px] font-medium">
          {{ $t("pageFields.customers.showing", { count: customers.length, total }) }}
        </span>
      </div>
      <TablePager :page="page" :page-count="pageCount" :loading="loading" @update:page="$emit('page', $event)" />
    </div>

    <div class="table-scroll admin-table">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="px-4 py-3 font-semibold">{{ $t("pageFields.customers.col.customer") }}</th>
            <th class="px-4 py-3 font-semibold text-right">
              {{ $t("pageFields.customers.col.spent") }}
            </th>
            <th class="px-4 py-3 font-semibold">{{ $t("pageFields.customers.col.lastVisit") }}</th>
            <th class="px-4 py-3 font-semibold text-right">
              {{ $t("pageFields.customers.col.actions") }}
            </th>
          </tr>
        </thead>
        <tbody>
          <TableStateRows :colspan="4" :pending="loading && customers.length === 0" :empty="customers.length === 0" :empty-text="$t('pageFields.customers.empty')" :skeleton-rows="4" skeleton-class="h-10 w-full" />
          <CustomerRow
            v-for="customer in customers"
            :key="customer.userId"
            :customer="customer"
            :stats="statsOf(stats, customer.userId)"
            :selected="customer.userId === selectedId"
            @select="$emit('select', customer.userId)"
          />
        </tbody>
      </table>
    </div>
  </div>
</template>

<script lang="ts" setup>
import TablePager from "@/components/common/TablePager.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import type { IUser } from "@/types/user.type";
import { statsOf, type CustomerStats } from "../customer-stats";
import CustomerRow from "./CustomerRow.vue";

defineProps<{
  customers: IUser[];
  stats: Map<string, CustomerStats>;
  total: number;
  page: number;
  pageCount: number;
  loading: boolean;
  selectedId: string | null;
}>();

defineEmits<{
  select: [userId: string];
  page: [page: number];
}>();
</script>
