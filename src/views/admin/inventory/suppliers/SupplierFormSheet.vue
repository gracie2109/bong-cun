<template>
  <Sheet :open="open" @update:open="emit('update:open', $event)">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-lg">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ supplier ? $t("inventory.suppliers.edit") : $t("inventory.suppliers.add") }}</SheetTitle>
        <SheetDescription>{{ $t("inventory.suppliers.subtitle") }}</SheetDescription>
      </SheetHeader>

      <form id="supplier-form" class="flex-1 space-y-5 overflow-y-auto px-6 py-5" @submit.prevent="submit">
        <div class="space-y-2">
          <Label for="supplier-name">{{ $t("inventory.suppliers.name") }}</Label>
          <Input id="supplier-name" v-model="form.name" />
          <p v-if="submitted && !form.name.trim()" class="text-sm text-red-600">{{ $t("petCare.common.required") }}</p>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label for="supplier-phone">{{ $t("inventory.suppliers.phone") }}</Label>
            <Input id="supplier-phone" v-model="form.phone" inputmode="tel" />
          </div>
          <div class="space-y-2">
            <Label for="supplier-email">{{ $t("inventory.suppliers.email") }}</Label>
            <Input id="supplier-email" v-model="form.email" type="email" />
          </div>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="space-y-2">
            <Label for="supplier-tax">{{ $t("inventory.suppliers.taxCode") }}</Label>
            <Input id="supplier-tax" v-model="form.taxCode" />
          </div>
          <div class="space-y-2">
            <Label for="supplier-address">{{ $t("inventory.suppliers.address") }}</Label>
            <Input id="supplier-address" v-model="form.address" />
          </div>
        </div>
        <div class="space-y-2">
          <Label for="supplier-note">{{ $t("inventory.documents.note") }}</Label>
          <Textarea id="supplier-note" v-model="form.note" rows="3" class="resize-none" />
        </div>
      </form>

      <SheetFooter class="gap-2 border-t px-6 py-4">
        <Button type="button" variant="outline" @click="emit('update:open', false)">{{ $t("petCare.common.cancel") }}</Button>
        <Button type="submit" form="supplier-form" :disabled="mutation.isPending.value">{{ $t("petCare.common.save") }}</Button>
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
import { useSaveSupplier } from "@/queries/inventory";
import type { Supplier } from "@/repositories/inventory";

const props = defineProps<{ open: boolean; supplier: Supplier | null }>();
const emit = defineEmits<{ "update:open": [value: boolean] }>();

const form = reactive({ name: "", phone: "", email: "", taxCode: "", address: "", note: "" });
const submitted = ref(false);
const mutation = useSaveSupplier();

watch(
  () => props.open,
  (open) => {
    if (!open) return;
    const supplier = props.supplier;
    form.name = supplier?.name ?? "";
    form.phone = supplier?.phone ?? "";
    form.email = supplier?.email ?? "";
    form.taxCode = supplier?.taxCode ?? "";
    form.address = supplier?.address ?? "";
    form.note = supplier?.note ?? "";
    submitted.value = false;
  }
);

const submit = async () => {
  submitted.value = true;
  if (!form.name.trim()) return;
  try {
    await mutation.mutateAsync({
      id: props.supplier?.id,
      input: { ...form, isActive: props.supplier?.isActive ?? true },
    });
    emit("update:open", false);
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
