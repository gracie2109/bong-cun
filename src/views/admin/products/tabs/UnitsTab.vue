<template>
  <section class="space-y-4">
    <div>
      <h3 class="font-semibold">{{ $t("products.units.title") }}</h3>
      <p class="text-xs text-muted-foreground">{{ $t("products.units.hint") }}</p>
    </div>

    <div class="flex flex-wrap items-end gap-3">
      <div v-if="rows.length > 1" class="space-y-1">
        <Label>{{ $t("products.units.variant") }}</Label>
        <Select v-model="pickedKey">
          <SelectTrigger class="w-64"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="row in rows" :key="row.key" :value="row.key">
              {{ row.options.join(" / ") || $t("products.variants.default") }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <Button v-if="rows.length > 1 && current && current.units.length" type="button" variant="outline" size="sm" @click="copyToAll">
        {{ $t("products.units.copyAll") }}
      </Button>
    </div>

    <UnitsTable
      v-if="current"
      v-model:rows="current.units"
      :base-unit="current.unit || '—'"
      :base-price="parseAmount(current.price)"
      :submitted="submitted"
    />
  </section>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { parseAmount } from "@/views/admin/pos/format";
import type { VariantRow } from "../productVariantForm";
import { copyUnitRows } from "../units/productUnitForm";
import UnitsTable from "../units/UnitsTable.vue";

/** Conversion units (hộp, thùng...) of one variant at a time. */
defineProps<{ submitted: boolean }>();
const rows = defineModel<VariantRow[]>("rows", { required: true });

const pickedKey = ref("");
// Keep a valid variant picked as the variants change.
watch(
  () => rows.value.map((row) => row.key),
  (keys) => {
    if (!keys.includes(pickedKey.value)) pickedKey.value = keys[0] ?? "";
  },
  { immediate: true }
);
const current = computed(() => rows.value.find((row) => row.key === pickedKey.value) ?? rows.value[0]);

const copyToAll = () => {
  const source = current.value;
  if (!source) return;
  for (const row of rows.value) if (row !== source) row.units = copyUnitRows(source.units);
};
</script>
