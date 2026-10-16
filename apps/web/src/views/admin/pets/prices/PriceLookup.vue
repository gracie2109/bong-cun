<template>
  <div class="rounded-xl border bg-white p-4">
    <div class="flex flex-wrap items-end gap-4">
      <div class="space-y-1">
        <h3 class="font-semibold">{{ $t("petCare.prices.lookup.title") }}</h3>
        <p class="text-xs text-muted-foreground">{{ $t("petCare.prices.lookup.note") }}</p>
      </div>
      <div class="space-y-1">
        <Label for="lookup-weight" class="text-xs">{{ $t("petCare.prices.lookup.weight") }}</Label>
        <Input
          id="lookup-weight"
          v-model="weight"
          type="number"
          min="0"
          step="0.1"
          inputmode="decimal"
          class="w-32"
        />
      </div>
    </div>

    <p v-if="weightKg === null" class="mt-3 text-sm text-muted-foreground">
      {{ $t("petCare.prices.lookup.enterWeight") }}
    </p>
    <p v-else-if="!bracket" class="mt-3 text-sm text-amber-700">{{ $t("petCare.prices.lookup.none") }}</p>
    <div v-else class="mt-3 space-y-2">
      <p class="text-sm font-medium text-primary">
        {{ $t("petCare.prices.lookup.bracket", { label: bracket.label }) }}
      </p>
      <ul class="divide-y rounded-lg border">
        <li v-for="service in services" :key="service.id" class="flex items-center justify-between px-3 py-2 text-sm">
          <span>{{ service.name }}</span>
          <span v-if="priceOf(service.id) !== undefined" class="font-semibold">
            {{ formatPrice(priceOf(service.id) as number) }}
          </span>
          <span v-else class="text-xs text-muted-foreground">{{ $t("petCare.prices.missing") }}</span>
        </li>
      </ul>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { formatPrice } from "@/lib/utils";
import type { PetService } from "@/repositories/petServices";
import { findBracket, type WeightBracket } from "@/repositories/weightBrackets";

const props = defineProps<{
  services: PetService[];
  brackets: WeightBracket[];
  /** Effective price (override else shared) by "serviceId:bracketId". */
  prices: Map<string, number>;
  initialWeight?: number;
}>();

const weight = ref(props.initialWeight !== undefined ? String(props.initialWeight) : "");
watch(
  () => props.initialWeight,
  (value) => {
    if (value !== undefined) weight.value = String(value);
  }
);

const weightKg = computed(() => {
  if (weight.value === "") return null;
  const value = Number(weight.value);
  return Number.isNaN(value) || value < 0 ? null : value;
});
const bracket = computed(() => (weightKg.value === null ? undefined : findBracket(props.brackets, weightKg.value)));
const priceOf = (serviceId: string): number | undefined =>
  bracket.value ? props.prices.get(`${serviceId}:${bracket.value.id}`) : undefined;
</script>
