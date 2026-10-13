<template>
  <section class="space-y-3 rounded-xl border bg-white p-5">
    <h2 class="text-lg font-semibold">{{ $t("shop.checkout.method") }}</h2>
    <div class="grid gap-3 sm:grid-cols-2">
      <button
        v-for="item in methods"
        :key="item"
        type="button"
        class="rounded-lg border p-4 text-left transition"
        :class="item === method ? 'border-primary bg-primary/5 ring-1 ring-primary' : 'hover:border-primary/50'"
        @click="$emit('update', item)"
      >
        <p class="flex items-center gap-2 font-semibold">
          <component :is="item === 'delivery' ? Truck : Store" class="size-4" />
          {{ $t(`shop.checkout.methods.${item}`) }}
        </p>
        <p class="mt-1 text-sm text-muted-foreground">{{ $t(`shop.checkout.methodHint.${item}`) }}</p>
      </button>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { Store, Truck } from "lucide-vue-next";
import type { DeliveryMethod } from "@/types/shopOrder";

defineProps<{ methods: DeliveryMethod[]; method: DeliveryMethod }>();
defineEmits<{ update: [method: DeliveryMethod] }>();
</script>
