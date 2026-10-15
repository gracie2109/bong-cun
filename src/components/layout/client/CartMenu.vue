<template>
  <button
    type="button"
    class="relative grid size-11 place-content-center rounded-full text-foreground transition-colors hover:bg-muted"
    :aria-label="$t('client.header.cartWithCount', { n: count })"
    @click="open = true"
  >
    <ShoppingBag class="size-[22px]" :stroke-width="1.8" />
    <Transition name="badge">
      <span
        v-if="count > 0"
        :key="count"
        class="absolute right-0.5 top-0.5 grid h-5 min-w-5 place-content-center rounded-full bg-primary px-1 text-[11px] font-bold tabular-nums text-white ring-2 ring-white"
      >
        {{ count > 99 ? "99+" : count }}
      </span>
    </Transition>
  </button>

  <Sheet :open="open" @update:open="(value) => (open = value)">
    <SheetContent class="flex w-full flex-col gap-0 p-0 sm:max-w-[440px]">
      <SheetHeader class="border-b px-5 py-4 text-left">
        <SheetTitle class="text-lg font-bold">{{ $t("shop.cart.title") }} ({{ count }})</SheetTitle>
      </SheetHeader>
      <MiniCartPanel :active="open" @navigate="open = false" />
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { ShoppingBag } from "lucide-vue-next";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { useCart } from "@/stores";
import MiniCartPanel from "./MiniCartPanel.vue";

const cart = useCart();
const open = ref(false);
const count = computed(() => cart.lines.length);
</script>

<style scoped>
.badge-enter-active {
  animation: shop-pop 320ms var(--ease-pop);
}
</style>
