<template>
  <FilterField :label="$t('products.col.category')">
    <CategorySelect v-model="categoryId" :none-label="$t('products.filter.allCategories')" />
  </FilterField>
  <FilterField :label="$t('products.col.brand')">
    <BrandSelect v-model="brandId" :none-label="$t('products.filter.allBrands')" />
  </FilterField>
  <label class="flex items-center gap-2 self-end pb-2 text-sm text-muted-foreground">
    <Switch v-model:checked="showArchived" />
    {{ $t("products.showArchived") }}
  </label>
</template>

<script lang="ts" setup>
import { FilterField } from "@/components/common/search-view";
import { Switch } from "@/components/ui/switch";
import BrandSelect from "./pickers/BrandSelect.vue";
import CategorySelect from "./pickers/CategorySelect.vue";

const categoryId = defineModel<string>("categoryId", { required: true });
const brandId = defineModel<string>("brandId", { required: true });
const showArchived = defineModel<boolean>("showArchived", { required: true });
</script>
