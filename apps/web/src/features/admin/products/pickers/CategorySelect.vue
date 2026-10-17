<template>
  <InfiniteSelect
    :model-value="modelValue"
    :options="options"
    :placeholder="placeholder ?? $t('products.filter.pickCategory')"
    :search-placeholder="$t('productCatalog.categories.searchPlaceholder')"
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
import { useProductCategoryOptions } from "@/features/shared/products/queries/productCategories";
import { categoryLabel } from "@bongcun/supabase/products";

/** Searchable category choice; "" means no category. */
const props = defineProps<{
  modelValue: string;
  placeholder?: string;
  noneLabel?: string;
  /** Name to show for a saved choice that is not among the loaded pages (a category switched off). */
  selectedName?: string;
  disabled?: boolean;
  /** Top-level categories only, for choosing a parent. */
  rootsOnly?: boolean;
  /** A category left out of the choices (itself, when picking its parent). */
  excludeId?: string;
}>();
const emit = defineEmits<{ "update:modelValue": [value: string] }>();

const search = ref("");
const { items, loadMore, hasMore, loading, loadingMore } = useProductCategoryOptions(search, props.rootsOnly);
const options = computed(() =>
  items.value.filter((item) => item.id !== props.excludeId).map((item) => ({ value: item.id, label: categoryLabel(item) }))
);
</script>
