<template>
  <section v-if="stays.length" class="space-y-2 rounded-lg border border-primary/30 bg-primary/5 p-2.5">
    <p class="text-xs font-semibold text-primary">{{ $t("pos.boardingCharges.title", { count: stays.length }) }}</p>
    <ul class="space-y-1">
      <li v-for="stay in stays" :key="stay.stayId" class="flex items-center justify-between gap-2 text-xs">
        <span class="min-w-0 truncate">
          <span class="font-medium">{{ stay.code }}</span>
          <span class="text-muted-foreground">· {{ $t("pos.boardingCharges.charges", { count: stay.charges.length }) }}</span>
        </span>
        <span class="flex items-center gap-2">
          <span class="font-semibold">{{ money(stay.total) }}</span>
          <Button size="sm" variant="ghost" class="h-7 px-2 text-xs" :disabled="isAdded(stay)" @click="emit('add', stay)">
            {{ isAdded(stay) ? $t("pos.boardingCharges.added") : $t("pos.boardingCharges.add") }}
          </Button>
        </span>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Button } from "@/components/ui/button";
import { useBillableBoarding } from "@/queries/boarding";
import type { BillableBoardingStay } from "@bongcun/core/boarding";
import { money } from "../format";

const props = defineProps<{
  branchId: string | undefined;
  customerId: string | undefined;
  /** Ids of the stay charges already in the cart. */
  added: Set<string>;
}>();
const emit = defineEmits<{ add: [stay: BillableBoardingStay] }>();

const staysQuery = useBillableBoarding(
  computed(() => props.branchId),
  computed(() => props.customerId)
);
const stays = computed(() => staysQuery.data.value ?? []);

const isAdded = (stay: BillableBoardingStay) => stay.charges.every((charge) => props.added.has(charge.id));
</script>
