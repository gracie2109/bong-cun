<template>
  <AppDialog v-model:open="open" :title="$t('shop.checkout.pickAddress')" size="xl" hide-footer>
    <div class="space-y-3">
      <button
        v-for="item in addresses"
        :key="item.id"
        type="button"
        class="block w-full text-left"
        @click="$emit('pick', item.id)"
      >
        <AddressCard :address="item" :selected="item.id === selectedId" hide-actions />
      </button>
      <Button variant="outline" class="w-full" @click="$emit('add')">{{ $t("shop.address.add") }}</Button>
    </div>
  </AppDialog>
</template>

<script lang="ts" setup>
import AppDialog from "@/components/common/AppDialog.vue";
import AddressCard from "@/components/shop/AddressCard.vue";
import { Button } from "@/components/ui/button";
import type { Address } from "@bongcun/core/shop";

const open = defineModel<boolean>("open", { required: true });
defineProps<{ addresses: Address[]; selectedId: string | null }>();
defineEmits<{ pick: [id: string]; add: [] }>();
</script>
