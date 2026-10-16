<template>
  <AppDialog
    v-model:open="open"
    :title="category ? $t('productCatalog.categories.edit') : $t('productCatalog.categories.add')"
    :ok-text="$t('petCare.common.save')"
    form-id="category-form"
    :busy="saving"
  >
    <form id="category-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-2">
        <Label for="category-name">{{ $t("productCatalog.name") }}</Label>
        <Input id="category-name" v-model="form.name" />
        <p v-if="submitted && !form.name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
      </div>
      <div class="space-y-2">
        <Label>{{ $t("productCatalog.categories.parent") }}</Label>
        <CategorySelect
          v-model="form.parentId"
          roots-only
          :exclude-id="category?.id"
          :disabled="Boolean(category && category.childCount > 0)"
          :none-label="$t('productCatalog.categories.noParent')"
          :selected-name="form.parentName"
        />
        <p v-if="category && category.childCount > 0" class="text-xs text-muted-foreground">
          {{ $t("productCatalog.categories.hasChildrenHint") }}
        </p>
      </div>
      <div class="space-y-2">
        <Label>{{ $t("productCatalog.image") }}</Label>
        <UploadFields
          folder-name="categories"
          :limit="1"
          :show-control="false"
          shared
          keep-files
          :model-value="form.imageUrl ? [form.imageUrl] : []"
          @set-images="(list: string[]) => (form.imageUrl = list[0] ?? '')"
        />
      </div>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import { toRef } from "vue";
import AppDialog from "@/components/common/AppDialog.vue";
import UploadFields from "@/components/common/UploadFields.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ProductCategory } from "@/repositories/productCategories";
import CategorySelect from "../pickers/CategorySelect.vue";
import { useCategoryForm } from "./useCategoryForm";

const props = defineProps<{ category: ProductCategory | null }>();
const open = defineModel<boolean>("open", { required: true });

const { form, submitted, saving, submit } = useCategoryForm(open, toRef(props, "category"), () => {
  open.value = false;
});
</script>
