<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-lg">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ product ? $t("products.edit") : $t("products.add") }}</SheetTitle>
        <SheetDescription>{{ $t("products.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="product-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="product-name">{{ $t("products.form.name") }}</Label>
          <Input id="product-name" v-model="form.name" />
          <p v-if="submitted && !form.name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label for="product-sku">{{ $t("products.form.sku") }}</Label>
            <Input id="product-sku" v-model="form.sku" />
          </div>
          <div class="space-y-2">
            <Label for="product-barcode">{{ $t("products.form.barcode") }}</Label>
            <Input id="product-barcode" v-model="form.barcode" />
          </div>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label for="product-price">{{ $t("products.form.price") }}</Label>
            <Input id="product-price" v-model="form.price" inputmode="numeric" />
            <p class="text-xs text-muted-foreground">{{ money(parseAmount(form.price)) }}</p>
          </div>
          <div class="space-y-2">
            <Label for="product-unit">{{ $t("products.form.unit") }}</Label>
            <Input id="product-unit" v-model="form.unit" />
            <p v-if="submitted && !form.unit.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
          </div>
        </div>
        <div class="space-y-2">
          <Label for="product-desc">{{ $t("products.form.desc") }}</Label>
          <Textarea id="product-desc" v-model="form.desc" rows="3" class="resize-none" />
        </div>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">{{ $t("petCare.common.cancel") }}</Button>
        <Button type="submit" form="product-form" :disabled="mutation.isPending.value">{{ $t("petCare.common.save") }}</Button>
      </SheetFooter>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { reactive, ref, watch } from "vue";
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
import { Textarea } from "@/components/ui/textarea";
import { useSaveProduct } from "@/queries/products";
import type { Product } from "@/repositories/products";
import { money, parseAmount } from "@/views/admin/pos/format";

const DEFAULT_UNIT = "cái";

const props = defineProps<{ open: boolean; product: Product | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const form = reactive({ name: "", sku: "", barcode: "", price: "", unit: DEFAULT_UNIT, desc: "" });
const submitted = ref(false);
const mutation = useSaveProduct();

watch(
  () => props.open,
  (open) => {
    if (!open) return;
    const product = props.product;
    form.name = product?.name ?? "";
    form.sku = product?.sku ?? "";
    form.barcode = product?.barcode ?? "";
    form.price = product ? String(product.price) : "";
    form.unit = product?.unit ?? DEFAULT_UNIT;
    form.desc = product?.desc ?? "";
    submitted.value = false;
  }
);

const submit = async () => {
  submitted.value = true;
  if (!form.name.trim() || !form.unit.trim()) return;
  try {
    await mutation.mutateAsync({
      id: props.product?.id,
      input: {
        name: form.name,
        sku: form.sku,
        barcode: form.barcode,
        price: parseAmount(form.price),
        unit: form.unit,
        desc: form.desc,
        isActive: props.product?.isActive ?? true,
      },
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
