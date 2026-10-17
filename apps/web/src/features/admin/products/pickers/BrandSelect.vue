<template>
  <InfiniteSelect
    :model-value="modelValue"
    :options="options"
    :placeholder="placeholder ?? $t('products.filter.pickBrand')"
    :search-placeholder="$t('productCatalog.brands.searchPlaceholder')"
    :none-label="noneLabel"
    :selected-fallback="selectedName || $t('products.filter.selected')"
    :has-more="hasMore"
    :loading="loading"
    :loading-more="loadingMore"
    :disabled="disabled"
    @update:model-value="emit('update:modelValue', $event)"
    @update:search="search = $event"
    @load-more="loadMore"
  />
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import InfiniteSelect from "@/components/common/InfiniteSelect.vue";
import { useProductBrandOptions } from "@/features/shared/products";

/** Searchable brand choice; "" means no brand. */
defineProps<{
  modelValue: string;
  placeholder?: string;
  noneLabel?: string;
  /** Name to show for a saved choice that is not among the loaded pages (a brand switched off). */
  selectedName?: string;
  disabled?: boolean;
}>();
const emit = defineEmits<{ "update:modelValue": [value: string] }>();

const search = ref("");
const { items, loadMore, hasMore, loading, loadingMore } = useProductBrandOptions(search);
const options = computed(() => items.value.map((item) => ({ value: item.id, label: item.name })));
</script>
