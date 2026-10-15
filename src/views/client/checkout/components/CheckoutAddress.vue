<template>
  <CheckoutSection :step="2" :title="$t('shop.checkout.address')">
    <template #action>
      <Button
        v-if="address.selected.value"
        variant="ghost"
        size="sm"
        class="rounded-full font-semibold text-primary hover:text-primary"
        @click="address.pickerOpen.value = true"
      >
        {{ $t("shop.checkout.changeAddress") }}
      </Button>
    </template>

    <div v-if="address.loading.value" class="shop-skeleton h-24 rounded-2xl" aria-hidden="true" />
    <AddressCard v-else-if="address.selected.value" :address="address.selected.value" hide-actions />
    <div v-else class="flex flex-col items-start gap-3 rounded-2xl border border-dashed p-4 sm:flex-row sm:items-center sm:justify-between">
      <p class="flex items-center gap-2 text-sm text-muted-foreground"><MapPin class="size-4 shrink-0" />{{ $t("shop.checkout.noAddress") }}</p>
      <Button class="h-10 rounded-full px-5" @click="address.addNew()"><Plus class="mr-1.5 size-4" />{{ $t("shop.address.add") }}</Button>
    </div>
    <p v-if="showError && !address.selected.value" class="mt-2 text-sm font-medium text-destructive" role="alert">
      {{ $t("shop.checkout.errors.address_not_found") }}
    </p>

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
  </CheckoutSection>
</template>

<script lang="ts" setup>
import { MapPin, Plus } from "lucide-vue-next";
import AddressCard from "@/components/shop/AddressCard.vue";
import AddressFormDialog from "@/components/shop/AddressFormDialog.vue";
import { Button } from "@/components/ui/button";
import type { useCheckoutAddress } from "@/composables/shop/useCheckoutAddress";
import AddressPickerDialog from "./AddressPickerDialog.vue";
import CheckoutSection from "./CheckoutSection.vue";

defineProps<{ address: ReturnType<typeof useCheckoutAddress>; showError: boolean }>();
</script>
