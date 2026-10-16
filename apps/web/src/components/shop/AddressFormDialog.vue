<template>
  <AppDialog
    v-model:open="open"
    :title="form.id ? $t('shop.address.editTitle') : $t('shop.address.addTitle')"
    size="xl"
    :ok-text="$t('petCare.common.save')"
    :cancel-text="$t('petCare.common.cancel')"
    :busy="saving"
    form-id="address-form"
  >
    <form id="address-form" class="space-y-4" @submit.prevent="$emit('submit')">
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="addr-name">{{ $t("shop.address.receiver") }}</Label>
          <Input id="addr-name" v-model="form.receiverName" autocomplete="name" />
          <p v-if="submitted && errors.receiverName" class="text-xs text-red-600">{{ $t("petCare.common.required") }}</p>
        </div>
        <div class="space-y-1.5">
          <Label for="addr-phone">{{ $t("shop.address.phone") }}</Label>
          <Input id="addr-phone" v-model="form.phone" inputmode="tel" autocomplete="tel" />
          <p v-if="submitted && errors.phone" class="text-xs text-red-600">{{ $t("shop.address.errors.invalid_phone") }}</p>
        </div>
      </div>

      <div class="space-y-1.5">
        <GhnLocationPicker v-model="form.location" />
        <p v-if="submitted && errors.location" class="text-xs text-red-600">{{ $t("shop.address.errors.address_location") }}</p>
      </div>

      <div class="space-y-1.5">
        <Label for="addr-street">{{ $t("shop.address.street") }}</Label>
        <Input id="addr-street" v-model="form.street" autocomplete="street-address" />
        <p v-if="submitted && errors.street" class="text-xs text-red-600">{{ $t("petCare.common.required") }}</p>
      </div>

      <label class="flex items-center gap-2 text-sm">
        <Checkbox v-model:checked="form.isDefault" :disabled="lockDefault" />
        {{ $t("shop.address.setDefault") }}
      </label>
    </form>
  </AppDialog>
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import GhnLocationPicker from "@/components/common/GhnLocationPicker.vue";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { AddressErrors, AddressForm } from "@bongcun/core/shop";

defineProps<{
  form: AddressForm;
  errors: AddressErrors;
  submitted: boolean;
  saving: boolean;
  /** The default address stays the default; the box is ticked and cannot be cleared. */
  lockDefault?: boolean;
}>();
defineEmits<{ submit: [] }>();

const open = defineModel<boolean>("open", { required: true });
</script>
