<template>
  <div class="fixed inset-x-0 bottom-0 z-30 border-t bg-white/95 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 backdrop-blur lg:hidden">
    <div class="flex items-center gap-3">
      <PriceDisplay class="min-w-0 flex-1" :amount="picked ? price : group.minPrice" :from="!picked && hasRange" />
      <Button class="h-12 shrink-0 rounded-full px-6 text-base" :disabled="!canAdd" @click="emit('add')">
        <ShoppingBag class="mr-2 size-5" />{{ $t("shop.addToCart") }}
      </Button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { groupHasPriceRange } from "@/utils/shop/catalog";
import { computed } from "vue";
import { ShoppingBag } from "lucide-vue-next";
import PriceDisplay from "@/components/shop/PriceDisplay.vue";
import { Button } from "@/components/ui/button";
import type { ProductGroup } from "@bongcun/supabase/products";

/** Phones: price and "add to cart" stay at the bottom of the screen while reading the page. */
const props = defineProps<{ price: number | null; group: ProductGroup; picked: boolean; canAdd: boolean }>();
const emit = defineEmits<{ add: [] }>();

const hasRange = computed(() => groupHasPriceRange(props.group));
</script>
