<template>
  <div class="space-y-2">
    <p class="text-sm font-medium">{{ $t("pos.units.pick") }}</p>
    <div class="grid gap-2 sm:grid-cols-2">
      <button
        v-for="option in options"
        :key="option.id ?? 'base'"
        type="button"
        class="flex items-center justify-between gap-2 rounded-lg border px-3 py-2 text-left text-sm transition-colors"
        :class="option.id === modelValue ? 'border-primary bg-primary/5' : 'hover:border-primary/50'"
        @click="emit('update:modelValue', option.id)"
      >
        <span class="min-w-0">
          <span class="block truncate font-semibold">{{ option.name }}</span>
          <span v-if="option.factor > 1" class="block text-[11px] text-muted-foreground">= {{ option.factor }} {{ baseUnit }}</span>
        </span>
        <span class="whitespace-nowrap font-bold text-primary">{{ money(option.price) }}</span>
      </button>
    </div>
    <p v-if="stockLabel" class="text-xs text-muted-foreground">{{ stockLabel }}</p>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { ProductUnit } from "@bongcun/supabase/products";
import { qty } from "@/views/admin/inventory/format";
import { money } from "../format";
import { unitPrice, wholeUnits } from "../unitPricing";

const props = defineProps<{
  baseUnit: string;
  basePrice: number;
  units: ProductUnit[];
  /** The picked unit's id; null for the base unit. */
  modelValue: string | null;
  /** Stock in base units, when it is tracked and known. */
  stock?: number;
}>();
const emit = defineEmits<{ "update:modelValue": [id: string | null] }>();
const { t } = useI18n();

const options = computed(() => [
  { id: null as string | null, name: props.baseUnit, factor: 1, price: props.basePrice },
  ...props.units.map((unit) => ({ id: unit.id as string | null, name: unit.name, factor: unit.factor, price: unitPrice(props.basePrice, unit) })),
]);

// "Còn 35 viên (3 hộp)": what is left in base units and in the largest unit that fits.
const stockLabel = computed(() => {
  if (props.stock === undefined) return "";
  const whole = [...props.units].sort((a, b) => b.factor - a.factor).map((unit) => wholeUnits(props.stock as number, unit)).find(Boolean);
  const base = `${qty(props.stock)} ${props.baseUnit}`;
  return t("pos.catalog.inStock", { n: whole ? `${base} (${whole})` : base });
});
</script>
