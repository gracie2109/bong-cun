<template>
  <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
    <div class="relative min-w-60 flex-1">
      <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <Input v-model="search" class="pl-9" :placeholder="$t('products.searchPlaceholder')" />
    </div>
    <div class="w-52">
      <CategorySelect v-model="categoryId" :none-label="$t('products.filter.allCategories')" />
    </div>
    <div class="w-48">
      <BrandSelect v-model="brandId" :none-label="$t('products.filter.allBrands')" />
    </div>
    <label class="flex items-center gap-2 text-sm text-muted-foreground">
      <Switch v-model:checked="showArchived" />
      {{ $t("products.showArchived") }}
    </label>
  </div>
</template>

<script lang="ts" setup>
import { Search } from "lucide-vue-next";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import BrandSelect from "./pickers/BrandSelect.vue";
import CategorySelect from "./pickers/CategorySelect.vue";

const search = defineModel<string>("search", { required: true });
const categoryId = defineModel<string>("categoryId", { required: true });
const brandId = defineModel<string>("brandId", { required: true });
const showArchived = defineModel<boolean>("showArchived", { required: true });
</script>
