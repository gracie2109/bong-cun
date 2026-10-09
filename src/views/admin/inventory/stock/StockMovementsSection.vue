<template>
  <section class="space-y-2">
    <h3 class="text-sm font-semibold">{{ $t("inventory.movements.title") }}</h3>
    <Skeleton v-if="movementsQuery.isPending.value" class="h-24 w-full" />
    <p v-else-if="movements.length === 0" class="rounded-lg border border-dashed p-4 text-center text-sm text-muted-foreground">
      {{ $t("inventory.movements.empty") }}
    </p>
    <div v-else class="admin-table overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="py-2 font-semibold">{{ $t("pos.invoices.time") }}</th>
            <th class="py-2 font-semibold">{{ $t("inventory.movements.reason") }}</th>
            <th class="py-2 font-semibold">{{ $t("inventory.lots.lotNo") }}</th>
            <th class="py-2 text-right font-semibold">{{ $t("inventory.movements.qty") }}</th>
            <th class="py-2 text-right font-semibold">{{ $t("inventory.movements.balance") }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="move in movements" :key="move.id" class="border-b last:border-0">
            <td class="whitespace-nowrap py-2 text-xs">{{ dateTime(move.createdAt) }}</td>
            <td class="py-2">
              {{ $t(`inventory.movements.reasons.${move.reason}`) }}
              <span v-if="move.ref" class="block text-xs text-muted-foreground">{{ move.ref }}</span>
            </td>
            <td class="py-2 text-xs">
              {{ move.lotNo || $t("inventory.lots.noLot") }}
              <span v-if="move.expiryDate" class="block text-muted-foreground">{{ day(move.expiryDate) }}</span>
            </td>
            <td class="py-2 text-right font-semibold" :class="move.qty > 0 ? 'text-primary' : 'text-red-600'">
              {{ move.qty > 0 ? "+" : "" }}{{ qty(move.qty) }}
            </td>
            <td class="py-2 text-right text-muted-foreground">{{ qty(move.balanceAfter) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Skeleton } from "@/components/ui/skeleton";
import { useProductMovements } from "@/queries/inventory";
import { dateTime } from "@/views/admin/pos/format";
import { day, qty } from "../format";

const props = defineProps<{ branchId: string | undefined; productId: string }>();

const movementsQuery = useProductMovements(
  computed(() => props.branchId),
  computed(() => props.productId)
);
const movements = computed(() => movementsQuery.data.value ?? []);
</script>
