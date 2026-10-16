<template>
  <p class="text-sm text-muted-foreground">
    {{ $t("productImport.stat.createdGroups") }}: {{ extra.created_groups ?? 0 }}
  </p>
  <p v-if="extra.new_categories?.length" class="text-sm text-muted-foreground">
    {{ $t("productImport.newCategories", { names: extra.new_categories.join(", ") }) }}
  </p>
  <p v-if="extra.new_brands?.length" class="text-sm text-muted-foreground">
    {{ $t("productImport.newBrands", { names: extra.new_brands.join(", ") }) }}
  </p>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { ImportReport } from "@/lib/data-io/types";

const props = defineProps<{ report: ImportReport }>();

const extra = computed(
  () => (props.report.extra ?? {}) as { created_groups?: number; new_categories?: string[]; new_brands?: string[] }
);
</script>
