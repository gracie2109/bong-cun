<template>
  <dl class="grid grid-cols-2 gap-3 sm:grid-cols-4">
    <div class="rounded-xl bg-muted/50 p-3">
      <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.sellable") }}</dt>
      <dd class="text-lg font-bold">{{ qty(row.sellable) }}</dd>
    </div>
    <div class="rounded-xl bg-muted/50 p-3">
      <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.expired") }}</dt>
      <dd class="text-lg font-bold" :class="row.expired > 0 ? 'text-red-600' : ''">{{ qty(row.expired) }}</dd>
    </div>
    <div class="rounded-xl bg-muted/50 p-3">
      <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.expiringShort", { days: expiryDays }) }}</dt>
      <dd class="text-lg font-bold" :class="row.expiring > 0 ? 'text-amber-700' : ''">{{ qty(row.expiring) }}</dd>
    </div>
    <div class="rounded-xl bg-muted/50 p-3">
      <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.value") }}</dt>
      <dd class="text-lg font-bold">{{ money(row.stockValue) }}</dd>
    </div>
  </dl>
</template>

<script lang="ts" setup>
import type { StockRow } from "@/repositories/inventory";
import { money } from "@/views/admin/pos/format";
import { qty } from "../format";

defineProps<{ row: StockRow; expiryDays: number }>();
</script>
