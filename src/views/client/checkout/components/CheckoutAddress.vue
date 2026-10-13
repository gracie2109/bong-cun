<template>
  <section class="space-y-3 rounded-xl border bg-white p-5">
    <div class="flex items-center justify-between gap-2">
      <h2 class="text-lg font-semibold">{{ $t("shop.checkout.address") }}</h2>
      <Button v-if="address.selected.value" variant="ghost" size="sm" @click="address.pickerOpen.value = true">
        {{ $t("shop.checkout.changeAddress") }}
      </Button>
    </div>

    <p v-if="address.loading.value" class="text-sm text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <AddressCard v-else-if="address.selected.value" :address="address.selected.value" hide-actions />
    <div v-else class="space-y-2">
      <p class="text-sm text-muted-foreground">{{ $t("shop.checkout.noAddress") }}</p>
      <Button variant="outline" @click="address.addNew()">{{ $t("shop.address.add") }}</Button>
    </div>
    <p v-if="showError && !address.selected.value" class="text-xs text-red-600">{{ $t("shop.checkout.errors.address_not_found") }}</p>

    <AddressPickerDialog
      v-model:open="address.pickerOpen.value"
      :addresses="address.addresses.value"
      :selected-id="address.selected.value?.id ?? null"
      @pick="address.pick"
      @add="address.addNew()"
    />
    <AddressFormDialog
      v-model:open="address.form.open.value"
      :form="address.form.form"
      :errors="address.form.errors.value"
      :submitted="address.form.submitted.value"
      :saving="address.form.saving.value"
      :lock-default="address.addresses.value.length === 0"
      @submit="address.form.submit()"
    />
  </section>
</template>

<script lang="ts" setup>
import AddressCard from "@/components/shop/AddressCard.vue";
import AddressFormDialog from "@/components/shop/AddressFormDialog.vue";
import { Button } from "@/components/ui/button";
import type { useCheckoutAddress } from "@/composables/shop/useCheckoutAddress";
import AddressPickerDialog from "./AddressPickerDialog.vue";

defineProps<{ address: ReturnType<typeof useCheckoutAddress>; showError: boolean }>();
</script>
