<template>
  <CheckoutSection :step="1" :title="$t('shop.checkout.method')">
    <div class="grid gap-3 sm:grid-cols-2">
      <button
        v-for="item in methods"
        :key="item"
        type="button"
        class="relative flex gap-3 rounded-2xl border-2 p-4 text-left transition-colors duration-200"
        :class="item === method ? 'border-foreground bg-secondary/60' : 'border-border hover:border-foreground/40'"
        :aria-pressed="item === method"
        @click="$emit('update', item)"
      >
        <span
          class="grid size-10 shrink-0 place-content-center rounded-full"
          :class="item === method ? 'bg-foreground text-white' : 'bg-muted text-foreground'"
        >
          <component :is="item === 'delivery' ? Truck : Store" class="size-5" />
        </span>
        <span class="min-w-0">
          <span class="block font-semibold">{{ $t(`shop.checkout.methods.${item}`) }}</span>
          <span class="mt-0.5 block text-sm text-muted-foreground">{{ $t(`shop.checkout.methodHint.${item}`) }}</span>
        </span>
        <CheckCircle2 v-if="item === method" class="absolute right-3 top-3 size-5 text-sage" aria-hidden="true" />
      </button>
    </div>
  </CheckoutSection>
</template>

<script lang="ts" setup>
import { CheckCircle2, Store, Truck } from "lucide-vue-next";
import type { DeliveryMethod } from "@/types/shopOrder";
import CheckoutSection from "./CheckoutSection.vue";

defineProps<{ methods: DeliveryMethod[]; method: DeliveryMethod }>();
defineEmits<{ update: [method: DeliveryMethod] }>();
</script>
