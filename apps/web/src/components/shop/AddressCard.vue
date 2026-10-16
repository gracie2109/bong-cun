<template>
  <div
    class="flex flex-col gap-3 rounded-xl border bg-white p-4 sm:flex-row sm:items-start sm:justify-between"
    :class="selected ? 'border-primary ring-1 ring-primary' : ''"
  >
    <div class="min-w-0 space-y-1">
      <p class="flex flex-wrap items-center gap-2 font-semibold">
        {{ address.receiverName }}
        <span class="font-normal text-muted-foreground">{{ address.phone }}</span>
        <span v-if="address.isDefault" class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-semibold text-primary">
          {{ $t("shop.address.default") }}
        </span>
      </p>
      <p class="text-sm text-muted-foreground">{{ formatAddress(address) }}</p>
    </div>
    <div v-if="!hideActions" class="flex shrink-0 flex-wrap items-center gap-1 text-sm">
      <Button v-if="!address.isDefault" variant="ghost" size="sm" :disabled="busy" @click="$emit('makeDefault')">
        {{ $t("shop.address.makeDefault") }}
      </Button>
      <Button variant="ghost" size="sm" @click="$emit('edit')">{{ $t("shop.address.edit") }}</Button>
      <Button variant="ghost" size="sm" class="text-red-600 hover:text-red-700" :disabled="busy" @click="$emit('delete')">
        {{ $t("shop.address.delete") }}
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { Address } from "@bongcun/core/shop";
import { formatAddress } from "@bongcun/core/shop";

defineProps<{ address: Address; selected?: boolean; hideActions?: boolean; busy?: boolean }>();
defineEmits<{ edit: []; delete: []; makeDefault: [] }>();
</script>
