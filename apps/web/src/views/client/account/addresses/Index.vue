<template>
  <section class="mx-auto max-w-3xl space-y-4 pb-12">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h2 class="text-lg font-semibold">{{ $t("shop.address.title") }}</h2>
        <p class="text-sm text-muted-foreground">{{ $t("shop.address.hint", { max: MAX_ADDRESSES }) }}</p>
      </div>
      <Button :disabled="atLimit" @click="form.openNew(addresses.length === 0)">
        <Plus class="mr-1 size-4" />
        {{ $t("shop.address.add") }}
      </Button>
    </div>

    <p v-if="loading" class="py-8 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="addresses.length === 0" class="rounded-xl border border-dashed py-12 text-center text-muted-foreground">
      {{ $t("shop.address.empty") }}
    </div>
    <div v-else class="space-y-3">
      <AddressCard
        v-for="address in addresses"
        :key="address.id"
        :address="address"
        :busy="busy"
        @edit="form.openEdit(address)"
        @delete="toDelete = address"
        @make-default="makeDefault(address.id)"
      />
    </div>

    <AddressFormDialog
      v-model:open="form.open.value"
      :form="form.form"
      :errors="form.errors.value"
      :submitted="form.submitted.value"
      :saving="form.saving.value"
      :lock-default="Boolean(form.form.id) && form.form.isDefault"
      @submit="form.submit"
    />

    <DialogConfirm
      :open="toDelete !== null"
      danger
      :title="$t('shop.address.deleteTitle')"
      :desc="toDelete ? formatAddress(toDelete) : ''"
      :ok-btn="$t('shop.address.delete')"
      @handle-ok="confirmDelete"
      @open-change="toDelete = null"
      @cancel="toDelete = null"
    />
  </section>
</template>

<script lang="ts" setup>
import { Plus } from "lucide-vue-next";
import { DialogConfirm } from "@/components/common";
import AddressCard from "@/components/shop/AddressCard.vue";
import AddressFormDialog from "@/components/shop/AddressFormDialog.vue";
import { Button } from "@/components/ui/button";
import { useAddressBook } from "@/composables/shop/useAddressBook";
import { useAddressForm } from "@/composables/shop/useAddressForm";
import { MAX_ADDRESSES } from "@/types/shop";
import { formatAddress } from "@/utils/shop/address";

const { addresses, atLimit, loading, toDelete, confirmDelete, makeDefault, busy } = useAddressBook();
const form = useAddressForm();
</script>
