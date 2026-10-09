<template>
  <PagedTableCard
    :page="page"
    :page-size="pageSize"
    :page-count="pageCount"
    :loading="loading"
    :count="customers.length"
    :total="total"
    @update:page="$emit('page', $event)"
    @update:page-size="$emit('pageSize', $event as number)"
  >
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
  </PagedTableCard>
</template>

<script lang="ts" setup>
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import type { IUser } from "@/types/user.type";
import { statsOf, type CustomerStats } from "../customer-stats";
import CustomerRow from "./CustomerRow.vue";

defineProps<{
  customers: IUser[];
  stats: Map<string, CustomerStats>;
  total: number;
  page: number;
  pageSize: number;
  pageCount: number;
  loading: boolean;
  selectedId: string | null;
}>();

defineEmits<{
  select: [userId: string];
  page: [page: number];
  pageSize: [size: number];
}>();
</script>
