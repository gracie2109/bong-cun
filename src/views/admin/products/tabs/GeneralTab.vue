<template>
  <div class="grid gap-4 md:grid-cols-[1fr_auto]">
    <div class="space-y-4">
      <div class="space-y-2">
        <Label for="group-name">{{ $t("products.form.name") }}</Label>
        <Input id="group-name" v-model="form.name" />
        <p v-if="submitted && !form.name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
      </div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-2">
          <Label>{{ $t("products.form.category") }}</Label>
          <CategorySelect
            v-model="form.categoryId"
            :none-label="$t('products.form.noCategory')"
            :selected-name="form.categoryName"
          />
        </div>
        <div class="space-y-2">
          <Label>{{ $t("products.form.brand") }}</Label>
          <BrandSelect v-model="form.brandId" :none-label="$t('products.form.noBrand')" :selected-name="form.brandName" />
        </div>
      </div>
      <div class="space-y-2">
        <Label for="group-desc">{{ $t("products.form.desc") }}</Label>
        <Textarea id="group-desc" v-model="form.desc" rows="2" class="resize-none" />
      </div>
    </div>
    <div class="space-y-2">
      <Label>{{ $t("products.form.image") }}</Label>
      <UploadFields
        folder-name="products"
        :limit="1"
        :show-control="false"
        keep-files
        :model-value="form.imageUrl ? [form.imageUrl] : []"
        @set-images="(list: string[]) => (form.imageUrl = list[0] ?? '')"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import UploadFields from "@/components/common/UploadFields.vue";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import BrandSelect from "../pickers/BrandSelect.vue";
import CategorySelect from "../pickers/CategorySelect.vue";

/** The group's own fields: name, category, brand, description and its cover image. */
defineProps<{
  form: {
    name: string;
    desc: string;
    imageUrl: string;
    categoryId: string;
    categoryName: string;
    brandId: string;
    brandName: string;
  };
  submitted: boolean;
}>();
</script>
