<template>
  <div class="space-y-6">
    <ProductAttributesEditor v-model:attributes="attributes" :known-attributes="knownAttributes" :submitted="submitted" />
    <ProductVariantsTable v-model:rows="rows" v-model:bulk="bulk" :submitted="submitted" />
  </div>
</template>

<script lang="ts" setup>
import type { ProductAttribute } from "@/repositories/products";
import ProductAttributesEditor from "../ProductAttributesEditor.vue";
import type { AttributeForm, VariantRow } from "../productVariantForm";
import ProductVariantsTable from "../ProductVariantsTable.vue";

/** Attributes of the group and the table of variants made from their values. */
defineProps<{ knownAttributes: ProductAttribute[]; submitted: boolean }>();

const attributes = defineModel<AttributeForm[]>("attributes", { required: true });
const rows = defineModel<VariantRow[]>("rows", { required: true });
const bulk = defineModel<{ price: string; unit: string }>("bulk", { required: true });
</script>
