<template>
  <div class="space-y-3">
    <p v-if="!settled" class="rounded-lg border border-dashed bg-white px-4 py-3 text-sm text-muted-foreground">
      {{ $t("boarding.detail.estimateNote") }}
    </p>
    <ul class="divide-y rounded-xl border bg-white">
      <li v-for="line in lines" :key="line.key" class="flex items-center justify-between gap-3 px-4 py-3 text-sm">
        <div>
          <p class="font-medium">{{ line.name }}</p>
          <p class="text-xs text-muted-foreground">{{ line.petName }} · {{ line.qty }} × {{ money(line.unitPrice) }}</p>
        </div>
        <span class="font-semibold">{{ money(line.amount) }}</span>
      </li>
      <li class="flex items-center justify-between px-4 py-3 text-base font-bold">
        <span>{{ settled ? $t("boarding.detail.total") : $t("boarding.dialog.estimate") }}</span>
        <span>{{ money(total) }}</span>
      </li>
    </ul>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { BoardingStay } from "@bongcun/core/boarding";
import { money } from "../format";

const props = defineProps<{ stay: BoardingStay }>();

// After check-out the charges are the truth; before it, the nights so far plus the extras added.
const settled = computed(() => props.stay.status === "checked_out" || props.stay.status === "paid");

const lines = computed(() => {
  if (settled.value) {
    return props.stay.charges.map((charge) => ({
      key: charge.id,
      name: charge.name,
      petName: charge.petName ?? "",
      qty: charge.qty,
      unitPrice: charge.unitPrice,
      amount: charge.amount,
    }));
  }
  const nights = props.stay.pets
    .filter((pet) => pet.status === "active")
    .map((pet) => {
      const unitPrice = pet.nightPrice ?? pet.estNightPrice;
      return {
        key: pet.id,
        name: `${pet.kennelTypeName} (${pet.kennelCode})`,
        petName: pet.petName,
        qty: pet.chargedNights,
        unitPrice,
        amount: unitPrice * pet.chargedNights,
      };
    });
  const extras = props.stay.charges.map((charge) => ({
    key: charge.id,
    name: charge.name,
    petName: charge.petName ?? "",
    qty: charge.qty,
    unitPrice: charge.unitPrice,
    amount: charge.amount,
  }));
  return [...nights, ...extras];
});

const total = computed(() => lines.value.reduce((sum, line) => sum + line.amount, 0));
</script>
