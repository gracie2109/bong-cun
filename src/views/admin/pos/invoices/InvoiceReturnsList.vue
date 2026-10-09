<template>
  <section class="space-y-2">
    <h3 class="text-sm font-semibold">{{ $t("pos.returns.title") }}</h3>
    <div v-for="item in salesReturns" :key="item.id" class="space-y-1 rounded-lg border p-3 text-sm">
      <div class="flex justify-between gap-3">
        <span class="font-semibold">{{ item.code }}</span>
        <span class="font-semibold text-red-600">-{{ money(item.refundAmount) }}</span>
      </div>
      <p class="text-xs text-muted-foreground">
        {{ dateTime(item.createdAt) }} · {{ item.createdByName }} · {{ $t(`pos.method.${item.refundMethod}`) }}
      </p>
      <p v-for="line in item.lines" :key="line.invoiceLineId" class="text-xs">{{ line.qty }} × {{ line.name }}</p>
      <p class="text-xs text-muted-foreground">{{ item.reason }}</p>
    </div>
  </section>
</template>

<script lang="ts" setup>
import type { SalesReturn } from "@/repositories/pos";
import { dateTime, money } from "../format";

defineProps<{ salesReturns: SalesReturn[] }>();
</script>
