<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-5xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ groupId ? $t("products.edit") : $t("products.add") }}</SheetTitle>
        <SheetDescription>{{ $t("products.subtitle") }}</SheetDescription>
      </SheetHeader>

      <div v-if="groupId && groupQuery.isPending.value" class="space-y-3 p-6">
        <Skeleton v-for="i in 4" :key="i" class="h-10 w-full" />
      </div>

      <form v-else id="product-group-form" class="flex-1 space-y-6 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <!-- General -->
        <section class="grid gap-4 md:grid-cols-[1fr_auto]">
          <div class="space-y-4">
            <div class="space-y-2">
              <Label for="group-name">{{ $t("products.form.name") }}</Label>
              <Input id="group-name" v-model="form.name" />
              <p v-if="submitted && !form.name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
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
              :model-value="toImages(form.imageUrl)"
              @set-images="(list: string[]) => (form.imageUrl = list[0] ?? '')"
            />
          </div>
        </section>

        <ProductAttributesEditor v-model:attributes="attributes" :known-attributes="knownAttributes" :submitted="submitted" />

        <ProductVariantsTable v-model:rows="rows" v-model:bulk="bulk" :submitted="submitted" />
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">{{ $t("petCare.common.cancel") }}</Button>
        <Button type="submit" form="product-group-form" :disabled="mutation.isPending.value || (Boolean(groupId) && groupQuery.isPending.value)">
          {{ $t("petCare.common.save") }}
        </Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Textarea } from "@/components/ui/textarea";
import { useProductAttributes, useProductGroup, useSaveProductGroup } from "@/queries/products";
import type { ProductGroup } from "@/repositories/products";
import UploadFields from "@/components/common/UploadFields.vue";
import { parseAmount } from "@/views/admin/pos/format";
import ProductAttributesEditor from "./ProductAttributesEditor.vue";
import { attributeError, commitDraft } from "./productVariantForm";
import ProductVariantsTable from "./ProductVariantsTable.vue";
import { useProductVariants } from "./useProductVariants";

/** The single-image list the upload box shows. */
const toImages = (url: string) => (url ? [url] : []);

const props = defineProps<{ open: boolean; groupId: string | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();
const { t } = useI18n();

const form = reactive({ name: "", desc: "", imageUrl: "", isActive: true });
const { attributes, rows, bulk, fill: fillVariants } = useProductVariants();
const submitted = ref(false);

const groupQuery = useProductGroup(computed(() => (props.open && props.groupId) || undefined));
const attributesQuery = useProductAttributes();
const knownAttributes = computed(() => attributesQuery.data.value ?? []);
const mutation = useSaveProductGroup();

const fill = (group: ProductGroup | null) => {
  form.name = group?.name ?? "";
  form.desc = group?.desc ?? "";
  form.imageUrl = group?.imageUrl ?? "";
  form.isActive = group?.isActive ?? true;
  submitted.value = false;
  fillVariants(group);
};

watch(
  () => [props.open, props.groupId, groupQuery.data.value] as const,
  ([open, groupId, group]) => {
    if (!open) return;
    if (!groupId) fill(null);
    else if (group && group.id === groupId) fill(group);
  },
  { immediate: true }
);

const submit = async () => {
  for (const attribute of attributes.value) commitDraft(attribute);
  submitted.value = true;
  if (!form.name.trim()) return;
  if (attributes.value.some((attribute) => attributeError(attributes.value, attribute, t))) return;
  if (rows.value.some((row) => !row.unit.trim())) return;

  try {
    await mutation.mutateAsync({
      id: props.groupId ?? undefined,
      name: form.name,
      desc: form.desc,
      imageUrl: form.imageUrl,
      isActive: form.isActive,
      attributes: attributes.value.map((attribute) => ({ name: attribute.name.trim(), values: attribute.values })),
      variants: rows.value.map((row) => ({
        id: row.id,
        options: row.options,
        sku: row.sku,
        barcode: row.barcode,
        unit: row.unit,
        price: parseAmount(row.price),
        trackStock: row.trackStock,
        isActive: row.isActive,
        imageUrl: row.imageUrl,
      })),
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
