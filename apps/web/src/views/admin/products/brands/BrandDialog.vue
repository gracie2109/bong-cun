<template>
  <AppDialog
    v-model:open="open"
    :title="brand ? $t('productCatalog.brands.edit') : $t('productCatalog.brands.add')"
    :ok-text="$t('petCare.common.save')"
    form-id="brand-form"
    :busy="saving"
  >
    <form id="brand-form" class="space-y-4" @submit.prevent="submit">
      <div class="space-y-2">
        <Label for="brand-name">{{ $t("productCatalog.name") }}</Label>
        <Input id="brand-name" v-model="form.name" />
        <p v-if="submitted && !form.name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
      </div>
      <div class="space-y-2">
        <Label>{{ $t("productCatalog.brands.logo") }}</Label>
        <UploadFields
          folder-name="brands"
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
import type { ProductBrand } from "@bongcun/supabase/products";
import { useBrandForm } from "./useBrandForm";

const props = defineProps<{ brand: ProductBrand | null }>();
const open = defineModel<boolean>("open", { required: true });

const { form, submitted, saving, submit } = useBrandForm(open, toRef(props, "brand"), () => {
  open.value = false;
});
</script>
