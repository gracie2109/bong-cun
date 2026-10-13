<template>
  <section class="space-y-3 rounded-xl border bg-white p-5">
    <h2 class="text-lg font-semibold">{{ $t("shop.checkout.items", { n: lines.length }) }}</h2>
    <ul class="divide-y">
      <li v-for="line in lines" :key="lineKey(line)" class="flex gap-3 py-3 first:pt-0 last:pb-0">
        <div class="size-14 shrink-0 overflow-hidden rounded-lg bg-muted/40">
          <img v-if="line.imageUrl" :src="line.imageUrl" alt="" class="size-full object-cover" loading="lazy" />
          <div v-else class="grid size-full place-content-center"><ImageIcon class="size-5 text-muted-foreground" /></div>
        </div>
        <div class="min-w-0 flex-1">
          <p class="line-clamp-2 text-sm font-medium">{{ line.name }}</p>
          <p v-if="line.variant || line.unitName" class="text-xs text-muted-foreground">
            {{ [line.variant, line.unitName].filter(Boolean).join(" · ") }}
          </p>
          <p class="text-xs text-muted-foreground">{{ formatPrice(line.unitPrice ?? 0) }} × {{ line.qty }}</p>
        </div>
        <p class="shrink-0 text-sm font-semibold">{{ formatPrice(lineAmount(line)) }}</p>
      </li>
    </ul>
    <router-link :to="{ name: 'cart' }" class="text-sm text-primary hover:underline">{{ $t("shop.checkout.editCart") }}</router-link>
  </section>
</template>

<script lang="ts" setup>
import { Image as ImageIcon } from "lucide-vue-next";
import { formatPrice } from "@/lib/utils";
import type { CartLineView } from "@/types/shop";
import { lineAmount, lineKey } from "@/utils/shop/cart";

defineProps<{ lines: CartLineView[] }>();
</script>
