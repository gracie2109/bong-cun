<template>
  <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
    <div v-for="stat in stats" :key="stat.label" class="rounded-xl border bg-white p-3">
      <p class="text-xs text-muted-foreground">{{ $t(stat.label) }}</p>
      <p class="mt-1 text-xl font-semibold" :class="stat.danger && stat.value > 0 ? 'text-destructive' : ''">{{ stat.value }}</p>
    </div>
  </div>
  <p v-if="report.new_categories.length" class="text-sm text-muted-foreground">
    {{ $t("productImport.newCategories", { names: report.new_categories.join(", ") }) }}
  </p>
  <p v-if="report.new_brands.length" class="text-sm text-muted-foreground">
    {{ $t("productImport.newBrands", { names: report.new_brands.join(", ") }) }}
  </p>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { ImportReport } from "./importTypes";

const props = defineProps<{ report: ImportReport; errorCount: number }>();

const stats = computed(() => [
  { label: "productImport.stat.createdVariants", value: props.report.created_variants, danger: false },
  { label: "productImport.stat.updatedVariants", value: props.report.updated_variants, danger: false },
  { label: "productImport.stat.createdGroups", value: props.report.created_groups, danger: false },
  { label: "productImport.stat.errorRows", value: props.errorCount, danger: true },
]);
</script>
