<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <div v-if="isEmpty" class="grid flex-1 place-content-center gap-3 p-6 text-center">
      <span class="mx-auto grid size-20 place-content-center rounded-full bg-brand-soft text-brand"><ShoppingBag class="size-9" /></span>
      <p class="font-semibold">{{ $t("shop.cart.empty") }}</p>
    </div>
    <div v-else-if="loading" class="space-y-3 p-5" aria-hidden="true"><div v-for="n in 3" :key="n" class="shop-skeleton h-14 rounded-xl" /></div>

    <template v-else>
      <ul class="min-h-0 flex-1 space-y-3 overflow-y-auto p-5">
        <li v-for="line in firstLines" :key="lineKey(line)" class="flex gap-3" :class="{ 'opacity-60': !line.isSellable }">
          <div class="size-14 shrink-0 overflow-hidden rounded-xl bg-white ring-1 ring-border/70">
            <img v-if="line.imageUrl" :src="line.imageUrl" alt="" class="size-full object-contain p-1" loading="lazy" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="line-clamp-1 text-sm font-semibold">{{ line.name }}</p>
            <p class="text-xs text-muted-foreground">
              {{ [line.variant, line.unitId ? line.unitName : null].filter(Boolean).join(" · ") }}
            </p>
            <p class="text-xs">
              <span v-if="line.isSellable">{{ line.qty }} × {{ formatPrice(line.unitPrice ?? 0) }}</span>
              <span v-else class="text-destructive">{{ $t("shop.cart.unavailable") }}</span>
            </p>
          </div>
        </li>
        <li v-if="lines.length > firstLines.length" class="text-center text-xs text-muted-foreground">
          {{ $t("shop.cart.more", { n: lines.length - firstLines.length }) }}
        </li>
      </ul>

      <div class="space-y-3 border-t p-5">
        <div class="flex items-baseline justify-between">
          <span class="text-sm text-muted-foreground">{{ $t("shop.cart.subtotal") }}</span>
          <span class="text-xl font-extrabold tracking-tight tabular-nums">{{ formatPrice(subtotal) }}</span>
        </div>
        <Button class="h-12 w-full rounded-full text-base font-semibold" @click="openCart">{{ $t("shop.cart.viewCart") }}</Button>
      </div>
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed, watch } from "vue";
import { useRouter } from "vue-router";
import { ShoppingBag } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { useCartView } from "@/composables/shop/useCartView";
import { formatPrice } from "@/lib/utils";
import { useCart } from "@/stores";
import { lineKey } from "@/utils/shop/cart";

const MINI_LINES = 5;

const props = defineProps<{ active: boolean }>();
const emit = defineEmits<{ navigate: [] }>();

const router = useRouter();
const cart = useCart();
const { lines, loading, subtotal, refresh } = useCartView();

const isEmpty = computed(() => cart.lines.length === 0);
const firstLines = computed(() => lines.value.slice(0, MINI_LINES));

// Opening the panel re-reads price and stock, so it never shows a stale price.
watch(
  () => props.active,
  (open) => {
    if (open && !isEmpty.value) void refresh();
  }
);

const openCart = () => {
  void router.push({ name: "cart" });
  emit("navigate");
};
</script>
