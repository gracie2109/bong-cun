<template>
  <CheckoutSection :step="3" :title="$t('shop.checkout.items', { n: lines.length })">
    <template #action>
      <RouterLink :to="{ name: 'cart' }" class="text-sm font-semibold text-primary hover:underline">{{ $t("shop.checkout.editCart") }}</RouterLink>
    </template>
    <ul class="divide-y">
      <li v-for="line in lines" :key="lineKey(line)" class="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
        <div class="relative size-16 shrink-0 overflow-hidden rounded-xl bg-white ring-1 ring-border/70">
          <img v-if="line.imageUrl" :src="line.imageUrl" alt="" class="size-full object-contain p-1" loading="lazy" />
          <div v-else class="grid size-full place-content-center bg-brand-soft text-brand"><PawMark class="size-6" /></div>
          <span class="absolute right-0 top-0 grid min-w-5 place-content-center rounded-bl-lg bg-foreground px-1 text-[11px] font-bold text-white">
            {{ line.qty }}
          </span>
        </div>
        <div class="min-w-0 flex-1">
          <p class="line-clamp-2 text-sm font-semibold">{{ line.name }}</p>
          <p v-if="line.variant || line.unitName" class="text-xs text-muted-foreground">
            {{ [line.variant, line.unitName].filter(Boolean).join(" · ") }}
          </p>
          <p class="text-xs text-muted-foreground">{{ formatPrice(line.unitPrice ?? 0) }} × {{ line.qty }}</p>
        </div>
        <p class="shrink-0 text-sm font-bold tabular-nums">{{ formatPrice(lineAmount(line)) }}</p>
      </li>
    </ul>
  </CheckoutSection>
</template>

<script lang="ts" setup>
import PawMark from "@/components/shop/PawMark.vue";
import { formatPrice } from "@/lib/utils";
import type { CartLineView } from "@bongcun/core/shop";
import { lineAmount, lineKey } from "@/utils/shop/cart";
import CheckoutSection from "./CheckoutSection.vue";

defineProps<{ lines: CartLineView[] }>();
</script>
