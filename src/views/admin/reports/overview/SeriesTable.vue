<template>
  <PagedTableCard
    class="min-h-80"
    v-model:page="page.pageIndex"
    v-model:page-size="page.pageSize"
    :page-count="pageCount"
    :count="rows.length"
    :total="total"
    :loading="loading"
    scroll-x="900px"
  >
    <table class="w-full text-sm">
      <thead>
        <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
          <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.date") }}</th>
          <th v-for="col in numberCols" :key="col.key" class="px-4 py-3 text-right font-semibold">{{ $t(col.label) }}</th>
        </tr>
      </thead>
      <tbody>
        <TableStateRows :colspan="numberCols.length + 1" :pending="loading" :empty="rows.length === 0" :empty-text="$t('reports.empty')" />
        <tr v-for="row in rows" :key="row.bucket" class="border-t">
          <td class="whitespace-nowrap px-4 py-2.5 font-semibold">{{ label(row.bucket) }}</td>
          <td v-for="col in numberCols" :key="col.key" class="whitespace-nowrap px-4 py-2.5 text-right">{{ cell(row[col.key], col.money) }}</td>
        </tr>
      </tbody>
      <tfoot v-if="rows.length">
        <tr class="border-t-2 bg-muted/40 font-bold">
          <td class="px-4 py-3">{{ $t("reports.total") }}</td>
          <td v-for="col in numberCols" :key="col.key" class="whitespace-nowrap px-4 py-3 text-right">{{ cell(totals[col.key], col.money) }}</td>
        </tr>
      </tfoot>
    </table>
  </PagedTableCard>
</template>

<script lang="ts" setup>
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import type { Bucket, SeriesPoint } from "@/repositories/reports";
import { bucketLabel, formatDay } from "../shared/dateRange";
import { money } from "../shared/format";
import type { SeriesTotals } from "./seriesTotals";

const props = defineProps<{
  rows: SeriesPoint[];
  total: number;
  pageCount: number;
  totals: SeriesTotals;
  bucket: Bucket;
  loading?: boolean;
}>();

const page = defineModel<{ pageIndex: number; pageSize: number }>("pagination", { required: true });

type NumberKey = keyof SeriesTotals;
const numberCols: { key: NumberKey; label: string; money: boolean }[] = [
  { key: "invoiceCount", label: "reports.cols.invoices", money: false },
  { key: "gross", label: "reports.cols.gross", money: true },
  { key: "discount", label: "reports.cols.discount", money: true },
  { key: "refunds", label: "reports.cols.refunds", money: true },
  { key: "netRevenue", label: "reports.cols.netRevenue", money: true },
  { key: "shop", label: "reports.cols.shop", money: true },
  { key: "spa", label: "reports.cols.spa", money: true },
  { key: "boarding", label: "reports.cols.boarding", money: true },
  { key: "cash", label: "reports.cols.cash", money: true },
  { key: "transfer", label: "reports.cols.transfer", money: true },
  { key: "card", label: "reports.cols.card", money: true },
];

const cell = (value: number, asMoney: boolean): string => (asMoney ? money(value) : String(value));
const label = (iso: string): string => (props.bucket === "day" ? formatDay(iso) : bucketLabel(props.bucket, iso));
</script>
